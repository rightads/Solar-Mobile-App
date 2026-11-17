"""Operations reports and Excel exports (MongoDB). Admin/manager only; KEDL may read the KEDL report."""
from datetime import datetime
from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse

from app.core.deps import MongoUserProxy, require_roles
from app.models.enums import UserRole
from app.schemas.report import (
    DashboardReportResponse,
    KedlReportResponse,
    PaymentsReportResponse,
    SalesReportResponse,
    WorkReportResponse,
)
from app.services.report_service import ReportService

router = APIRouter(prefix="/reports", tags=["Reports & Operations Analytics"])
require_managers = require_roles(UserRole.ADMIN, UserRole.MANAGER)
XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"


def _xlsx(stream, name: str) -> StreamingResponse:
    filename = f"{name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"
    return StreamingResponse(stream, media_type=XLSX,
                             headers={"Content-Disposition": f'attachment; filename="{filename}"'})


@router.get("/dashboard", response_model=DashboardReportResponse, summary="Operations KPIs (Admin, Manager)")
async def get_dashboard(current_user: MongoUserProxy = Depends(require_managers)):
    return ReportService.get_dashboard_report()


@router.get("/sales", response_model=SalesReportResponse, summary="Sales performance by salesperson (Admin, Manager)")
async def get_sales_report(current_user: MongoUserProxy = Depends(require_managers)):
    return ReportService.get_sales_report()


@router.get("/payments", response_model=PaymentsReportResponse, summary="Billed vs collected and mode split (Admin, Manager)")
async def get_payments_report(current_user: MongoUserProxy = Depends(require_managers)):
    return ReportService.get_payments_report()


@router.get("/work", response_model=WorkReportResponse, summary="Site work by assigned employee (Admin, Manager)")
async def get_work_report(current_user: MongoUserProxy = Depends(require_managers)):
    return ReportService.get_work_report()


@router.get("/kedl", response_model=KedlReportResponse, summary="KEDL paperwork and demand balance (Admin, Manager, KEDL)")
async def get_kedl_report(current_user: MongoUserProxy = Depends(require_roles(UserRole.ADMIN, UserRole.MANAGER, UserRole.KEDL))):
    return ReportService.get_kedl_report()


@router.get("/export/customers", summary="Excel export of all customer projects (Admin, Manager)")
async def export_customers(current_user: MongoUserProxy = Depends(require_managers)):
    return _xlsx(ReportService.export_customers_excel(), "customers_report")


@router.get("/export/payments", summary="Excel export of the payment ledger (Admin, Manager)")
async def export_payments(current_user: MongoUserProxy = Depends(require_managers)):
    return _xlsx(ReportService.export_payments_excel(), "payments_ledger")


@router.get("/export/inventory", summary="Excel export of inventory and stock status (Admin, Manager)")
async def export_inventory(current_user: MongoUserProxy = Depends(require_managers)):
    return _xlsx(ReportService.export_inventory_excel(), "inventory_report")
