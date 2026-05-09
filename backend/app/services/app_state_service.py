from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any
from urllib.parse import unquote, urlparse
from uuid import uuid4

from fastapi import HTTPException, status
from sqlalchemy import and_
from sqlalchemy.orm import Session, selectinload

from backend.app.db.models import (
    AppStateSnapshot,
    ErrorRecord,
    ErrorTag,
    MediaAsset,
    User,
    UserDevice,
    UserProfile,
)


def load_canonical_snapshot(db: Session, user: User) -> tuple[dict[str, Any] | None, datetime | None]:
    snapshot_record = _get_snapshot_record(db, user.sync_user_id)
    if snapshot_record is not None and _needs_structured_migration(db, user):
        raw_snapshot = decode_snapshot_json(snapshot_record.snapshot_json)
        apply_snapshot_to_structured(db, user, raw_snapshot)
        db.commit()
        snapshot_record = _get_snapshot_record(db, user.sync_user_id)

    canonical_snapshot = build_snapshot_from_structured(db, user)
    if canonical_snapshot is None:
        if snapshot_record is None:
            return None, None
        return decode_snapshot_json(snapshot_record.snapshot_json), snapshot_record.updated_at

    snapshot_record = upsert_snapshot_record(db, user.sync_user_id, canonical_snapshot)
    db.commit()
    db.refresh(snapshot_record)
    return canonical_snapshot, snapshot_record.updated_at


def save_canonical_snapshot(
    db: Session,
    user: User,
    snapshot: dict[str, Any],
) -> tuple[dict[str, Any], datetime, set[str]]:
    snapshot_record = _get_snapshot_record(db, user.sync_user_id)
    previous_snapshot = (
        decode_snapshot_json(snapshot_record.snapshot_json)
        if snapshot_record is not None
        else build_snapshot_from_structured(db, user) or {}
    )

    apply_snapshot_to_structured(db, user, snapshot)
    canonical_snapshot = build_snapshot_from_structured(db, user) or {}
    snapshot_record = upsert_snapshot_record(db, user.sync_user_id, canonical_snapshot)
    stale_file_references = extract_remote_file_references(previous_snapshot) - extract_remote_file_references(canonical_snapshot)

    db.commit()
    db.refresh(snapshot_record)
    return canonical_snapshot, snapshot_record.updated_at, stale_file_references


def decode_snapshot_json(raw_snapshot: str) -> dict[str, Any]:
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


def build_snapshot_from_structured(db: Session, user: User) -> dict[str, Any] | None:
    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
    devices = (
        db.query(UserDevice)
        .filter(UserDevice.user_id == user.id)
        .order_by(UserDevice.created_at.asc(), UserDevice.id.asc())
        .all()
    )
    errors = (
        db.query(ErrorRecord)
        .options(selectinload(ErrorRecord.tags))
        .filter(ErrorRecord.user_id == user.id)
        .order_by(ErrorRecord.created_at.desc(), ErrorRecord.id.desc())
        .all()
    )

    if profile is None and not devices and not errors:
        return None

    favorite_ids = {item.client_error_id for item in errors if item.is_favorite}
    mastered_ids = {item.client_error_id for item in errors if item.is_mastered}

    return {
        "favorite_ids": sorted(favorite_ids),
        "mastered_ids": sorted(mastered_ids),
        "avatar_path": profile.avatar_path if profile is not None else None,
        "profile": {
            "name": profile.display_name if profile and profile.display_name else user.username,
            "user_id": profile.public_user_id if profile and profile.public_user_id else user.username,
            "motto": profile.motto if profile is not None else "",
            "email": user.email,
        },
        "password_updated_at": _to_iso(profile.password_updated_at if profile is not None else None),
        "devices": [
            {
                "id": item.device_identifier,
                "name": item.name,
                "detail": item.detail,
                "is_current": item.is_current,
                "is_trusted": item.is_trusted,
                "is_online": item.is_online,
            }
            for item in devices
        ],
        "errors": [
            {
                "id": item.client_error_id,
                "subject": item.subject,
                "topic": item.topic,
                "question": item.question,
                "reason": item.reason,
                "date_label": item.date_label,
                "tags": [tag.tag for tag in sorted(item.tags, key=lambda entry: (entry.sort_order, entry.id))],
                "my_answer": item.my_answer,
                "ai_analysis": item.ai_analysis,
                "rich_artifacts": _decode_json_list(item.rich_artifacts_json),
                "image_url": item.image_url,
                "is_mastered": item.is_mastered,
                "is_favorite": item.is_favorite,
            }
            for item in errors
        ],
    }


def apply_snapshot_to_structured(db: Session, user: User, snapshot: dict[str, Any]) -> None:
    profile_payload = _as_map(snapshot.get("profile"))
    avatar_path = _normalize_text(snapshot.get("avatar_path"))
    password_updated_at = _parse_datetime(snapshot.get("password_updated_at"))

    email = _normalize_text(profile_payload.get("email")) or user.email
    email = email.lower()
    if email != user.email.lower():
        existing_user = (
            db.query(User)
            .filter(and_(User.email == email, User.id != user.id))
            .first()
        )
        if existing_user is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Email is already registered by another account.",
            )
        user.email = email

    profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
    if profile is None:
        profile = UserProfile(user_id=user.id)
        db.add(profile)

    profile.display_name = _normalize_text(profile_payload.get("name")) or user.username
    profile.public_user_id = _normalize_text(profile_payload.get("user_id")) or user.username
    profile.motto = _normalize_text(profile_payload.get("motto")) or ""
    profile.avatar_path = avatar_path
    if password_updated_at is not None:
        profile.password_updated_at = password_updated_at

    _replace_devices(db, user, _as_list_of_maps(snapshot.get("devices")))
    errors_by_image_url = _upsert_error_records(
        db,
        user,
        _as_list_of_maps(snapshot.get("errors")),
        favorite_ids=_as_string_set(snapshot.get("favorite_ids")),
        mastered_ids=_as_string_set(snapshot.get("mastered_ids")),
    )
    db.flush()
    _sync_media_assets(
        db,
        user,
        avatar_path=avatar_path,
        errors_by_image_url=errors_by_image_url,
    )


def upsert_snapshot_record(db: Session, sync_user_id: str, snapshot: dict[str, Any]) -> AppStateSnapshot:
    encoded_snapshot = json.dumps(snapshot, ensure_ascii=False)
    record = _get_snapshot_record(db, sync_user_id)
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
    db.flush()
    return record


def extract_remote_file_references(snapshot: dict[str, Any]) -> set[str]:
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


def delete_media_assets_by_urls(db: Session, user: User, file_urls: set[str]) -> None:
    if not file_urls:
        return
    assets = (
        db.query(MediaAsset)
        .filter(MediaAsset.user_id == user.id, MediaAsset.file_url.in_(list(file_urls)))
        .all()
    )
    for asset in assets:
        db.delete(asset)
    db.commit()


def create_or_update_media_asset(
    db: Session,
    *,
    user: User,
    category: str,
    object_key: str,
    file_url: str,
    content_type: str | None,
    size_bytes: int | None,
) -> MediaAsset:
    asset = db.query(MediaAsset).filter(MediaAsset.file_url == file_url).first()
    if asset is None:
        asset = MediaAsset(
            user_id=user.id,
            category=category,
            object_key=object_key or None,
            file_url=file_url,
            content_type=content_type,
            size_bytes=size_bytes,
        )
        db.add(asset)
    else:
        asset.user_id = user.id
        asset.category = category
        asset.object_key = object_key or asset.object_key
        asset.content_type = content_type or asset.content_type
        asset.size_bytes = size_bytes if size_bytes is not None else asset.size_bytes
    db.flush()
    return asset


def guess_object_key_from_url(file_url: str) -> str | None:
    if not file_url:
        return None
    if "://" not in file_url:
        return file_url.lstrip("/") or None
    parsed = urlparse(file_url)
    if not parsed.path:
        return None
    return unquote(parsed.path.lstrip("/")) or None


def _replace_devices(db: Session, user: User, devices: list[dict[str, Any]]) -> None:
    existing = db.query(UserDevice).filter(UserDevice.user_id == user.id).all()
    for item in existing:
        db.delete(item)
    db.flush()

    for device in devices:
        identifier = _normalize_text(device.get("id")) or f"device-{uuid4().hex}"
        db.add(
            UserDevice(
                user_id=user.id,
                device_identifier=identifier,
                name=_normalize_text(device.get("name")) or "Unnamed device",
                detail=_normalize_text(device.get("detail")) or "Recently active",
                is_current=_as_bool(device.get("is_current")),
                is_trusted=_as_bool(device.get("is_trusted"), default=True),
                is_online=_as_bool(device.get("is_online"), default=True),
            )
        )


def _upsert_error_records(
    db: Session,
    user: User,
    errors: list[dict[str, Any]],
    *,
    favorite_ids: set[str],
    mastered_ids: set[str],
) -> dict[str, ErrorRecord]:
    existing_records = {
        item.client_error_id: item
        for item in db.query(ErrorRecord)
        .options(selectinload(ErrorRecord.tags))
        .filter(ErrorRecord.user_id == user.id)
        .all()
    }
    seen_ids: set[str] = set()
    errors_by_image_url: dict[str, ErrorRecord] = {}

    for payload in errors:
        client_error_id = _normalize_text(payload.get("id")) or f"error-{uuid4().hex}"
        seen_ids.add(client_error_id)
        record = existing_records.pop(client_error_id, None)
        if record is None:
            record = ErrorRecord(user_id=user.id, client_error_id=client_error_id)
            db.add(record)

        record.subject = _normalize_text(payload.get("subject")) or ""
        record.topic = _normalize_text(payload.get("topic")) or ""
        record.question = _normalize_text(payload.get("question")) or ""
        record.reason = _normalize_text(payload.get("reason")) or ""
        record.date_label = _normalize_text(payload.get("date_label")) or ""
        record.my_answer = _normalize_text(payload.get("my_answer")) or ""
        record.ai_analysis = _normalize_text(payload.get("ai_analysis")) or ""
        record.rich_artifacts_json = _encode_json_list(payload.get("rich_artifacts"))
        record.image_url = _normalize_text(payload.get("image_url"))
        record.is_favorite = client_error_id in favorite_ids or _as_bool(payload.get("is_favorite"))
        record.is_mastered = client_error_id in mastered_ids or _as_bool(payload.get("is_mastered"))
        record.tags = [
            ErrorTag(tag=_normalize_text(tag) or "", sort_order=index)
            for index, tag in enumerate(_as_string_list(payload.get("tags")))
            if (_normalize_text(tag) or "")
        ]

        if record.image_url and record.image_url.startswith(("http://", "https://")):
            errors_by_image_url[record.image_url] = record

    for leftover in existing_records.values():
        db.delete(leftover)

    return errors_by_image_url


def _sync_media_assets(
    db: Session,
    user: User,
    *,
    avatar_path: str | None,
    errors_by_image_url: dict[str, ErrorRecord],
) -> None:
    referenced_urls = set(errors_by_image_url.keys())
    if avatar_path and avatar_path.startswith(("http://", "https://")):
        referenced_urls.add(avatar_path)

    existing_assets = db.query(MediaAsset).filter(MediaAsset.user_id == user.id).all()
    existing_by_url = {item.file_url: item for item in existing_assets}

    for asset in existing_assets:
        if asset.file_url not in referenced_urls:
            asset.error_record_id = None

    if avatar_path and avatar_path.startswith(("http://", "https://")):
        asset = existing_by_url.get(avatar_path)
        if asset is None:
            asset = MediaAsset(
                user_id=user.id,
                category="avatar",
                object_key=guess_object_key_from_url(avatar_path),
                file_url=avatar_path,
            )
            db.add(asset)
        else:
            asset.category = "avatar"
        asset.error_record_id = None

    for image_url, error_record in errors_by_image_url.items():
        asset = existing_by_url.get(image_url)
        if asset is None:
            asset = MediaAsset(
                user_id=user.id,
                category="error-image",
                object_key=guess_object_key_from_url(image_url),
                file_url=image_url,
            )
            db.add(asset)
        else:
            asset.category = "error-image"
        asset.error_record_id = error_record.id


def _needs_structured_migration(db: Session, user: User) -> bool:
    has_errors = db.query(ErrorRecord.id).filter(ErrorRecord.user_id == user.id).first() is not None
    has_devices = db.query(UserDevice.id).filter(UserDevice.user_id == user.id).first() is not None
    if has_errors or has_devices:
        return False
    return True


def _get_snapshot_record(db: Session, sync_user_id: str) -> AppStateSnapshot | None:
    return (
        db.query(AppStateSnapshot)
        .filter(AppStateSnapshot.sync_user_id == sync_user_id)
        .first()
    )


def _as_map(value: Any) -> dict[str, Any]:
    if isinstance(value, dict):
        return {str(key): map_value for key, map_value in value.items()}
    return {}


def _as_list_of_maps(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []
    return [_as_map(item) for item in value if isinstance(item, dict)]


def _as_string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item) for item in value if str(item).strip()]


def _as_string_set(value: Any) -> set[str]:
    return set(_as_string_list(value))


def _as_bool(value: Any, *, default: bool = False) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        lowered = value.strip().lower()
        if lowered in {"true", "1", "yes", "y"}:
            return True
        if lowered in {"false", "0", "no", "n"}:
            return False
    if isinstance(value, (int, float)):
        return bool(value)
    return default


def _decode_json_list(raw_value: Any) -> list[dict[str, Any]]:
    if not raw_value:
        return []
    if isinstance(raw_value, list):
        return _as_list_of_maps(raw_value)
    if not isinstance(raw_value, str):
        return []
    try:
        parsed = json.loads(raw_value)
    except json.JSONDecodeError:
        return []
    return _as_list_of_maps(parsed)


def _encode_json_list(value: Any) -> str:
    items = _as_list_of_maps(value)
    if not items:
        return ""
    return json.dumps(items, ensure_ascii=False, sort_keys=True, default=str)


def _normalize_text(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _parse_datetime(value: Any) -> datetime | None:
    text = _normalize_text(value)
    if text is None:
        return None
    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def _to_iso(value: datetime | None) -> str | None:
    if value is None:
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc).isoformat()
