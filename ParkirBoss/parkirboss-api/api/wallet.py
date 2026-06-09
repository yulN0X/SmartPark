from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from core.database import get_db
from models import domain
from schemas import api_models
from .auth import get_current_user

router = APIRouter(prefix="/api/wallet", tags=["wallet"])

@router.get("/balance")
def get_balance(current_user: domain.User = Depends(get_current_user)):
    return {"balance": current_user.balance}

@router.post("/topup", response_model=api_models.TransactionResponse)
def topup_balance(
    topup_in: api_models.TopUpRequest,
    db: Session = Depends(get_db),
    current_user: domain.User = Depends(get_current_user)
):
    if topup_in.amount <= 0:
        raise HTTPException(status_code=400, detail="Amount must be positive")
        
    current_user.balance += topup_in.amount
    
    transaction = domain.Transaction(
        user_id=current_user.id,
        type=domain.TransactionType.TOPUP,
        amount=topup_in.amount,
        balance_after=current_user.balance,
        description=f"Top Up via App: {topup_in.amount}"
    )
    
    db.add(transaction)
    db.commit()
    db.refresh(transaction)
    
    return transaction

@router.get("/transactions", response_model=List[api_models.TransactionResponse])
def get_transactions(
    db: Session = Depends(get_db),
    current_user: domain.User = Depends(get_current_user)
):
    transactions = db.query(domain.Transaction).filter(
        domain.Transaction.user_id == current_user.id
    ).order_by(domain.Transaction.created_at.desc()).all()
    
    return transactions
