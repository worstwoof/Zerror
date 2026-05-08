from __future__ import annotations

import mimetypes
import json
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from backend.app.rendering.geogebra_renderer import build_geogebra_scene
from backend.app.rendering.manim_renderer import ManimUnavailable
from backend.app.services import manimcat_client
from backend.app.services import render_jobs
from ai_engine.llm_logic.diagnostic_chain import DiagnosticService


class RenderDiagnosticsTest(unittest.TestCase):
    def setUp(self) -> None:
        render_jobs._jobs.clear()
        render_jobs._cache.clear()
        render_jobs._renderer_available_cache = True

    def test_geogebra_magnetic_particle_scene_has_commands_and_variants(self) -> None:
        scene = {
            "scene_type": "charged_particle_magnetic_field",
            "subject": "物理",
            "parameters": {"a": 4, "b": 10, "L": 3},
            "objects": [
                {"type": "point", "id": "P", "x": 0, "y": 4},
                {"type": "point", "id": "Q", "x": 10, "y": 0},
            ],
            "scene_variants": [
                {"id": "case_1", "title": "情形一", "left_boundary_x": "b - L"},
                {"id": "case_2", "title": "情形二", "left_boundary_x": "b - L/2"},
            ],
        }

        payload = build_geogebra_scene(scene)

        self.assertTrue(payload["commands"])
        self.assertEqual(len(payload["scene_variants"]), 2)
        self.assertTrue(payload["metadata"]["valid"])
        commands = "\n".join(payload["commands"])
        self.assertIn("a = Slider", commands)
        self.assertIn("b = Slider", commands)
        self.assertIn("L = Slider", commands)

    def test_geogebra_magnetic_particle_variants_avoid_inline_point_arguments(self) -> None:
        scene = {
            "scene_type": "charged_particle_magnetic_field",
            "subject": "物理",
            "parameters": {"a": 4, "b": 10, "L": 3},
            "objects": [
                {"type": "point", "id": "P", "x": 0, "y": 4},
                {"type": "point", "id": "Q", "x": 10, "y": 0},
            ],
            "scene_variants": [
                {"id": "case_1", "title": "甲", "left_boundary_x": "b - L"},
                {"id": "case_2", "title": "乙", "left_boundary_x": "b - L/2"},
            ],
        }

        payload = build_geogebra_scene(scene)
        commands = "\n".join(
            command
            for variant in payload["scene_variants"]
            for command in variant["commands"]
        )

        self.assertNotRegex(commands, r"Vector\([^,\n]+,\s*\(")
        self.assertNotRegex(commands, r"Segment\([^,\n]+,\s*\(")
        self.assertNotRegex(commands, r"Segment\(\s*\(")

    def test_geogebra_newton_second_law_scene_has_mechanics_commands(self) -> None:
        service = object.__new__(DiagnosticService)
        scene = service._build_physics_scene_spec(
            combined_context="物理 牛顿第二定律 F=ma 合力 加速度 质量 水平面运动",
            scene_brief="物体在水平面上受恒定合力作用",
            knowledge_points=["牛顿第二定律"],
            solution_summary="合力越大加速度越大，质量越大加速度越小。",
        )

        payload = build_geogebra_scene(scene)
        commands = "\n".join(payload["commands"])

        self.assertTrue(payload["commands"])
        self.assertEqual(scene["render_targets"], ["geogebra"])
        self.assertIn("F = Slider", commands)
        self.assertIn("m = Slider", commands)
        self.assertIn("F = ma", commands)
        self.assertIn("a = F / m", commands)
        self.assertTrue(payload["metadata"]["valid"])

    def test_math_ellipse_focus_chord_scene_has_full_geogebra_commands(self) -> None:
        service = object.__new__(DiagnosticService)
        scene = service._build_math_scene_spec(
            "椭圆 x^2/a^2 + y^2/b^2 = 1(a>b>0) 的一个焦点是 F(1,0)，"
            "O 是坐标原点。过点 F 的直线 l 交椭圆于 A、B 两点，"
            "若 |OA|^2 + |OB|^2 < |AB|^2，求 a 的取值范围。"
        )

        payload = build_geogebra_scene(scene)
        commands = "\n".join(payload["commands"])

        self.assertEqual(scene["scene_type"], "conic")
        self.assertIn("椭圆焦点弦", scene["title"])
        self.assertIn("a = Slider", commands)
        self.assertIn("m = Slider", commands)
        self.assertIn("C: x^2 / a^2 + y^2 / b^2 = 1", commands)
        self.assertIn("l: y = m * (x - 1)", commands)
        self.assertIn("A = Intersect(C, l, 1)", commands)
        self.assertIn("B = Intersect(C, l, 2)", commands)
        self.assertIn("tri = Polygon(O, A, B)", commands)
        self.assertTrue(payload["metadata"]["valid"])

    def test_math_ellipse_focus_chord_template_overrides_weak_model_scene(self) -> None:
        service = object.__new__(DiagnosticService)
        artifacts = service._build_structured_render_artifacts(
            subject="math",
            cleaned_question=(
                "椭圆 x^2/a^2 + y^2/b^2 = 1 的一个焦点是 F(1,0)，"
                "过点 F 的直线 l 交椭圆于 A、B 两点，且含 |OA|、|OB|、|AB|。"
            ),
            scene_brief="",
            knowledge_points=[],
            solution_summary="",
            solution_steps=[],
            existing_artifacts=[],
            model_scene_spec={
                "subject": "math",
                "scene_type": "geometry",
                "objects": [{"type": "point", "id": "F", "x": 1, "y": 0}],
                "render_targets": ["geogebra"],
            },
        )

        geogebra_artifact = next(
            artifact for artifact in artifacts if artifact.artifact_type == "geogebra_scene"
        )
        payload = json.loads(geogebra_artifact.content)
        commands = "\n".join(payload["commands"])
        self.assertIn("C: x^2 / a^2 + y^2 / b^2 = 1", commands)
        self.assertIn("A = Intersect(C, l, 1)", commands)
        self.assertIn("B = Intersect(C, l, 2)", commands)
        self.assertNotEqual(payload["metadata"]["object_count"], 1)

    def test_frontend_physics_card_uses_algodoo_artifacts(self) -> None:
        source = (ROOT / "frontend" / "lib" / "screen" / "capture" / "error_edit_screen.dart").read_text(
            encoding="utf-8"
        )

        self.assertIn("bool _hasAlgodooArtifact()", source)
        self.assertIn("int _findAlgodooArtifactIndex()", source)
        self.assertIn("void _upsertAlgodooArtifact", source)
        self.assertIn("_buildLocalAlgodooFallbackArtifact", source)
        self.assertIn("HtmlArtifactPreviewScreen", source)
        self.assertIn("Algodoo", source)
        self.assertIn("htmlContent", source)
        self.assertNotIn("_findPhysicsAnimationArtifactIndex", source)

    def test_backend_physics_animation_prefers_algodoo_html(self) -> None:
        source = (ROOT / "ai_engine" / "llm_logic" / "diagnostic_chain.py").read_text(
            encoding="utf-8"
        )
        method_start = source.index("def generate_physics_animation(")
        method_end = source.index("def _generate_geogebra_scene_artifact", method_start)
        method_source = source[method_start:method_end]

        self.assertIn("_build_electromagnetism_template_artifact", method_source)
        self.assertIn("_build_physics_template_artifact", method_source)
        self.assertIn("Algodoo", method_source)
        self.assertIn("algodoo-style html scene", method_source)

    def test_geogebra_preview_hides_editor_chrome(self) -> None:
        source = (ROOT / "frontend" / "lib" / "screen" / "capture" / "geogebra_scene_preview_screen.dart").read_text(
            encoding="utf-8"
        )

        self.assertIn("showToolBar: false", source)
        self.assertIn("showAlgebraInput: false", source)
        self.assertIn("showMenuBar: false", source)
        self.assertIn("perspective: 'G'", source)
        self.assertIn("customToolBar: ''", source)
        self.assertIn("api.setAxesVisible(false, false)", source)
        self.assertIn("_buildElectromagnetismDemoHtml", source)
        self.assertIn("electromagnetism_svg_demo", source)
        self.assertIn('id="R" type="range"', source)

    def test_physics_animation_endpoint_does_not_require_vivo_credentials(self) -> None:
        source = (ROOT / "backend" / "app" / "api" / "v1" / "upload.py").read_text(
            encoding="utf-8"
        )
        endpoint_start = source.index('def generate_physics_animation(')
        endpoint_end = source.index('def _should_fallback_to_text_analysis', endpoint_start)
        endpoint_source = source[endpoint_start:endpoint_end]

        self.assertNotIn("_ensure_credentials()", endpoint_source)

    def test_manim_success_and_cached_jobs_include_diagnostics(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            media_root = Path(temp_dir)

            def fake_render(*, scene_spec, job_id, output_dir):
                output = output_dir / f"{job_id}.mp4"
                output.write_bytes(b"fake mp4")
                return output

            with patch.object(render_jobs, "MEDIA_ROOT", media_root), patch.object(
                render_jobs,
                "render_manim_video",
                side_effect=fake_render,
            ):
                scene = {"scene_type": "generic", "objects": [{"type": "point", "id": "P"}]}
                job = render_jobs.create_manim_job(scene)
                completed = self._wait_for_job(job["job_id"])

                self.assertEqual(completed["status"], "succeeded")
                self.assertGreater(completed["diagnostics"]["file_size_bytes"], 0)
                self.assertTrue(completed["diagnostics"]["output_path_exists"])

                cached = render_jobs.create_manim_job(scene)
                self.assertEqual(cached["status"], "succeeded")
                self.assertIn("diagnostics", cached)
                self.assertTrue(cached["diagnostics"]["output_path_exists"])

    def test_manim_failed_job_includes_diagnostics(self) -> None:
        with patch.object(
            render_jobs,
            "render_manim_video",
            side_effect=ManimUnavailable("Manim missing"),
        ):
            job = render_jobs.create_manim_job({"scene_type": "generic", "objects": []})
            completed = self._wait_for_job(job["job_id"])

        self.assertEqual(completed["status"], "failed")
        self.assertIn("diagnostics", completed)
        self.assertFalse(completed["diagnostics"]["output_path_exists"])
        self.assertIn("Manim missing", completed["diagnostics"]["error_summary"])

    def test_math_manim_requires_manimcat_without_local_fallback(self) -> None:
        with patch.object(
            render_jobs,
            "render_math_video_with_manimcat",
            side_effect=render_jobs.ManimCatUnavailable("ManimCat missing"),
        ) as manimcat_render, patch.object(render_jobs, "render_manim_video") as local_render:
            job = render_jobs.create_manim_job(
                {
                    "subject": "math",
                    "scene_type": "function_graph",
                    "parameters": {"question_excerpt": "y=x^2"},
                }
            )
            completed = self._wait_for_job(job["job_id"])

        self.assertEqual(completed["status"], "failed")
        self.assertIn("ManimCat missing", completed["diagnostics"]["error_summary"])
        manimcat_render.assert_called_once()
        local_render.assert_not_called()

    def test_manimcat_cache_key_includes_math_problem_identity(self) -> None:
        base_scene = {
            "subject": "math",
            "scene_type": "function_graph",
            "title": "Function graph",
            "fallback_text": "Use Manim to explain the graph.",
        }
        first = {
            **base_scene,
            "parameters": {"question_excerpt": "Find the vertex of y=x^2-2x+1."},
            "steps": ["Complete the square."],
        }
        second = {
            **base_scene,
            "parameters": {"question_excerpt": "Find the zeros of y=x^2-4."},
            "steps": ["Factor the polynomial."],
        }

        self.assertNotEqual(
            manimcat_client._render_cache_key(first),
            manimcat_client._render_cache_key(second),
        )

    def test_mp4_mime_type_is_registered(self) -> None:
        main_source = (ROOT / "backend" / "app" / "main.py").read_text(encoding="utf-8")
        self.assertIn('mimetypes.add_type("video/mp4", ".mp4")', main_source)
        mimetypes.add_type("video/mp4", ".mp4")
        self.assertEqual(mimetypes.guess_type("demo.mp4")[0], "video/mp4")

    def _wait_for_job(self, job_id: str) -> dict:
        deadline = time.time() + 5
        while time.time() < deadline:
            job = render_jobs.get_manim_job(job_id)
            if job and job["status"] in {"succeeded", "failed"}:
                return job
            time.sleep(0.05)
        self.fail(f"job {job_id} did not finish")


if __name__ == "__main__":
    unittest.main()
