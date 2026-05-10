from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
ROOT = Path(__file__).resolve().parents[1]

from backend.app.core.config import (
    _get_positive_int_setting,
    _normalize_url_prefix,
    get_settings,
)


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


def test_positive_int_setting_clamps_to_one() -> None:
    assert _get_positive_int_setting("MISSING_SETTING", {}, "2") == 2
    assert _get_positive_int_setting("MISSING_SETTING", {}, "0") == 1
    assert _get_positive_int_setting("MISSING_SETTING", {}, "-5") == 1


def test_background_worker_counts_can_be_configured_from_env() -> None:
    previous_analysis = os.environ.get("ANALYSIS_JOB_MAX_WORKERS")
    previous_manim = os.environ.get("MANIM_RENDER_MAX_WORKERS")
    os.environ["ANALYSIS_JOB_MAX_WORKERS"] = "2"
    os.environ["MANIM_RENDER_MAX_WORKERS"] = "0"
    try:
        settings = get_settings()
        assert settings.analysis_job_max_workers == 2
        assert settings.manim_render_max_workers == 1
    finally:
        if previous_analysis is None:
            os.environ.pop("ANALYSIS_JOB_MAX_WORKERS", None)
        else:
            os.environ["ANALYSIS_JOB_MAX_WORKERS"] = previous_analysis
        if previous_manim is None:
            os.environ.pop("MANIM_RENDER_MAX_WORKERS", None)
        else:
            os.environ["MANIM_RENDER_MAX_WORKERS"] = previous_manim


def test_manim_renderer_timeouts_can_be_configured_from_env() -> None:
    previous_render = os.environ.get("MANIM_RENDER_TIMEOUT_SECONDS")
    previous_faststart = os.environ.get("MANIM_FASTSTART_TIMEOUT_SECONDS")
    previous_probe = os.environ.get("MANIM_PROBE_TIMEOUT_SECONDS")
    os.environ["MANIM_RENDER_TIMEOUT_SECONDS"] = "600"
    os.environ["MANIM_FASTSTART_TIMEOUT_SECONDS"] = "0"
    os.environ["MANIM_PROBE_TIMEOUT_SECONDS"] = "20"
    try:
        settings = get_settings()
        assert settings.manim_render_timeout_seconds == 600
        assert settings.manim_faststart_timeout_seconds == 1
        assert settings.manim_probe_timeout_seconds == 20
    finally:
        if previous_render is None:
            os.environ.pop("MANIM_RENDER_TIMEOUT_SECONDS", None)
        else:
            os.environ["MANIM_RENDER_TIMEOUT_SECONDS"] = previous_render
        if previous_faststart is None:
            os.environ.pop("MANIM_FASTSTART_TIMEOUT_SECONDS", None)
        else:
            os.environ["MANIM_FASTSTART_TIMEOUT_SECONDS"] = previous_faststart
        if previous_probe is None:
            os.environ.pop("MANIM_PROBE_TIMEOUT_SECONDS", None)
        else:
            os.environ["MANIM_PROBE_TIMEOUT_SECONDS"] = previous_probe


def test_auth_hash_iterations_can_be_configured_from_env() -> None:
    previous = os.environ.get("AUTH_PBKDF2_ITERATIONS")
    os.environ["AUTH_PBKDF2_ITERATIONS"] = "130000"
    try:
        assert get_settings().auth_pbkdf2_iterations == 130000
    finally:
        if previous is None:
            os.environ.pop("AUTH_PBKDF2_ITERATIONS", None)
        else:
            os.environ["AUTH_PBKDF2_ITERATIONS"] = previous


def test_env_example_documents_runtime_settings() -> None:
    env_example = (ROOT / ".env.example").read_text(encoding="utf-8")
    expected_keys = {
        "VIVO_QUALITY_TEXT_MODEL",
        "VIVO_QUALITY_TEXT_THINKING_MODE",
        "VIVO_QUALITY_TEXT_REASONING_EFFORT",
        "VIVO_QUALITY_MAX_TOKENS",
        "AUTH_PBKDF2_ITERATIONS",
        "MANIM_MEDIA_URL_PREFIX",
        "ANALYSIS_JOB_MAX_WORKERS",
        "MANIM_RENDER_MAX_WORKERS",
        "MANIM_RENDER_TIMEOUT_SECONDS",
        "MANIM_FASTSTART_TIMEOUT_SECONDS",
        "MANIM_PROBE_TIMEOUT_SECONDS",
    }

    for key in expected_keys:
        assert f"{key}=" in env_example


if __name__ == "__main__":
    test_normalize_url_prefix_handles_slashes()
    test_manim_media_url_prefix_can_be_configured_from_env()
    test_positive_int_setting_clamps_to_one()
    test_background_worker_counts_can_be_configured_from_env()
    test_manim_renderer_timeouts_can_be_configured_from_env()
    test_auth_hash_iterations_can_be_configured_from_env()
    test_env_example_documents_runtime_settings()
    print("config guard tests passed")
