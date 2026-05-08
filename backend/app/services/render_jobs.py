from __future__ import annotations

import hashlib
import json
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any, Dict

from backend.app.core.config import PROJECT_ROOT
from backend.app.rendering.manim_renderer import (
    ManimUnavailable,
    is_manim_available,
    render_manim_video,
)
from backend.app.services.manimcat_client import (
    ManimCatUnavailable,
    is_manimcat_configured,
    render_math_video_with_manimcat,
)


MEDIA_ROOT = PROJECT_ROOT / "static" / "media" / "manim"
MEDIA_URL_PREFIX = "/static/media/manim"
MANIM_RENDER_CACHE_VERSION = "math-manimcat-adapter-v1"

_executor = ThreadPoolExecutor(max_workers=1)
_lock = threading.Lock()
_jobs: Dict[str, Dict[str, Any]] = {}
_cache: Dict[str, str] = {}
_renderer_available_cache: bool | None = None


def create_manim_job(scene_spec: Dict[str, Any]) -> Dict[str, Any]:
    scene_hash = _scene_hash(scene_spec)
    with _lock:
        cached_url = _cache.get(scene_hash)
        if cached_url:
            job_id = f"cached-{scene_hash[:16]}"
            job = _build_job(
                job_id=job_id,
                scene_hash=scene_hash,
                status="succeeded",
                progress=100,
                video_url=cached_url,
                message="Manim video is ready.",
                diagnostics=_video_diagnostics(cached_url),
            )
            _jobs[job_id] = job
            return dict(job)

        job_id = scene_hash[:20]
        existing = _jobs.get(job_id)
        if existing:
            return dict(existing)

        job = _build_job(
            job_id=job_id,
            scene_hash=scene_hash,
            status="pending",
            progress=0,
            message="Manim render job is queued.",
        )
        _jobs[job_id] = job
        _executor.submit(_run_manim_job, job_id, scene_hash, dict(scene_spec))
        return dict(job)


def get_manim_job(job_id: str) -> Dict[str, Any] | None:
    with _lock:
        job = _jobs.get(job_id)
        return dict(job) if job else None


def _run_manim_job(job_id: str, scene_hash: str, scene_spec: Dict[str, Any]) -> None:
    started_at = time.perf_counter()
    _update_job(
        job_id,
        status="running",
        progress=15,
        message="Manim renderer is starting.",
        diagnostics={
            "renderer_available": _renderer_available(),
            "render_started_at": time.time(),
        },
    )
    try:
        renderer_backend = "manimcat" if _is_math_scene(scene_spec) else "local_manim"
        try:
            output_path = _render_scene_video(scene_spec=scene_spec, job_id=job_id)
        except ManimCatUnavailable:
            if _is_math_scene(scene_spec):
                raise
            output_path = render_manim_video(
                scene_spec=scene_spec,
                job_id=job_id,
                output_dir=MEDIA_ROOT,
            )
        video_url = f"{MEDIA_URL_PREFIX}/{output_path.name}"
        elapsed = time.perf_counter() - started_at
        diagnostics = _video_diagnostics(video_url)
        diagnostics.update(
            {
                "renderer_available": True,
                "renderer_backend": renderer_backend,
                "render_elapsed_seconds": round(elapsed, 3),
                "error_summary": "",
            }
        )
        with _lock:
            _cache[scene_hash] = video_url
        _update_job(
            job_id,
            status="succeeded",
            progress=100,
            video_url=video_url,
            message="Manim video is ready.",
            diagnostics=diagnostics,
        )
    except ManimUnavailable as exc:
        elapsed = time.perf_counter() - started_at
        # Animation is an enhancement, not the source of truth for the answer.
        # Keep the raw failure in diagnostics for maintainers while returning
        # a short, student-safe message to the client.
        _update_job(
            job_id,
            status="failed",
            progress=100,
            error="动画生成服务暂不可用。",
            message="动画生成失败，题目详解不受影响，可稍后重试。",
            diagnostics={
                "renderer_available": False,
                "output_path_exists": False,
                "file_size_bytes": 0,
                "render_elapsed_seconds": round(elapsed, 3),
                "error_summary": _error_summary(exc),
            },
        )
    except Exception as exc:
        elapsed = time.perf_counter() - started_at
        # Same contract as the unavailable case: do not let Manim failures
        # degrade the completed explanation card.
        _update_job(
            job_id,
            status="failed",
            progress=100,
            error="动画生成失败，可稍后重试。",
            message="动画生成失败，题目详解不受影响，可稍后重试。",
            diagnostics={
                "renderer_available": _renderer_available(),
                "output_path_exists": False,
                "file_size_bytes": 0,
                "render_elapsed_seconds": round(elapsed, 3),
                "error_summary": _error_summary(exc),
            },
        )


def _build_job(
    *,
    job_id: str,
    scene_hash: str,
    status: str,
    progress: int,
    video_url: str = "",
    message: str = "",
    error: str = "",
    diagnostics: Dict[str, Any] | None = None,
) -> Dict[str, Any]:
    return {
        "job_id": job_id,
        "scene_hash": scene_hash,
        "status": status,
        "progress": progress,
        "video_url": video_url,
        "duration": None,
        "thumbnail_url": None,
        "message": message,
        "error": error,
        "diagnostics": diagnostics
        if diagnostics is not None
        else {
            "renderer_available": _renderer_available(),
            "manimcat_configured": is_manimcat_configured(),
            "output_path_exists": False,
            "file_size_bytes": 0,
            "error_summary": "",
        },
        "updated_at": time.time(),
    }


def _update_job(job_id: str, **updates: Any) -> None:
    with _lock:
        job = _jobs.get(job_id)
        if not job:
            return
        job.update(updates)
        job["updated_at"] = time.time()


def _scene_hash(scene_spec: Dict[str, Any]) -> str:
    canonical = json.dumps(
        {
            "renderer_version": MANIM_RENDER_CACHE_VERSION,
            "scene_spec": scene_spec,
        },
        sort_keys=True,
        ensure_ascii=False,
        default=str,
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def _renderer_available() -> bool:
    global _renderer_available_cache
    if _renderer_available_cache is not None:
        return _renderer_available_cache
    try:
        _renderer_available_cache = is_manim_available()
    except Exception:
        _renderer_available_cache = False
    return _renderer_available_cache


def _render_scene_video(*, scene_spec: Dict[str, Any], job_id: str) -> Path:
    if _is_math_scene(scene_spec):
        return render_math_video_with_manimcat(
            scene_spec=scene_spec,
            job_id=job_id,
            output_dir=MEDIA_ROOT,
        )
    return render_manim_video(
        scene_spec=scene_spec,
        job_id=job_id,
        output_dir=MEDIA_ROOT,
    )


def _is_math_scene(scene_spec: Dict[str, Any]) -> bool:
    subject = str(scene_spec.get("subject") or "").lower()
    scene_type = str(scene_spec.get("scene_type") or "").lower()
    if subject:
        return subject == "math"
    return scene_type in {"conic", "function_graph", "geometry"}


def _video_diagnostics(video_url: str) -> Dict[str, Any]:
    path = _path_for_video_url(video_url)
    exists = path.exists() if path else False
    size = path.stat().st_size if path and exists else 0
    return {
        "renderer_available": _renderer_available(),
        "manimcat_configured": is_manimcat_configured(),
        "output_path_exists": exists,
        "output_path": str(path) if path else "",
        "file_size_bytes": size,
        "error_summary": "",
    }


def _path_for_video_url(video_url: str) -> Path | None:
    if not video_url.startswith(f"{MEDIA_URL_PREFIX}/"):
        return None
    name = Path(video_url).name
    if not name:
        return None
    return MEDIA_ROOT / name


def _error_summary(exc: Exception) -> str:
    message = str(exc).strip()
    if len(message) > 300:
        return f"{message[:297]}..."
    return message
