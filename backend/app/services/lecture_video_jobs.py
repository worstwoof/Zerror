from __future__ import annotations

import json
import logging
import re
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from typing import Any, Dict

from ai_engine.llm_logic.lecture_video_chain import LectureVideoService
from ai_engine.llm_logic.vivo_client import VivoAPIError
from backend.app.schemas.card_schema import (
    LectureVideoJobResponse,
    LectureVideoRequest,
    LectureVideoResponse,
    RichArtifact,
)
from backend.app.services.render_jobs import get_manim_job, retain_manim_artifacts


logger = logging.getLogger(__name__)
_CLIENT_JOB_ID_RE = re.compile(r"^[A-Za-z0-9_.:-]{8,96}$")
_executor = ThreadPoolExecutor(max_workers=1)
_lock = threading.Lock()
_jobs: Dict[str, Dict[str, Any]] = {}


def create_lecture_video_job(
    *,
    request: LectureVideoRequest,
    service: LectureVideoService,
) -> LectureVideoJobResponse:
    normalized_client_job_id = request.client_job_id.strip()
    job_id = (
        normalized_client_job_id
        if _CLIENT_JOB_ID_RE.fullmatch(normalized_client_job_id)
        else uuid.uuid4().hex[:24]
    )
    now = time.time()
    with _lock:
        existing_job = _jobs.get(job_id)
        if existing_job is not None:
            return _to_response(dict(existing_job))
        _jobs[job_id] = {
            "job_id": job_id,
            "status": "pending",
            "progress": 0,
            "message": "已加入视频讲解队列。",
            "error": "",
            "created_at": now,
            "updated_at": now,
            "result": None,
            "request": request,
        }
    _executor.submit(_run_lecture_video_job, job_id, service)
    return get_lecture_video_job(job_id)  # type: ignore[return-value]


def get_lecture_video_job(job_id: str) -> LectureVideoJobResponse | None:
    with _lock:
        job = _jobs.get(job_id)
        if not job:
            return None
        return _to_response(dict(job))


def retry_lecture_video_job(
    *,
    job_id: str,
    service: LectureVideoService,
) -> LectureVideoJobResponse | None:
    with _lock:
        job = _jobs.get(job_id)
        if not job:
            return None
        if job.get("status") in {"pending", "processing"}:
            return _to_response(dict(job))
        job.update(
            {
                "status": "pending",
                "progress": 0,
                "message": "正在重新提交视频讲解任务。",
                "error": "",
                "result": None,
                "updated_at": time.time(),
            }
        )
    _executor.submit(_run_lecture_video_job, job_id, service)
    return get_lecture_video_job(job_id)


def _run_lecture_video_job(job_id: str, service: LectureVideoService) -> None:
    _update_job(job_id, status="processing", progress=10, message="正在规划视频讲解分镜。")
    request = _get_job_request(job_id)
    if request is None:
        _update_job(
            job_id,
            status="failed",
            progress=100,
            message="视频讲解任务参数丢失。",
            error="请重新发起视频讲解。",
        )
        return
    if not request.prompt.strip():
        _update_job(
            job_id,
            status="failed",
            progress=100,
            message="视频讲解主题不能为空。",
            error="请告诉我需要讲解的知识点。",
        )
        return

    try:
        result = service.generate_video(request)
        _update_job(
            job_id,
            status="processing",
            progress=28,
            message="Manim 正在渲染视频讲解。",
            result=result,
            error="",
        )
        manim_job_id = _manim_job_id(result)
        if not manim_job_id:
            _update_job(
                job_id,
                status="failed",
                progress=100,
                message="视频讲解任务创建失败。",
                error="视频渲染任务没有返回任务号，请稍后重试。",
            )
            return
        _wait_for_manim_job(job_id=job_id, manim_job_id=manim_job_id, result=result)
    except VivoAPIError as exc:
        logger.warning("lecture video job vivo failed job_id=%s error=%s", job_id, exc)
        _update_job(
            job_id,
            status="failed",
            progress=100,
            message="视频讲解生成失败，可稍后重试。",
            error=_friendly_error(exc),
        )
    except Exception as exc:
        logger.exception("lecture video job crashed job_id=%s", job_id)
        _update_job(
            job_id,
            status="failed",
            progress=100,
            message="视频讲解生成失败。",
            error=_friendly_error(exc),
        )


def _wait_for_manim_job(
    *,
    job_id: str,
    manim_job_id: str,
    result: LectureVideoResponse,
) -> None:
    while True:
        manim_job = get_manim_job(manim_job_id)
        if manim_job is None:
            _update_job(
                job_id,
                status="failed",
                progress=100,
                message="视频渲染任务不存在。",
                error="Manim 渲染任务已丢失，请重新生成。",
            )
            return

        status = str(manim_job.get("status") or "")
        progress = int(manim_job.get("progress") or 0)
        if status == "succeeded" and manim_job.get("video_url"):
            retain_manim_artifacts(job_ids=[manim_job_id])
            completed = result.model_copy(
                update={
                    "artifact": _artifact_from_manim_job(
                        manim_job,
                        title=result.title,
                        artifact_type="manim_video",
                    )
                }
            )
            _update_job(
                job_id,
                status="completed",
                progress=100,
                message="视频讲解已生成。",
                result=completed,
                error="",
            )
            return
        if status == "failed":
            _update_job(
                job_id,
                status="failed",
                progress=100,
                message="视频渲染失败，可稍后重试。",
                error=str(manim_job.get("error") or "Manim 视频渲染失败。"),
                result=result.model_copy(
                    update={
                        "artifact": _artifact_from_manim_job(
                            manim_job,
                            title=result.title,
                            artifact_type="manim_job",
                        )
                    }
                ),
            )
            return

        _update_job(
            job_id,
            status="processing",
            progress=max(30, min(96, 30 + int(progress * 0.66))),
            message=str(manim_job.get("message") or "Manim 正在渲染视频讲解。"),
            result=result.model_copy(
                update={
                    "artifact": _artifact_from_manim_job(
                        manim_job,
                        title=result.title,
                        artifact_type="manim_job",
                    )
                }
            ),
            error="",
        )
        time.sleep(2.0)


def _manim_job_id(result: LectureVideoResponse) -> str:
    try:
        content = json.loads(result.artifact.content)
    except json.JSONDecodeError:
        return ""
    return str(content.get("job_id") or "").strip()


def _artifact_from_manim_job(
    manim_job: Dict[str, Any],
    *,
    title: str,
    artifact_type: str,
) -> RichArtifact:
    content = {
        "url": manim_job.get("video_url"),
        "video_url": manim_job.get("video_url"),
        "job_id": manim_job.get("job_id"),
        "status": manim_job.get("status"),
        "progress": manim_job.get("progress"),
        "message": manim_job.get("message"),
        "error": manim_job.get("error"),
        "updated_at": manim_job.get("updated_at"),
        "diagnostics": manim_job.get("diagnostics"),
        "duration": manim_job.get("duration"),
        "thumbnail_url": manim_job.get("thumbnail_url"),
    }
    return RichArtifact(
        artifact_type=artifact_type,  # type: ignore[arg-type]
        title=title,
        description="知识点视频讲解已生成。"
        if artifact_type == "manim_video"
        else "后台正在生成知识点视频讲解。",
        mime_type="application/json",
        content=json.dumps(content, ensure_ascii=False),
    )


def _update_job(job_id: str, **updates: Any) -> None:
    with _lock:
        job = _jobs.get(job_id)
        if not job:
            return
        job.update(updates)
        job["updated_at"] = time.time()


def _get_job_request(job_id: str) -> LectureVideoRequest | None:
    with _lock:
        request = (_jobs.get(job_id) or {}).get("request")
        return request if isinstance(request, LectureVideoRequest) else None


def _to_response(job: Dict[str, Any]) -> LectureVideoJobResponse:
    result = job.get("result")
    return LectureVideoJobResponse(
        job_id=str(job["job_id"]),
        status=job["status"],
        progress=int(job.get("progress") or 0),
        message=str(job.get("message") or ""),
        error=str(job.get("error") or ""),
        created_at=float(job.get("created_at") or 0),
        updated_at=float(job.get("updated_at") or 0),
        result=result if isinstance(result, LectureVideoResponse) else None,
    )


def _friendly_error(exc: Exception) -> str:
    message = str(exc).lower()
    if "timed out" in message or "timeout" in message:
        return "AI 规划视频讲解暂时较慢，请稍后重试。"
    if "connection" in message or "network" in message or "网络" in message:
        return "网络连接中断，请检查网络后重试。"
    if "manim" in message or "动画" in message:
        return "视频渲染服务暂时不可用，请稍后重试。"
    return "AI 视频讲解服务暂时不可用，请稍后重试。"
