from __future__ import annotations

import logging
import time

from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from ai_engine.llm_logic.diagnostic_chain import DiagnosticService
from ai_engine.llm_logic.ocr_parser import normalize_ocr_text
from ai_engine.llm_logic.vivo_client import VivoAPIError, VivoLMClient
from backend.app.core.config import settings
from backend.app.schemas.card_schema import (
    AnalysisRequest,
    AnalysisResponse,
    ImageAnalysisJobResponse,
    ImageAnalysisResponse,
    OCRResponse,
    PhysicsAnimationRequest,
    PhysicsAnimationResponse,
    ReviewPlan,
)
from backend.app.services.analysis_jobs import (
    create_image_analysis_job,
    get_image_analysis_job,
    retry_image_analysis_job,
)


router = APIRouter(prefix="/api/v1", tags=["ai"])
vivo_client = VivoLMClient(settings)
diagnostic_service = DiagnosticService(vivo_client)
logger = logging.getLogger(__name__)


def _ensure_credentials() -> None:
    if not settings.has_vivo_credentials:
        raise HTTPException(
            status_code=503,
            detail="VIVO_API_KEY 未配置，无法调用 vivo 蓝心接口。",
        )


@router.get("/health")
def healthcheck() -> dict[str, str]:
    return {
        "status": "ok",
        "service": settings.app_name,
        "version": settings.app_version,
    }


@router.post("/analysis/text", response_model=AnalysisResponse)
def analyze_text(request: AnalysisRequest) -> AnalysisResponse:
    _ensure_credentials()
    try:
        return diagnostic_service.analyze_text(request)
    except VivoAPIError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.post("/ocr/extract", response_model=OCRResponse)
async def extract_text(image: UploadFile = File(...)) -> OCRResponse:
    _ensure_credentials()
    started_at = time.perf_counter()
    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="上传图片为空。")

    try:
        ocr_started_at = time.perf_counter()
        ocr_result = vivo_client.ocr_image(image_bytes)
        normalized_text = normalize_ocr_text(ocr_result["raw_text"])
        logger.info(
            "api ocr extract image_kb=%.1f ocr=%.2fs total=%.2fs",
            len(image_bytes) / 1024,
            time.perf_counter() - ocr_started_at,
            time.perf_counter() - started_at,
        )
        return OCRResponse(
            raw_text=ocr_result["raw_text"],
            normalized_text=normalized_text,
            blocks=ocr_result.get("blocks", []),
        )
    except VivoAPIError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.post("/analysis/image", response_model=ImageAnalysisResponse)
async def analyze_image(
    image: UploadFile = File(...),
    subject: str = Form("通用"),
    user_answer: str = Form(""),
    wrong_reason_hint: str = Form(""),
    enable_subject_extensions: bool = Form(True),
) -> ImageAnalysisResponse:
    # Compatibility path for the current mobile client. New batch-photo flows
    # should prefer /analysis/image/jobs so uploads return quickly and quality
    # explanations can finish in the background.
    _ensure_credentials()
    started_at = time.perf_counter()
    upload_content_type = image.content_type or ""
    upload_filename = image.filename or ""
    requested_subject_extensions = enable_subject_extensions
    effective_subject_extensions = True
    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="上传图片为空。")

    try:
        ocr_started_at = time.perf_counter()
        ocr_result = vivo_client.ocr_image(image_bytes)
        ocr_elapsed = time.perf_counter() - ocr_started_at
        normalized_text = normalize_ocr_text(ocr_result["raw_text"])
        logger.info(
            "api analysis image upload filename=%s content_type=%s image_kb=%.1f requested_subject_extensions=%s effective_subject_extensions=%s",
            upload_filename,
            upload_content_type or "unknown",
            len(image_bytes) / 1024,
            requested_subject_extensions,
            effective_subject_extensions,
        )
        request_payload = AnalysisRequest(
            question_text=normalized_text,
            subject=subject,
            user_answer=user_answer,
            wrong_reason_hint=wrong_reason_hint,
            enable_subject_extensions=effective_subject_extensions,
        )
        fallback_to_text = False
        try:
            analysis_started_at = time.perf_counter()
            analysis = diagnostic_service.analyze_image(
                request_payload,
                image_bytes=image_bytes,
                mime_type=upload_content_type or "image/png",
                ocr_draft=normalized_text,
            )
            analysis_elapsed = time.perf_counter() - analysis_started_at
        except VivoAPIError as exc:
            # Degrade gracefully when the multimodal request is too slow or unavailable:
            # we already have OCR text, so fall back to the lighter text analysis path.
            if normalized_text.strip() and _should_fallback_to_text_analysis(exc):
                fallback_to_text = True
                analysis_started_at = time.perf_counter()
                try:
                    analysis = diagnostic_service.analyze_text(
                        AnalysisRequest(
                            question_text=normalized_text,
                            subject=subject,
                            user_answer=user_answer,
                            wrong_reason_hint=wrong_reason_hint,
                            enable_subject_extensions=effective_subject_extensions,
                        )
                    )
                except VivoAPIError as text_exc:
                    if not _should_fallback_to_text_analysis(text_exc):
                        raise
                    logger.warning(
                        "api analysis image falling back to ocr-only response after text analysis failed: %s",
                        text_exc,
                    )
                    analysis = _build_ocr_only_analysis(
                        request_payload=request_payload,
                        normalized_text=normalized_text,
                        source="image",
                    )
                analysis_elapsed = time.perf_counter() - analysis_started_at
            else:
                if not normalized_text.strip():
                    raise
                logger.warning(
                    "api analysis image falling back to ocr-only response after vision analysis failed: %s",
                    exc,
                )
                fallback_to_text = True
                analysis_elapsed = 0.0
                analysis = _build_ocr_only_analysis(
                    request_payload=request_payload,
                    normalized_text=normalized_text,
                    source="image",
                )
        response_payload = analysis.model_dump()
        response_payload["source"] = "image"
        response_payload["ocr"] = OCRResponse(
            raw_text=ocr_result["raw_text"],
            normalized_text=normalized_text,
            blocks=ocr_result.get("blocks", []),
        )
        logger.info(
            "api analysis image image_kb=%.1f ocr=%.2fs analysis=%.2fs fallback_to_text=%s requested_subject_extensions=%s effective_subject_extensions=%s artifacts=%s total=%.2fs",
            len(image_bytes) / 1024,
            ocr_elapsed,
            analysis_elapsed,
            fallback_to_text,
            requested_subject_extensions,
            effective_subject_extensions,
            len(analysis.rich_artifacts),
            time.perf_counter() - started_at,
        )
        return ImageAnalysisResponse(
            **response_payload,
        )
    except VivoAPIError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.post("/analysis/image/jobs", response_model=ImageAnalysisJobResponse)
async def create_analysis_image_job(
    image: UploadFile = File(...),
    subject: str = Form("通用"),
    user_answer: str = Form(""),
    wrong_reason_hint: str = Form(""),
    enable_subject_extensions: bool = Form(True),
    client_job_id: str = Form(""),
) -> ImageAnalysisJobResponse:
    # Two-stage path for batch capture: create a short-lived in-memory job,
    # expose OCR partials quickly, then let the quality model finish detached
    # from the phone's upload connection.
    _ensure_credentials()
    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="上传图片为空。")
    return create_image_analysis_job(
        client_job_id=client_job_id,
        image_bytes=image_bytes,
        filename=image.filename or "",
        content_type=image.content_type or "image/png",
        subject=subject,
        user_answer=user_answer,
        wrong_reason_hint=wrong_reason_hint,
        enable_subject_extensions=enable_subject_extensions,
        diagnostic_service=diagnostic_service,
        vivo_client=vivo_client,
    )


@router.get("/analysis/image/jobs/{job_id}", response_model=ImageAnalysisJobResponse)
def get_analysis_image_job(job_id: str) -> ImageAnalysisJobResponse:
    job = get_image_analysis_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="解析任务不存在。")
    return job


@router.post("/analysis/image/jobs/{job_id}/retry", response_model=ImageAnalysisJobResponse)
def retry_analysis_image_job(job_id: str) -> ImageAnalysisJobResponse:
    _ensure_credentials()
    job = retry_image_analysis_job(
        job_id=job_id,
        diagnostic_service=diagnostic_service,
    )
    if job is None:
        raise HTTPException(status_code=404, detail="解析任务不存在或尚无 OCR 结果。")
    return job


@router.post("/analysis/physics-animation", response_model=PhysicsAnimationResponse)
def generate_physics_animation(request: PhysicsAnimationRequest) -> PhysicsAnimationResponse:
    started_at = time.perf_counter()
    try:
        artifact = diagnostic_service.generate_physics_animation(
            cleaned_question=request.cleaned_question,
            scene_brief=request.scene_brief,
            subject=request.subject,
            knowledge_points=request.knowledge_points,
            solution_summary=request.solution_summary,
            solution_steps=request.solution_steps,
        )
        generated = artifact is not None
        reason = ""
        if not generated:
            reason = diagnostic_service.explain_physics_animation_unavailable(
                cleaned_question=request.cleaned_question,
                scene_brief=request.scene_brief,
                subject=request.subject,
                knowledge_points=request.knowledge_points,
                solution_summary=request.solution_summary,
                solution_steps=request.solution_steps,
            )
        logger.info(
            "api physics animation subject=%s generated=%s elapsed=%.2fs",
            request.subject,
            generated,
            time.perf_counter() - started_at,
        )
        return PhysicsAnimationResponse(
            subject=request.subject,
            artifact=artifact,
            generated=generated,
            reason=reason,
        )
    except VivoAPIError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


def _should_fallback_to_text_analysis(exc: VivoAPIError) -> bool:
    message = str(exc).lower()
    fallback_markers = [
        "status=504",
        "gateway time-out",
        "gateway timeout",
        "read timed out",
        "timed out",
        "connection aborted",
        "connection reset",
        "invalid base64_image_url",
        "\"code\": \"1010\"",
        "\"code\":\"1010\"",
    ]
    return any(marker in message for marker in fallback_markers)


def _build_ocr_only_analysis(
    *,
    request_payload: AnalysisRequest,
    normalized_text: str,
    source: str,
) -> AnalysisResponse:
    cleaned = normalized_text.strip() or request_payload.question_text.strip()
    subject = request_payload.subject if request_payload.subject != "通用" else "未分类"
    excerpt = cleaned[:80]
    return AnalysisResponse(
        question_text=request_payload.question_text,
        cleaned_question=cleaned,
        scene_brief=excerpt,
        subject=subject,
        knowledge_points=["OCR 已识别题干", "AI 深度解析稍后重试"],
        solution_summary="AI 服务暂时响应过慢，已先保存 OCR 识别结果。可以稍后重试自动解析，或先手动整理本题。",
        solution_steps=[
            "已完成图片文字识别，题干内容会保留在错题档案中。",
            "本次深度解析受到上游接口超时影响，暂未生成完整步骤。",
            "稍后点击重试，或使用手动整理补充答案、关键公式和错因。",
        ],
        mistake_diagnosis="本次未完成深度解析，暂不能稳定判断错因。",
        review_plan=ReviewPlan(
            next_review_in_days=1,
            focus="先确认 OCR 题干是否准确，再补充完整解析。",
            schedule=[1, 3, 7],
        ),
        similar_questions=[],
        rich_artifacts=[],
        source=source,  # type: ignore[arg-type]
        raw_model_output="",
    )
