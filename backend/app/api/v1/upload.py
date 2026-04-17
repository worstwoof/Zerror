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
    ImageAnalysisResponse,
    OCRResponse,
    PhysicsAnimationRequest,
    PhysicsAnimationResponse,
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
    enable_subject_extensions: bool = Form(False),
) -> ImageAnalysisResponse:
    _ensure_credentials()
    started_at = time.perf_counter()
    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="上传图片为空。")

    try:
        ocr_started_at = time.perf_counter()
        ocr_result = vivo_client.ocr_image(image_bytes)
        ocr_elapsed = time.perf_counter() - ocr_started_at
        normalized_text = normalize_ocr_text(ocr_result["raw_text"])
        request_payload = AnalysisRequest(
            question_text=normalized_text,
            subject=subject,
            user_answer=user_answer,
            wrong_reason_hint=wrong_reason_hint,
            enable_subject_extensions=enable_subject_extensions,
        )
        fallback_to_text = False
        try:
            analysis_started_at = time.perf_counter()
            analysis = diagnostic_service.analyze_image(
                request_payload,
                image_bytes=image_bytes,
                mime_type=image.content_type or "image/png",
                ocr_draft=normalized_text,
            )
            analysis_elapsed = time.perf_counter() - analysis_started_at
        except VivoAPIError as exc:
            # Degrade gracefully when the multimodal request is too slow or unavailable:
            # we already have OCR text, so fall back to the lighter text analysis path.
            if normalized_text.strip() and _should_fallback_to_text_analysis(exc):
                fallback_to_text = True
                analysis_started_at = time.perf_counter()
                analysis = diagnostic_service.analyze_text(
                    AnalysisRequest(
                        question_text=normalized_text,
                        subject=subject,
                        user_answer=user_answer,
                        wrong_reason_hint=wrong_reason_hint,
                        enable_subject_extensions=False,
                    )
                )
                analysis_elapsed = time.perf_counter() - analysis_started_at
            else:
                raise
        response_payload = analysis.model_dump()
        response_payload["source"] = "image"
        response_payload["ocr"] = OCRResponse(
            raw_text=ocr_result["raw_text"],
            normalized_text=normalized_text,
            blocks=ocr_result.get("blocks", []),
        )
        logger.info(
            "api analysis image image_kb=%.1f ocr=%.2fs analysis=%.2fs fallback_to_text=%s total=%.2fs",
            len(image_bytes) / 1024,
            ocr_elapsed,
            analysis_elapsed,
            fallback_to_text,
            time.perf_counter() - started_at,
        )
        return ImageAnalysisResponse(
            **response_payload,
        )
    except VivoAPIError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@router.post("/analysis/physics-animation", response_model=PhysicsAnimationResponse)
def generate_physics_animation(request: PhysicsAnimationRequest) -> PhysicsAnimationResponse:
    _ensure_credentials()
    started_at = time.perf_counter()
    try:
        artifact = diagnostic_service.generate_physics_animation(
            cleaned_question=request.cleaned_question,
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
    ]
    return any(marker in message for marker in fallback_markers)
