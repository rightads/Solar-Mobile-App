"""Fixed-window rate limiting backed by MongoDB.

Counters live in the shared database (not process memory) so limits hold
across every gunicorn worker and container restart. A TTL index on
``expires_at`` lets MongoDB garbage-collect expired windows.
"""
from datetime import datetime, timedelta, timezone
import math
import threading
from typing import Dict, Optional, Tuple
from fastapi import Request
from app.core.config import settings
from app.core.exceptions import TooManyRequestsException

_COLLECTION = "rate_limits"

# Fallback used only when MongoDB is unreachable (dev/tests without a DB).
_memory: Dict[str, Tuple[int, datetime]] = {}
_memory_lock = threading.Lock()


def _col():
    from app.db.mongo import get_mongo_db
    db = get_mongo_db()
    return db[_COLLECTION] if db is not None else None


def _as_aware(dt: datetime) -> datetime:
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)


def _increment(key: str, window_seconds: int) -> Tuple[int, datetime]:
    now = datetime.now(timezone.utc)
    col = _col()
    if col is None:
        with _memory_lock:
            count, expires = _memory.get(key, (0, now))
            if expires <= now:
                count, expires = 0, now + timedelta(seconds=window_seconds)
            count += 1
            _memory[key] = (count, expires)
            return count, expires

    current = col.find_one({"_id": key})
    if current is None or _as_aware(current["expires_at"]) <= now:
        col.replace_one(
            {"_id": key},
            {"_id": key, "count": 0, "expires_at": now + timedelta(seconds=window_seconds)},
            upsert=True,
        )
    from pymongo import ReturnDocument
    doc = col.find_one_and_update(
        {"_id": key}, {"$inc": {"count": 1}}, return_document=ReturnDocument.AFTER
    )
    return int(doc["count"]), _as_aware(doc["expires_at"])


def peek(key: str) -> int:
    """Return the current count for ``key`` without incrementing it."""
    now = datetime.now(timezone.utc)
    col = _col()
    if col is None:
        with _memory_lock:
            count, expires = _memory.get(key, (0, now))
            return count if expires > now else 0
    doc = col.find_one({"_id": key})
    if not doc or _as_aware(doc["expires_at"]) <= now:
        return 0
    return int(doc.get("count", 0))


def reset(key: str) -> None:
    col = _col()
    if col is None:
        with _memory_lock:
            _memory.pop(key, None)
        return
    col.delete_one({"_id": key})


def hit(key: str, limit: int, window_seconds: int, message: Optional[str] = None) -> int:
    """Count one event for ``key``; raise 429 once ``limit`` is exceeded."""
    count, expires = _increment(key, window_seconds)
    if count > limit:
        retry = max(1, math.ceil((expires - datetime.now(timezone.utc)).total_seconds()))
        raise TooManyRequestsException(
            message or f"Too many attempts. Please try again in {_human(retry)}.",
            retry_after=retry,
        )
    return count


def ensure_below(key: str, limit: int, message: Optional[str] = None, window_seconds: int = 900) -> None:
    """Raise 429 if ``key`` has already reached ``limit`` (does not increment)."""
    if peek(key) >= limit:
        raise TooManyRequestsException(
            message or "Too many failed attempts. Please try again later.",
            retry_after=window_seconds,
        )


def _human(seconds: int) -> str:
    if seconds < 90:
        return f"{seconds} seconds"
    return f"{math.ceil(seconds / 60)} minutes"


def client_ip(request: Optional[Request]) -> str:
    """Best-effort client IP. Proxy headers are trusted only behind our nginx."""
    if request is None:
        return "unknown"
    if settings.TRUST_PROXY_HEADERS:
        real_ip = request.headers.get("x-real-ip")
        if real_ip:
            return real_ip.strip()[:64]
    return request.client.host if request.client else "unknown"
