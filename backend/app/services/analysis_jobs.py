from __future__ import annotations

import logging
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from typing import Any, Dict

from ai_engine.llm_logic.diagnostic_chain import DiagnosticService
from ai_engine.llm_logic.ocr_parser import normalize_ocr_text
from ai_engine.llm_logic.vivo_client import VivoAPIError, VivoLMClient
from backend.app.schemas.card_schema import (
    AnalysisRequest,
    ImageAnalysisJobResponse,
    ImageAnalysisResponse,
    OCRResponse,
    ReviewPlan,
)


logger = logging.getLogger(__name__)

ANALYSIS_JOB_MAX_WORKERS = 2

_executor = ThreadPoolExecutor(max_workers=ANALYSIS_JOB_MAX_WORKERS)
_lock = threading.Lock()
_jobs: Dict[str, Dict[str, Any]] = {}


def create_image_analysis_job(
    *,
    image_bytes: bytes,
    filename: str,
    content_type: str,
    subject: str,
    user_answer: str,
    wrong_reason_hint: str,
    enable_subject_extensions: bool,
    diagnostic_service: DiagnosticService,
    vivo_client: VivoLMClient,
) -> ImageAnalysisJobResponse:
    """Queue a two-stage image analysis job and return immediately.

    Stage 1 performs OCR and stores an OCR-only partial result. Stage 2 uses the
    quality text model in the background, so the mobile client does not hold a
    long HTTP connection while the detailed explanation is being generated.
    """

    job_id = uuid.uuid4().hex[:24]
    now = time.time()
    with _lock:
        _jobs[job_id] = {
            "job_id": job_id,
            "status": "pending",
            "progress": 0,
            "message": "已加入后台解析队列。",
            "error": "",
            "created_at": now,
            "updated_at": now,
            "ocr": None,
            "result": None,
            "partial_result": None,
            "diagnostics": {
                "filename": filename,
                "content_type": content_type,
                "image_size_bytes": len(image_bytes),
            },
        }
    _executor.submit(
        _run_image_analysis_job,
        job_id,
        image_bytes,
        content_type,
        subject,
        user_answer,
        wrong_reason_hint,
        enable_subject_extensions,
        diagnostic_service,
        vivo_client,
    )
    return get_image_analysis_job(job_id)  # type: ignore[return-value]


def get_image_analysis_job(job_id: str) -> ImageAnalysisJobResponse | None:
    with _lock:
        job = _jobs.get(job_id)
        if not job:
            return None
        return _to_response(dict(job))


def retry_image_analysis_job(
    *,
    job_id: str,
    diagnostic_service: DiagnosticService,
) -> ImageAnalysisJobResponse | None:
    """Retry only the high-quality stage when OCR text is already available."""

    with _lock:
        job = _jobs.get(job_id)
        if not job:
            return None
        ocr = job.get("ocr")
        if not isinstance(ocr, OCRResponse):
            return _to_response(dict(job))
        subject = str(job.get("subject") or "未分类")
        user_answer = str(job.get("user_answer") or "")
        wrong_reason_hint = str(job.get("wrong_reason_hint") or "")
        enable_subject_extensions = bool(job.get("enable_subject_extensions", True))
        job.update(
            {
                "status": "processing",
                "progress": max(int(job.get("progress") or 0), 55),
                "message": "正在重新生成高质量详解。",
                "error": "",
                "updated_at": time.time(),
            }
        )
    _executor.submit(
        _run_quality_stage,
        job_id,
        ocr.normalized_text,
        subject,
        user_answer,
        wrong_reason_hint,
        enable_subject_extensions,
        diagnostic_service,
    )
    return get_image_analysis_job(job_id)


def _run_image_analysis_job(
    job_id: str,
    image_bytes: bytes,
    content_type: str,
    subject: str,
    user_answer: str,
    wrong_reason_hint: str,
    enable_subject_extensions: bool,
    diagnostic_service: DiagnosticService,
    vivo_client: VivoLMClient,
) -> None:
    _update_job(job_id, status="processing", progress=10, message="正在识别题目文字。")
    try:
        ocr_result = vivo_client.ocr_image(image_bytes)
        normalized_text = normalize_ocr_text(ocr_result["raw_text"])
        ocr = OCRResponse(
            raw_text=ocr_result["raw_text"],
            normalized_text=normalized_text,
            blocks=ocr_result.get("blocks", []),
        )
        request_payload = AnalysisRequest(
            question_text=normalized_text or "未识别到清晰题目文字",
            subject=subject,
            user_answer=user_answer,
            wrong_reason_hint=wrong_reason_hint,
            enable_subject_extensions=enable_subject_extensions,
        )
        partial = _build_ocr_only_image_response(
            request_payload=request_payload,
            ocr=ocr,
        )
        _update_job(
            job_id,
            status="partial_success",
            progress=45,
            message="已识别题目文字，正在生成高质量详解。",
            ocr=ocr,
            partial_result=partial,
            subject=subject,
            user_answer=user_answer,
            wrong_reason_hint=wrong_reason_hint,
            enable_subject_extensions=enable_subject_extensions,
        )
        _run_quality_stage(
            job_id,
            normalized_text,
            subject,
            user_answer,
            wrong_reason_hint,
            enable_subject_extensions,
            diagnostic_service,
            ocr=ocr,
        )
    except VivoAPIError as exc:
        logger.warning("image analysis job ocr failed job_id=%s error=%s", job_id, exc)
        _update_job(
            job_id,
            status="need_retry",
            progress=100,
            message="题目文字识别失败，可稍后重试。",
            error=_friendly_error(exc),
        )
    except Exception as exc:
        logger.exception("image analysis job failed job_id=%s", job_id)
        _update_job(
            job_id,
            status="failed",
            progress=100,
            message="后台解析失败。",
            error=_friendly_error(exc),
        )


def _run_quality_stage(
    job_id: str,
    normalized_text: str,
    subject: str,
    user_answer: str,
    wrong_reason_hint: str,
    enable_subject_extensions: bool,
    diagnostic_service: DiagnosticService,
    ocr: OCRResponse | None = None,
) -> None:
    if not normalized_text.strip():
        _update_job(
            job_id,
            status="need_retry",
            progress=100,
            message="OCR 未识别到可用题干。",
            error="请裁剪清晰题目区域后重试。",
        )
        return

    _update_job(job_id, status="processing", progress=65, message="正在生成高质量详解。")
    try:
        analysis = diagnostic_service.analyze_text_quality(
            AnalysisRequest(
                question_text=normalized_text,
                subject=subject,
                user_answer=user_answer,
                wrong_reason_hint=wrong_reason_hint,
                enable_subject_extensions=enable_subject_extensions,
            )
        )
        stored_ocr = ocr or _get_job_ocr(job_id)
        if stored_ocr is None:
            stored_ocr = OCRResponse(raw_text=normalized_text, normalized_text=normalized_text, blocks=[])
        result = ImageAnalysisResponse(
            **analysis.model_dump(),
            ocr=stored_ocr,
        )
        _update_job(
            job_id,
            status="completed",
            progress=100,
            message="高质量详解已生成。",
            result=result,
            error="",
        )
    except VivoAPIError as exc:
        logger.warning("image analysis job quality stage failed job_id=%s error=%s", job_id, exc)
        _update_job(
            job_id,
            status="partial_success",
            progress=80,
            message="已保留基础识别结果，完整详解生成失败，可稍后重试。",
            error=_friendly_error(exc),
        )


def _build_ocr_only_image_response(
    *,
    request_payload: AnalysisRequest,
    ocr: OCRResponse,
) -> ImageAnalysisResponse:
    cleaned = ocr.normalized_text.strip() or request_payload.question_text.strip()
    subject = request_payload.subject if request_payload.subject != "通用" else "未分类"
    return ImageAnalysisResponse(
        question_text=request_payload.question_text,
        cleaned_question=cleaned,
        scene_brief=cleaned[:80],
        subject=subject,
        knowledge_points=["OCR 已识别题干", "高质量详解生成中"],
        solution_summary="已完成题目文字识别，系统正在后台生成高质量详解。",
        solution_steps=[
            "题目已先进入错题档案，避免因为 AI 响应慢导致整题丢失。",
            "完整答案、公式推导、错因分析和复习建议会在后台继续补全。",
        ],
        mistake_diagnosis="完整错因分析生成中。",
        review_plan=ReviewPlan(
            next_review_in_days=1,
            focus="等待高质量详解生成后再复习。",
            schedule=[1, 3, 7],
        ),
        similar_questions=[],
        rich_artifacts=[],
        source="image",
        raw_model_output="",
        ocr=ocr,
    )


def _update_job(job_id: str, **updates: Any) -> None:
    with _lock:
        job = _jobs.get(job_id)
        if not job:
            return
        job.update(updates)
        job["updated_at"] = time.time()


def _get_job_ocr(job_id: str) -> OCRResponse | None:
    with _lock:
        ocr = (_jobs.get(job_id) or {}).get("ocr")
        return ocr if isinstance(ocr, OCRResponse) else None


def _to_response(job: Dict[str, Any]) -> ImageAnalysisJobResponse:
    return ImageAnalysisJobResponse(
        job_id=str(job["job_id"]),
        status=job["status"],
        progress=int(job.get("progress") or 0),
        message=str(job.get("message") or ""),
        error=str(job.get("error") or ""),
        created_at=float(job.get("created_at") or 0),
        updated_at=float(job.get("updated_at") or 0),
        ocr=job.get("ocr") if isinstance(job.get("ocr"), OCRResponse) else None,
        result=job.get("result") if isinstance(job.get("result"), ImageAnalysisResponse) else None,
        partial_result=job.get("partial_result")
        if isinstance(job.get("partial_result"), ImageAnalysisResponse)
        else None,
    )


def _friendly_error(exc: Exception) -> str:
    message = str(exc).lower()
    if "timed out" in message or "timeout" in message:
        return "AI 解析暂时较慢，已保留题目基础信息，可稍后重新生成详解。"
    if "connection" in message or "network" in message or "网络" in message:
        return "网络连接中断，请检查网络后重试。"
    return "AI 解析暂时不可用，请稍后重试。"
