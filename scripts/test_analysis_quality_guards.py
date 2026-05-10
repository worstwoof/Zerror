from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from ai_engine.llm_logic.diagnostic_chain import DiagnosticService
from ai_engine.llm_logic.vivo_client import VivoAPIError
from backend.app.schemas.card_schema import AnalysisRequest, AnalysisResponse, ReviewPlan
from backend.app.services.analysis_jobs import (
    _jobs,
    _friendly_error,
    _run_image_analysis_job,
    analyze_image_with_fallback,
    build_ocr_only_analysis,
    extract_ocr_response,
    should_fallback_to_text_analysis,
)


def test_latex_backslash_repairs_are_conservative() -> None:
    service = object.__new__(DiagnosticService)

    repaired = service._latexize_mixed_text(
        "结合题意有 rac{mv_0}{eB} < a < rac{2mv_0}{eB}，角度 theta 由几何关系确定。"
    )

    assert r"\frac{mv_0}{eB}" in repaired
    assert r"\frac{2mv_0}{eB}" in repaired
    assert r"\theta" in repaired


def test_compact_broken_fraction_is_not_guessed() -> None:
    service = object.__new__(DiagnosticService)

    repaired = service._latexize_mixed_text("模型误写为 racmv_0eB 时不要强行猜分子分母。")

    assert "racmv_0eB" in repaired


def test_background_job_error_messages_are_student_friendly() -> None:
    assert "AI 解析暂时较慢" in _friendly_error(RuntimeError("Read timed out"))
    assert "网络连接中断" in _friendly_error(RuntimeError("connection reset by peer"))


def test_image_analysis_fallback_helpers_are_service_level() -> None:
    assert should_fallback_to_text_analysis(RuntimeError("Read timed out"))
    assert should_fallback_to_text_analysis(RuntimeError('{"code":"1010"}'))
    assert not should_fallback_to_text_analysis(RuntimeError("bad request"))

    result = build_ocr_only_analysis(
        request_payload=AnalysisRequest(question_text="original", subject="通用"),
        normalized_text="normalized text",
        source="image",
    )

    assert result.cleaned_question == "normalized text"
    assert result.source == "image"
    assert result.subject == "未分类"


def test_ocr_extraction_normalizes_text_in_service_layer() -> None:
    result = extract_ocr_response(
        image_bytes=b"image",
        vivo_client=_FakeVivoClient(raw_text="  first line\r\n\r\nsecond line  "),  # type: ignore[arg-type]
    )

    assert result.ocr.raw_text == "  first line\r\n\r\nsecond line  "
    assert result.ocr.normalized_text == "first line\n\nsecond line"
    assert result.ocr.blocks == [{"text": "  first line\r\n\r\nsecond line  "}]
    assert result.ocr_elapsed >= 0


def test_background_image_job_uses_normalized_ocr_text() -> None:
    job_id = "test-normalized-ocr-job"
    raw_text = "  first line\r\n\r\nsecond line  "
    _jobs.clear()
    _jobs[job_id] = {
        "job_id": job_id,
        "status": "pending",
        "progress": 0,
        "message": "",
        "error": "",
        "created_at": 0.0,
        "updated_at": 0.0,
        "ocr": None,
        "result": None,
        "partial_result": None,
    }
    diagnostic_service = _FakeDiagnosticService()

    try:
        _run_image_analysis_job(
            job_id,
            b"image",
            "数学",
            "",
            "",
            True,
            diagnostic_service,  # type: ignore[arg-type]
            _FakeVivoClient(raw_text=raw_text),  # type: ignore[arg-type]
        )

        job = _jobs[job_id]
        assert job["status"] == "completed"
        assert job["ocr"].raw_text == raw_text
        assert job["ocr"].normalized_text == "first line\n\nsecond line"
        assert diagnostic_service.quality_calls == 1
        assert diagnostic_service.quality_requests[0].question_text == "first line\n\nsecond line"
        assert job["partial_result"].ocr.raw_text == raw_text
        assert job["result"].ocr.normalized_text == "first line\n\nsecond line"
    finally:
        _jobs.clear()


class _FakeVivoClient:
    def __init__(self, raw_text: str = "OCR text") -> None:
        self.raw_text = raw_text

    def ocr_image(self, image_bytes: bytes) -> dict[str, object]:
        return {"raw_text": self.raw_text, "blocks": [{"text": self.raw_text}]}


class _FakeDiagnosticService:
    def __init__(
        self,
        *,
        image_error: Exception | None = None,
        text_error: Exception | None = None,
    ) -> None:
        self.image_error = image_error
        self.text_error = text_error
        self.image_calls = 0
        self.text_calls = 0
        self.quality_calls = 0
        self.quality_requests: list[AnalysisRequest] = []

    def analyze_image(
        self,
        request: AnalysisRequest,
        *,
        image_bytes: bytes,
        mime_type: str,
        ocr_draft: str,
    ) -> AnalysisResponse:
        self.image_calls += 1
        if self.image_error is not None:
            raise self.image_error
        return _analysis_response(request, "vision")

    def analyze_text(self, request: AnalysisRequest) -> AnalysisResponse:
        self.text_calls += 1
        if self.text_error is not None:
            raise self.text_error
        return _analysis_response(request, "text")

    def analyze_text_quality(self, request: AnalysisRequest) -> AnalysisResponse:
        self.quality_calls += 1
        self.quality_requests.append(request)
        return _analysis_response(request, "quality")


def _analysis_response(request: AnalysisRequest, marker: str) -> AnalysisResponse:
    return AnalysisResponse(
        question_text=request.question_text,
        cleaned_question=request.question_text,
        scene_brief=marker,
        subject=request.subject,
        knowledge_points=[marker],
        solution_summary=marker,
        solution_steps=[marker],
        mistake_diagnosis="",
        review_plan=ReviewPlan(next_review_in_days=1, focus="", schedule=[1]),
        similar_questions=[],
        rich_artifacts=[],
        source="image",
        raw_model_output=marker,
    )


def test_image_analysis_flow_falls_back_to_text_for_timeout() -> None:
    diagnostic_service = _FakeDiagnosticService(
        image_error=VivoAPIError("Read timed out")
    )

    result = analyze_image_with_fallback(
        image_bytes=b"image",
        content_type="image/png",
        subject="数学",
        user_answer="",
        wrong_reason_hint="",
        enable_subject_extensions=True,
        diagnostic_service=diagnostic_service,  # type: ignore[arg-type]
        vivo_client=_FakeVivoClient(),  # type: ignore[arg-type]
    )

    assert result.fallback_to_text
    assert result.analysis.scene_brief == "text"
    assert result.ocr.normalized_text == "OCR text"
    assert diagnostic_service.image_calls == 1
    assert diagnostic_service.text_calls == 1


def test_image_analysis_flow_uses_ocr_only_when_text_fallback_also_times_out() -> None:
    diagnostic_service = _FakeDiagnosticService(
        image_error=VivoAPIError("Read timed out"),
        text_error=VivoAPIError("gateway timeout"),
    )

    result = analyze_image_with_fallback(
        image_bytes=b"image",
        content_type="image/png",
        subject="通用",
        user_answer="",
        wrong_reason_hint="",
        enable_subject_extensions=True,
        diagnostic_service=diagnostic_service,  # type: ignore[arg-type]
        vivo_client=_FakeVivoClient(),  # type: ignore[arg-type]
    )

    assert result.fallback_to_text
    assert result.analysis.subject == "未分类"
    assert "OCR 已识别题干" in result.analysis.knowledge_points
    assert diagnostic_service.image_calls == 1
    assert diagnostic_service.text_calls == 1


if __name__ == "__main__":
    test_latex_backslash_repairs_are_conservative()
    test_compact_broken_fraction_is_not_guessed()
    test_background_job_error_messages_are_student_friendly()
    test_image_analysis_fallback_helpers_are_service_level()
    test_ocr_extraction_normalizes_text_in_service_layer()
    test_background_image_job_uses_normalized_ocr_text()
    test_image_analysis_flow_falls_back_to_text_for_timeout()
    test_image_analysis_flow_uses_ocr_only_when_text_fallback_also_times_out()
    print("analysis quality guard tests passed")
