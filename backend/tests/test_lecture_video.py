from __future__ import annotations

import json
import logging
import tempfile
import time
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from ai_engine.llm_logic.diagnostic_chain import DiagnosticService
from ai_engine.llm_logic.lecture_video_chain import LectureVideoService
from backend.app.rendering import tts_provider
from backend.app.rendering.manim_renderer import (
    _safe_scene_spec,
    add_background_music,
)
from backend.app.rendering.tts_provider import TtsSynthesisResult
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
            vivo_animation_model="Doubao-Seed-2.0-pro",
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
        self.assertEqual("function_graph", scene_spec["scene_type"])
        self.assertEqual("math", scene_spec["subject"])
        self.assertTrue(scene_spec["objects"])
        self.assertGreaterEqual(len(scene_spec["steps"]), 8)
        self.assertGreaterEqual(len(scene_spec["teaching_stages"]), 8)
        self.assertGreaterEqual(scene_spec["parameters"]["target_duration_seconds"], 150)
        self.assertLessEqual(scene_spec["parameters"]["target_duration_seconds"], 240)
        self.assertTrue(scene_spec["audio"]["voiceover"])
        self.assertTrue(scene_spec["audio"]["voiceover_required"])
        self.assertTrue(scene_spec["audio"]["narration_outline"])
        self.assertTrue(scene_spec["teaching_stages"][0]["visual_transform"])
        self.assertIn("不要写 Python", service.client.prompts[0])
        self.assertIn("teaching_stages", service.client.prompts[0])
        self.assertIn("visual_transform", service.client.prompts[0])
        self.assertIn("讲解语音", service.client.prompts[0])
        self.assertIn("8 到 12", service.client.prompts[0])
        self.assertIn("function_graph/conic/geometry", service.client.prompts[0])

    def test_audio_diagnostics_report_missing_voiceover_config(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            video_path = Path(temporary_dir) / "lesson.mp4"
            video_path.write_bytes(b"not a real video")
            with patch("backend.app.rendering.manim_renderer.shutil.which", return_value=None), patch(
                "backend.app.rendering.manim_renderer.settings",
                SimpleNamespace(
                    piper_tts_command="",
                    piper_voice_model="",
                    piper_voice_config="",
                    background_music_path="",
                ),
            ), patch(
                "backend.app.rendering.tts_provider.settings",
                self._tts_settings(),
            ), patch.dict(
                "os.environ",
                {
                    "PIPER_TTS_COMMAND": "",
                    "PIPER_COMMAND": "",
                    "PIPER_VOICE_MODEL": "",
                    "ZERROR_PIPER_VOICE_MODEL": "",
                    "ZERROR_TTS_PROVIDER": "",
                    "ZERROR_TTS_SERVICE_URL": "",
                    "ZERROR_TTS_FALLBACK_PROVIDER": "",
                },
                clear=False,
            ):
                diagnostics = add_background_music(
                    video_path,
                    scene_spec={
                        "background_music": True,
                        "audio": {"voiceover": True},
                    },
                )

        self.assertTrue(diagnostics["background_music_requested"])
        self.assertTrue(diagnostics["voiceover_requested"])
        self.assertEqual("none", diagnostics["background_music_source"])
        self.assertFalse(diagnostics["background_music_file_configured"])
        self.assertFalse(diagnostics["voiceover_configured"])
        self.assertFalse(diagnostics["voiceover_generated"])
        self.assertFalse(diagnostics["background_music_added"])

    def test_required_voiceover_records_missing_natural_tts_without_failing(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            video_path = Path(temporary_dir) / "lesson.mp4"
            video_path.write_bytes(b"not a real video")
            with patch("backend.app.rendering.manim_renderer.shutil.which", return_value="ffmpeg"), patch(
                "backend.app.rendering.manim_renderer.settings",
                SimpleNamespace(background_music_path=""),
            ), patch(
                "backend.app.rendering.tts_provider.settings",
                self._tts_settings(tts_fallback_provider="none"),
            ), patch.dict("os.environ", self._empty_tts_env(), clear=False):
                diagnostics = add_background_music(
                    video_path,
                    scene_spec={
                        "background_music": True,
                        "audio": {
                            "voiceover": True,
                            "voiceover_required": True,
                            "narration_outline": ["这一步需要自然语音讲解。"],
                        },
                    },
                )

        self.assertTrue(diagnostics["voiceover_required"])
        self.assertFalse(diagnostics["voiceover_generated"])
        self.assertEqual("TTS service URL is not configured.", diagnostics["voiceover_error"])

    def test_manim_formula_steps_normalize_unicode_math_for_latex(self) -> None:
        safe = _safe_scene_spec(
            {
                "formula_steps": [
                    "h₂=m/qB√(2qBv₁d/m)=√(2mdv₁/qB)",
                    "v²≤x×y",
                ],
            }
        )

        formulas = safe["formula_steps"]
        joined = " ".join(formulas)
        self.assertNotIn("√", joined)
        self.assertNotIn("₁", joined)
        self.assertNotIn("₂", joined)
        self.assertIn(r"\sqrt{2qBv_{1}d/m}", joined)
        self.assertIn(r"h_{2}", joined)
        self.assertIn(r"v^{2}", joined)
        self.assertIn(r"\le", joined)
        self.assertIn(r"\times", joined)

    def test_cosyvoice_http_provider_chunks_and_succeeds(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            video_path = Path(temporary_dir) / "lesson.mp4"
            video_path.write_bytes(b"video")

            def fake_http_chunk(**kwargs: object) -> None:
                output_path = kwargs["output_path"]
                assert isinstance(output_path, Path)
                output_path.write_bytes(b"wav")

            def fake_combine(chunks: list[Path], output_path: Path) -> bool:
                self.assertGreater(len(chunks), 1)
                output_path.write_bytes(b"combined")
                return True

            with patch(
                "backend.app.rendering.tts_provider.settings",
                self._tts_settings(
                    tts_provider="cosyvoice_http",
                    tts_service_url="http://tts.local:7861",
                ),
            ), patch(
                "backend.app.rendering.tts_provider._http_tts_chunk",
                side_effect=fake_http_chunk,
            ), patch(
                "backend.app.rendering.tts_provider._combine_audio_chunks",
                side_effect=fake_combine,
            ), patch.dict("os.environ", self._empty_tts_env(), clear=False):
                result = tts_provider.synthesize_voiceover(
                    video_path,
                    text="函数图像先向右移动，再观察切线斜率变化。" * 18,
                )

            self.assertEqual("cosyvoice_http", result.provider)
            self.assertFalse(result.fallback_used)
            self.assertGreater(result.chunk_count, 1)
            self.assertTrue(result.path and result.path.exists())

    def test_cosyvoice_http_timeout_falls_back_to_piper(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            video_path = Path(temporary_dir) / "lesson.mp4"
            video_path.write_bytes(b"video")

            def fake_piper(path: Path, *, text: str) -> TtsSynthesisResult:
                output_path = path.with_name(f"{path.stem}.voice.wav")
                output_path.write_bytes(b"piper")
                return TtsSynthesisResult(
                    path=output_path,
                    provider="piper",
                    fallback_used=False,
                    chunk_count=1,
                    voice="teacher_female_clear",
                    elapsed_seconds=0,
                )

            with patch(
                "backend.app.rendering.tts_provider.settings",
                self._tts_settings(
                    tts_provider="cosyvoice_http",
                    tts_service_url="http://tts.local:7861",
                    tts_fallback_provider="piper",
                ),
            ), patch(
                "backend.app.rendering.tts_provider._http_tts_chunk",
                side_effect=TimeoutError("timeout"),
            ), patch(
                "backend.app.rendering.tts_provider._synthesize_piper_voiceover",
                side_effect=fake_piper,
            ), patch.dict("os.environ", self._empty_tts_env(), clear=False):
                result = tts_provider.synthesize_voiceover(video_path, text="讲解一段知识点。")

            self.assertEqual("piper", result.provider)
            self.assertTrue(result.fallback_used)
            self.assertEqual(1, result.chunk_count)
            self.assertTrue(result.path and result.path.exists())

    def test_cosyvoice_http_timeout_does_not_use_piper_when_fallback_disabled(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_dir:
            video_path = Path(temporary_dir) / "lesson.mp4"
            video_path.write_bytes(b"video")

            with patch(
                "backend.app.rendering.tts_provider.settings",
                self._tts_settings(
                    tts_provider="cosyvoice_http",
                    tts_service_url="http://tts.local:7861",
                    tts_fallback_provider="none",
                ),
            ), patch(
                "backend.app.rendering.tts_provider._http_tts_chunk",
                side_effect=TimeoutError("timeout"),
            ), patch(
                "backend.app.rendering.tts_provider._synthesize_piper_voiceover",
            ) as piper, patch.dict("os.environ", self._empty_tts_env(), clear=False):
                result = tts_provider.synthesize_voiceover(video_path, text="讲解一段知识点。")

            self.assertEqual("cosyvoice_http", result.provider)
            self.assertFalse(result.fallback_used)
            self.assertIsNone(result.path)
            piper.assert_not_called()

    def test_physics_manim_scene_requests_natural_voiceover(self) -> None:
        service = DiagnosticService(_FakeClient("{}"))  # type: ignore[arg-type]

        scene_spec = service._build_physics_manim_scene_spec(
            cleaned_question="长木板放在光滑平台上，物块在木板上表面，细线绕过定滑轮。",
            scene_brief="木板和物块组成板块模型，物块受到水平拉力。",
            knowledge_points=["牛顿第二定律", "板块模型动力学"],
            solution_summary="先判断相对滑动，再分别列牛顿第二定律。",
            solution_steps=[
                "第(1)问：对木板和物块分别受力分析，判断静摩擦力是否足够。",
                "第(2)问：相对位移等于板长，列位移公式求时间。",
            ],
        )

        self.assertTrue(scene_spec["audio"]["voiceover"])
        self.assertTrue(scene_spec["audio"]["voiceover_required"])
        self.assertTrue(scene_spec["audio"]["narration_outline"])
        self.assertIn("木板", " ".join(scene_spec["audio"]["narration_outline"]))

    def test_math_conic_request_routes_to_math_conic_scene(self) -> None:
        raw = json.dumps(
            {
                "title": "椭圆离心率视频讲解",
                "subject": "数学",
                "topic": "椭圆离心率",
                "scene_type": "generic",
                "summary": "用动画讲清楚 e=c/a 和椭圆扁圆变化。",
                "focus_points": ["核心定义", "焦点距离", "二级结论"],
                "steps": ["先画椭圆和焦点", "再看动点距离变化", "最后比较离心率大小"],
                "formula_steps": ["e=\\frac{c}{a}", "0<e<1"],
            },
            ensure_ascii=False,
        )
        service = LectureVideoService(_FakeClient(raw))

        with patch(
            "ai_engine.llm_logic.lecture_video_chain.create_manim_job",
            return_value={
                "job_id": "job-conic",
                "status": "pending",
                "progress": 0,
                "message": "queued",
                "video_url": "",
                "updated_at": 1.0,
                "diagnostics": {},
            },
        ) as create_job:
            service.generate_video(
                LectureVideoRequest(
                    prompt="用视频讲一下高中数学椭圆离心率核心定义",
                    subject="数学",
                    topic="椭圆离心率",
                )
            )

        scene_spec = create_job.call_args.args[0]
        self.assertEqual("math", scene_spec["subject"])
        self.assertEqual("conic", scene_spec["scene_type"])
        self.assertGreaterEqual(len(scene_spec["teaching_stages"]), 8)

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

    def _tts_settings(self, **overrides: object) -> SimpleNamespace:
        values = {
            "piper_tts_command": "",
            "piper_voice_model": "",
            "piper_voice_config": "",
            "tts_provider": "cosyvoice_http",
            "tts_service_url": "",
            "tts_api_key": "",
            "tts_voice": "teacher_female_clear",
            "tts_timeout_seconds": 300,
            "tts_fallback_provider": "piper",
        }
        values.update(overrides)
        return SimpleNamespace(**values)

    def _empty_tts_env(self) -> dict[str, str]:
        return {
            "ZERROR_TTS_PROVIDER": "",
            "ZERROR_TTS_SERVICE_URL": "",
            "ZERROR_TTS_API_KEY": "",
            "ZERROR_TTS_VOICE": "",
            "ZERROR_TTS_TIMEOUT_SECONDS": "",
            "ZERROR_TTS_FALLBACK_PROVIDER": "",
            "PIPER_TTS_COMMAND": "",
            "PIPER_COMMAND": "",
            "PIPER_VOICE_MODEL": "",
            "ZERROR_PIPER_VOICE_MODEL": "",
        }


if __name__ == "__main__":
    unittest.main()
