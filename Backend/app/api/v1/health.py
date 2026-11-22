from fastapi import APIRouter, HTTPException, status
from fastapi.concurrency import run_in_threadpool
import structlog

from app.db.mongo import get_mongo_db
from app.schemas.common import HealthResponse

logger = structlog.get_logger()

router = APIRouter(tags=["Health"])


@router.get("/health", response_model=HealthResponse)
async def health_check():
    """Report 200 only when MongoDB answers a ping; otherwise 503.

    The deploy script and the Docker HEALTHCHECK both rely on this, so it must
    never claim "ok" while the database is unreachable.
    """
    mongo_db = get_mongo_db()
    if mongo_db is None:
        logger.error("Health check failed: MongoDB is not configured")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database not configured.",
        )
    try:
        # pymongo is synchronous; keep the event loop free while it waits.
        await run_in_threadpool(mongo_db.command, "ping")
    except Exception as exc:
        logger.error("Health check failed: MongoDB unreachable", error=str(exc))
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database unavailable.",
        )
    return HealthResponse(status="ok", db="mongodb")
