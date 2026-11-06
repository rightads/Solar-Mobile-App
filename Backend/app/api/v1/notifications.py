from typing import Any, Dict, List, Optional
import uuid
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.notification import NotificationRead, UnreadCountResponse
from app.services.notification_service import NotificationService

router = APIRouter(prefix="/notifications", tags=["In-App Notifications"])


@router.get(
    "",
    response_model=None,
    summary="List in-app notifications for the logged in user",
)
async def list_notifications(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(get_current_user),
):
    from app.db.mongo import mongo_get_notifications
    user_id_str = str(getattr(current_user, "id", ""))
    role_str = str(getattr(current_user, "role", ""))
    if hasattr(current_user.role, "value"):
        role_str = current_user.role.value

    # First check MongoDB Atlas
    mongo_notifs = mongo_get_notifications(user_id=user_id_str, role=role_str, limit=limit, offset=offset)
    if mongo_notifs:
        return mongo_notifs

    # Fallback to SQL
    if db is not None:
        try:
            uid = uuid.UUID(user_id_str)
            return await NotificationService.get_user_notifications(
                db=db,
                user_id=uid,
                limit=limit,
                offset=offset,
            )
        except Exception:
            pass
    return []


@router.get(
    "/unread-count",
    response_model=None,
    summary="Get count of unread notifications for badge counter",
)
async def get_unread_count(
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(get_current_user),
):
    from app.db.mongo import mongo_get_unread_notification_count
    user_id_str = str(getattr(current_user, "id", ""))
    role_str = str(getattr(current_user, "role", ""))
    if hasattr(current_user.role, "value"):
        role_str = current_user.role.value

    mongo_count = mongo_get_unread_notification_count(user_id=user_id_str, role=role_str)
    if mongo_count > 0:
        return {"unread_count": mongo_count, "count": mongo_count}

    if db is not None:
        try:
            uid = uuid.UUID(user_id_str)
            count = await NotificationService.get_unread_count(db, uid)
            return {"unread_count": count, "count": count}
        except Exception:
            pass
    return {"unread_count": 0, "count": 0}


@router.post(
    "/{notification_id}/read",
    response_model=None,
    summary="Mark a single notification as read",
)
async def mark_notification_read(
    notification_id: str,
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(get_current_user),
):
    from app.db.mongo import mongo_mark_notification_read
    if mongo_mark_notification_read(str(notification_id)):
        return {"message": "Notification marked as read."}

    if db is not None:
        try:
            nid = uuid.UUID(str(notification_id))
            uid = uuid.UUID(str(current_user.id))
            return await NotificationService.mark_as_read(db, nid, uid)
        except Exception:
            pass
    return {"message": "Notification marked as read."}


@router.post(
    "/read-all",
    response_model=None,
    summary="Mark all unread notifications as read",
)
async def mark_all_read(
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(get_current_user),
):
    from app.db.mongo import mongo_mark_all_notifications_read
    user_id_str = str(getattr(current_user, "id", ""))
    role_str = str(getattr(current_user, "role", ""))
    if hasattr(current_user.role, "value"):
        role_str = current_user.role.value

    count = mongo_mark_all_notifications_read(user_id=user_id_str, role=role_str)
    if db is not None:
        try:
            uid = uuid.UUID(user_id_str)
            count += await NotificationService.mark_all_as_read(db, uid)
        except Exception:
            pass
    return {"message": f"Marked {count} notifications as read."}
