"""
Notifications API — derives a live activity feed from real data
(active parking session + wallet transactions). No push infrastructure
required; the app polls this endpoint.
"""

import math
from datetime import datetime
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from core.database import get_db
from models.domain import (
    User, ParkingSession, ParkingRate, Transaction,
    SessionStatus, TransactionType,
)
from api.auth import get_current_user

router = APIRouter(prefix="/api/notifications", tags=["notifications"])


def _group_for(ts: datetime) -> str:
    """Bucket a timestamp into a human header for the notifications list."""
    today = datetime.utcnow().date()
    d = ts.date()
    if d == today:
        return "TODAY"
    delta = (today - d).days
    if delta == 1:
        return "YESTERDAY"
    return "EARLIER"


@router.get("")
def get_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Aggregate the user's active session and recent wallet transactions."""
    items = []

    # ── Active session (ongoing + low balance alert) ─────────────────
    session = (
        db.query(ParkingSession)
        .filter(
            ParkingSession.user_id == current_user.id,
            ParkingSession.status == SessionStatus.ACTIVE,
        )
        .first()
    )

    if session:
        now = datetime.utcnow()
        duration_hours = (now - session.entry_time).total_seconds() / 3600
        rate = (
            db.query(ParkingRate)
            .filter(ParkingRate.vehicle_type == "car", ParkingRate.is_active == True)
            .first()
        )
        rate_per_hour = rate.rate_per_hour if rate else 5000.0
        max_daily = rate.max_daily if rate else 50000.0
        current_cost = min(math.ceil(duration_hours) * rate_per_hour, max_daily)

        if current_user.balance < current_cost:
            items.append({
                "id": f"alert-balance-{session.id}",
                "category": "alert",
                "title": "SALDO TIDAK CUKUP",
                "body": (
                    "Saldo Anda tidak cukup untuk biaya parkir berjalan. "
                    "Segera isi saldo agar tidak terkunci di gate keluar."
                ),
                "timestamp": now.isoformat(),
                "group": "TODAY",
            })

        items.append({
            "id": f"session-{session.id}",
            "category": "session",
            "title": "SESI PARKIR BERLANGSUNG",
            "body": (
                f"Kendaraan {session.plate_number} sedang parkir. "
                f"Biaya berjalan Rp {int(current_cost):,}".replace(",", ".")
            ),
            "timestamp": session.entry_time.isoformat(),
            "group": "TODAY",
        })

    # ── Wallet transactions ──────────────────────────────────────────
    transactions = (
        db.query(Transaction)
        .filter(Transaction.user_id == current_user.id)
        .order_by(Transaction.created_at.desc())
        .limit(20)
        .all()
    )

    for tx in transactions:
        if tx.type == TransactionType.TOPUP:
            category, title = "topup", "TOP UP BERHASIL"
            body = f"Saldo kini Rp {int(tx.balance_after):,}".replace(",", ".")
        elif tx.type == TransactionType.PARKING_FEE:
            category, title = "payment", "PEMBAYARAN BERHASIL"
            body = f"Biaya parkir Rp {int(abs(tx.amount)):,}".replace(",", ".")
        elif tx.type == TransactionType.REFUND:
            category, title = "topup", "DANA DIKEMBALIKAN"
            body = f"Refund Rp {int(abs(tx.amount)):,}".replace(",", ".")
        else:
            category, title, body = "payment", "TRANSAKSI", tx.description

        items.append({
            "id": f"tx-{tx.id}",
            "category": category,
            "title": title,
            "body": body,
            "timestamp": tx.created_at.isoformat(),
            "group": _group_for(tx.created_at),
        })

    # Newest first across all sources.
    items.sort(key=lambda x: x["timestamp"], reverse=True)
    return items
