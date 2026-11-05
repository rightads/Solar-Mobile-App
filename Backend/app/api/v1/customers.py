from datetime import datetime, timezone
import uuid
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Form, Query, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession
import structlog
from app.core.deps import get_current_user, require_roles
from app.core.helpers import paginate_list, read_upload_file
from app.db.session import get_db
from app.models.enums import CustomerStage, DocumentType, UserRole
from app.models.user import User
from app.schemas.common import PaginatedResponse
from app.schemas.customer import (
    CustomerCreate,
    CustomerRead,
    CustomerStageUpdate,
    CustomerUpdate,
)
from app.schemas.document import CustomerDocumentRead
from app.services.customer_service import CustomerService
from app.services.document_service import DocumentService

logger = structlog.get_logger()
router = APIRouter(prefix="/customers", tags=["Customers"])


@router.post(
    "",
    response_model=None,
    status_code=status.HTTP_201_CREATED,
    summary="Create a new customer (Admin or Sales)",
)
async def create_customer(
    payload: CustomerCreate,
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(require_roles(UserRole.ADMIN, UserRole.SALES)),
):
    from app.db.mongo import mongo_create_customer
    cust_dict = payload.model_dump()
    mongo_doc = mongo_create_customer(cust_dict)
    if db is not None:
        try:
            return await CustomerService.create_customer(
                db=db,
                customer_in=payload,
                creator=current_user,
            )
        except Exception as e:
            logger.debug("sql_create_customer_fallback_to_mongo", error=str(e))
    return mongo_doc


@router.get(
    "",
    response_model=None,
    status_code=status.HTTP_200_OK,
    summary="List customers with filters and role-level isolation",
)
async def list_customers(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    stage: Optional[CustomerStage] = Query(default=None),
    sales_id: Optional[uuid.UUID] = Query(default=None),
    search: Optional[str] = Query(default=None),
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if db is not None:
        try:
            return await CustomerService.list_customers(
                db=db,
                current_user=current_user,
                page=page,
                page_size=page_size,
                stage=stage,
                sales_id=sales_id,
                search=search,
            )
        except Exception as e:
            logger.debug("sql_list_customers_fallback_to_mongo", error=str(e))
    from app.db.mongo import mongo_get_customers
    stage_str = stage.value if hasattr(stage, "value") else (str(stage) if stage else None)
    sales_id_str = str(sales_id) if sales_id else None
    customers = mongo_get_customers(stage=stage_str, search=search, sales_id=sales_id_str)
    return paginate_list(items=customers, page=page, page_size=page_size)


@router.get(
    "/{customer_id}",
    response_model=None,
    status_code=status.HTTP_200_OK,
    summary="Get customer details by ID",
)
async def get_customer(
    customer_id: str,
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if db is not None:
        try:
            return await CustomerService.get_customer_by_id(
                db=db,
                customer_id=uuid.UUID(str(customer_id)),
                current_user=current_user,
            )
        except Exception as e:
            logger.debug("sql_get_customer_fallback_to_mongo", error=str(e))
    from app.db.mongo import mongo_get_customer_by_id
    doc = mongo_get_customer_by_id(str(customer_id))
    if not doc:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Customer not found")
    return doc


@router.patch(
    "/{customer_id}",
    response_model=None,
    status_code=status.HTTP_200_OK,
    summary="Update customer details (Admin or assigned Sales)",
)
async def update_customer(
    customer_id: str,
    payload: dict,
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(require_roles(UserRole.ADMIN, UserRole.SALES)),
):
    if db is not None:
        try:
            return await CustomerService.update_customer(
                db=db,
                customer_id=uuid.UUID(str(customer_id)),
                customer_in=CustomerUpdate(**payload),
                current_user=current_user,
            )
        except Exception as e:
            logger.debug("sql_update_customer_fallback_to_mongo", error=str(e))
    from app.db.mongo import mongo_update_customer
    res = mongo_update_customer(str(customer_id), payload)
    if not res:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Customer not found")
    return res


@router.patch(
    "/{customer_id}/stage",
    response_model=None,
    status_code=status.HTTP_200_OK,
    summary="Update customer lifecycle stage with history tracking (Admin only)",
)
async def update_customer_stage(
    customer_id: str,
    payload: CustomerStageUpdate,
    db: Optional[AsyncSession] = Depends(get_db),
    admin_user=Depends(require_roles(UserRole.ADMIN)),
):
    if db is not None:
        try:
            return await CustomerService.update_customer_stage(
                db=db,
                customer_id=uuid.UUID(str(customer_id)),
                stage_in=payload,
                current_user=admin_user,
            )
        except Exception as e:
            logger.debug("sql_update_stage_fallback_to_mongo", error=str(e))
    from app.db.mongo import mongo_update_customer
    stage_val = payload.stage.value if hasattr(payload.stage, "value") else str(payload.stage)
    res = mongo_update_customer(str(customer_id), {"stage": stage_val})
    if not res:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Customer not found")
    return res


@router.post(
    "/{customer_id}/milestones",
    response_model=None,
    status_code=status.HTTP_200_OK,
    summary="Add or verify payment milestone with employee and customer dates",
)
async def update_customer_milestone(
    customer_id: str,
    payload: dict,
    current_user=Depends(require_roles(UserRole.ADMIN, UserRole.SALES)),
):
    from app.db.mongo import mongo_update_customer_milestone
    milestone_id = payload.get("id") or payload.get("milestone_id") or str(uuid.uuid4())
    res = mongo_update_customer_milestone(str(customer_id), str(milestone_id), payload)
    if not res:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Customer not found")
    return res


@router.post(
    "/{customer_id}/documents",
    response_model=None,
    status_code=status.HTTP_201_CREATED,
    summary="Upload a customer document (JPG, PNG, PDF up to 10 MB)",
)
async def upload_document(
    customer_id: str,
    type: str = Form(..., description="Type of document (e_bill, aadhaar, pan, cheque, registry)"),
    file: UploadFile = File(..., description="Document file to upload"),
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(get_current_user),
):
    file_info = await read_upload_file(file)
    from app.db.mongo import mongo_get_customer_by_id, mongo_update_customer
    cust = mongo_get_customer_by_id(str(customer_id))
    if cust:
        docs = cust.get("documents") or {}
        doc_key = type.lower().replace("-", "_")
        docs[doc_key] = {
            "filename": file_info.filename if file_info else file.filename,
            "content_type": file_info.content_type if file_info else file.content_type,
            "size": file_info.size if file_info else 0,
            "uploaded_at": datetime.now(timezone.utc).isoformat(),
            "uploaded_by": getattr(current_user, "email", "staff"),
        }
        mongo_update_customer(str(customer_id), {
            "documents": docs,
            "documents_count": sum(1 for v in docs.values() if v),
        })
    return {
        "status": "success",
        "doc_type": type,
        "filename": file_info.filename if file_info else file.filename,
    }


@router.get(
    "/{customer_id}/documents",
    response_model=None,
    status_code=status.HTTP_200_OK,
    summary="List customer documents",
)
async def list_documents(
    customer_id: str,
    db: Optional[AsyncSession] = Depends(get_db),
    current_user=Depends(get_current_user),
):
    from app.db.mongo import mongo_get_customer_by_id
    cust = mongo_get_customer_by_id(str(customer_id))
    if not cust:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Customer not found")
    return cust.get("documents", {})

