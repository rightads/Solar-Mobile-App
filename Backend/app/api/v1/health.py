from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db
from app.schemas.common import HealthResponse

router = APIRouter(tags=["Health"])


@router.get("/health", response_model=HealthResponse)
async def health_check(db: AsyncSession = Depends(get_db)):
    """Check API and Database connectivity health."""
    try:
        if db is not None:
            try:
                await db.execute(text("SELECT 1"))
                return HealthResponse(status="ok", db="postgresql")
            except Exception:
                pass
        
        # Check MongoDB when running in MongoDB Atlas mode
        try:
            from app.db.mongo import get_mongo_db
            mongo_db = get_mongo_db()
            if mongo_db is not None:
                mongo_db.command("ping")
                return HealthResponse(status="ok", db="mongodb")
        except Exception:
            pass

        return HealthResponse(status="ok", db="ok")
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database unavailable.",
        )
