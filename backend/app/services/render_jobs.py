from __future__ import annotations

import hashlib
import json
import threading
import time
import uuid
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
    download_manimcat_video,
    get_manimcat_job,
    is_manimcat_configured,
    render_math_video_with_manimcat,
)


MEDIA_ROOT = PROJECT_ROOT / "static" / "media" / "manim"
JOBS_ROOT = MEDIA_ROOT / "_jobs"
MEDIA_URL_PREFIX = "/static/media/manim"
MANIM_RENDER_CACHE_VERSION = "math-manimcat-adapter-v3-blackboard"

_executor = ThreadPoolExecutor(max_workers=1)
_lock = threading.Lock()
_jobs: Dict[str, Dict[str, Any]] = {}
_renderer_available_cache: bool | None = None


def create_manim_job(scene_spec: Dict[str, Any]) -> Dict[str, Any]:
    scene_hash = _scene_hash(scene_spec)
    with _lock:
        job_id = f"{scene_hash[:12]}{uuid.uuid4().hex[:12]}"
        job = _build_job(
            job_id=job_id,
            scene_hash=scene_hash,
            status="pending",
            progress=0,
            message="Manim render job is queued.",
            scene_spec=dict(scene_spec),
        )
        _jobs[job_id] = job
        _save_job(job)
        _executor.submit(_run_manim_job, job_id, scene_hash, dict(scene_spec))
        return _public_job(job)


def get_manim_job(job_id: str) -> Dict[str, Any] | None:
    loaded_from_disk = False
    with _lock:
        job = _jobs.get(job_id)
        if job is None:
            job = _load_job(job_id)
            if job is not None:
                _jobs[job_id] = job
                loaded_from_disk = True
    if job is None:
        return None
    if loaded_from_disk:
        job = _refresh_recovered_manimcat_job(job)
    return _public_job(job)


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
    scene_spec: Dict[str, Any] | None = None,
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
        "scene_spec": scene_spec or {},
        "updated_at": time.time(),
    }


def _update_job(job_id: str, **updates: Any) -> None:
    with _lock:
        job = _jobs.get(job_id)
        if not job:
            return
        job.update(updates)
        job["updated_at"] = time.time()
        _save_job(job)


def _public_job(job: Dict[str, Any]) -> Dict[str, Any]:
    payload = dict(job)
    payload.pop("scene_spec", None)
    return payload


def _job_path(job_id: str) -> Path:
    safe_id = "".join(character for character in str(job_id) if character.isalnum() or character in {"-", "_"})
    return JOBS_ROOT / f"{safe_id}.json"


def _save_job(job: Dict[str, Any]) -> None:
    job_id = str(job.get("job_id") or "")
    if not job_id:
        return
    try:
        JOBS_ROOT.mkdir(parents=True, exist_ok=True)
        path = _job_path(job_id)
        temporary_path = path.with_suffix(".json.tmp")
        temporary_path.write_text(
            json.dumps(job, ensure_ascii=False, sort_keys=True, default=str),
            encoding="utf-8",
        )
        temporary_path.replace(path)
    except OSError:
        pass


def _load_job(job_id: str) -> Dict[str, Any] | None:
    path = _job_path(job_id)
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return payload if isinstance(payload, dict) else None


def _refresh_recovered_manimcat_job(job: Dict[str, Any]) -> Dict[str, Any]:
    if job.get("status") not in {"pending", "running"}:
        return job
    scene_spec = job.get("scene_spec") if isinstance(job.get("scene_spec"), dict) else {}
    if not _is_math_scene(scene_spec):
        return job
    diagnostics = job.get("diagnostics") if isinstance(job.get("diagnostics"), dict) else {}
    remote_job_id = str(diagnostics.get("manimcat_remote_job_id") or "").strip()
    if not remote_job_id:
        return job
    try:
        payload = get_manimcat_job(remote_job_id)
    except ManimCatUnavailable as exc:
        recovered = dict(job)
        recovered["diagnostics"] = {
            **diagnostics,
            "error_summary": _error_summary(exc),
            "recovery_failed_at": time.time(),
        }
        return recovered

    status = str(payload.get("status") or "").lower()
    if status == "completed":
        video_url = str(payload.get("video_url") or payload.get("videoUrl") or "").strip()
        if not video_url:
            _update_job(
                str(job.get("job_id") or ""),
                status="failed",
                progress=100,
                error="数学讲解视频生成失败，可稍后重试。",
                message="数学讲解视频生成失败。",
                diagnostics={
                    **diagnostics,
                    "manimcat_status": status,
                    "error_summary": "ManimCat completed without a video URL.",
                },
            )
            return _jobs.get(str(job.get("job_id") or ""), job)
        output_path = MEDIA_ROOT / f"{job.get('job_id')}.mp4"
        try:
            download_manimcat_video(video_url, output_path)
        except ManimCatUnavailable as exc:
            _update_job(
                str(job.get("job_id") or ""),
                status="failed",
                progress=100,
                error="数学讲解视频下载失败，可稍后重试。",
                message="数学讲解视频下载失败。",
                diagnostics={**diagnostics, "manimcat_status": status, "error_summary": _error_summary(exc)},
            )
            return _jobs.get(str(job.get("job_id") or ""), job)
        local_video_url = f"{MEDIA_URL_PREFIX}/{output_path.name}"
        recovered_diagnostics = _video_diagnostics(local_video_url)
        recovered_diagnostics.update(
            {
                **diagnostics,
                "renderer_available": True,
                "renderer_backend": "manimcat",
                "manimcat_status": status,
                "manimcat_recovered": True,
                "error_summary": "",
            }
        )
        _update_job(
            str(job.get("job_id") or ""),
            status="succeeded",
            progress=100,
            video_url=local_video_url,
            message="Manim video is ready.",
            diagnostics=recovered_diagnostics,
        )
        return _jobs.get(str(job.get("job_id") or ""), job)

    if status in {"failed", "cancelled", "canceled"}:
        _update_job(
            str(job.get("job_id") or ""),
            status="failed",
            progress=100,
            error="数学讲解视频生成失败，可稍后重试。",
            message="数学讲解视频生成失败。",
            diagnostics={**diagnostics, "manimcat_status": status, "error_summary": _error_summary_text(payload)},
        )
        return _jobs.get(str(job.get("job_id") or ""), job)

    _update_manimcat_progress(str(job.get("job_id") or ""), payload)
    return _jobs.get(str(job.get("job_id") or ""), job)


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
            on_progress=lambda payload: _update_manimcat_progress(job_id, payload),
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


def _update_manimcat_progress(job_id: str, payload: Dict[str, Any]) -> None:
    status = str(payload.get("status") or "").lower()
    stage = str(payload.get("stage") or "").lower()
    revision = payload.get("revision")
    attempt = payload.get("attempt")
    progress = 25
    if status in {"queued", "waiting", "delayed"}:
        progress = 10
    elif stage == "analyzing":
        progress = 30
    elif stage in {"generating", "rendering"}:
        progress = 60
    elif status == "processing":
        progress = 45
    elif status == "completed":
        progress = 95
    elif status in {"failed", "cancelled", "canceled"}:
        progress = 100

    message = "正在生成黑板风格数学讲解视频。"
    if stage == "analyzing":
        message = "正在拆解题干条件，规划片头、题干高亮和推导分镜。"
    elif stage == "generating":
        message = "正在编写 Manim 黑板动画脚本。"
    elif stage == "rendering":
        message = "正在渲染公式、图形和逐步推导动画。"
    elif status in {"queued", "waiting", "delayed"}:
        message = "数学讲解视频已进入后台队列。"
    elif status == "completed":
        message = "数学讲解视频已生成。"
    elif status in {"failed", "cancelled", "canceled"}:
        message = "数学讲解视频生成失败。"

    diagnostics = {
        "renderer_available": True,
        "renderer_backend": "manimcat",
        "manimcat_remote_job_id": payload.get("jobId") or payload.get("job_id"),
        "manimcat_status": status,
        "manimcat_stage": stage,
        "manimcat_revision": revision,
        "manimcat_attempt": attempt,
        "manimcat_updated_at": payload.get("updated_at"),
    }
    _update_job(
        job_id,
        status="running",
        progress=progress,
        message=message,
        diagnostics={key: value for key, value in diagnostics.items() if value not in (None, "")},
    )


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


def _error_summary_text(payload: Dict[str, Any]) -> str:
    for key in ("error", "message", "details"):
        value = str(payload.get(key) or "").strip()
        if value:
            return value[:300]
    return "ManimCat render failed."
