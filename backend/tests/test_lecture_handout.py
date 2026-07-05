from __future__ import annotations

import json
import logging
import time
import unittest
from types import SimpleNamespace

from ai_engine.llm_logic.lecture_handout_chain import LectureHandoutService
from ai_engine.llm_logic.vivo_client import VivoAPIError
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
        self.prompts: list[str] = []
        self.settings = SimpleNamespace(
            vivo_handout_model="Doubao-Seed-2.0-pro",
            vivo_handout_thinking_mode="auto",
            vivo_handout_reasoning_effort="medium",
            vivo_handout_max_tokens=8192,
            vivo_handout_timeout_seconds=360,
            vivo_text_model="Doubao-Seed-2.0-mini",
            vivo_text_thinking_mode="auto",
            vivo_text_reasoning_effort="auto",
        )

    def chat_completion(self, prompt: str, *_args, **_kwargs) -> str:
        self.prompts.append(prompt)
        return self.raw_output


class _TokenFallbackClient:
    def __init__(self, raw_output: str) -> None:
        self.raw_output = raw_output
        self.calls: list[dict] = []
        self.settings = SimpleNamespace(
            vivo_handout_model="Doubao-Seed-2.0-pro",
            vivo_handout_thinking_mode="auto",
            vivo_handout_reasoning_effort="medium",
            vivo_handout_max_tokens=20000,
            vivo_handout_timeout_seconds=360,
            vivo_text_model="Doubao-Seed-2.0-mini",
            vivo_text_thinking_mode="auto",
            vivo_text_reasoning_effort="auto",
        )

    def chat_completion(self, prompt: str, *_args, **kwargs) -> str:
        self.calls.append(kwargs)
        if len(self.calls) == 1:
            raise VivoAPIError("vivo 接口请求失败，status=400，body=max_tokens too large")
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

    def test_textbook_style_route_renders_models_and_examples(self) -> None:
        raw = json.dumps(
            {
                "title": "第 1 章 导数及其应用",
                "subtitle": "导数核心模型实战学案",
                "subject": "数学",
                "topic": "导数单调性",
                "overview": "围绕导数判断单调性、参数范围与极值模型展开。",
                "exam_analysis": "高考常以含参函数、零点与不等式恒成立综合考查。",
                "knowledge_map": ["导函数符号", "单调区间", "参数分类"],
                "sections": [
                    {
                        "title": "1.1 利用导数判断单调区间",
                        "body": "单调性由 \\(f'(x)\\) 的符号决定。",
                        "bullets": ["先求导", "再分区间讨论符号"],
                    }
                ],
                "model_cards": [
                    {
                        "title": "核心模型一：含参导数单调性",
                        "feature": "题目出现含参函数并要求单调区间或参数范围。",
                        "logic": "将单调性转化为 \\(f'(x)\\ge 0\\) 或 \\(f'(x)\\le 0\\)。",
                        "procedure": ["求导并化简", "令导函数为零找临界点", "按参数分类讨论"],
                        "secondary_conclusions": [
                            "二级结论：导函数恒非负等价于最小值非负。",
                            "二级结论：端点和零点重合时优先检查定义域。",
                        ],
                        "examples": [
                            {
                                "title": "例题 1.1 经典母题",
                                "source": "改编题",
                                "stem": "已知 \\(f(x)=e^x-ax\\)，讨论单调性。",
                                "answer": "按 \\(a\\le 0\\) 与 \\(a>0\\) 分类。",
                                "analysis": "关键是观察 \\(f'(x)=e^x-a\\)。",
                                "solution_steps": ["求导", "讨论 \\(e^x-a\\) 的符号"],
                                "notes": ["注意 \\(e^x>0\\)。"],
                            }
                        ],
                        "traps": ["不要忽略参数导致的临界点不存在。"],
                    }
                ],
                "secondary_conclusions": ["若 \\(f'(x)\\) 单调，则最值常在端点取得。"],
                "summary_tables": [
                    {
                        "title": "含参单调性题型表",
                        "headers": ["题型", "识别信号", "处理方法"],
                        "rows": [["恒成立", "\\(f'(x)\\ge0\\)", "转最值"]],
                    }
                ],
                "key_points": ["导数符号决定单调性"],
                "formula_cards": ["\\(f'(x)>0\\Rightarrow f(x)\\) 单调递增"],
                "method_notes": ["求导、找零点、画符号表"],
                "common_traps": ["不要写考场思维还原。"],
                "recap_checklist": ["能独立画导函数符号表"],
            },
            ensure_ascii=False,
        )
        client = _FakeClient(raw)
        service = LectureHandoutService(client)

        response = service.generate_handout(
            LectureHandoutRequest(prompt="整理高中数学导数单调性讲义")
        )

        self.assertIn("内容提要", response.printable_html)
        self.assertIn("核心模型一", response.printable_html)
        self.assertIn("二级结论", response.printable_html)
        self.assertIn("例题精讲", response.printable_html)
        self.assertIn("含参单调性题型表", response.printable_html)
        self.assertIn("不要使用这个标题", client.prompts[0])
        self.assertIn("不要设置页数上限", client.prompts[0])
        self.assertNotIn("<h3>考场思维还原</h3>", response.printable_html)

    def test_empty_prompt_is_rejected(self) -> None:
        service = LectureHandoutService(_FakeClient("{}"))

        with self.assertRaises(ValueError):
            service.generate_handout(LectureHandoutRequest(prompt="   "))

    def test_handout_model_retries_with_safe_token_limit(self) -> None:
        raw = json.dumps(
            {
                "title": "圆锥曲线讲义",
                "subtitle": "数学 · 知识梳理",
                "subject": "数学",
                "topic": "圆锥曲线",
                "overview": "圆锥曲线核心复习。",
            },
            ensure_ascii=False,
        )
        client = _TokenFallbackClient(raw)
        service = LectureHandoutService(client)  # type: ignore[arg-type]

        response = service.generate_handout(
            LectureHandoutRequest(prompt="生成圆锥曲线讲义")
        )

        self.assertEqual("圆锥曲线讲义", response.title)
        self.assertEqual(2, len(client.calls))
        self.assertEqual(20000, client.calls[0]["max_tokens"])
        self.assertEqual(8192, client.calls[1]["max_tokens"])
        self.assertEqual(client.calls[0]["model_name"], client.calls[1]["model_name"])

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
