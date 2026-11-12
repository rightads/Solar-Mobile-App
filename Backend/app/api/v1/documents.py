"""Authenticated file upload/download.

Files are never publicly reachable: every download re-checks that the caller
is an admin, the uploader, or someone allowed to view the file's customer.
"""
from fastapi import APIRouter, Depends, File, Form, UploadFile, status
from fastapi.responses import FileResponse
from app.core import access
from app.core.deps import MongoUserProxy, get_current_user
from app.core.exceptions import NotFoundException
from app.core.uploads import get_file_record, resolve_path, save_upload
from app.db.mongo import get_mongo_db

router = APIRouter(prefix="/files", tags=["Files"])


def _can_read(user: MongoUserProxy, record: dict) -> bool:
    if access.is_admin(user) or record.get("uploaded_by") == user.id:
        return True
    cid = record.get("customer_id")
    if not cid:
        return False
    cust = get_mongo_db()["customers"].find_one({"_id": cid})
    return bool(cust) and access.can_view_customer(user, cust)


@router.post("", status_code=status.HTTP_201_CREATED, summary="Upload an image (e.g. ticket photos)")
async def upload_file(
    file: UploadFile = File(...),
    purpose: str = Form("ticket_image", max_length=30),
    current_user: MongoUserProxy = Depends(get_current_user),
):
    customer_id = None
    if access.role_of(current_user) in access.CLIENT_ROLES:
        cust = access.require_client_customer(current_user)
        customer_id = str(cust["_id"])
    return await save_upload(file, category=purpose if purpose in ("ticket_image", "profile") else "misc",
                             uploaded_by=current_user.id, customer_id=customer_id, allow_pdf=False)


@router.get("/{file_id}", summary="Download a file you are allowed to see")
async def download_file(file_id: str, current_user: MongoUserProxy = Depends(get_current_user)):
    record = get_file_record(file_id)
    if not record or not _can_read(current_user, record):
        raise NotFoundException("File not found.")
    path = resolve_path(record)
    if not path.is_file():
        raise NotFoundException("File not found.")
    return FileResponse(
        path,
        media_type=record["mime"],
        filename=record["name"],
        headers={
            "X-Content-Type-Options": "nosniff",
            "Cache-Control": "private, no-store",
            "Content-Security-Policy": "default-src 'none'; sandbox",
        },
    )
