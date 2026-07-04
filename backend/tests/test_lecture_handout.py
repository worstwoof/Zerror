from __future__ import annotations

import json
import logging
import time
import unittest
from types import SimpleNamespace

from ai_engine.llm_logic.lecture_handout_chain import LectureHandoutService
from backend.app.schemas.card_schema import (
    LectureHandoutRequest,
    LectureHandoutResponse,
)
from backend.app.services.lecture_handout_jobs import (
    create_lecture_handout_job,
    get_lecture_handout_job,
    retry_lecture_handout_job,
)


class _FakeClient:
    def __init__(self, raw_output: str) -> None:
        self.raw_output = raw_output
        self.settings = SimpleNamespace(
            vivo_handout_model="Doubao-Seed-2.0-pro",
            vivo_handout_thinking_mode="auto",
            vivo_handout_reasoning_effort="medium",
            vivo_handout_max_tokens=8192,
            vivo_handout_timeout_seconds=240,
        )

    def chat_completion(self, *_args, **_kwargs) -> str:
        return self.raw_output


class _FlakyHandoutService:
    def __init__(self) -> None:
        self.calls = 0

    def generate_handout(self, request: LectureHandoutRequest) -> LectureHandoutResponse:
        self.calls += 1
        if self.calls == 1:
            raise RuntimeError("temporary failure")
        return LectureHandoutResponse(
            title="一次函数知识讲义",
            subtitle="数学 · 知识梳理",
            subject=request.subject,
            topic=request.topic,
            overview="一次函数核心复习。",
            printable_html="<html><body>ok</body></html>",
        )


class LectureHandoutServiceTest(unittest.TestCase):
    def test_model_text_is_escaped_in_printable_html(self) -> None:
        raw = json.dumps(
            {
                "title": "一次函数",
                "subtitle": "初中数学",
                "subject": "数学",
                "topic": "一次函数",
                "overview": "<script>alert(1)</script>",
                "sections": [
                    {
                        "title": "概念",
                        "body": "函数 \\(y=kx+b\\) <script>alert(2)</script>",
                        "bullets": ["k 决定增减性"],
                    }
                ],
                "key_points": ["看 k 与 b"],
                "formula_cards": ["\\(y=kx+b\\)"],
                "method_notes": ["先看 k"],
                "common_traps": ["不要忽略定义域"],
                "recap_checklist": ["能解释 k 的意义"],
            },
            ensure_ascii=False,
        )
        service = LectureHandoutService(_FakeClient(raw))

        response = service.generate_handout(
            LectureHandoutRequest(prompt="整理初中数学一次函数知识点")
        )

        self.assertIn("&lt;script&gt;alert(1)&lt;/script&gt;", response.printable_html)
        self.assertIn("&lt;script&gt;alert(2)&lt;/script&gt;", response.printable_html)
        self.assertNotIn("<script>alert(1)</script>", response.printable_html)
        self.assertNotIn("<script>alert(2)</script>", response.printable_html)

    def test_empty_prompt_is_rejected(self) -> None:
        service = LectureHandoutService(_FakeClient("{}"))

        with self.assertRaises(ValueError):
            service.generate_handout(LectureHandoutRequest(prompt="   "))

    def test_job_create_query_failure_and_retry(self) -> None:
        service = _FlakyHandoutService()
        request = LectureHandoutRequest(
            prompt="整理初中数学一次函数知识点",
            subject="数学",
            topic="一次函数",
            client_job_id=f"handout-test-{time.time_ns()}",
        )

        logging.disable(logging.CRITICAL)
        try:
            created = create_lecture_handout_job(request=request, service=service)  # type: ignore[arg-type]
            failed = self._wait_for_status(created.job_id, "failed")
            self.assertEqual("failed", failed.status)

            retried = retry_lecture_handout_job(job_id=created.job_id, service=service)  # type: ignore[arg-type]
            self.assertIsNotNone(retried)
            completed = self._wait_for_status(created.job_id, "completed")
        finally:
            logging.disable(logging.NOTSET)
        self.assertEqual("completed", completed.status)
        self.assertIsNotNone(completed.result)
        self.assertEqual("一次函数知识讲义", completed.result.title)

    def _wait_for_status(self, job_id: str, status: str):
        deadline = time.time() + 5
        while time.time() < deadline:
            job = get_lecture_handout_job(job_id)
            if job is not None and job.status == status:
                return job
            time.sleep(0.05)
        self.fail(f"job {job_id} did not reach status {status}")


if __name__ == "__main__":
    unittest.main()
