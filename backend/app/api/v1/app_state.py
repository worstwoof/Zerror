from __future__ import annotations

import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.app.core.config import settings
from backend.app.core.object_storage import ObjectStorageError, TencentCOSStorage
from backend.app.db.models import AppStateSnapshot
from backend.app.db.session import get_db
from backend.app.schemas.app_state_schema import AppStateResponse, AppStateWriteRequest


router = APIRouter(prefix="/api/v1/app-state", tags=["app-state"])
cos_storage = TencentCOSStorage(settings) if settings.has_tencent_cos_config else None


@router.get("/{sync_user_id}", response_model=AppStateResponse)
def get_app_state(sync_user_id: str, db: Session = Depends(get_db)) -> AppStateResponse:
    record = (
        db.query(AppStateSnapshot)
        .filter(AppStateSnapshot.sync_user_id == sync_user_id)
        .first()
    )
    if record is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="App state not found.",
        )

    return AppStateResponse(
        sync_user_id=record.sync_user_id,
        snapshot=_decode_snapshot(record.snapshot_json),
        updated_at=record.updated_at,
    )


@router.put("/{sync_user_id}", response_model=AppStateResponse)
def save_app_state(
    sync_user_id: str,
    request: AppStateWriteRequest,
    db: Session = Depends(get_db),
) -> AppStateResponse:
    record = (
        db.query(AppStateSnapshot)
        .filter(AppStateSnapshot.sync_user_id == sync_user_id)
        .first()
    )
    previous_snapshot = _decode_snapshot(record.snapshot_json) if record is not None else {}
    stale_file_references = _extract_remote_file_references(previous_snapshot) - _extract_remote_file_references(request.snapshot)
    encoded_snapshot = json.dumps(request.snapshot, ensure_ascii=False)

    if record is None:
        record = AppStateSnapshot(
            sync_user_id=sync_user_id,
            snapshot_json=encoded_snapshot,
            updated_at=datetime.now(timezone.utc),
        )
        db.add(record)
    else:
        record.snapshot_json = encoded_snapshot
        record.updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(record)
    _cleanup_stale_files(stale_file_references)

    return AppStateResponse(
        sync_user_id=record.sync_user_id,
        snapshot=request.snapshot,
        updated_at=record.updated_at,
    )


def _decode_snapshot(raw_snapshot: str) -> dict[str, object]:
    if not raw_snapshot:
        return {}
    try:
        decoded = json.loads(raw_snapshot)
    except json.JSONDecodeError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Stored app state is corrupted.",
        ) from exc
    if isinstance(decoded, dict):
        return decoded
    return {}


def _extract_remote_file_references(snapshot: dict[str, object]) -> set[str]:
    references: set[str] = set()

    avatar_path = snapshot.get("avatar_path")
    if isinstance(avatar_path, str) and avatar_path.startswith(("http://", "https://")):
        references.add(avatar_path)

    raw_errors = snapshot.get("errors")
    if isinstance(raw_errors, list):
        for item in raw_errors:
            if not isinstance(item, dict):
                continue
            image_url = item.get("image_url")
            if isinstance(image_url, str) and image_url.startswith(("http://", "https://")):
                references.add(image_url)

    return references


def _cleanup_stale_files(file_references: set[str]) -> None:
    if cos_storage is None:
        return

    for file_reference in file_references:
        try:
            cos_storage.delete_file_reference(file_reference)
        except ObjectStorageError:
            continue
