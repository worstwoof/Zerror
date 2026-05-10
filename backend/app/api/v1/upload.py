from __future__ import annotations

import logging
import time

from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from ai_engine.llm_logic.diagnostic_chain import DiagnosticService
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
)
from backend.app.services.analysis_jobs import (
    analyze_image_with_fallback,
    create_image_analysis_job,
    extract_ocr_response,
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


async def _read_required_upload_bytes(image: UploadFile) -> bytes:
    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="上传图片为空。")
    return image_bytes


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
    image_bytes = await _read_required_upload_bytes(image)

    try:
        result = extract_ocr_response(
            image_bytes=image_bytes,
            vivo_client=vivo_client,
        )
        logger.info(
            "api ocr extract image_kb=%.1f ocr=%.2fs total=%.2fs",
            len(image_bytes) / 1024,
            result.ocr_elapsed,
            time.perf_counter() - started_at,
        )
        return result.ocr
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
    image_bytes = await _read_required_upload_bytes(image)

    try:
        logger.info(
            "api analysis image upload filename=%s content_type=%s image_kb=%.1f requested_subject_extensions=%s effective_subject_extensions=%s",
            upload_filename,
            upload_content_type or "unknown",
            len(image_bytes) / 1024,
            requested_subject_extensions,
            effective_subject_extensions,
        )
        result = analyze_image_with_fallback(
            image_bytes=image_bytes,
            content_type=upload_content_type or "image/png",
            subject=subject,
            user_answer=user_answer,
            wrong_reason_hint=wrong_reason_hint,
            enable_subject_extensions=effective_subject_extensions,
            diagnostic_service=diagnostic_service,
            vivo_client=vivo_client,
        )
        analysis = result.analysis
        response_payload = analysis.model_dump()
        response_payload["source"] = "image"
        response_payload["ocr"] = result.ocr
        logger.info(
            "api analysis image image_kb=%.1f ocr=%.2fs analysis=%.2fs fallback_to_text=%s requested_subject_extensions=%s effective_subject_extensions=%s artifacts=%s total=%.2fs",
            len(image_bytes) / 1024,
            result.ocr_elapsed,
            result.analysis_elapsed,
            result.fallback_to_text,
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
    image_bytes = await _read_required_upload_bytes(image)
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
