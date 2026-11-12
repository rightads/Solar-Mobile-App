"""Staff service tickets. Admins see everything; service engineers see their own
tickets plus the unassigned queue."""
from datetime import datetime, timezone
from typing import Optional
import uuid
from fastapi import APIRouter, Depends, Query, status
from pydantic import BaseModel, Field
from app.core import access
from app.core.deps import MongoUserProxy, require_roles
from app.core.exceptions import BadRequestException, ForbiddenException, NotFoundException
from app.db.mongo import (
    _format_mongo_doc,
    get_mongo_db,
    mongo_create_notification,
    mongo_get_tickets,
    mongo_update_ticket_status,
)
from app.models.enums import TicketStatus, UserRole
from app.schemas.ticket import TicketCommentCreate

router = APIRouter(prefix="/tickets", tags=["Staff Service Tickets"])
require_ticket_staff = require_roles(UserRole.ADMIN, UserRole.MANAGER, UserRole.SERVICE)


class TicketAssignIn(BaseModel):
    assigned_to: str = Field(..., min_length=1, max_length=64)


class TicketStatusIn(BaseModel):
    status: TicketStatus
    note: Optional[str] = Field(None, max_length=2000)
    resolution_notes: Optional[str] = Field(None, max_length=2000)


@router.get("", summary="List tickets visible to the caller")
async def list_tickets(
    customer_id: Optional[str] = Query(None, max_length=64),
    status_filter: Optional[str] = Query(None, alias="status", max_length=20),
    ticket_type: Optional[str] = Query(None, alias="type", max_length=20),
    current_user: MongoUserProxy = Depends(require_ticket_staff),
):
    if access.role_of(current_user) in access.MANAGER_ROLES:
        return mongo_get_tickets(customer_id=customer_id, status=status_filter, ticket_type=ticket_type)
    # Service engineers: own + unassigned
    return mongo_get_tickets(customer_id=customer_id, status=status_filter, ticket_type=ticket_type,
                             assigned_to=current_user.id)


@router.get("/{ticket_id}", summary="Ticket details")
async def get_ticket(ticket_id: str, current_user: MongoUserProxy = Depends(require_ticket_staff)):
    return _format_mongo_doc(access.require_ticket(current_user, ticket_id))


@router.post("/{ticket_id}/assign", summary="Assign a ticket to a service engineer (Admin)")
async def assign_ticket(
    ticket_id: str,
    data: TicketAssignIn,
    current_user: MongoUserProxy = Depends(require_roles(UserRole.ADMIN)),
):
    ticket = access.require_ticket(current_user, ticket_id)
    db = get_mongo_db()
    staff = db["users"].find_one({"$or": [{"_id": data.assigned_to}, {"employee_no": data.assigned_to}], "is_active": True})
    if not staff or str(staff.get("role", "")).lower() not in access.SERVICE_ROLES | access.SITE_ROLES:
        raise NotFoundException("Employee not found.")
    staff_id = str(staff["_id"])
    from pymongo import ReturnDocument
    res = db["tickets"].find_one_and_update(
        {"_id": ticket["_id"]},
        {"$set": {
            "assigned_to": staff_id,
            "assigned_staff": staff.get("name"),
            "assigned_staff_emp_no": staff.get("employee_no"),
            "status": "assigned" if ticket.get("status") in (None, "open", "reopened") else ticket.get("status"),
            "updated_at": datetime.now(timezone.utc),
        }},
        return_document=ReturnDocument.AFTER,
    )
    mongo_create_notification({
        "title": "Service ticket assigned to you",
        "body": f"{ticket.get('customer_name', 'Customer')}: {ticket.get('title', '')}",
        "type": "ticket", "user_id": staff_id, "target_id": str(ticket["_id"]),
    })
    return _format_mongo_doc(res)


@router.post("/{ticket_id}/status", summary="Update ticket status (Admin or the assigned engineer)")
async def update_ticket_status(
    ticket_id: str,
    data: TicketStatusIn,
    current_user: MongoUserProxy = Depends(require_ticket_staff),
):
    ticket = access.require_ticket(current_user, ticket_id)
    is_manager = access.role_of(current_user) in access.MANAGER_ROLES
    if not is_manager:
        if ticket.get("assigned_to") in (None, ""):
            # Engineers claim an unassigned ticket by starting it.
            if data.status != TicketStatus.IN_PROGRESS:
                raise ForbiddenException("Start the ticket before changing its status.")
            get_mongo_db()["tickets"].update_one(
                {"_id": ticket["_id"], "$or": [{"assigned_to": None}, {"assigned_to": ""}]},
                {"$set": {"assigned_to": current_user.id, "assigned_staff": current_user.name,
                          "assigned_staff_emp_no": current_user.employee_no}},
            )
        elif data.status == TicketStatus.CLOSED:
            raise ForbiddenException("Only an admin can close tickets.")
    note = (data.resolution_notes or data.note or "").strip() or None
    if data.status == TicketStatus.RESOLVED and not note:
        raise BadRequestException("A resolution note is required to resolve a ticket.")
    res = mongo_update_ticket_status(str(ticket["_id"]), data.status.value, note=note)
    if not res:
        raise NotFoundException("Ticket not found.")
    return res


@router.post("/{ticket_id}/comments", status_code=status.HTTP_201_CREATED, summary="Comment on a ticket as staff")
async def add_staff_ticket_comment(
    ticket_id: str,
    data: TicketCommentCreate,
    current_user: MongoUserProxy = Depends(require_ticket_staff),
):
    ticket = access.require_ticket(current_user, ticket_id)
    cmt = {
        "id": f"cmt_{uuid.uuid4().hex[:12]}",
        "ticket_id": str(ticket["_id"]),
        "author_id": current_user.id,
        "author_name": current_user.name,
        "author_role": access.role_of(current_user),
        "message": data.message.strip(),
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    get_mongo_db()["tickets"].update_one({"_id": ticket["_id"]}, {"$push": {"comments": cmt}})
    return cmt
