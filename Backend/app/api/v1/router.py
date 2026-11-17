from fastapi import APIRouter
from app.api.v1.auth import router as auth_router
from app.api.v1.client import router as client_router
from app.api.v1.customers import router as customers_router
from app.api.v1.documents import router as documents_router
from app.api.v1.health import router as health_router
from app.api.v1.inventory import router as inventory_router
from app.api.v1.kedl import router as kedl_router
from app.api.v1.leads import router as leads_router
from app.api.v1.notifications import router as notifications_router
from app.api.v1.payments import router as payments_router
from app.api.v1.reports import router as reports_router
from app.api.v1.teams import router as teams_router
from app.api.v1.tickets import router as tickets_router
from app.api.v1.users import router as users_router
from app.api.v1.work_assignments import router as work_assignments_router

api_v1_router = APIRouter()
api_v1_router.include_router(health_router)
api_v1_router.include_router(auth_router)
api_v1_router.include_router(users_router)
api_v1_router.include_router(teams_router)
api_v1_router.include_router(leads_router)
api_v1_router.include_router(customers_router)
api_v1_router.include_router(documents_router)
api_v1_router.include_router(payments_router)
api_v1_router.include_router(work_assignments_router)
api_v1_router.include_router(kedl_router)
api_v1_router.include_router(client_router)
api_v1_router.include_router(tickets_router)
api_v1_router.include_router(notifications_router)
api_v1_router.include_router(inventory_router)
api_v1_router.include_router(reports_router)



