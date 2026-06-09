"""
Gate API — Entry & Exit endpoints.
Implements the full verification pipeline:
  ① ANPR + OCR  →  ② DB Lookup  →  ③ GPS Verify  →  ④ Action
"""

import math
from datetime import datetime
from fastapi import APIRouter, Depends, File, Form, UploadFile
from sqlalchemy.orm import Session

from core.database import get_db
from models.domain import (
    Vehicle, ParkingSession, User, GateLocation, ParkingRate,
    Transaction, SessionStatus, EntryMethod, TransactionType, GateType,
)
from services.vision import detect_plate
from services.gps import verify_location
from api.auth import get_current_user

router = APIRouter(prefix="/api/gate", tags=["gate"])


# ═══════════════════════════════════════════════════════════════════════
# POST /api/gate/entry
# ═══════════════════════════════════════════════════════════════════════
@router.post("/entry")
async def gate_entry(
    image: UploadFile = File(...),
    gate_id: str = Form(...),
    user_lat: float = Form(...),
    user_lon: float = Form(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Entry gate pipeline:
    ① ANPR+OCR → ② DB Lookup (kendaraan terdaftar?) →
    ③ GPS Radius → ④ Buat sesi / TOLAK
    """

    # ① ANPR + OCR ─────────────────────────────────────────────────────
    image_bytes = await image.read()
    detection = detect_plate(image_bytes)

    if not detection["success"]:
        return {
            "action": "MANUAL_REQUIRED",
            "reason": f"Plat tidak terdeteksi: {detection.get('error', 'unknown')}",
            "detection": detection,
        }

    plate = detection["plate"]

    # ② DB Lookup ──────────────────────────────────────────────────────
    vehicle = (
        db.query(Vehicle)
        .filter(Vehicle.plate_number == plate, Vehicle.is_active == True)
        .first()
    )

    if not vehicle:
        return {
            "action": "MANUAL_REQUIRED",
            "reason": f"Kendaraan dengan plat {plate} tidak terdaftar",
            "plate": plate,
        }

    # ③ GPS Radius ─────────────────────────────────────────────────────
    gate = db.query(GateLocation).filter(GateLocation.id == gate_id).first()

    if gate:
        loc = verify_location(
            user_lat, user_lon,
            gate.latitude, gate.longitude,
            gate.radius_meters,
        )
        if not loc["nearby"]:
            return {
                "action": "REJECTED",
                "reason": f"Lokasi terlalu jauh ({loc['distance_meters']}m, maks {loc['max_radius']}m)",
                "plate": plate,
            }

    # ④ Buka gate → buat sesi ACTIVE ──────────────────────────────────
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
    db.commit()
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
    user_lat: float = Form(...),
    user_lon: float = Form(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Exit gate pipeline (NO manual fallback):
    ① ANPR+OCR → ② DB Lookup (sesi ACTIVE?) →
    ③ GPS Radius → ④ Cek Saldo → ⑤ Potong Saldo & Buka Gate
    """

    # ① ANPR + OCR ─────────────────────────────────────────────────────
    image_bytes = await image.read()
    detection = detect_plate(image_bytes)

    if not detection["success"]:
        return {
            "action": "REJECTED",
            "reason": f"Plat tidak terdeteksi: {detection.get('error', 'unknown')}",
        }

    plate = detection["plate"]

    # ② DB Lookup – cari sesi ACTIVE ──────────────────────────────────
    session = (
        db.query(ParkingSession)
        .filter(
            ParkingSession.plate_number == plate,
            ParkingSession.status == SessionStatus.ACTIVE,
        )
        .first()
    )

    if not session:
        return {
            "action": "REJECTED",
            "reason": f"Tidak ada sesi aktif untuk plat {plate}",
            "plate": plate,
        }

    # ③ GPS Radius ─────────────────────────────────────────────────────
    gate = db.query(GateLocation).filter(GateLocation.id == gate_id).first()

    if gate:
        loc = verify_location(
            user_lat, user_lon,
            gate.latitude, gate.longitude,
            gate.radius_meters,
        )
        if not loc["nearby"]:
            return {
                "action": "REJECTED",
                "reason": f"Lokasi terlalu jauh ({loc['distance_meters']}m, maks {loc['max_radius']}m)",
                "plate": plate,
            }

    # ④ Hitung biaya ──────────────────────────────────────────────────
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

    # ⑤ Cek saldo ─────────────────────────────────────────────────────
    user = db.query(User).filter(User.id == session.user_id).first()

    if user.balance < cost:
        return {
            "action": "INSUFFICIENT_BALANCE",
            "reason": "Saldo tidak cukup, silakan top-up di aplikasi",
            "cost": cost,
            "balance": user.balance,
            "plate": plate,
        }

    # ⑥ Potong saldo → tutup sesi → buka gate ────────────────────────
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
    db.commit()

    return {
        "action": "OPEN_GATE",
        "cost": cost,
        "new_balance": user.balance,
        "duration_min": session.duration_min,
        "plate": plate,
        "message": f"Terima kasih! Biaya parkir Rp {cost:,.0f}",
    }
