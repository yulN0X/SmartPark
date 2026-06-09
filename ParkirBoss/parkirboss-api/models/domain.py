import uuid
from sqlalchemy import Column, String, Float, Boolean, ForeignKey, Integer, DateTime, Enum
from sqlalchemy.orm import relationship
from datetime import datetime
from core.database import Base

import enum

class SessionStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    COMPLETED = "COMPLETED"

class EntryMethod(str, enum.Enum):
    AUTO = "AUTO"
    MANUAL = "MANUAL"

class TransactionType(str, enum.Enum):
    TOPUP = "TOPUP"
    PARKING_FEE = "PARKING_FEE"
    REFUND = "REFUND"

class GateType(str, enum.Enum):
    ENTRY = "ENTRY"
    EXIT = "EXIT"

class User(Base):
    __tablename__ = "users"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String)
    email = Column(String, unique=True, index=True)
    phone = Column(String)
    password_hash = Column(String)
    balance = Column(Float, default=0.0)
    created_at = Column(DateTime, default=datetime.utcnow)

    vehicles = relationship("Vehicle", back_populates="owner")
    sessions = relationship("ParkingSession", back_populates="user")
    transactions = relationship("Transaction", back_populates="user")

class Vehicle(Base):
    __tablename__ = "vehicles"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"))
    plate_number = Column(String, unique=True, index=True)
    color = Column(String, nullable=True)
    brand = Column(String, nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    owner = relationship("User", back_populates="vehicles")
    sessions = relationship("ParkingSession", back_populates="vehicle")

class ParkingSession(Base):
    __tablename__ = "parking_sessions"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    vehicle_id = Column(String, ForeignKey("vehicles.id"), nullable=True)
    user_id = Column(String, ForeignKey("users.id"), nullable=True)
    plate_number = Column(String)
    gate_in_id = Column(String)
    gate_out_id = Column(String, nullable=True)
    entry_time = Column(DateTime, default=datetime.utcnow)
    exit_time = Column(DateTime, nullable=True)
    duration_min = Column(Integer, nullable=True)
    total_cost = Column(Float, nullable=True)
    status = Column(Enum(SessionStatus), default=SessionStatus.ACTIVE)
    entry_photo = Column(String, nullable=True)
    exit_photo = Column(String, nullable=True)
    entry_method = Column(Enum(EntryMethod), default=EntryMethod.AUTO)
    created_at = Column(DateTime, default=datetime.utcnow)

    vehicle = relationship("Vehicle", back_populates="sessions")
    user = relationship("User", back_populates="sessions")

class Transaction(Base):
    __tablename__ = "transactions"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"))
    session_id = Column(String, ForeignKey("parking_sessions.id"), nullable=True)
    type = Column(Enum(TransactionType))
    amount = Column(Float)
    balance_after = Column(Float)
    description = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="transactions")

class ParkingRate(Base):
    __tablename__ = "parking_rates"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    vehicle_type = Column(String, default="car")
    rate_per_hour = Column(Float, default=5000.0)
    max_daily = Column(Float, default=50000.0)
    is_active = Column(Boolean, default=True)

class GateLocation(Base):
    __tablename__ = "gate_locations"
    id = Column(String, primary_key=True)
    name = Column(String)
    type = Column(Enum(GateType))
    latitude = Column(Float)
    longitude = Column(Float)
    radius_meters = Column(Integer, default=15)
    is_active = Column(Boolean, default=True)

class ParkingLocation(Base):
    """A nearby parking venue surfaced on the dashboard (real-time availability)."""
    __tablename__ = "parking_locations"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String)
    total_slots = Column(Integer, default=0)
    available_slots = Column(Integer, default=0)
    latitude = Column(Float)
    longitude = Column(Float)
    is_active = Column(Boolean, default=True)
