from __future__ import annotations

import hashlib
import json
import shutil
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Any, Dict, Iterable
from urllib.parse import unquote, urlparse

from backend.app.core.config import PROJECT_ROOT
from backend.app.rendering.manim_renderer import (
    ManimUnavailable,
    is_manim_available,
    render_manim_video,
)

MEDIA_ROOT = PROJECT_ROOT / "static" / "media" / "manim"
JOBS_ROOT = MEDIA_ROOT / "_jobs"
MEDIA_URL_PREFIX = "/static/media/manim"
MANIM_RENDER_CACHE_VERSION = "local-manim-math-physics-v4"

_executor = ThreadPoolExecutor(max_workers=1)
_lock = threading.Lock()
_jobs: Dict[str, Dict[str, Any]] = {}
_renderer_available_cache: bool | None = None
_INTERRUPTED_JOB_STATUSES = {"pending", "running"}
_LOCAL_MANIM_PROGRESS_CHECKPOINTS = (
    (0.0, 15),
    (4.0, 22),
    (10.0, 31),
    (18.0, 43),
    (30.0, 58),
    (48.0, 72),
    (75.0, 84),
    (110.0, 91),
)


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
    with _lock:
        job = _jobs.get(job_id)
        if job is None:
            job = _load_job(job_id)
            if job is not None:
                job = _mark_interrupted_job_after_restart(job)
                _jobs[job_id] = job
                _save_job(job)
    if job is None:
        return None
    return _public_job(job)


def mark_interrupted_manim_jobs_after_restart() -> int:
    marked_count = 0
    with _lock:
        if not JOBS_ROOT.exists():
            return 0
        for path in JOBS_ROOT.glob("*.json"):
            job = _load_job(path.stem)
            if job is None:
                continue
            updated_job = _mark_interrupted_job_after_restart(job)
            if updated_job is job:
                continue
            _jobs[str(updated_job.get("job_id") or path.stem)] = updated_job
            _save_job(updated_job)
            marked_count += 1
    return marked_count


def retain_manim_artifacts(
    *,
    job_ids: Iterable[str] = (),
    video_urls: Iterable[str] = (),
) -> Dict[str, Any]:
    retained_ids = _collect_job_ids(job_ids=job_ids, video_urls=video_urls)
    retained_count = 0
    with _lock:
        for job_id in retained_ids:
            job = _jobs.get(job_id) or _load_job(job_id)
            if job is None:
                continue
            job["retained"] = True
            job["discarded"] = False
            job["updated_at"] = time.time()
            _jobs[job_id] = job
            _save_job(job)
            retained_count += 1
    return {
        "retained": retained_count,
        "job_ids": sorted(retained_ids),
    }


def discard_manim_artifacts(
    *,
    job_ids: Iterable[str] = (),
    video_urls: Iterable[str] = (),
) -> Dict[str, Any]:
    target_ids = _collect_job_ids(job_ids=job_ids, video_urls=video_urls)
    deleted_count = 0
    deferred_count = 0
    with _lock:
        for job_id in target_ids:
            job = _jobs.get(job_id) or _load_job(job_id)
            if job is not None and job.get("retained"):
                continue
            status = str(job.get("status") or "") if isinstance(job, dict) else ""
            if status in {"pending", "running"}:
                # Old clients may call cleanup when a preview screen is closed
                # while the renderer is still working. Do not mark active jobs
                # for deletion, or a successful video can disappear immediately
                # after rendering completes.
                deferred_count += 1
                continue
            if _delete_job_artifacts_locked(job_id, job=job):
                deleted_count += 1

        for video_url in video_urls:
            if _delete_orphan_video_url_locked(str(video_url)):
                deleted_count += 1

    return {
        "deleted": deleted_count,
        "deferred": deferred_count,
        "job_ids": sorted(target_ids),
    }


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
    progress_stop, progress_thread = _start_local_manim_progress_heartbeat(
        job_id,
        started_at,
    )
    try:
        renderer_backend = "local_manim"
        output_path = _render_scene_video(scene_spec=scene_spec, job_id=job_id)
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
    finally:
        progress_stop.set()
        progress_thread.join(timeout=0.2)
        _cleanup_discarded_job(job_id)


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
        "retained": False,
        "discarded": False,
        "diagnostics": diagnostics
        if diagnostics is not None
        else {
            "renderer_available": _renderer_available(),
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


def _start_local_manim_progress_heartbeat(
    job_id: str,
    started_at: float,
) -> tuple[threading.Event, threading.Thread]:
    stop_event = threading.Event()
    thread = threading.Thread(
        target=_run_local_manim_progress_heartbeat,
        args=(job_id, started_at, stop_event),
        daemon=True,
    )
    thread.start()
    return stop_event, thread


def _run_local_manim_progress_heartbeat(
    job_id: str,
    started_at: float,
    stop_event: threading.Event,
) -> None:
    while not stop_event.wait(2.0):
        elapsed = time.perf_counter() - started_at
        progress = _estimated_local_manim_progress(elapsed)
        if not _update_local_manim_progress(job_id, progress, elapsed):
            return


def _estimated_local_manim_progress(elapsed_seconds: float) -> int:
    previous_elapsed, previous_progress = _LOCAL_MANIM_PROGRESS_CHECKPOINTS[0]
    for next_elapsed, next_progress in _LOCAL_MANIM_PROGRESS_CHECKPOINTS[1:]:
        if elapsed_seconds <= next_elapsed:
            span = max(next_elapsed - previous_elapsed, 0.001)
            ratio = max(
                0.0,
                min(1.0, (elapsed_seconds - previous_elapsed) / span),
            )
            return int(previous_progress + (next_progress - previous_progress) * ratio)
        previous_elapsed, previous_progress = next_elapsed, next_progress
    return _LOCAL_MANIM_PROGRESS_CHECKPOINTS[-1][1]


def _local_manim_progress_message(progress: int) -> str:
    if progress < 25:
        return "正在准备 Manim 场景脚本。"
    if progress < 45:
        return "正在绘制题干、高亮和基础图形。"
    if progress < 65:
        return "正在生成推导动画和过渡分镜。"
    if progress < 85:
        return "正在渲染视频帧，请稍等。"
    return "正在封装 MP4 视频。"


def _update_local_manim_progress(
    job_id: str,
    progress: int,
    elapsed_seconds: float,
) -> bool:
    with _lock:
        job = _jobs.get(job_id)
        if not job or job.get("status") != "running":
            return False
        current_progress = int(job.get("progress") or 0)
        if progress <= current_progress:
            return True
        diagnostics = (
            job.get("diagnostics")
            if isinstance(job.get("diagnostics"), dict)
            else {}
        )
        job.update(
            progress=progress,
            message=_local_manim_progress_message(progress),
            diagnostics={
                **diagnostics,
                "renderer_backend": "local_manim",
                "estimated_progress": True,
                "render_elapsed_seconds": round(elapsed_seconds, 3),
            },
            updated_at=time.time(),
        )
        _save_job(job)
    return True


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


def _mark_interrupted_job_after_restart(job: Dict[str, Any]) -> Dict[str, Any]:
    status = str(job.get("status") or "")
    if status not in _INTERRUPTED_JOB_STATUSES:
        return job

    diagnostics = (
        job.get("diagnostics")
        if isinstance(job.get("diagnostics"), dict)
        else {}
    )
    return {
        **job,
        "status": "failed",
        "progress": 100,
        "message": "动画生成进程已中断，可重新生成视频。",
        "error": "动画生成进程已中断，请重新生成。",
        "diagnostics": {
            **diagnostics,
            "interrupted_after_restart": True,
            "error_summary": "Manim job was pending or running when the backend process restarted.",
        },
        "updated_at": time.time(),
    }


def _safe_job_id(value: str) -> str:
    return "".join(
        character
        for character in str(value)
        if character.isalnum() or character in {"-", "_"}
    )


def _collect_job_ids(
    *,
    job_ids: Iterable[str],
    video_urls: Iterable[str],
) -> set[str]:
    collected: set[str] = set()
    for job_id in job_ids:
        safe_id = _safe_job_id(str(job_id))
        if safe_id:
            collected.add(safe_id)
    for video_url in video_urls:
        job_id = _job_id_from_video_url(str(video_url))
        if job_id:
            collected.add(job_id)
    return collected


def _job_id_from_video_url(video_url: str) -> str:
    path = _path_for_video_url(video_url)
    if path is None:
        parsed = urlparse(video_url)
        candidate_path = unquote(parsed.path if parsed.scheme else video_url)
        prefix = f"{MEDIA_URL_PREFIX}/"
        if prefix not in candidate_path:
            return ""
        path = MEDIA_ROOT / Path(candidate_path.split(prefix, 1)[1]).name
    if path.suffix.lower() != ".mp4":
        return ""
    return _safe_job_id(path.stem)


def _cleanup_discarded_job(job_id: str) -> None:
    with _lock:
        job = _jobs.get(job_id) or _load_job(job_id)
        if not isinstance(job, dict):
            return
        if job.get("discarded") and not job.get("retained"):
            _delete_job_artifacts_locked(job_id, job=job)


def _delete_job_artifacts_locked(
    job_id: str,
    *,
    job: Dict[str, Any] | None,
) -> bool:
    safe_id = _safe_job_id(job_id)
    if not safe_id:
        return False

    deleted = False
    deleted = _unlink_safe(_job_path(safe_id), roots=(JOBS_ROOT,)) or deleted
    for path in (
        MEDIA_ROOT / f"{safe_id}.py",
        MEDIA_ROOT / f"{safe_id}.mp4",
        MEDIA_ROOT / f"{safe_id}.faststart.mp4",
    ):
        deleted = _unlink_safe(path) or deleted

    diagnostics = job.get("diagnostics") if isinstance(job, dict) else {}
    output_path = diagnostics.get("output_path") if isinstance(diagnostics, dict) else ""
    if output_path:
        deleted = _unlink_safe(Path(str(output_path))) or deleted

    for directory_name in ("videos", "images", "texts", "__pycache__"):
        deleted = _remove_tree_safe(MEDIA_ROOT / directory_name / safe_id) or deleted

    _jobs.pop(safe_id, None)
    return deleted


def _delete_orphan_video_url_locked(video_url: str) -> bool:
    path = _path_for_video_url(video_url)
    if path is None:
        parsed = urlparse(video_url)
        candidate_path = unquote(parsed.path if parsed.scheme else video_url)
        prefix = f"{MEDIA_URL_PREFIX}/"
        if prefix not in candidate_path:
            return False
        path = MEDIA_ROOT / Path(candidate_path.split(prefix, 1)[1]).name
    job_id = _safe_job_id(path.stem)
    job = _jobs.get(job_id) or _load_job(job_id)
    if isinstance(job, dict) and job.get("retained"):
        return False
    return _unlink_safe(path)


def _unlink_safe(path: Path, *, roots: tuple[Path, ...] | None = None) -> bool:
    try:
        resolved = path.resolve()
        resolved_roots = [root.resolve() for root in (roots or (MEDIA_ROOT,))]
    except OSError:
        return False
    if not any(resolved != root and root in resolved.parents for root in resolved_roots):
        return False
    try:
        if resolved.is_file() or resolved.is_symlink():
            resolved.unlink()
            return True
    except OSError:
        return False
    return False


def _remove_tree_safe(path: Path) -> bool:
    try:
        resolved = path.resolve()
        media_root = MEDIA_ROOT.resolve()
    except OSError:
        return False
    if resolved == media_root or media_root not in resolved.parents:
        return False
    try:
        if resolved.is_dir():
            shutil.rmtree(resolved)
            return True
    except OSError:
        return False
    return False



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
    return render_manim_video(
        scene_spec=scene_spec,
        job_id=job_id,
        output_dir=MEDIA_ROOT,
    )


def _video_diagnostics(video_url: str) -> Dict[str, Any]:
    path = _path_for_video_url(video_url)
    exists = path.exists() if path else False
    size = path.stat().st_size if path and exists else 0
    return {
        "renderer_available": _renderer_available(),
        "output_path_exists": exists,
        "output_path": str(path) if path else "",
        "file_size_bytes": size,
        "mp4_faststart": _mp4_faststart_ready(path) if path and exists else False,
        "error_summary": "",
    }


def _path_for_video_url(video_url: str) -> Path | None:
    if not video_url.startswith(f"{MEDIA_URL_PREFIX}/"):
        return None
    name = Path(video_url).name
    if not name:
        return None
    return MEDIA_ROOT / name


def _mp4_faststart_ready(path: Path) -> bool:
    try:
        with path.open("rb") as file:
            header = file.read(4096)
    except OSError:
        return False
    moov_offset = header.find(b"moov")
    mdat_offset = header.find(b"mdat")
    return moov_offset != -1 and (mdat_offset == -1 or moov_offset < mdat_offset)


def _error_summary(exc: Exception) -> str:
    message = str(exc).strip()
    if len(message) > 300:
        return f"{message[:297]}..."
    return message
