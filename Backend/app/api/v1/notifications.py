"""In-app notifications. Users only ever see or modify notifications addressed
to them personally or broadcast to their role."""
from fastapi import APIRouter, Depends, Query
from app.core import access
from app.core.deps import MongoUserProxy, get_current_user
from app.core.exceptions import NotFoundException
from app.db.mongo import (
    mongo_get_notifications,
    mongo_get_unread_notification_count,
    mongo_mark_all_notifications_read,
    mongo_mark_notification_read,
)

router = APIRouter(prefix="/notifications", tags=["In-App Notifications"])


@router.get("", summary="Notifications for the signed-in user")
async def list_notifications(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0, le=10_000),
    current_user: MongoUserProxy = Depends(get_current_user),
):
    return mongo_get_notifications(user_id=current_user.id, role=access.role_of(current_user), limit=limit, offset=offset)


@router.get("/unread-count", summary="Unread badge count")
async def get_unread_count(current_user: MongoUserProxy = Depends(get_current_user)):
    count = mongo_get_unread_notification_count(user_id=current_user.id, role=access.role_of(current_user))
    return {"unread_count": count, "count": count}


@router.post("/{notification_id}/read", summary="Mark one notification as read")
async def mark_notification_read(notification_id: str, current_user: MongoUserProxy = Depends(get_current_user)):
    if not mongo_mark_notification_read(notification_id, current_user.id, access.role_of(current_user)):
        raise NotFoundException("Notification not found.")
    return {"message": "Notification marked as read."}


@router.post("/read-all", summary="Mark all of your notifications as read")
async def mark_all_read(current_user: MongoUserProxy = Depends(get_current_user)):
    count = mongo_mark_all_notifications_read(user_id=current_user.id, role=access.role_of(current_user))
    return {"message": f"Marked {count} notifications as read."}
