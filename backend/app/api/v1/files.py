from __future__ import annotations

import re

from fastapi import APIRouter, File, Form, HTTPException, UploadFile, status

from backend.app.core.config import settings
from backend.app.core.object_storage import ObjectStorageError, TencentCOSStorage
from backend.app.schemas.file_schema import FileUploadResponse


router = APIRouter(prefix="/api/v1/files", tags=["files"])
cos_storage = TencentCOSStorage(settings) if settings.has_tencent_cos_config else None


@router.post("/upload", response_model=FileUploadResponse)
async def upload_file(
    file: UploadFile = File(...),
    category: str = Form("general"),
    sync_user_id: str = Form("anonymous"),
) -> FileUploadResponse:
    if cos_storage is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Tencent COS is not configured.",
        )

    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty.",
        )

    folder = _build_folder(sync_user_id=sync_user_id, category=category)
    try:
        object_key, file_url = cos_storage.upload_bytes(
            file_bytes=file_bytes,
            filename=file.filename,
            content_type=file.content_type,
            folder=folder,
        )
    except ObjectStorageError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=str(exc),
        ) from exc

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
