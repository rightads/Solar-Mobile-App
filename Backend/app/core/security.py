from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import re
import secrets
from typing import Any, Dict, Optional
import bcrypt
import jwt
from app.core.config import settings
from app.core.exceptions import UnauthorizedException

# bcrypt only uses the first 72 bytes of input; longer passwords are rejected
# up-front so two different long passwords can never collide.
MAX_PASSWORD_BYTES = 72
MIN_PASSWORD_LENGTH = 8

_EMAIL_RE = re.compile(r"^[A-Za-z0-9._%+\-]{1,64}@[A-Za-z0-9.\-]{1,253}\.[A-Za-z]{2,24}$")


def normalize_phone(phone: str) -> str:
    """Normalize phone number to 10-digit format for Indian numbers."""
    cleaned = re.sub(r"\D", "", str(phone))
    if len(cleaned) == 12 and cleaned.startswith("91"):
        cleaned = cleaned[2:]
    elif len(cleaned) == 11 and cleaned.startswith("0"):
        cleaned = cleaned[1:]
    if len(cleaned) != 10 or cleaned[0] not in "6789":
        raise ValueError("Invalid phone number. Must be a 10-digit Indian mobile number.")
    return cleaned


def normalize_email(email: str) -> str:
    clean = str(email).strip().lower()
    if not _EMAIL_RE.match(clean) or ".." in clean:
        raise ValueError("Invalid email address.")
    return clean


def validate_password_strength(password: str) -> str:
    if len(password) < MIN_PASSWORD_LENGTH:
        raise ValueError(f"Password must be at least {MIN_PASSWORD_LENGTH} characters.")
    if len(password.encode("utf-8")) > MAX_PASSWORD_BYTES:
        raise ValueError("Password is too long (max 72 bytes).")
    if not re.search(r"[A-Za-z]", password) or not re.search(r"\d", password):
        raise ValueError("Password must contain both letters and numbers.")
    return password


def hash_password(password: str) -> str:
    """Hash a password using bcrypt with an automatically generated cryptographic salt."""
    salt = bcrypt.gensalt(rounds=12)
    return bcrypt.hashpw(password.encode("utf-8")[:MAX_PASSWORD_BYTES], salt).decode("utf-8")


# Pre-computed hash used to keep login timing identical whether or not the
# account exists (prevents user enumeration by response time).
_DUMMY_HASH = bcrypt.hashpw(secrets.token_bytes(16), bcrypt.gensalt(rounds=12)).decode("utf-8")


def verify_password(plain_password: str, hashed_password: Optional[str]) -> bool:
    """Verify a plaintext password against a stored bcrypt hash in constant time."""
    try:
        candidate = plain_password.encode("utf-8")[:MAX_PASSWORD_BYTES]
        if not hashed_password:
            bcrypt.checkpw(candidate, _DUMMY_HASH.encode("utf-8"))
            return False
        return bcrypt.checkpw(candidate, hashed_password.encode("utf-8"))
    except Exception:
        return False


def sanitize_input(value: Any) -> Any:
    """
    Defence-in-depth against NoSQL operator injection: strips whitespace from
    strings and drops any dict key that starts with "$" or contains ".".
    """
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, dict):
        return {
            k: sanitize_input(v)
            for k, v in value.items()
            if not str(k).startswith("$") and "." not in str(k)
        }
    if isinstance(value, list):
        return [sanitize_input(v) for v in value]
    return value


def hash_token(token: str) -> str:
    """Hash sensitive tokens/OTPs using HMAC-SHA256 keyed with the server secret."""
    return hmac.new(
        settings.JWT_SECRET.encode("utf-8"),
        token.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def verify_token_hash(token: str, token_hash: str) -> bool:
    """Verify a token against its stored hash in constant time."""
    return hmac.compare_digest(hash_token(token), token_hash or "")


def generate_otp(length: int = 6) -> str:
    """Generate a cryptographically secure random numeric OTP code."""
    return "".join(secrets.choice("0123456789") for _ in range(length))


def generate_random_token() -> str:
    """Generate a secure random string for refresh tokens."""
    return secrets.token_urlsafe(48)


def create_access_token(
    subject: str,
    role: str,
    token_version: int = 0,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """Generate a signed, short-lived JWT access token."""
    now = datetime.now(timezone.utc)
    expire = now + (expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode: Dict[str, Any] = {
        "sub": str(subject),
        "role": str(role),
        "tv": int(token_version),
        "iss": settings.JWT_ISSUER,
        "iat": now,
        "nbf": now,
        "exp": expire,
        "jti": secrets.token_hex(12),
        "type": "access",
    }
    return jwt.encode(to_encode, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)


def decode_access_token(token: str) -> Dict[str, Any]:
    """Decode and strictly validate a JWT access token."""
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET,
            algorithms=[settings.JWT_ALGORITHM],
            issuer=settings.JWT_ISSUER,
            options={"require": ["exp", "iat", "sub", "iss", "type"]},
        )
    except jwt.ExpiredSignatureError:
        raise UnauthorizedException("Token has expired.")
    except jwt.PyJWTError:
        raise UnauthorizedException("Could not validate credentials.")
    if payload.get("type") != "access":
        raise UnauthorizedException("Invalid token type.")
    return payload
