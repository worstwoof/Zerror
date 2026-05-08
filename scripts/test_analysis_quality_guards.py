from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from ai_engine.llm_logic.diagnostic_chain import DiagnosticService
from backend.app.services.analysis_jobs import _friendly_error


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


if __name__ == "__main__":
    test_latex_backslash_repairs_are_conservative()
    test_compact_broken_fraction_is_not_guessed()
    test_background_job_error_messages_are_student_friendly()
    print("analysis quality guard tests passed")
