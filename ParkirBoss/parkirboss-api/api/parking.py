"""
Parking Session API — active sessions, cost tracking, and history.
"""

import math
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from core.database import get_db
from models.domain import (
    User, ParkingSession, ParkingRate, SessionStatus, ParkingLocation,
)
from services.gps import haversine
from api.auth import get_current_user

router = APIRouter(prefix="/api/parking", tags=["parking"])

# Reference point used to rank nearby parking when the app sends no GPS.
# Matches GATE-A-IN (ITS Surabaya) used elsewhere in the demo.
REFERENCE_LAT = -7.279594
REFERENCE_LON = 112.797377


@router.get("/active")
def get_active_session(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Returns the user's active parking session with real-time cost calculation.
    Polled every 30 seconds by the app for live cost & balance check.
    """
    session = (
        db.query(ParkingSession)
        .filter(
            ParkingSession.user_id == current_user.id,
            ParkingSession.status == SessionStatus.ACTIVE,
        )
        .first()
    )

    if not session:
        return {"active": False}

    now = datetime.utcnow()
    duration_seconds = (now - session.entry_time).total_seconds()
    duration_minutes = int(duration_seconds / 60)
    duration_hours = duration_seconds / 3600

    rate = (
        db.query(ParkingRate)
        .filter(ParkingRate.vehicle_type == "car", ParkingRate.is_active == True)
        .first()
    )
    rate_per_hour = rate.rate_per_hour if rate else 5000.0
    max_daily = rate.max_daily if rate else 50000.0

    current_cost = math.ceil(duration_hours) * rate_per_hour
    current_cost = min(current_cost, max_daily)

    return {
        "active": True,
        "session_id": session.id,
        "plate": session.plate_number,
        "entry_time": session.entry_time.isoformat(),
        "duration_minutes": duration_minutes,
        "current_cost": current_cost,
        "rate_per_hour": rate_per_hour,
        "user_balance": current_user.balance,
        "balance_sufficient": current_user.balance >= current_cost,
    }


@router.get("/history")
def get_parking_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Returns completed parking sessions for the current user."""
    sessions = (
        db.query(ParkingSession)
        .filter(
            ParkingSession.user_id == current_user.id,
            ParkingSession.status == SessionStatus.COMPLETED,
        )
        .order_by(ParkingSession.exit_time.desc())
        .all()
    )

    return [
        {
            "id": s.id,
            "session_id": s.id,
            "plate": s.plate_number,
            "plate_number": s.plate_number,
            "gate_in_id": s.gate_in_id,
            "gate_out_id": s.gate_out_id,
            "status": s.status.value if s.status else "COMPLETED",
            "entry_time": s.entry_time.isoformat(),
            "exit_time": s.exit_time.isoformat() if s.exit_time else None,
            "duration_min": s.duration_min,
            "total_cost": s.total_cost,
        }
        for s in sessions
    ]


@router.get("/locations")
def get_parking_locations(
    lat: Optional[float] = None,
    lon: Optional[float] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Nearby parking venues with live availability, sorted by distance.
    Pass ?lat=&lon= to rank from the user's position; otherwise a fixed
    reference point (GATE-A-IN) is used for the demo.
    """
    ref_lat = lat if lat is not None else REFERENCE_LAT
    ref_lon = lon if lon is not None else REFERENCE_LON

    locations = (
        db.query(ParkingLocation)
        .filter(ParkingLocation.is_active == True)
        .all()
    )

    result = []
    for loc in locations:
        distance_m = haversine(ref_lat, ref_lon, loc.latitude, loc.longitude)
        total = loc.total_slots or 0
        available = max(loc.available_slots, 0)
        occupancy = (total - available) / total if total else 0.0

        if available <= 0:
            status = "FULL"
        elif occupancy >= 0.8:
            status = "FAST FILLING"
        else:
            status = "AVAILABLE"

        result.append({
            "id": loc.id,
            "name": loc.name,
            "distance_km": round(distance_m / 1000, 1),
            "distance_meters": round(distance_m, 1),
            "total_slots": total,
            "available_slots": available,
            "occupancy": round(occupancy, 2),
            "status": status,
        })

    result.sort(key=lambda x: x["distance_meters"])
    return result
