import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field, field_validator
from app.core.security import normalize_phone
from app.models.enums import CustomerStage, SystemPhase
from app.schemas.document import CustomerDocumentRead
from app.schemas.user import UserRead


class StageHistoryRead(BaseModel):
    id: uuid.UUID
    customer_id: uuid.UUID
    from_stage: Optional[CustomerStage] = None
    to_stage: CustomerStage
    changed_by: Optional[uuid.UUID] = None
    note: Optional[str] = None
    created_at: datetime
    actor: Optional[UserRead] = None

    class Config:
        from_attributes = True


class CustomerBase(BaseModel):
    name: str = Field(..., min_length=2, max_length=100)
    mobile: str = Field(..., description="10-digit Indian mobile number")
    address: str = Field(..., min_length=5)
    latitude: Optional[float] = Field(None, ge=-90.0, le=90.0)
    longitude: Optional[float] = Field(None, ge=-180.0, le=180.0)
    final_price: int = Field(..., ge=0, description="Final price in paise (e.g., 25000000 = Rs. 2,50,000)")
    capacity_kw: float = Field(..., gt=0, description="Solar capacity in kW")
    phase: SystemPhase = Field(..., description="single or three phase")
    panel_brand: str = Field(..., min_length=2, max_length=100)
    panel_watt: int = Field(..., gt=0)
    panel_count: int = Field(..., gt=0)
    inverter_brand: str = Field(..., min_length=2, max_length=100)
    structure_type: str = Field(..., min_length=2, max_length=100)

    @field_validator("mobile")
    @classmethod
    def validate_mobile(cls, v: str) -> str:
        return normalize_phone(v)


class CustomerCreate(CustomerBase):
    sales_id: Optional[uuid.UUID] = Field(None, description="Assigned sales user (admin can assign; sales defaults to self)")


class CustomerUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=2, max_length=100)
    address: Optional[str] = Field(None, min_length=5)
    latitude: Optional[float] = Field(None, ge=-90.0, le=90.0)
    longitude: Optional[float] = Field(None, ge=-180.0, le=180.0)
    final_price: Optional[int] = Field(None, ge=0)
    capacity_kw: Optional[float] = Field(None, gt=0)
    phase: Optional[SystemPhase] = None
    panel_brand: Optional[str] = None
    panel_watt: Optional[int] = Field(None, gt=0)
    panel_count: Optional[int] = Field(None, gt=0)
    inverter_brand: Optional[str] = None
    structure_type: Optional[str] = None
    sales_id: Optional[uuid.UUID] = None


class CustomerStageUpdate(BaseModel):
    stage: CustomerStage = Field(..., description="Target customer stage")
    note: Optional[str] = Field(None, description="Optional reason / notes for transition")


class CustomerRead(CustomerBase):
    id: uuid.UUID
    sales_id: uuid.UUID
    user_id: uuid.UUID
    stage: CustomerStage
    sale_closed_at: datetime
    is_deleted: bool
    created_at: datetime
    updated_at: datetime
    sales_agent: Optional[UserRead] = None
    client_user: Optional[UserRead] = None
    documents_count: int = 0
    documents: Optional[List[CustomerDocumentRead]] = None
    stage_histories: Optional[List[StageHistoryRead]] = None
    payment_summary: Dict[str, Any] = Field(
        default_factory=lambda: {
            "total_amount_paise": 0,
            "received_amount_paise": 0,
            "pending_amount_paise": 0,
            "status": "pending_setup",
        }
    )
    work_assignments: Optional[List[Any]] = None

    class Config:
        from_attributes = True


# ── Project bill of materials (equipment scope beyond panels) ───────────────
from pydantic import ConfigDict as _ConfigDict  # noqa: E402

_S60 = Field(None, max_length=60)
_S120 = Field(None, max_length=120)


class ProjectBom(BaseModel):
    """Equipment details captured by sales at conversion. Shown to the site
    team as their scope of work (never prices)."""
    model_config = _ConfigDict(extra="forbid")
    is_subsidy: Optional[bool] = None
    inverter_count: Optional[int] = Field(None, ge=0, le=100)
    inverter_capacity_kw: Optional[float] = Field(None, ge=0, le=1000)
    structure_count: Optional[int] = Field(None, ge=0, le=10000)
    structure_height: Optional[str] = _S60
    ac_wire_brand: Optional[str] = _S60
    ac_wire_size: Optional[str] = _S60
    dc_wire_brand: Optional[str] = _S60
    dc_wire_size: Optional[str] = _S60
    earthing_wire_brand: Optional[str] = _S60
    earthing_wire_size: Optional[str] = _S60
    spd_ac_brand: Optional[str] = _S60
    spd_ac_details: Optional[str] = _S120
    spd_dc_brand: Optional[str] = _S60
    spd_dc_details: Optional[str] = _S120
    solar_meter_brand: Optional[str] = _S60
    solar_meter_count: Optional[int] = Field(None, ge=0, le=20)
    civil_work: Optional[str] = Field(None, max_length=2000)
    earthing_notes: Optional[str] = Field(None, max_length=2000)

    def cleaned(self) -> Dict[str, Any]:
        out: Dict[str, Any] = {}
        for k, v in self.model_dump(exclude_none=True).items():
            if isinstance(v, str):
                v = v.strip()
                if not v:
                    continue
            out[k] = v
        return out


# ── Payment plan & bank loan (managed by sales, visible to admins) ──────────
class PlanMilestone(BaseModel):
    model_config = _ConfigDict(extra="ignore")
    id: str = Field(..., min_length=1, max_length=64)
    title: str = Field(..., min_length=1, max_length=100)
    isPercentage: bool = True
    percentage: float = Field(0, ge=0, le=100)
    fixedAmountPaise: int = Field(0, ge=0, le=10_000_000_00)
    dueCondition: str = Field("", max_length=200)


class PaymentPlanIn(BaseModel):
    model_config = _ConfigDict(extra="ignore")
    isLocked: bool = False
    milestones: List[PlanMilestone] = Field(default_factory=list, max_length=20)


class LoanInstallment(BaseModel):
    model_config = _ConfigDict(extra="ignore")
    id: str = Field(..., min_length=1, max_length=64)
    amountPaise: int = Field(0, ge=0, le=10_000_000_00)
    expectedDate: datetime
    isReceived: bool = False
    notes: str = Field("", max_length=500)


class LoanDetailsIn(BaseModel):
    model_config = _ConfigDict(extra="ignore")
    hasLoan: bool = False
    bankName: str = Field("", max_length=100)
    loanAmountPaise: int = Field(0, ge=0, le=10_000_000_00)
    installments: List[LoanInstallment] = Field(default_factory=list, max_length=50)
