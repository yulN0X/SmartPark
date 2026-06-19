from datetime import datetime
import math
from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from core.database import get_db
from models.domain import (
    Vehicle, ParkingSession, User, GateLocation, ParkingRate,
    Transaction, SessionStatus, EntryMethod, TransactionType, Device,
    UserLocation
)
from services.gps import verify_location
from services.plate import normalize_plate
from api.gate import (
    verify_device, _log_gate_event, _is_duplicate_trigger,
    MIN_ANPR_CONFIDENCE, GPS_FRESHNESS_SECONDS, GPS_MAX_ACCURACY_METERS
)

router = APIRouter(prefix="/api/device", tags=["device-bridge"])

class DeviceEventRequest(BaseModel):
    device_id: str
    gate_id: str
    gate_type: str  # "entry" or "exit"
    plate: str
    confidence: float
    raw_ocr: str | None = None


@router.post("/event")
def process_device_event(
    payload: DeviceEventRequest,
    db: Session = Depends(get_db),
    device: Device | None = Depends(verify_device),
):
    """
    Bridge endpoint for IoT devices or root API forwarding.
    Verifies X-Device-Secret header and makes decision (entry/exit).
    """
    if not device:
        raise HTTPException(
            status_code=401,
            detail="Header X-Device-Secret diperlukan untuk endpoint ini"
        )

    # Normalize plate
    plate = normalize_plate(payload.plate)
    confidence = payload.confidence
    gate_id = payload.gate_id
    gate_type = payload.gate_type.lower()
    device_id = device.id

    if gate_type not in ("entry", "exit"):
        raise HTTPException(status_code=400, detail="gate_type must be entry or exit")

    # 1. Confidence threshold check
    if confidence < MIN_ANPR_CONFIDENCE:
        reason = f"Confidence rendah ({confidence:.2f} < {MIN_ANPR_CONFIDENCE})"
        _log_gate_event(
            db, plate=plate, confidence=confidence,
            gate_id=gate_id, gate_type=gate_type, action="REVIEW",
            reason=reason, device_id=device_id,
            raw_ocr=payload.raw_ocr or plate,
        )
        db.commit()
        return {
            "action": "REVIEW",
            "reason": reason,
            "plate": plate,
            "confidence": confidence,
        }

    # 2. Anti-duplicate trigger check
    if _is_duplicate_trigger(plate, gate_id):
        return {
            "action": "IGNORED",
            "reason": "Duplicate trigger (same plate + gate within 5s)",
            "plate": plate,
        }

    if gate_type == "entry":
        # 3. DB Lookup for registered vehicle
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
                reason=reason, device_id=device_id,
                raw_ocr=payload.raw_ocr or plate,
            )
            db.commit()
            return {
                "action": "MANUAL_REQUIRED",
                "reason": reason,
                "plate": plate,
            }

        user_id = vehicle.user_id

        # 4. Duplicate session check
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
                reason=reason, device_id=device_id, user_id=user_id,
                session_id=existing_active.id,
            )
            db.commit()
            return {
                "action": "REJECTED",
                "reason": reason,
                "plate": plate,
                "existing_session_id": existing_active.id,
            }

        # 5. GPS Check
        gate = db.query(GateLocation).filter(GateLocation.id == gate_id).first()
        if gate:
            user_loc = db.query(UserLocation).filter(UserLocation.user_id == user_id).first()
            if not user_loc:
                reason = "Lokasi GPS pengguna tidak tersedia"
                _log_gate_event(
                    db, plate=plate, confidence=confidence,
                    gate_id=gate_id, gate_type="entry", action="REJECTED",
                    reason=reason, device_id=device_id, user_id=user_id,
                )
                db.commit()
                return {"action": "REJECTED", "reason": reason, "plate": plate}

            # Check freshness
            age = (datetime.utcnow() - user_loc.updated_at).total_seconds()
            if age > GPS_FRESHNESS_SECONDS:
                reason = f"Lokasi GPS kadaluarsa ({int(age)}s > {GPS_FRESHNESS_SECONDS}s)"
                _log_gate_event(
                    db, plate=plate, confidence=confidence,
                    gate_id=gate_id, gate_type="entry", action="REJECTED",
                    reason=reason, device_id=device_id, user_id=user_id,
                )
                db.commit()
                return {"action": "REJECTED", "reason": reason, "plate": plate}

            # Check accuracy
            if user_loc.accuracy and user_loc.accuracy > GPS_MAX_ACCURACY_METERS:
                reason = f"Akurasi GPS terlalu rendah ({user_loc.accuracy:.0f}m > {GPS_MAX_ACCURACY_METERS}m)"
                _log_gate_event(
                    db, plate=plate, confidence=confidence,
                    gate_id=gate_id, gate_type="entry", action="REJECTED",
                    reason=reason, device_id=device_id, user_id=user_id,
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
                    reason=reason, device_id=device_id, user_id=user_id,
                )
                db.commit()
                return {"action": "REJECTED", "reason": reason, "plate": plate}

        # 6. Create Active Session
        try:
            nested = db.begin_nested()
            session = ParkingSession(
                vehicle_id=vehicle.id,
                user_id=user_id,
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
                user_id=user_id, session_id=session.id,
                raw_ocr=payload.raw_ocr or plate,
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

    else:
        # Exit gate pipeline
        # 3. Find active session
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
                reason=reason, device_id=device_id,
            )
            db.commit()
            return {"action": "REJECTED", "reason": reason, "plate": plate}

        user_id = session.user_id

        # 4. GPS Check
        gate = db.query(GateLocation).filter(GateLocation.id == gate_id).first()
        if gate:
            user_loc = db.query(UserLocation).filter(UserLocation.user_id == user_id).first()
            if not user_loc:
                reason = "Lokasi GPS pengguna tidak tersedia"
                _log_gate_event(
                    db, plate=plate, confidence=confidence,
                    gate_id=gate_id, gate_type="exit", action="REJECTED",
                    reason=reason, device_id=device_id, user_id=user_id,
                    session_id=session.id,
                )
                db.commit()
                return {"action": "REJECTED", "reason": reason, "plate": plate}

            # Check freshness
            age = (datetime.utcnow() - user_loc.updated_at).total_seconds()
            if age > GPS_FRESHNESS_SECONDS:
                reason = f"Lokasi GPS kadaluarsa ({int(age)}s > {GPS_FRESHNESS_SECONDS}s)"
                _log_gate_event(
                    db, plate=plate, confidence=confidence,
                    gate_id=gate_id, gate_type="exit", action="REJECTED",
                    reason=reason, device_id=device_id, user_id=user_id,
                    session_id=session.id,
                )
                db.commit()
                return {"action": "REJECTED", "reason": reason, "plate": plate}

            # Check accuracy
            if user_loc.accuracy and user_loc.accuracy > GPS_MAX_ACCURACY_METERS:
                reason = f"Akurasi GPS terlalu rendah ({user_loc.accuracy:.0f}m > {GPS_MAX_ACCURACY_METERS}m)"
                _log_gate_event(
                    db, plate=plate, confidence=confidence,
                    gate_id=gate_id, gate_type="exit", action="REJECTED",
                    reason=reason, device_id=device_id, user_id=user_id,
                    session_id=session.id,
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
                    gate_id=gate_id, gate_type="exit", action="REJECTED",
                    reason=reason, device_id=device_id, user_id=user_id,
                    session_id=session.id,
                )
                db.commit()
                return {"action": "REJECTED", "reason": reason, "plate": plate}

        # 5. Calculate cost
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
        cost = min(cost, max_daily)

        # 6. Check balance
        user = db.query(User).filter(User.id == user_id).first()
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

        # 7. Deduct balance and close session
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
