from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from backend.app.services.app_state_service import (
    extract_remote_file_references,
    guess_object_key_from_url,
    is_remote_file_reference,
)


def test_remote_file_reference_helper_only_accepts_http_urls() -> None:
    assert is_remote_file_reference("https://cdn.example.com/avatar.png")
    assert is_remote_file_reference("http://cdn.example.com/error.jpg")
    assert not is_remote_file_reference("/static/avatar.png")
    assert not is_remote_file_reference("cos/key/avatar.png")
    assert not is_remote_file_reference(None)


def test_extract_remote_file_references_ignores_local_paths() -> None:
    references = extract_remote_file_references(
        {
            "avatar_path": "https://cdn.example.com/avatar.png",
            "errors": [
                {"image_url": "http://cdn.example.com/error-1.jpg"},
                {"image_url": "/local/error-2.jpg"},
                {"image_url": ""},
                "not-a-map",
            ],
        }
    )

    assert references == {
        "https://cdn.example.com/avatar.png",
        "http://cdn.example.com/error-1.jpg",
    }


def test_guess_object_key_from_url_decodes_remote_paths() -> None:
    assert (
        guess_object_key_from_url("https://cdn.example.com/uploads/a%20b.png")
        == "uploads/a b.png"
    )
    assert guess_object_key_from_url("uploads/local.png") == "uploads/local.png"
    assert guess_object_key_from_url("") is None


if __name__ == "__main__":
    test_remote_file_reference_helper_only_accepts_http_urls()
    test_extract_remote_file_references_ignores_local_paths()
    test_guess_object_key_from_url_decodes_remote_paths()
    print("app state service guard tests passed")
