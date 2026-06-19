"""
GPS heartbeat — the mobile app sends location updates here.

The latest coordinates are stored in ``user_locations`` (upsert) and
looked up by the gate router for strict proximity verification.
"""

from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from core.database import get_db
from models.domain import User, UserLocation
from api.auth import get_current_user

router = APIRouter(prefix="/api/gps", tags=["gps"])

# ── Configuration ────────────────────────────────────────────────────
MAX_ACCURACY_METERS = 50     # reject if GPS accuracy worse than this
MAX_AGE_SECONDS = 30         # reject if timestamp older than this


class HeartbeatRequest(BaseModel):
    latitude: float
    longitude: float
    accuracy: float | None = None
    timestamp: str | None = None       # ISO 8601 string from the device


@router.post("/heartbeat")
def gps_heartbeat(
    payload: HeartbeatRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Accept a GPS heartbeat from the mobile app.

    Validations:
    - accuracy must be ≤ 50 m (if provided)
    - timestamp must be ≤ 30 s old (if provided; anti-replay)
    """

    # Accuracy gate
    if payload.accuracy is not None and payload.accuracy > MAX_ACCURACY_METERS:
        raise HTTPException(
            status_code=400,
            detail=f"Akurasi GPS terlalu rendah ({payload.accuracy:.0f}m > {MAX_ACCURACY_METERS}m)",
        )

    # Freshness gate (optional — clients may omit timestamp)
    if payload.timestamp:
        try:
            ts = datetime.fromisoformat(payload.timestamp.replace("Z", "+00:00"))
            age = (datetime.utcnow() - ts.replace(tzinfo=None)).total_seconds()
            if age > MAX_AGE_SECONDS:
                raise HTTPException(
                    status_code=400,
                    detail=f"Timestamp GPS terlalu lama ({int(age)}s > {MAX_AGE_SECONDS}s)",
                )
        except ValueError:
            pass  # malformed timestamp — still accept the update

    # Upsert user_locations
    loc = db.query(UserLocation).filter(UserLocation.user_id == current_user.id).first()
    if loc:
        loc.latitude = payload.latitude
        loc.longitude = payload.longitude
        loc.accuracy = payload.accuracy
        loc.updated_at = datetime.utcnow()
    else:
        loc = UserLocation(
            user_id=current_user.id,
            latitude=payload.latitude,
            longitude=payload.longitude,
            accuracy=payload.accuracy,
            updated_at=datetime.utcnow(),
        )
        db.add(loc)

    db.commit()
    return {"status": "ok", "message": "Lokasi diperbarui"}
