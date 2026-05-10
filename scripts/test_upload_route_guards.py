from __future__ import annotations

import asyncio
import sys
from pathlib import Path

from fastapi import HTTPException

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from ai_engine.llm_logic.vivo_client import VivoAPIError
from backend.app.api.v1.upload import _read_required_upload_bytes, _vivo_gateway_error


class _FakeUpload:
    def __init__(self, data: bytes) -> None:
        self.data = data

    async def read(self) -> bytes:
        return self.data


def test_read_required_upload_bytes_returns_image_data() -> None:
    result = asyncio.run(_read_required_upload_bytes(_FakeUpload(b"image")))  # type: ignore[arg-type]

    assert result == b"image"


def test_read_required_upload_bytes_rejects_empty_upload() -> None:
    try:
        asyncio.run(_read_required_upload_bytes(_FakeUpload(b"")))  # type: ignore[arg-type]
    except HTTPException as exc:
        assert exc.status_code == 400
        assert exc.detail == "上传图片为空。"
    else:
        raise AssertionError("empty upload should raise HTTPException")


def test_vivo_gateway_error_maps_to_http_502() -> None:
    error = _vivo_gateway_error(VivoAPIError("upstream failed"))

    assert error.status_code == 502
    assert error.detail == "upstream failed"


if __name__ == "__main__":
    test_read_required_upload_bytes_returns_image_data()
    test_read_required_upload_bytes_rejects_empty_upload()
    test_vivo_gateway_error_maps_to_http_502()
    print("upload route guard tests passed")
