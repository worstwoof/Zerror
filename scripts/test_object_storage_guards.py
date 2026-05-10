from __future__ import annotations

import sys
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from backend.app.core.object_storage import TencentCOSStorage


def _storage(*, base_url: str = "") -> TencentCOSStorage:
    storage = object.__new__(TencentCOSStorage)
    storage.settings = SimpleNamespace(
        tencent_cos_bucket="bucket",
        tencent_cos_region="ap-test",
        tencent_cos_base_url=base_url,
    )
    return storage


def test_public_url_uses_default_cos_host_when_base_url_is_absent() -> None:
    storage = _storage()

    assert storage._default_cos_host() == "bucket.cos.ap-test.myqcloud.com"
    assert (
        storage._build_public_url("uploads/a.png")
        == "https://bucket.cos.ap-test.myqcloud.com/uploads/a.png"
    )


def test_public_url_uses_configured_base_url() -> None:
    storage = _storage(base_url="https://cdn.example.com/base/")

    assert storage._build_public_url("uploads/a.png") == "https://cdn.example.com/base/uploads/a.png"


def test_extract_object_key_accepts_default_cos_url_and_local_key() -> None:
    storage = _storage()

    assert storage._extract_object_key("uploads/a.png") == "uploads/a.png"
    assert (
        storage._extract_object_key("https://bucket.cos.ap-test.myqcloud.com/uploads/a%20b.png")
        == "uploads/a b.png"
    )


def test_extract_object_key_accepts_configured_base_url_only() -> None:
    storage = _storage(base_url="https://cdn.example.com/base")

    assert storage._extract_object_key("https://cdn.example.com/base/uploads/a.png") == "uploads/a.png"
    assert storage._extract_object_key("https://cdn.example.com/other/uploads/a.png") is None
    assert storage._extract_object_key("https://other.example.com/base/uploads/a.png") is None


if __name__ == "__main__":
    test_public_url_uses_default_cos_host_when_base_url_is_absent()
    test_public_url_uses_configured_base_url()
    test_extract_object_key_accepts_default_cos_url_and_local_key()
    test_extract_object_key_accepts_configured_base_url_only()
    print("object storage guard tests passed")
