import uuid
from typing import Callable, List, Optional, Set
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
import structlog
from app.core.exceptions import ForbiddenException, UnauthorizedException
from app.core.security import decode_access_token
from app.db.session import get_db
from app.models.enums import UserRole
from app.models.user import User

logger = structlog.get_logger()
security_bearer = HTTPBearer(auto_error=False)


class MongoUserProxy:
    """Lightweight proxy for Mongo-backed authenticated users."""
    def __init__(self, doc: dict):
        self.id = str(doc.get("id") or doc["_id"])
        self.name = doc.get("name", "")
        self.phone = doc.get("phone", "")
        self.email = doc.get("email")
        try:
            self.role = UserRole(doc.get("role", "client"))
        except Exception:
            self.role = doc.get("role", "client")
        self.is_active = doc.get("is_active", True)
        self.fcm_token = doc.get("fcm_token")
        self.employee_no = doc.get("employee_no")
        self.trade = doc.get("trade")
        self.team = doc.get("team")


def _get_user_from_mongo(user_id_str: str) -> Optional[MongoUserProxy]:
    """Helper to query active user document from MongoDB Atlas."""
    from app.db.mongo import get_mongo_db
    mongo_db = get_mongo_db()
    if mongo_db is None:
        return None

    from bson import ObjectId
    query_conditions = [{"id": user_id_str}, {"_id": user_id_str}]
    if ObjectId.is_valid(user_id_str):
        query_conditions.append({"_id": ObjectId(user_id_str)})

    mongo_user = mongo_db["users"].find_one({"$or": query_conditions, "is_active": True})
    return MongoUserProxy(mongo_user) if mongo_user else None


async def _get_user_from_db(db: AsyncSession, user_id_str: str) -> Optional[User]:
    """Helper to query active user record from SQLAlchemy."""
    try:
        user_uuid = uuid.UUID(user_id_str)
        query = select(User).where(
            User.id == user_uuid,
            User.is_deleted == False,
        )
        result = await db.execute(query)
        user = result.scalar_one_or_none()
        if user and not user.is_active:
            raise ForbiddenException("User account is deactivated.")
        return user
    except ForbiddenException:
        raise
    except Exception as e:
        logger.debug("sql_user_lookup_failed", error=str(e), user_id=user_id_str)
        return None


def _expand_allowed_roles(*allowed_roles: UserRole | str) -> Set[str]:
    """Normalize roles and expand aliases (e.g., sales includes salesman/employee, admin includes vendor/co_admin)."""
    expanded = {
        role.value if isinstance(role, UserRole) else str(role)
        for role in allowed_roles
    }
    if "admin" in expanded:
        expanded.add("main_admin")
        expanded.add("co_admin")
        expanded.add("super_admin")
        expanded.add("vendor")
    if "sales" in expanded:
        expanded.add("salesman")
        expanded.add("employee")
    if "technician" in expanded or "labour" in expanded:
        expanded.add("site")
        expanded.add("service")
        expanded.add("electrician")
        expanded.add("structure")
        expanded.add("civil")
    if "service" in expanded:
        expanded.add("technician")
    return expanded


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
    db: Optional[AsyncSession] = Depends(get_db),
) -> User | MongoUserProxy:
    """Extract and validate the current authenticated active user from JWT."""
    if not credentials or not credentials.credentials:
        raise UnauthorizedException("Authentication token required.")

    payload = decode_access_token(credentials.credentials)
    user_id_str: Optional[str] = payload.get("sub")

    if not user_id_str:
        raise UnauthorizedException("Invalid token payload.")

    # 1. Check MongoDB Atlas first
    mongo_user = _get_user_from_mongo(user_id_str)
    if mongo_user:
        return mongo_user

    # 2. Check SQLAlchemy if db session is available
    if db is not None:
        user = await _get_user_from_db(db, user_id_str)
        if user:
            return user

    raise UnauthorizedException("User not found.")


def require_roles(*allowed_roles: UserRole | str) -> Callable[[User], User]:
    """Dependency factory to enforce role-based access control."""
    allowed_role_values = _expand_allowed_roles(*allowed_roles)

    async def role_checker(current_user: User = Depends(get_current_user)) -> User:
        user_role_val = current_user.role.value if isinstance(current_user.role, UserRole) else str(current_user.role)
        if user_role_val not in allowed_role_values:
            raise ForbiddenException(
                f"Operation not permitted. Required roles: {', '.join(allowed_role_values)}"
            )
        return current_user

    return role_checker

