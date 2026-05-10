from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from backend.app.core.config import _normalize_url_prefix, get_settings


def test_normalize_url_prefix_handles_slashes() -> None:
    assert _normalize_url_prefix("/static/media/manim") == "/static/media/manim"
    assert _normalize_url_prefix("static/media/manim/") == "/static/media/manim"
    assert _normalize_url_prefix("/") == ""
    assert _normalize_url_prefix("  ") == ""


def test_manim_media_url_prefix_can_be_configured_from_env() -> None:
    previous = os.environ.get("MANIM_MEDIA_URL_PREFIX")
    os.environ["MANIM_MEDIA_URL_PREFIX"] = "assets/manim/"
    try:
        assert get_settings().manim_media_url_prefix == "/assets/manim"
    finally:
        if previous is None:
            os.environ.pop("MANIM_MEDIA_URL_PREFIX", None)
        else:
            os.environ["MANIM_MEDIA_URL_PREFIX"] = previous


if __name__ == "__main__":
    test_normalize_url_prefix_handles_slashes()
    test_manim_media_url_prefix_can_be_configured_from_env()
    print("config guard tests passed")
