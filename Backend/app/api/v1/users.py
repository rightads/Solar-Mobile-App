"""User administration and staff registration approvals (Admin only)."""
from datetime import datetime, timezone
import html
import re
from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from pydantic import BaseModel, ConfigDict, Field
import structlog
from app.core import access
from app.core.deps import MongoUserProxy, require_roles
from app.core.exceptions import BadRequestException, ForbiddenException, NotFoundException
from app.core.helpers import paginate_list
from app.db.mongo import (
    _format_mongo_doc,
    get_mongo_db,
    mongo_approve_user,
    mongo_create_employee,
    mongo_get_registration_approvals,
    mongo_reject_user,
)
from app.models.enums import ApprovalStatus, UserRole
from app.services.auth_service import AuthService

logger = structlog.get_logger()
router = APIRouter(prefix="/users", tags=["Users"])
require_admin = require_roles(UserRole.ADMIN)


class UserCreateIn(BaseModel):
    model_config = ConfigDict(extra="ignore")
    name: str = Field(..., min_length=2, max_length=100)
    phone: str = Field(..., max_length=15)
    email: Optional[str] = Field(None, max_length=120)
    role: str = Field(..., max_length=20)
    trade: Optional[str] = Field(None, max_length=30)
    team: Optional[str] = Field(None, max_length=60)
    password: Optional[str] = Field(None, min_length=8, max_length=72)


class UserPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: Optional[str] = Field(None, min_length=2, max_length=100)
    role: Optional[str] = Field(None, max_length=20)
    team: Optional[str] = Field(None, max_length=60)
    trade: Optional[str] = Field(None, max_length=30)
    is_active: Optional[bool] = None


def _user(user_id: str) -> dict:
    doc = get_mongo_db()["users"].find_one({"$or": [{"_id": user_id}, {"id": user_id}]})
    if not doc or doc.get("deleted_at"):
        raise NotFoundException("User not found.")
    return doc


def _guard_target(actor: MongoUserProxy, target: dict) -> None:
    if target.get("is_superadmin") and not actor.is_superadmin:
        raise ForbiddenException("Only the Super Admin can modify this account.")
    if str(target.get("role", "")).lower() in access.ADMIN_ROLES and not actor.is_superadmin:
        raise ForbiddenException("Only the Super Admin can modify administrator accounts.")


@router.post("", status_code=status.HTTP_201_CREATED, summary="Create a staff account")
async def create_user(payload: UserCreateIn, admin_user: MongoUserProxy = Depends(require_admin)):
    try:
        return mongo_create_employee(payload.model_dump(exclude_none=True))
    except ValueError as e:
        raise BadRequestException(str(e))


@router.get("", summary="List users")
async def list_users(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    role: Optional[str] = Query(default=None, max_length=20),
    is_active: Optional[bool] = Query(default=None),
    search: Optional[str] = Query(default=None, max_length=60),
    admin_user: MongoUserProxy = Depends(require_admin),
):
    query: dict = {"deleted_at": None}
    if role:
        query["role"] = role.lower()
    if is_active is not None:
        query["is_active"] = is_active
    if search:
        s = re.escape(search.strip())
        query["$or"] = [{f: {"$regex": s, "$options": "i"}} for f in ("name", "phone", "email", "employee_no")]
    col = get_mongo_db()["users"]
    total = col.count_documents(query)
    cursor = col.find(query).sort("created_at", -1).skip((page - 1) * page_size).limit(page_size)
    return paginate_list(items=[_format_mongo_doc(d) for d in cursor], page=page, page_size=page_size, total=total)


@router.get("/approvals/list", summary="Staff registration requests")
async def list_pending_approvals(
    status: ApprovalStatus = Query(default=ApprovalStatus.PENDING),
    admin_user: MongoUserProxy = Depends(require_admin),
):
    return mongo_get_registration_approvals(status=status.value)


@router.post("/approvals/{user_id}/approve", summary="Approve a staff registration")
async def approve_registration(user_id: str, admin_user: MongoUserProxy = Depends(require_admin)):
    target = _user(user_id)
    if str(target.get("role", "")).lower() == "client":
        raise BadRequestException("Client accounts do not need approval.")
    _guard_target(admin_user, target)
    user = mongo_approve_user(str(target["_id"]))
    if not user:
        raise NotFoundException("Registration request not found.")
    logger.info("user_registration_approved", user_id=str(target["_id"]), approved_by=admin_user.id)
    if user.get("email"):
        try:
            from app.services.email_service import email_service
            import asyncio
            asyncio.create_task(email_service._send_resend(
                user["email"],
                "Your SolarPro account is approved",
                f"<p>Hello <strong>{html.escape(str(user.get('name', '')))}</strong>,</p>"
                "<p>Your SolarPro staff account has been approved. You can now sign in to the app.</p>",
            ))
        except Exception as e:
            logger.warning("approval_email_dispatch_failed", error=str(e))
    return {"message": "User registration approved successfully.", "user": _format_mongo_doc(user)}


@router.post("/approvals/{user_id}/reject", summary="Reject a staff registration")
async def reject_registration(user_id: str, admin_user: MongoUserProxy = Depends(require_admin)):
    target = _user(user_id)
    _guard_target(admin_user, target)
    user = mongo_reject_user(str(target["_id"]))
    if not user:
        raise NotFoundException("Registration request not found.")
    AuthService.revoke_all_sessions(str(target["_id"]))
    logger.info("user_registration_rejected", user_id=str(target["_id"]), rejected_by=admin_user.id)
    return {"message": "User registration request rejected.", "user": _format_mongo_doc(user)}


@router.get("/{user_id}", summary="User details")
async def get_user(user_id: str, admin_user: MongoUserProxy = Depends(require_admin)):
    return _format_mongo_doc(_user(user_id))


@router.patch("/{user_id}", summary="Update a user")
async def update_user(user_id: str, payload: UserPatch, admin_user: MongoUserProxy = Depends(require_admin)):
    target = _user(user_id)
    _guard_target(admin_user, target)
    updates = payload.model_dump(exclude_unset=True)
    if "role" in updates:
        new_role = (updates["role"] or "").lower()
        allowed = access.ASSIGNABLE_STAFF_ROLES | ({"admin"} if admin_user.is_superadmin else set())
        if new_role not in allowed or str(target.get("role")) == "client":
            raise BadRequestException("Invalid role change.")
        updates["role"] = new_role
    if str(target["_id"]) == admin_user.id and updates.get("is_active") is False:
        raise BadRequestException("You cannot deactivate your own account.")
    updates["updated_at"] = datetime.now(timezone.utc)
    from pymongo import ReturnDocument
    res = get_mongo_db()["users"].find_one_and_update({"_id": target["_id"]}, {"$set": updates},
                                                       return_document=ReturnDocument.AFTER)
    if "role" in updates or updates.get("is_active") is False:
        AuthService.revoke_all_sessions(str(target["_id"]))
    return _format_mongo_doc(res)


@router.delete("/{user_id}", summary="Deactivate and remove a user")
async def delete_user(user_id: str, admin_user: MongoUserProxy = Depends(require_admin)):
    target = _user(user_id)
    _guard_target(admin_user, target)
    if str(target["_id"]) == admin_user.id:
        raise BadRequestException("You cannot delete your own account.")
    now = datetime.now(timezone.utc)
    get_mongo_db()["users"].update_one({"_id": target["_id"]}, {"$set": {"is_active": False, "deleted_at": now, "updated_at": now}})
    AuthService.revoke_all_sessions(str(target["_id"]))
    return {"message": "User deactivated and deleted successfully."}
