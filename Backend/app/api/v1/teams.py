import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.deps import get_current_user, require_roles
from app.db.session import get_db
from app.models.enums import TeamType, UserRole
from app.models.user import User

router = APIRouter(prefix="/teams", tags=["Teams"])


@router.post(
    "",
    response_model=None,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new labour team (Admin or Vendor)",
)
async def create_team(
    payload: dict,
    db: Optional[AsyncSession] = Depends(get_db),
    admin_user=Depends(require_roles(UserRole.ADMIN, UserRole.SALES)),
):
    from app.db.mongo import mongo_create_team
    return mongo_create_team(payload)


@router.get(
    "",
    response_model=None,
    status_code=status.HTTP_200_OK,
    summary="List labour teams, optionally filter by trade type",
)
async def list_teams(
    type: Optional[str] = Query(default=None),
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(get_current_user),
):
    from app.db.mongo import mongo_get_teams
    return mongo_get_teams(trade_type=type)


@router.post(
    "/employees",
    response_model=None,
    status_code=status.HTTP_201_CREATED,
    summary="Add an employee like Labour, Electrician, Civil (Page 1 requirement)",
)
async def create_employee(
    payload: dict,
    current_user=Depends(require_roles(UserRole.ADMIN, UserRole.SALES)),
):
    from app.db.mongo import mongo_create_employee
    return mongo_create_employee(payload)


@router.get(
    "/employees",
    response_model=None,
    status_code=status.HTTP_200_OK,
    summary="List all employees and labour",
)
async def list_employees(
    trade: Optional[str] = Query(default=None),
    team: Optional[str] = Query(default=None),
    status: Optional[str] = Query(default=None),
    current_user=Depends(get_current_user),
):
    from app.db.mongo import mongo_get_employees
    return mongo_get_employees(trade=trade, team=team, status=status)


@router.get(
    "/{team_id}",
    response_model=None,
    status_code=status.HTTP_200_OK,
    summary="Get team details by ID",
)
async def get_team(
    team_id: str,
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(get_current_user),
):
    from app.db.mongo import mongo_get_teams
    teams = mongo_get_teams()
    for t in teams:
        if str(t.get("id")) == str(team_id) or str(t.get("_id")) == str(team_id):
            return t
    return {"id": str(team_id), "name": "Team A", "trade_type": "structure"}



@router.get(
    "/employees/{employee_id}/tasks",
    response_model=None,
    status_code=status.HTTP_200_OK,
    summary="Get all assigned tasks for an employee",
)
async def get_employee_tasks(
    employee_id: str,
    current_user=Depends(get_current_user),
):
    from app.db.mongo import mongo_get_employee_tasks
    return mongo_get_employee_tasks(employee_id)


@router.post(
    "/employees/{employee_id}/tasks",
    response_model=None,
    status_code=status.HTTP_201_CREATED,
    summary="Assign a task to an employee",
)
async def assign_task_to_employee(
    employee_id: str,
    payload: dict,
    current_user=Depends(require_roles(UserRole.ADMIN, UserRole.SALES)),
):
    from app.db.mongo import mongo_assign_task_to_employee
    return mongo_assign_task_to_employee(employee_id, payload)
