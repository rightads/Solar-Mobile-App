"""Validated, persisted file uploads.

* Streams the upload in chunks and aborts past ``MAX_UPLOAD_MB`` (no unbounded RAM use).
* Detects the real type from magic bytes; the client's filename and
  Content-Type are never trusted. Only JPEG, PNG, WEBP, HEIC and PDF are accepted.
* Stores files under random names outside any web root; a metadata record in
  the ``files`` collection ties each file to its customer and uploader so the
  download endpoint can enforce access control.
"""
from datetime import datetime, timezone
import hashlib
import os
import re
import uuid
from pathlib import Path
from typing import Any, Dict, Optional
from fastapi import UploadFile
from app.core.config import settings
from app.core.exceptions import BadRequestException

CHUNK = 64 * 1024

_TYPES = {
    "jpg": "image/jpeg",
    "png": "image/png",
    "webp": "image/webp",
    "heic": "image/heic",
    "pdf": "application/pdf",
}


def _sniff(head: bytes) -> Optional[str]:
    if head.startswith(b"\xff\xd8\xff"):
        return "jpg"
    if head.startswith(b"\x89PNG\r\n\x1a\n"):
        return "png"
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return "webp"
    if head[4:8] == b"ftyp" and head[8:12] in (b"heic", b"heix", b"mif1", b"msf1", b"heim", b"heis"):
        return "heic"
    if head.startswith(b"%PDF-"):
        return "pdf"
    return None


def _safe_display_name(name: Optional[str], ext: str) -> str:
    base = os.path.basename(name or "file")
    base = re.sub(r"[^A-Za-z0-9._ -]", "_", base)[:80].strip(" .") or "file"
    stem = base.rsplit(".", 1)[0]
    return f"{stem}.{ext}"


def upload_root() -> Path:
    root = Path(settings.UPLOAD_DIR).resolve()
    root.mkdir(parents=True, exist_ok=True)
    return root


async def save_upload(
    file: UploadFile,
    *,
    category: str,
    uploaded_by: str,
    customer_id: Optional[str] = None,
    allow_pdf: bool = True,
) -> Dict[str, Any]:
    """Validate and persist ``file``; returns the stored metadata record."""
    if file is None:
        raise BadRequestException("A file is required.")
    max_bytes = settings.MAX_UPLOAD_MB * 1024 * 1024

    first = await file.read(CHUNK)
    ext = _sniff(first[:16])
    if ext is None or (ext == "pdf" and not allow_pdf):
        raise BadRequestException("Unsupported file type. Upload a JPG, PNG, WEBP, HEIC" + (" or PDF." if allow_pdf else "."))

    file_id = uuid.uuid4().hex
    now = datetime.now(timezone.utc)
    category_slug = re.sub(r"[^a-z0-9_]", "", category.lower()) or "misc"
    rel = Path(category_slug) / now.strftime("%Y/%m") / f"{file_id}.{ext}"
    dest = upload_root() / rel
    dest.parent.mkdir(parents=True, exist_ok=True)

    digest = hashlib.sha256()
    size = 0
    try:
        with open(dest, "xb") as out:
            chunk = first
            while chunk:
                size += len(chunk)
                if size > max_bytes:
                    raise BadRequestException(f"File too large. Maximum size is {settings.MAX_UPLOAD_MB} MB.")
                digest.update(chunk)
                out.write(chunk)
                chunk = await file.read(CHUNK)
        os.chmod(dest, 0o640)
    except Exception:
        dest.unlink(missing_ok=True)
        raise

    record = {
        "_id": file_id,
        "id": file_id,
        "key": rel.as_posix(),
        "mime": _TYPES[ext],
        "size": size,
        "sha256": digest.hexdigest(),
        "name": _safe_display_name(file.filename, ext),
        "category": category_slug,
        "customer_id": str(customer_id) if customer_id else None,
        "uploaded_by": str(uploaded_by),
        "created_at": now,
    }
    from app.db.mongo import get_mongo_db
    db = get_mongo_db()
    if db is not None:
        db["files"].insert_one(record)
    return public_meta(record)


def public_meta(record: Dict[str, Any]) -> Dict[str, Any]:
    """Shape stored on business documents and returned to clients."""
    created = record.get("created_at")
    return {
        "file_id": record["id"],
        "filename": record["name"],
        "content_type": record["mime"],
        "size": record["size"],
        "url": f"/api/v1/files/{record['id']}",
        "uploaded_at": created.isoformat() if isinstance(created, datetime) else created,
    }


def get_file_record(file_id: str) -> Optional[Dict[str, Any]]:
    if not re.fullmatch(r"[0-9a-f]{32}", str(file_id)):
        return None
    from app.db.mongo import get_mongo_db
    db = get_mongo_db()
    return db["files"].find_one({"_id": file_id}) if db is not None else None


def resolve_path(record: Dict[str, Any]) -> Path:
    root = upload_root()
    path = (root / record["key"]).resolve()
    if root not in path.parents:
        raise BadRequestException("Invalid file path.")
    return path
