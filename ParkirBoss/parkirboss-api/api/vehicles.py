from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from core.database import get_db
from models import domain
from schemas import api_models
from services.plate import normalize_plate
from .auth import get_current_user

router = APIRouter(prefix="/api/vehicles", tags=["vehicles"])

@router.post("", response_model=api_models.VehicleResponse)
def add_vehicle(
    vehicle_in: api_models.VehicleCreate, 
    db: Session = Depends(get_db),
    current_user: domain.User = Depends(get_current_user)
):
    plate = normalize_plate(vehicle_in.plate_number)
    if not plate:
        raise HTTPException(status_code=400, detail="Plate number is required")

    existing = db.query(domain.Vehicle).filter(domain.Vehicle.plate_number == plate).first()
    if existing:
        # A user can remove a vehicle and later add the same plate again. The
        # old implementation treated this soft-deleted record as a duplicate,
        # making the mobile app show only a generic save failure.
        if existing.user_id == current_user.id and not existing.is_active:
            existing.is_active = True
            existing.color = vehicle_in.color
            existing.brand = vehicle_in.brand
            db.commit()
            db.refresh(existing)
            return existing
        raise HTTPException(status_code=400, detail="Vehicle with this plate number already registered")
        
    db_vehicle = domain.Vehicle(
        user_id=current_user.id,
        plate_number=plate,
        color=vehicle_in.color,
        brand=vehicle_in.brand
    )
    db.add(db_vehicle)
    db.commit()
    db.refresh(db_vehicle)
    return db_vehicle

@router.get("", response_model=List[api_models.VehicleResponse])
def get_vehicles(
    db: Session = Depends(get_db),
    current_user: domain.User = Depends(get_current_user)
):
    vehicles = db.query(domain.Vehicle).filter(domain.Vehicle.user_id == current_user.id, domain.Vehicle.is_active == True).all()
    return vehicles

@router.delete("/{vehicle_id}")
def delete_vehicle(
    vehicle_id: str,
    db: Session = Depends(get_db),
    current_user: domain.User = Depends(get_current_user)
):
    vehicle = db.query(domain.Vehicle).filter(domain.Vehicle.id == vehicle_id, domain.Vehicle.user_id == current_user.id).first()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found")
        
    vehicle.is_active = False
    db.commit()
    return {"status": "success", "message": "Vehicle deleted successfully"}
