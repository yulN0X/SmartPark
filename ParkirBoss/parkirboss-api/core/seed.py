"""
Seed initial data: parking rates and gate locations.
Run once at startup to ensure baseline data exists.
"""

from sqlalchemy.orm import Session
from models.domain import ParkingRate, GateLocation, GateType, ParkingLocation


def seed_data(db: Session):
    """Insert default parking rate and gate locations if they don't exist."""

    # ── Parking Rate ─────────────────────────────────────────────────
    existing_rate = db.query(ParkingRate).filter(ParkingRate.is_active == True).first()
    if not existing_rate:
        rate = ParkingRate(
            vehicle_type="car",
            rate_per_hour=5000.0,
            max_daily=50000.0,
            is_active=True,
        )
        db.add(rate)
        print("[SEED] ✅ Parking rate added: Rp 5.000/jam, maks Rp 50.000/hari")

    # ── Gate Locations (simulasi kampus ITS Surabaya) ────────────────
    gates = [
        {
            "id": "GATE-A-IN",
            "name": "Gate Masuk A",
            "type": GateType.ENTRY,
            "latitude": -7.279594,
            "longitude": 112.797377,
            "radius_meters": 15,
        },
        {
            "id": "GATE-A-OUT",
            "name": "Gate Keluar A",
            "type": GateType.EXIT,
            "latitude": -7.279700,
            "longitude": 112.797500,
            "radius_meters": 15,
        },
    ]

    for g in gates:
        existing = db.query(GateLocation).filter(GateLocation.id == g["id"]).first()
        if not existing:
            db.add(GateLocation(**g, is_active=True))
            print(f"[SEED] ✅ Gate added: {g['name']} ({g['id']})")

    # ── Nearby Parking Locations (dashboard availability) ────────────
    # Coordinates offset from GATE-A-IN (-7.279594, 112.797377) so the
    # Haversine distance lands roughly at the stated km figure.
    locations = [
        {
            "id": "LOC-ITS-PUSAT",
            "name": "ITS Parkir Pusat",
            "total_slots": 150,
            "available_slots": 88,
            "latitude": -7.278694,   # ~0.1 km
            "longitude": 112.797377,
        },
        {
            "id": "LOC-GRAND-MALL",
            "name": "Grand Mall P1",
            "total_slots": 100,
            "available_slots": 15,
            "latitude": -7.277794,   # ~0.2 km
            "longitude": 112.797377,
        },
        {
            "id": "LOC-CITY-CENTER",
            "name": "City Center Hub",
            "total_slots": 200,
            "available_slots": 120,
            "latitude": -7.275094,   # ~0.5 km
            "longitude": 112.797377,
        },
    ]

    for loc in locations:
        existing = db.query(ParkingLocation).filter(ParkingLocation.id == loc["id"]).first()
        if not existing:
            db.add(ParkingLocation(**loc, is_active=True))
            print(f"[SEED] ✅ Parking location added: {loc['name']} ({loc['id']})")

    db.commit()
