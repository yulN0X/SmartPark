from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from core.database import get_db
from core.security import get_password_hash, verify_password, create_access_token, oauth2_scheme, JWTError, jwt
from models import domain
from schemas import api_models
from core.config import settings

router = APIRouter(prefix="/api/auth", tags=["auth"])

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    user = db.query(domain.User).filter(domain.User.email == email).first()
    if user is None:
        raise credentials_exception
    return user

@router.post("/register", response_model=api_models.UserResponse)
def register(user_in: api_models.UserCreate, db: Session = Depends(get_db)):
    existing_user = db.query(domain.User).filter(domain.User.email == user_in.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")
        
    hashed_password = get_password_hash(user_in.password)
    db_user = domain.User(
        name=user_in.name,
        email=user_in.email,
        phone=user_in.phone,
        password_hash=hashed_password,
        balance=0.0
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@router.post("/login", response_model=api_models.Token)
def login(login_data: api_models.LoginRequest, db: Session = Depends(get_db)):
    user = db.query(domain.User).filter(domain.User.email == login_data.email).first()
    if not user or not verify_password(login_data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Incorrect email or password")
        
    access_token = create_access_token(data={"sub": user.email})
    return {"access_token": access_token, "token_type": "bearer"}

@router.get("/me", response_model=api_models.UserResponse)
def get_me(current_user: domain.User = Depends(get_current_user)):
    return current_user

@router.post("/change-password")
def change_password(
    data: api_models.ChangePasswordRequest,
    current_user: domain.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if not verify_password(data.old_password, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Password lama salah")
        
    current_user.password_hash = get_password_hash(data.new_password)
    db.commit()
    return {"message": "Kata sandi berhasil diubah"}
