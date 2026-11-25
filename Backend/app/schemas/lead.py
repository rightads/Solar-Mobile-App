import uuid
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field, field_validator
from app.core.security import normalize_phone
from app.models.enums import LeadStatus, SystemPhase
from app.schemas.user import UserRead


class LeadBase(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    phone: str = Field(..., description="10-digit Indian phone number")
    email: Optional[str] = None
    address: Optional[str] = None
    expected_kw: Optional[float] = Field(None, gt=0)
    source: Optional[str] = None
    follow_up_date: Optional[datetime] = None
    notes: Optional[str] = None

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        return normalize_phone(v)


class LeadCreate(LeadBase):
    assigned_sales_id: Optional[uuid.UUID] = Field(None, description="Admin can assign; Sales defaults to self")


class LeadUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=2, max_length=100)
    phone: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    expected_kw: Optional[float] = Field(None, gt=0)
    source: Optional[str] = None
    status: Optional[LeadStatus] = None
    follow_up_date: Optional[datetime] = None
    notes: Optional[str] = None
    assigned_sales_id: Optional[uuid.UUID] = None

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            return normalize_phone(v)
        return v


class LeadAssign(BaseModel):
    assigned_sales_id: uuid.UUID = Field(..., description="Target sales user ID")


class LeadMarkLost(BaseModel):
    reason: str = Field(..., min_length=3, description="Reason why the lead was lost")


class LeadConvert(BaseModel):
    address: str = Field(..., min_length=5)
    latitude: Optional[float] = Field(None, ge=-90.0, le=90.0)
    longitude: Optional[float] = Field(None, ge=-180.0, le=180.0)
    final_price: int = Field(..., ge=0, description="Final price in paise")
    capacity_kw: float = Field(..., gt=0)
    phase: SystemPhase = Field(..., description="single or three")
    panel_brand: str = Field(..., min_length=2, max_length=100)
    panel_watt: int = Field(..., gt=0)
    panel_count: int = Field(..., gt=0)
    inverter_brand: str = Field(..., min_length=2, max_length=100)
    structure_type: str = Field(..., min_length=2, max_length=100)


class LeadRead(LeadBase):
    id: uuid.UUID
    status: LeadStatus
    assigned_sales_id: uuid.UUID
    customer_id: Optional[uuid.UUID] = None
    lost_reason: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    assigned_sales: Optional[UserRead] = None

    class Config:
        from_attributes = True
