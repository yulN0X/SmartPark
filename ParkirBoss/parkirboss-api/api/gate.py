"""
Gate API — Entry & Exit endpoints.
Implements the full verification pipeline:
  ① ANPR + OCR  →  ② Confidence check  →  ③ DB Lookup  →
  ④ Duplicate check  →  ⑤ GPS Verify  →  ⑥ Action + Audit
"""

import math
import os
import threading
import time
from datetime import datetime
from fastapi import APIRouter, Depends, File, Form, Header, HTTPException, UploadFile
from sqlalchemy.orm import Session

from core.database import get_db
from models.domain import (
    Vehicle, ParkingSession, User, GateLocation, ParkingRate,
    Transaction, SessionStatus, EntryMethod, TransactionType, GateType,
    Device, DeviceStatus, GateEvent, UserLocation,
)
from services.vision import detect_plate
from services.gps import verify_location
from services.plate import normalize_plate
from api.auth import get_current_user

router = APIRouter(prefix="/api/gate", tags=["gate"])

# ── Configuration ────────────────────────────────────────────────────
# The detector running on the ESP32/RPi capture path is calibrated separately
# from the server-side YOLO model. 0.85 rejected valid plates in the 0.42–0.78
# range during the live gate test. Keep the threshold configurable so a
# production deployment can tighten it after calibration.
MIN_ANPR_CONFIDENCE = float(os.getenv("MIN_ANPR_CONFIDENCE", "0.40"))
GPS_FRESHNESS_SECONDS = 120         # user location must be ≤ 120 s old
GPS_MAX_ACCURACY_METERS = 50        # reject if GPS accuracy > 50 m
ANTI_DUPLICATE_SECONDS = 5          # ignore same plate+gate within 5 s

# ── Anti-duplicate trigger cache ─────────────────────────────────────
_recent_triggers: dict[str, float] = {}  # "plate:gate_id" → timestamp
_trigger_lock = threading.Lock()


def _is_duplicate_trigger(plate: str, gate_id: str) -> bool:
    """Return True if the same plate+gate was triggered within ANTI_DUPLICATE_SECONDS."""
    key = f"{plate}:{gate_id}"
    now = time.time()
    with _trigger_lock:
        last = _recent_triggers.get(key, 0.0)
        if now - last < ANTI_DUPLICATE_SECONDS:
            return True
        _recent_triggers[key] = now
        # Cleanup stale entries (keep cache small)
        stale = [k for k, v in _recent_triggers.items() if now - v > 30]
        for k in stale:
            del _recent_triggers[k]
    return False


# ── Device authentication ────────────────────────────────────────────

def verify_device(
    x_device_secret: str = Header(None, alias="X-Device-Secret"),
    db: Session = Depends(get_db),
) -> Device | None:
    """
    Validate per-device secret sent via X-Device-Secret header.
    Returns the Device row if valid, or None if no header was provided.
    Raises 403 if the header was provided but invalid.
    """
    if not x_device_secret:
        return None

    device = (
        db.query(Device)
        .filter(
            Device.device_secret == x_device_secret,
            Device.status == DeviceStatus.ACTIVE,
        )
        .first()
    )
    if not device:
        raise HTTPException(status_code=403, detail="Invalid or disabled device secret")

    # Touch last_seen
    device.last_seen = datetime.utcnow()
    db.commit()
    return device


# ── Audit helper ─────────────────────────────────────────────────────

def _log_gate_event(
    db: Session,
    *,
    plate: str | None = None,
    confidence: float | None = None,
    gate_id: str | None = None,
    gate_type: str | None = None,
    action: str,
    reason: str | None = None,
    device_id: str | None = None,
    user_id: str | None = None,
    session_id: str | None = None,
    raw_ocr: str | None = None,
):
    """Insert one row into gate_events for audit / debugging."""
    event = GateEvent(
        plate=plate,
        confidence=confidence,
        gate_id=gate_id,
        gate_type=gate_type,
        action=action,
        reason=reason,
        device_id=device_id,
        user_id=user_id,
        session_id=session_id,
        raw_ocr=raw_ocr,
    )
    db.add(event)
    # Don't commit here — caller controls the transaction boundary.


# ═══════════════════════════════════════════════════════════════════════
# POST /api/gate/entry
# ═══════════════════════════════════════════════════════════════════════
@router.post("/entry")
async def gate_entry(
    image: UploadFile = File(...),
    gate_id: str = Form(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    device: Device | None = Depends(verify_device),
):
    """
    Entry gate pipeline:
    ① ANPR+OCR → ② Confidence check → ③ DB Lookup (kendaraan terdaftar?) →
    ④ Duplicate session check → ⑤ GPS Radius → ⑥ Buat sesi / TOLAK
    """

    device_id = device.id if device else None

    # ① ANPR + OCR ─────────────────────────────────────────────────────
    image_bytes = await image.read()
    detection = detect_plate(image_bytes)

    if not detection["success"]:
        reason = f"Plat tidak terdeteksi: {detection.get('error', 'unknown')}"
        _log_gate_event(
            db, plate=None, confidence=detection.get("confidence"),
            gate_id=gate_id, gate_type="entry", action="MANUAL_REQUIRED",
            reason=reason, device_id=device_id, user_id=current_user.id,
            raw_ocr=detection.get("raw_ocr"),
        )
        db.commit()
        return {
            "action": "MANUAL_REQUIRED",
            "reason": reason,
            "detection": detection,
        }

    raw_plate = detection["plate"]
    plate = normalize_plate(raw_plate)
    confidence = detection.get("confidence", 0.0)

    # ② Confidence threshold ───────────────────────────────────────────
    if confidence < MIN_ANPR_CONFIDENCE:
        reason = f"Confidence rendah ({confidence:.2f} < {MIN_ANPR_CONFIDENCE})"
        _log_gate_event(
            db, plate=plate, confidence=confidence,
            gate_id=gate_id, gate_type="entry", action="REVIEW",
            reason=reason, device_id=device_id, user_id=current_user.id,
            raw_ocr=detection.get("raw_ocr"),
        )
        db.commit()
        return {
            "action": "REVIEW",
            "reason": reason,
            "plate": plate,
            "confidence": confidence,
        }

    # Anti-duplicate trigger ────────────────────────────────────────────
    if _is_duplicate_trigger(plate, gate_id):
        return {
            "action": "IGNORED",
            "reason": "Duplicate trigger (same plate + gate within 5s)",
            "plate": plate,
        }

    # ③ DB Lookup ──────────────────────────────────────────────────────
    vehicle = (
        db.query(Vehicle)
        .filter(Vehicle.plate_number == plate, Vehicle.is_active == True)
        .first()
    )

    if not vehicle:
        reason = f"Kendaraan dengan plat {plate} tidak terdaftar"
        _log_gate_event(
            db, plate=plate, confidence=confidence,
            gate_id=gate_id, gate_type="entry", action="MANUAL_REQUIRED",
            reason=reason, device_id=device_id, user_id=current_user.id,
            raw_ocr=detection.get("raw_ocr"),
        )
        db.commit()
        return {
            "action": "MANUAL_REQUIRED",
            "reason": reason,
            "plate": plate,
        }

    # ④ Duplicate session check (race condition protection) ────────────
    existing_active = (
        db.query(ParkingSession)
        .filter(
            ParkingSession.plate_number == plate,
            ParkingSession.status == SessionStatus.ACTIVE,
        )
        .first()
    )
    if existing_active:
        reason = f"Sesi aktif sudah ada untuk plat {plate} (session {existing_active.id})"
        _log_gate_event(
            db, plate=plate, confidence=confidence,
            gate_id=gate_id, gate_type="entry", action="REJECTED",
            reason=reason, device_id=device_id, user_id=current_user.id,
            session_id=existing_active.id,
        )
        db.commit()
        return {
            "action": "REJECTED",
            "reason": reason,
            "plate": plate,
            "existing_session_id": existing_active.id,
        }

    # ⑤ GPS Radius ─────────────────────────────────────────────────────
    gate = db.query(GateLocation).filter(GateLocation.id == gate_id).first()

    if gate:
        user_loc = (
            db.query(UserLocation)
            .filter(UserLocation.user_id == current_user.id)
            .first()
        )
        if user_loc:
            # Check freshness
            age = (datetime.utcnow() - user_loc.updated_at).total_seconds()
            if age > GPS_FRESHNESS_SECONDS:
                reason = f"Lokasi GPS kadaluarsa ({int(age)}s > {GPS_FRESHNESS_SECONDS}s)"
                _log_gate_event(
                    db, plate=plate, confidence=confidence,
                    gate_id=gate_id, gate_type="entry", action="REJECTED",
                    reason=reason, device_id=device_id, user_id=current_user.id,
                )
                db.commit()
                return {"action": "REJECTED", "reason": reason, "plate": plate}

            # Check accuracy
            if user_loc.accuracy and user_loc.accuracy > GPS_MAX_ACCURACY_METERS:
                reason = f"Akurasi GPS terlalu rendah ({user_loc.accuracy:.0f}m > {GPS_MAX_ACCURACY_METERS}m)"
                _log_gate_event(
                    db, plate=plate, confidence=confidence,
                    gate_id=gate_id, gate_type="entry", action="REJECTED",
                    reason=reason, device_id=device_id, user_id=current_user.id,
                )
                db.commit()
                return {"action": "REJECTED", "reason": reason, "plate": plate}

            # Check distance
            loc = verify_location(
                user_loc.latitude, user_loc.longitude,
                gate.latitude, gate.longitude,
                gate.radius_meters,
            )
            if not loc["nearby"]:
                reason = f"Lokasi terlalu jauh ({loc['distance_meters']}m, maks {loc['max_radius']}m)"
                _log_gate_event(
                    db, plate=plate, confidence=confidence,
                    gate_id=gate_id, gate_type="entry", action="REJECTED",
                    reason=reason, device_id=device_id, user_id=current_user.id,
                )
                db.commit()
                return {"action": "REJECTED", "reason": reason, "plate": plate}

    # ⑥ Buka gate → buat sesi ACTIVE (atomic) ─────────────────────────
    try:
        nested = db.begin_nested()
        session = ParkingSession(
            vehicle_id=vehicle.id,
            user_id=vehicle.user_id,
            plate_number=plate,
            gate_in_id=gate_id,
            entry_time=datetime.utcnow(),
            status=SessionStatus.ACTIVE,
            entry_method=EntryMethod.AUTO,
        )
        db.add(session)
        _log_gate_event(
            db, plate=plate, confidence=confidence,
            gate_id=gate_id, gate_type="entry", action="OPEN_GATE",
            reason="Sesi parkir dimulai", device_id=device_id,
            user_id=vehicle.user_id, session_id=session.id,
            raw_ocr=detection.get("raw_ocr"),
        )
        db.commit()
    except Exception:
        db.rollback()
        return {
            "action": "REJECTED",
            "reason": "Gagal membuat sesi (kemungkinan race condition)",
            "plate": plate,
        }

    db.refresh(session)
    return {
        "action": "OPEN_GATE",
        "session_id": session.id,
        "plate": plate,
        "entry_time": session.entry_time.isoformat(),
        "message": "Selamat datang! Sesi parkir dimulai.",
    }


# ═══════════════════════════════════════════════════════════════════════
# POST /api/gate/exit  — TANPA OPSI MANUAL
# ═══════════════════════════════════════════════════════════════════════
@router.post("/exit")
async def gate_exit(
    image: UploadFile = File(...),
    gate_id: str = Form(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    device: Device | None = Depends(verify_device),
):
    """
    Exit gate pipeline (NO manual fallback):
    ① ANPR+OCR → ② Confidence check → ③ DB Lookup (sesi ACTIVE?) →
    ④ GPS Radius → ⑤ Cek Saldo → ⑥ Potong Saldo & Buka Gate
    """

    device_id = device.id if device else None

    # ① ANPR + OCR ─────────────────────────────────────────────────────
    image_bytes = await image.read()
    detection = detect_plate(image_bytes)

    if not detection["success"]:
        reason = f"Plat tidak terdeteksi: {detection.get('error', 'unknown')}"
        _log_gate_event(
            db, plate=None, confidence=detection.get("confidence"),
            gate_id=gate_id, gate_type="exit", action="REJECTED",
            reason=reason, device_id=device_id, user_id=current_user.id,
            raw_ocr=detection.get("raw_ocr"),
        )
        db.commit()
        return {"action": "REJECTED", "reason": reason}

    raw_plate = detection["plate"]
    plate = normalize_plate(raw_plate)
    confidence = detection.get("confidence", 0.0)

    # ② Confidence threshold ───────────────────────────────────────────
    if confidence < MIN_ANPR_CONFIDENCE:
        reason = f"Confidence rendah ({confidence:.2f} < {MIN_ANPR_CONFIDENCE})"
        _log_gate_event(
            db, plate=plate, confidence=confidence,
            gate_id=gate_id, gate_type="exit", action="REVIEW",
            reason=reason, device_id=device_id, user_id=current_user.id,
            raw_ocr=detection.get("raw_ocr"),
        )
        db.commit()
        return {
            "action": "REVIEW",
            "reason": reason,
            "plate": plate,
            "confidence": confidence,
        }

    # Anti-duplicate trigger ────────────────────────────────────────────
    if _is_duplicate_trigger(plate, gate_id):
        return {
            "action": "IGNORED",
            "reason": "Duplicate trigger (same plate + gate within 5s)",
            "plate": plate,
        }

    # ③ DB Lookup – cari sesi ACTIVE ──────────────────────────────────
    session = (
        db.query(ParkingSession)
        .filter(
            ParkingSession.plate_number == plate,
            ParkingSession.status == SessionStatus.ACTIVE,
        )
        .first()
    )

    if not session:
        reason = f"Tidak ada sesi aktif untuk plat {plate}"
        _log_gate_event(
            db, plate=plate, confidence=confidence,
            gate_id=gate_id, gate_type="exit", action="REJECTED",
            reason=reason, device_id=device_id, user_id=current_user.id,
        )
        db.commit()
        return {"action": "REJECTED", "reason": reason, "plate": plate}

    # ④ GPS Radius ─────────────────────────────────────────────────────
    gate = db.query(GateLocation).filter(GateLocation.id == gate_id).first()

    if gate:
        user_loc = (
            db.query(UserLocation)
            .filter(UserLocation.user_id == current_user.id)
            .first()
        )
        if user_loc:
            age = (datetime.utcnow() - user_loc.updated_at).total_seconds()
            if age <= GPS_FRESHNESS_SECONDS:
                if not (user_loc.accuracy and user_loc.accuracy > GPS_MAX_ACCURACY_METERS):
                    loc = verify_location(
                        user_loc.latitude, user_loc.longitude,
                        gate.latitude, gate.longitude,
                        gate.radius_meters,
                    )
                    if not loc["nearby"]:
                        reason = f"Lokasi terlalu jauh ({loc['distance_meters']}m, maks {loc['max_radius']}m)"
                        _log_gate_event(
                            db, plate=plate, confidence=confidence,
                            gate_id=gate_id, gate_type="exit", action="REJECTED",
                            reason=reason, device_id=device_id,
                            user_id=current_user.id, session_id=session.id,
                        )
                        db.commit()
                        return {"action": "REJECTED", "reason": reason, "plate": plate}

    # ⑤ Hitung biaya ──────────────────────────────────────────────────
    now = datetime.utcnow()
    duration_seconds = (now - session.entry_time).total_seconds()
    duration_hours = duration_seconds / 3600

    rate = (
        db.query(ParkingRate)
        .filter(ParkingRate.vehicle_type == "car", ParkingRate.is_active == True)
        .first()
    )
    rate_per_hour = rate.rate_per_hour if rate else 5000.0
    max_daily = rate.max_daily if rate else 50000.0

    cost = math.ceil(duration_hours) * rate_per_hour
    cost = min(cost, max_daily)  # cap at daily max

    # ⑥ Cek saldo ─────────────────────────────────────────────────────
    user = db.query(User).filter(User.id == session.user_id).first()

    if user.balance < cost:
        reason = "Saldo tidak cukup, silakan top-up di aplikasi"
        _log_gate_event(
            db, plate=plate, confidence=confidence,
            gate_id=gate_id, gate_type="exit", action="INSUFFICIENT_BALANCE",
            reason=f"{reason} (cost={cost}, balance={user.balance})",
            device_id=device_id, user_id=user.id, session_id=session.id,
        )
        db.commit()
        return {
            "action": "INSUFFICIENT_BALANCE",
            "reason": reason,
            "cost": cost,
            "balance": user.balance,
            "plate": plate,
        }

    # ⑦ Potong saldo → tutup sesi → buka gate (atomic) ────────────────
    try:
        nested = db.begin_nested()
        user.balance -= cost

        session.exit_time = now
        session.gate_out_id = gate_id
        session.duration_min = int(duration_seconds / 60)
        session.total_cost = cost
        session.status = SessionStatus.COMPLETED

        transaction = Transaction(
            user_id=user.id,
            session_id=session.id,
            type=TransactionType.PARKING_FEE,
            amount=-cost,
            balance_after=user.balance,
            description=f"Parkir {session.plate_number} — {session.duration_min} menit",
        )
        db.add(transaction)

        _log_gate_event(
            db, plate=plate, confidence=confidence,
            gate_id=gate_id, gate_type="exit", action="OPEN_GATE",
            reason=f"Biaya Rp {cost:,.0f}, saldo Rp {user.balance:,.0f}",
            device_id=device_id, user_id=user.id, session_id=session.id,
        )
        db.commit()
    except Exception:
        db.rollback()
        return {
            "action": "REJECTED",
            "reason": "Gagal memproses pembayaran (race condition)",
            "plate": plate,
        }

    return {
        "action": "OPEN_GATE",
        "cost": cost,
        "new_balance": user.balance,
        "duration_min": session.duration_min,
        "plate": plate,
        "message": f"Terima kasih! Biaya parkir Rp {cost:,.0f}",
    }
