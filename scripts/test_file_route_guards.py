from __future__ import annotations

import asyncio
import sys
from pathlib import Path

from fastapi import HTTPException

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from backend.app.api.v1.files import (
    _build_folder,
    _object_storage_gateway_error,
    _read_required_file_bytes,
    _sanitize_segment,
)
from backend.app.core.object_storage import ObjectStorageError


class _FakeUpload:
    def __init__(self, data: bytes) -> None:
        self.data = data

    async def read(self) -> bytes:
        return self.data


def test_read_required_file_bytes_returns_data() -> None:
    result = asyncio.run(_read_required_file_bytes(_FakeUpload(b"file")))  # type: ignore[arg-type]

    assert result == b"file"


def test_read_required_file_bytes_rejects_empty_upload() -> None:
    try:
        asyncio.run(_read_required_file_bytes(_FakeUpload(b"")))  # type: ignore[arg-type]
    except HTTPException as exc:
        assert exc.status_code == 400
        assert exc.detail == "Uploaded file is empty."
    else:
        raise AssertionError("empty upload should raise HTTPException")


def test_object_storage_error_maps_to_http_502() -> None:
    error = _object_storage_gateway_error(ObjectStorageError("cos failed"))

    assert error.status_code == 502
    assert error.detail == "cos failed"


def test_build_folder_sanitizes_user_and_category_segments() -> None:
    assert _sanitize_segment(" user/../../id ", fallback="anonymous") == "user-id"
    assert _sanitize_segment("", fallback="general") == "general"
    assert (
        _build_folder(sync_user_id="user@example.com", category="error image")
        == "uploads/user-example-com/error-image"
    )


if __name__ == "__main__":
    test_read_required_file_bytes_returns_data()
    test_read_required_file_bytes_rejects_empty_upload()
    test_object_storage_error_maps_to_http_502()
    test_build_folder_sanitizes_user_and_category_segments()
    print("file route guard tests passed")
