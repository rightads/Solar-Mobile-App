"""Operations report schemas (MongoDB-backed; IDs are strings). Money is in paise."""
from typing import Dict, List
from pydantic import BaseModel


class DashboardReportResponse(BaseModel):
    total_leads: int
    leads_by_status: Dict[str, int]
    total_customers: int
    customers_by_stage: Dict[str, int]
    sales_this_month_paise: int
    pending_payment_verifications_count: int
    active_works_count: int
    open_kedl_demands_count: int
    open_service_tickets_count: int
    low_stock_items_count: int


class SalesRepPerformance(BaseModel):
    sales_rep_id: str
    sales_rep_name: str
    total_leads: int
    converted_customers: int
    total_sales_paise: int


class SalesReportResponse(BaseModel):
    sales_reps: List[SalesRepPerformance]
    total_sales_paise: int


class PaymentsReportResponse(BaseModel):
    total_billed_paise: int
    total_collected_paise: int
    pending_verification_paise: int
    pending_advance_paise: int
    pending_final_paise: int
    payments_by_mode: Dict[str, int]


class TeamWorkMetrics(BaseModel):
    """Site work grouped by the employee it is assigned to (``team_id`` is the employee id)."""
    team_id: str
    team_name: str
    team_type: str
    completed_works: int
    in_progress_works: int
    pending_works: int


class WorkReportResponse(BaseModel):
    teams: List[TeamWorkMetrics]
    total_completed: int
    total_active: int


class KedlReportResponse(BaseModel):
    files_by_status: Dict[str, int]
    open_demands_count: int
    open_demands_total_paise: int
    paid_demands_total_paise: int
