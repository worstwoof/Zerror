from __future__ import annotations

import hashlib
import json
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any, Dict

from backend.app.core.config import PROJECT_ROOT
from backend.app.rendering.manim_renderer import ManimUnavailable, render_manim_video


MEDIA_ROOT = PROJECT_ROOT / "static" / "media" / "manim"
MEDIA_URL_PREFIX = "/static/media/manim"

_executor = ThreadPoolExecutor(max_workers=1)
_lock = threading.Lock()
_jobs: Dict[str, Dict[str, Any]] = {}
_cache: Dict[str, str] = {}


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
        )
        _jobs[job_id] = job
        _executor.submit(_run_manim_job, job_id, scene_hash, dict(scene_spec))
        return dict(job)


def get_manim_job(job_id: str) -> Dict[str, Any] | None:
    with _lock:
        job = _jobs.get(job_id)
        return dict(job) if job else None


def _run_manim_job(job_id: str, scene_hash: str, scene_spec: Dict[str, Any]) -> None:
    _update_job(job_id, status="running", progress=15, message="Manim renderer is starting.")
    try:
        output_path = render_manim_video(
            scene_spec=scene_spec,
            job_id=job_id,
            output_dir=MEDIA_ROOT,
        )
        video_url = f"{MEDIA_URL_PREFIX}/{output_path.name}"
        with _lock:
            _cache[scene_hash] = video_url
        _update_job(
            job_id,
            status="succeeded",
            progress=100,
            video_url=video_url,
            message="Manim video is ready.",
        )
    except ManimUnavailable as exc:
        _update_job(
            job_id,
            status="failed",
            progress=100,
            error=str(exc),
            message="Manim is not available on this server yet.",
        )
    except Exception as exc:
        _update_job(
            job_id,
            status="failed",
            progress=100,
            error=str(exc),
            message="Manim render failed.",
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
    canonical = json.dumps(scene_spec, sort_keys=True, ensure_ascii=False, default=str)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()

