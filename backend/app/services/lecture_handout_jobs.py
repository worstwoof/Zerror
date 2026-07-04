from __future__ import annotations

import logging
import re
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from typing import Any, Dict

from ai_engine.llm_logic.lecture_handout_chain import LectureHandoutService
from ai_engine.llm_logic.vivo_client import VivoAPIError
from backend.app.schemas.card_schema import (
    LectureHandoutJobResponse,
    LectureHandoutRequest,
    LectureHandoutResponse,
)


logger = logging.getLogger(__name__)
_CLIENT_JOB_ID_RE = re.compile(r"^[A-Za-z0-9_.:-]{8,96}$")
_executor = ThreadPoolExecutor(max_workers=1)
_lock = threading.Lock()
_jobs: Dict[str, Dict[str, Any]] = {}


def create_lecture_handout_job(
    *,
    request: LectureHandoutRequest,
    service: LectureHandoutService,
) -> LectureHandoutJobResponse:
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
            "message": "已加入讲义生成队列。",
            "error": "",
            "created_at": now,
            "updated_at": now,
            "result": None,
            "request": request,
        }
    _executor.submit(_run_lecture_handout_job, job_id, service)
    return get_lecture_handout_job(job_id)  # type: ignore[return-value]


def get_lecture_handout_job(job_id: str) -> LectureHandoutJobResponse | None:
    with _lock:
        job = _jobs.get(job_id)
        if not job:
            return None
        return _to_response(dict(job))


def retry_lecture_handout_job(
    *,
    job_id: str,
    service: LectureHandoutService,
) -> LectureHandoutJobResponse | None:
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
                "message": "正在重新提交讲义生成任务。",
                "error": "",
                "result": None,
                "updated_at": time.time(),
            }
        )
    _executor.submit(_run_lecture_handout_job, job_id, service)
    return get_lecture_handout_job(job_id)


def _run_lecture_handout_job(job_id: str, service: LectureHandoutService) -> None:
    _update_job(job_id, status="processing", progress=12, message="正在分析讲义主题。")
    request = _get_job_request(job_id)
    if request is None:
        _update_job(
            job_id,
            status="failed",
            progress=100,
            message="讲义任务参数丢失。",
            error="请重新发起讲义生成。",
        )
        return
    if not request.prompt.strip():
        _update_job(
            job_id,
            status="failed",
            progress=100,
            message="讲义主题不能为空。",
            error="请告诉我需要整理的学科或知识点。",
        )
        return

    try:
        _update_job(job_id, status="processing", progress=35, message="AI 正在撰写知识讲义。")
        result = service.generate_handout(request)
        _update_job(job_id, status="processing", progress=88, message="正在整理可打印 PDF 版式。")
        _update_job(
            job_id,
            status="completed",
            progress=100,
            message="讲义已生成。",
            result=result,
            error="",
        )
    except VivoAPIError as exc:
        logger.warning("lecture handout job vivo failed job_id=%s error=%s", job_id, exc)
        _update_job(
            job_id,
            status="failed",
            progress=100,
            message="讲义生成失败，可稍后重试。",
            error=_friendly_error(exc),
        )
    except Exception as exc:
        logger.exception("lecture handout job crashed job_id=%s", job_id)
        _update_job(
            job_id,
            status="failed",
            progress=100,
            message="讲义生成失败。",
            error=_friendly_error(exc),
        )


def _update_job(job_id: str, **updates: Any) -> None:
    with _lock:
        job = _jobs.get(job_id)
        if not job:
            return
        job.update(updates)
        job["updated_at"] = time.time()


def _get_job_request(job_id: str) -> LectureHandoutRequest | None:
    with _lock:
        request = (_jobs.get(job_id) or {}).get("request")
        return request if isinstance(request, LectureHandoutRequest) else None


def _to_response(job: Dict[str, Any]) -> LectureHandoutJobResponse:
    result = job.get("result")
    return LectureHandoutJobResponse(
        job_id=str(job["job_id"]),
        status=job["status"],
        progress=int(job.get("progress") or 0),
        message=str(job.get("message") or ""),
        error=str(job.get("error") or ""),
        created_at=float(job.get("created_at") or 0),
        updated_at=float(job.get("updated_at") or 0),
        result=result if isinstance(result, LectureHandoutResponse) else None,
    )


def _friendly_error(exc: Exception) -> str:
    message = str(exc).lower()
    if "timed out" in message or "timeout" in message:
        return "AI 生成讲义暂时较慢，请稍后重试。"
    if "connection" in message or "network" in message or "网络" in message:
        return "网络连接中断，请检查网络后重试。"
    return "AI 讲义服务暂时不可用，请稍后重试。"
