from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime

class UserCreate(BaseModel):
    name: str
    email: EmailStr
    phone: str
    password: str

class UserResponse(BaseModel):
    id: str
    name: str
    email: str
    phone: str
    balance: float
    
    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str

class LoginRequest(BaseModel):
    email: str
    password: str

class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str

class VehicleCreate(BaseModel):
    plate_number: str
    color: Optional[str] = None
    brand: Optional[str] = None

class VehicleResponse(BaseModel):
    id: str
    plate_number: str
    color: Optional[str] = None
    brand: Optional[str] = None
    is_active: bool
    
    class Config:
        from_attributes = True

class TopUpRequest(BaseModel):
    amount: float
    
class TransactionResponse(BaseModel):
    id: str
    type: str
    amount: float
    balance_after: float
    description: str
    created_at: datetime
    
    class Config:
        from_attributes = True
