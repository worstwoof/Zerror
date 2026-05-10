from __future__ import annotations

import re

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from backend.app.core.auth import get_current_user
from backend.app.core.config import settings
from backend.app.core.object_storage import ObjectStorageError, TencentCOSStorage
from backend.app.db.models import User
from backend.app.db.session import get_db
from backend.app.schemas.file_schema import FileUploadResponse
from backend.app.services.app_state_service import create_or_update_media_asset


router = APIRouter(prefix="/api/v1/files", tags=["files"])
cos_storage = TencentCOSStorage(settings) if settings.has_tencent_cos_config else None


async def _read_required_file_bytes(file: UploadFile) -> bytes:
    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty.",
        )
    return file_bytes


def _object_storage_gateway_error(exc: ObjectStorageError) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_502_BAD_GATEWAY,
        detail=str(exc),
    )


@router.post("/upload", response_model=FileUploadResponse)
async def upload_file(
    file: UploadFile = File(...),
    category: str = Form("general"),
    sync_user_id: str = Form("anonymous"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> FileUploadResponse:
    if cos_storage is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Tencent COS is not configured.",
        )

    file_bytes = await _read_required_file_bytes(file)

    effective_sync_user_id = current_user.sync_user_id or sync_user_id
    folder = _build_folder(sync_user_id=effective_sync_user_id, category=category)
    try:
        object_key, file_url = cos_storage.upload_bytes(
            file_bytes=file_bytes,
            filename=file.filename,
            content_type=file.content_type,
            folder=folder,
        )
    except ObjectStorageError as exc:
        raise _object_storage_gateway_error(exc) from exc

    create_or_update_media_asset(
        db,
        user=current_user,
        category=category,
        object_key=object_key,
        file_url=file_url,
        content_type=file.content_type or "application/octet-stream",
        size_bytes=len(file_bytes),
    )
    db.commit()

    return FileUploadResponse(
        object_key=object_key,
        file_url=file_url,
        content_type=file.content_type or "application/octet-stream",
        size_bytes=len(file_bytes),
    )


def _build_folder(*, sync_user_id: str, category: str) -> str:
    safe_user_id = _sanitize_segment(sync_user_id, fallback="anonymous")
    safe_category = _sanitize_segment(category, fallback="general")
    return f"uploads/{safe_user_id}/{safe_category}"


def _sanitize_segment(value: str, *, fallback: str) -> str:
    normalized = re.sub(r"[^a-zA-Z0-9_-]+", "-", value).strip("-")
    return normalized or fallback
