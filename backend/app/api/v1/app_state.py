from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.app.core.auth import get_current_user
from backend.app.core.config import settings
from backend.app.core.object_storage import ObjectStorageError, TencentCOSStorage
from backend.app.db.models import User
from backend.app.db.session import get_db
from backend.app.schemas.app_state_schema import AppStateResponse, AppStateWriteRequest
from backend.app.services.app_state_service import (
    delete_media_assets_by_urls,
    load_canonical_snapshot,
    save_canonical_snapshot,
)


router = APIRouter(prefix="/api/v1/app-state", tags=["app-state"])
cos_storage = TencentCOSStorage(settings) if settings.has_tencent_cos_config else None


@router.get("/{sync_user_id}", response_model=AppStateResponse)
def get_app_state(
    sync_user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> AppStateResponse:
    _ensure_sync_user_access(sync_user_id, current_user)
    snapshot, updated_at = load_canonical_snapshot(db, current_user)
    if snapshot is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="App state not found.",
        )

    return AppStateResponse(
        sync_user_id=current_user.sync_user_id,
        snapshot=snapshot,
        updated_at=updated_at,
    )


@router.put("/{sync_user_id}", response_model=AppStateResponse)
def save_app_state(
    sync_user_id: str,
    request: AppStateWriteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> AppStateResponse:
    _ensure_sync_user_access(sync_user_id, current_user)
    snapshot, updated_at, stale_file_references = save_canonical_snapshot(
        db,
        current_user,
        request.snapshot,
    )
    _cleanup_stale_files(db, current_user, stale_file_references)

    return AppStateResponse(
        sync_user_id=current_user.sync_user_id,
        snapshot=snapshot,
        updated_at=updated_at,
    )


def _cleanup_stale_files(db: Session, current_user: User, file_references: set[str]) -> None:
    if not file_references:
        return

    if cos_storage is not None:
        for file_reference in file_references:
            try:
                cos_storage.delete_file_reference(file_reference)
            except ObjectStorageError:
                continue

    delete_media_assets_by_urls(db, current_user, file_references)


def _ensure_sync_user_access(sync_user_id: str, current_user: User) -> None:
    if sync_user_id != current_user.sync_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You do not have access to this app state.",
        )
