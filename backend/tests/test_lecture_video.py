from __future__ import annotations

import json
import logging
import time
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from ai_engine.llm_logic.lecture_video_chain import LectureVideoService
from backend.app.schemas.card_schema import (
    LectureVideoRequest,
    LectureVideoResponse,
    RichArtifact,
)
from backend.app.services.lecture_video_jobs import (
    create_lecture_video_job,
    get_lecture_video_job,
    retry_lecture_video_job,
)


class _FakeClient:
    def __init__(self, raw_output: str) -> None:
        self.raw_output = raw_output
        self.prompts: list[str] = []
        self.settings = SimpleNamespace(
            vivo_animation_model="Doubao-Seed-2.0-mini",
        )

    def animation_chat_completion(self, prompt: str) -> str:
        self.prompts.append(prompt)
        return self.raw_output


class _FlakyVideoService:
    def __init__(self) -> None:
        self.calls = 0

    def generate_video(self, request: LectureVideoRequest) -> LectureVideoResponse:
        self.calls += 1
        if self.calls == 1:
            raise RuntimeError("temporary failure")
        artifact = RichArtifact(
            artifact_type="manim_job",
            title="一次函数视频讲解",
            description="后台正在生成知识点视频讲解。",
            mime_type="application/json",
            content=json.dumps(
                {
                    "job_id": "manim-video-test",
                    "status": "running",
                    "progress": 42,
                },
                ensure_ascii=False,
            ),
        )
        return LectureVideoResponse(
            title="一次函数视频讲解",
            subject=request.subject,
            topic=request.topic,
            summary="用动画讲清楚一次函数图像。",
            artifact=artifact,
            raw_model_output="{}",
        )


class LectureVideoServiceTest(unittest.TestCase):
    def test_model_output_builds_safe_manim_job(self) -> None:
        raw = json.dumps(
            {
                "title": "函数单调性视频讲解",
                "subject": "数学",
                "topic": "函数单调性",
                "scene_type": "mechanics",
                "summary": "用图像变化讲清楚单调性。",
                "focus_points": ["定义", "图像", "易错边界"],
                "steps": ["先看自变量增加", "再看函数值变化", "最后判断区间"],
                "formula_steps": ["x_1<x_2 \\Rightarrow f(x_1)<f(x_2)"],
            },
            ensure_ascii=False,
        )
        service = LectureVideoService(_FakeClient(raw))

        with patch(
            "ai_engine.llm_logic.lecture_video_chain.create_manim_job",
            return_value={
                "job_id": "job-1",
                "status": "pending",
                "progress": 0,
                "message": "queued",
                "video_url": "",
                "updated_at": 1.0,
                "diagnostics": {},
            },
        ) as create_job:
            response = service.generate_video(
                LectureVideoRequest(
                    prompt="用视频讲一下高中数学函数单调性",
                    subject="数学",
                    topic="函数单调性",
                )
            )

        self.assertEqual("manim_job", response.artifact.artifact_type)
        scene_spec = create_job.call_args.args[0]
        self.assertEqual("generic", scene_spec["scene_type"])
        self.assertEqual("general", scene_spec["subject"])
        self.assertTrue(scene_spec["objects"])
        self.assertIn("不要写 Python", service.client.prompts[0])

    def test_job_create_query_failure_and_retry(self) -> None:
        service = _FlakyVideoService()
        request = LectureVideoRequest(
            prompt="用视频讲一下初中数学一次函数",
            subject="数学",
            topic="一次函数",
            client_job_id=f"video-test-{time.time_ns()}",
        )
        manim_job = {
            "job_id": "manim-video-test",
            "status": "succeeded",
            "progress": 100,
            "video_url": "/static/media/manim/manim-video-test.mp4",
            "message": "ready",
            "error": "",
            "updated_at": time.time(),
            "diagnostics": {"output_path_exists": True},
        }

        logging.disable(logging.CRITICAL)
        try:
            with patch(
                "backend.app.services.lecture_video_jobs.get_manim_job",
                return_value=manim_job,
            ), patch(
                "backend.app.services.lecture_video_jobs.retain_manim_artifacts",
                return_value={"retained": 1, "job_ids": ["manim-video-test"]},
            ):
                created = create_lecture_video_job(request=request, service=service)  # type: ignore[arg-type]
                failed = self._wait_for_status(created.job_id, "failed")
                self.assertEqual("failed", failed.status)

                retried = retry_lecture_video_job(job_id=created.job_id, service=service)  # type: ignore[arg-type]
                self.assertIsNotNone(retried)
                completed = self._wait_for_status(created.job_id, "completed")
        finally:
            logging.disable(logging.NOTSET)

        self.assertEqual("completed", completed.status)
        self.assertIsNotNone(completed.result)
        self.assertEqual("manim_video", completed.result.artifact.artifact_type)

    def _wait_for_status(self, job_id: str, status: str):
        deadline = time.time() + 5
        while time.time() < deadline:
            job = get_lecture_video_job(job_id)
            if job is not None and job.status == status:
                return job
            time.sleep(0.05)
        self.fail(f"job {job_id} did not reach status {status}")


if __name__ == "__main__":
    unittest.main()
