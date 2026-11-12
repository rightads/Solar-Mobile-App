from typing import Callable, Optional, Set
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import structlog
from app.core import access
from app.core.exceptions import ForbiddenException, UnauthorizedException
from app.core.security import decode_access_token
from app.models.enums import UserRole

logger = structlog.get_logger()
security_bearer = HTTPBearer(auto_error=False)


class MongoUserProxy:
    """Authenticated user loaded from MongoDB (never carries the password hash)."""

    def __init__(self, doc: dict):
        self.id = str(doc.get("id") or doc["_id"])
        self.name = doc.get("name", "")
        self.phone = doc.get("phone", "")
        self.email = doc.get("email")
        try:
            self.role = UserRole(doc.get("role", "client"))
        except Exception:
            self.role = str(doc.get("role", "client"))
        self.is_active = doc.get("is_active", True)
        self.is_superadmin = bool(doc.get("is_superadmin", False))
        self.is_phone_verified = bool(doc.get("is_phone_verified", False))
        self.is_email_verified = bool(doc.get("is_email_verified", False))
        self.token_version = int(doc.get("token_version", 0) or 0)
        self.fcm_token = doc.get("fcm_token")
        self.employee_no = doc.get("employee_no")
        self.trade = doc.get("trade")
        self.team = doc.get("team")


def load_user(user_id_str: str) -> Optional[dict]:
    from app.db.mongo import get_mongo_db
    db = get_mongo_db()
    if db is None:
        return None
    return db["users"].find_one({"$or": [{"_id": user_id_str}, {"id": user_id_str}]})


def assert_can_sign_in(doc: dict) -> None:
    """Shared gate for token issuance and every authenticated request."""
    if doc.get("is_superadmin"):
        return
    role = str(doc.get("role", "client")).lower()
    status = str(doc.get("approval_status") or ("approved" if doc.get("is_active") else "pending")).lower()
    if role != "client":
        if status == "rejected":
            raise ForbiddenException("Your account registration was rejected. Please contact support.")
        if status != "approved":
            raise ForbiddenException("Your account is pending approval by the Super Admin.")
    if not doc.get("is_active", False):
        raise ForbiddenException("This account has been deactivated.")


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
) -> MongoUserProxy:
    """Validate the bearer token and return the active user it belongs to."""
    if not credentials or not credentials.credentials:
        raise UnauthorizedException("Authentication token required.")

    payload = decode_access_token(credentials.credentials)
    user_id_str = str(payload.get("sub") or "")
    if not user_id_str:
        raise UnauthorizedException("Invalid token payload.")

    doc = load_user(user_id_str)
    if not doc:
        raise UnauthorizedException("User not found.")
    # Tokens issued before a logout-all / password change / deactivation are void.
    if int(payload.get("tv", -1)) != int(doc.get("token_version", 0) or 0):
        raise UnauthorizedException("Session has been revoked. Please sign in again.")
    try:
        assert_can_sign_in(doc)
    except ForbiddenException as e:
        raise UnauthorizedException(e.message)
    return MongoUserProxy(doc)


_ROLE_GROUPS = {
    "admin": access.ADMIN_ROLES,
    "manager": {"manager"},
    "sales": access.SALES_ROLES,
    "office_staff": {"office_staff"},
    "kedl": access.KEDL_ROLES,
    "service": access.SERVICE_ROLES,
    "technician": access.SITE_ROLES | access.SERVICE_ROLES,
    "labour": access.SITE_ROLES,
    "site": access.SITE_ROLES,
    "client": access.CLIENT_ROLES,
    "employee": access.SALES_ROLES,
}


def _expand_allowed_roles(*allowed_roles: UserRole | str) -> Set[str]:
    expanded: Set[str] = set()
    for role in allowed_roles:
        key = str(getattr(role, "value", role)).lower()
        expanded |= _ROLE_GROUPS.get(key, {key})
    return expanded


def require_roles(*allowed_roles: UserRole | str) -> Callable:
    """Dependency factory enforcing role-based access control."""
    allowed = _expand_allowed_roles(*allowed_roles)

    async def role_checker(current_user: MongoUserProxy = Depends(get_current_user)) -> MongoUserProxy:
        if access.role_of(current_user) not in allowed:
            raise ForbiddenException("You do not have permission to perform this action.")
        return current_user

    return role_checker


require_staff = require_roles(*access.STAFF_ROLES)
require_client = require_roles(UserRole.CLIENT)
require_admin = require_roles(UserRole.ADMIN)
