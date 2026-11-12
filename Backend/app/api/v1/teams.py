"""Labour teams and staff directory (admin-managed)."""
from datetime import date
from typing import Literal, Optional
from fastapi import APIRouter, Depends, Query, status
from pydantic import BaseModel, ConfigDict, Field
from app.core import access
from app.core.deps import MongoUserProxy, require_roles, require_staff
from app.core.exceptions import BadRequestException, NotFoundException
from app.db.mongo import (
    get_mongo_db,
    mongo_assign_task_to_employee,
    mongo_create_employee,
    mongo_create_team,
    mongo_get_employee_tasks,
    mongo_get_employees,
    mongo_get_teams,
)
from app.models.enums import UserRole

router = APIRouter(prefix="/teams", tags=["Teams"])
require_admin = require_roles(UserRole.ADMIN)
require_directory = require_roles(UserRole.ADMIN, UserRole.MANAGER, UserRole.SALES)


class TeamIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    name: str = Field(..., min_length=1, max_length=60)
    trade_type: Literal["structure", "electrical", "civil"]
    lead_name: Optional[str] = Field("", max_length=100)
    lead_phone: Optional[str] = Field("", max_length=15)
    member_count: int = Field(3, ge=1, le=100)


class EmployeeIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    name: str = Field(..., min_length=2, max_length=100)
    phone: str = Field(..., max_length=15)
    email: Optional[str] = Field(None, max_length=120)
    role: str = Field("labour", max_length=20)
    trade: Optional[str] = Field(None, max_length=30)
    team: Optional[str] = Field(None, max_length=60)
    password: Optional[str] = Field(None, min_length=8, max_length=72)


class TaskIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    title: str = Field(..., min_length=1, max_length=150)
    description: Optional[str] = Field("", max_length=2000)
    customer_id: Optional[str] = Field(None, max_length=64)
    location: Optional[str] = Field("", max_length=300)
    category: Optional[str] = Field("general", max_length=30)
    priority: Literal["low", "normal", "high", "urgent"] = "normal"
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    notes: Optional[str] = Field("", max_length=2000)


@router.post("", status_code=status.HTTP_201_CREATED, summary="Create a labour team (Admin)")
async def create_team(payload: TeamIn, current_user: MongoUserProxy = Depends(require_admin)):
    try:
        return mongo_create_team(payload.model_dump())
    except ValueError as e:
        raise BadRequestException(str(e))


@router.get("", summary="List labour teams")
async def list_teams(type: Optional[str] = Query(default=None, max_length=20), current_user: MongoUserProxy = Depends(require_staff)):
    return mongo_get_teams(trade_type=type)


@router.post("/employees", status_code=status.HTTP_201_CREATED, summary="Create a staff account (Admin)")
async def create_employee(payload: EmployeeIn, current_user: MongoUserProxy = Depends(require_admin)):
    try:
        return mongo_create_employee(payload.model_dump(exclude_none=True))
    except ValueError as e:
        raise BadRequestException(str(e))


@router.get("/employees", summary="Staff directory")
async def list_employees(
    trade: Optional[str] = Query(default=None, max_length=30),
    team: Optional[str] = Query(default=None, max_length=60),
    status: Optional[str] = Query(default=None, max_length=20),
    current_user: MongoUserProxy = Depends(require_directory),
):
    if not access.is_admin(current_user):
        status = None  # only admins may browse pending/rejected registrations
    return mongo_get_employees(trade=trade, team=team, status=status)


@router.get("/{team_id}", summary="Team details")
async def get_team(team_id: str, current_user: MongoUserProxy = Depends(require_staff)):
    for t in mongo_get_teams():
        if str(t.get("id")) == str(team_id):
            return t
    raise NotFoundException("Team not found.")


@router.get("/employees/{employee_id}/tasks", summary="An employee's assigned work (Admin or self)")
async def get_employee_tasks(employee_id: str, current_user: MongoUserProxy = Depends(require_staff)):
    if not access.is_admin(current_user) and employee_id not in (current_user.id, current_user.employee_no):
        raise NotFoundException("Employee not found.")
    return mongo_get_employee_tasks(employee_id)


@router.post("/employees/{employee_id}/tasks", status_code=status.HTTP_201_CREATED, summary="Assign a task to an employee")
async def assign_task_to_employee(
    employee_id: str,
    payload: TaskIn,
    current_user: MongoUserProxy = Depends(require_roles(UserRole.ADMIN, UserRole.SALES)),
):
    emp = get_mongo_db()["users"].find_one({"$or": [{"_id": employee_id}, {"employee_no": employee_id}], "is_active": True})
    if not emp or str(emp.get("role", "")).lower() not in access.STAFF_ROLES:
        raise NotFoundException("Employee not found.")
    data = payload.model_dump()
    data["work_type"] = (payload.category or "general").lower()
    for k in ("start_date", "end_date"):
        if data.get(k):
            data[k] = data[k].isoformat()
        else:
            data.pop(k, None)
    if payload.customer_id:
        cust = access.require_customer_write(current_user, payload.customer_id)
        data["customer_name"] = cust.get("name", "")
        data["location"] = data.get("location") or cust.get("address", "")
    else:
        data["customer_name"] = "Direct Assignment"
    return mongo_assign_task_to_employee(str(emp["_id"]), data)
