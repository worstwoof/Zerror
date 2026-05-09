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
from backend.app.rendering.manim_renderer import ManimUnavailable, build_manim_script
from backend.app.services import manimcat_client
from backend.app.services import render_jobs
from ai_engine.llm_logic.diagnostic_chain import DiagnosticService


class RenderDiagnosticsTest(unittest.TestCase):
    def setUp(self) -> None:
        render_jobs._jobs.clear()
        render_jobs._renderer_available_cache = True
        self._jobs_temp_dir = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.addCleanup(self._jobs_temp_dir.cleanup)
        render_jobs.JOBS_ROOT = Path(self._jobs_temp_dir.name)

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

    def test_math_apollonius_locus_creates_manim_job_over_text_fallback(self) -> None:
        service = object.__new__(DiagnosticService)
        with patch(
            "ai_engine.llm_logic.diagnostic_chain.create_manim_job",
            return_value={
                "job_id": "job-apollonius",
                "status": "pending",
                "progress": 0,
                "message": "queued",
                "error": "",
                "diagnostics": {},
            },
        ):
            artifacts = service._build_structured_render_artifacts(
                subject="math",
                cleaned_question=(
                    "已知直角坐标平面上点 Q(2,0) 和圆 C:x²+y²=1，"
                    "动点 M 到圆 C 的切线长与 |MQ| 的比为 λ，求 M 的轨迹方程。"
                ),
                scene_brief="",
                knowledge_points=["阿波罗尼斯圆", "圆的切线长公式", "轨迹方程"],
                solution_summary="利用圆的切线长公式和两点距离公式建立方程。",
                solution_steps=[],
                existing_artifacts=[],
                model_scene_spec={
                    "subject": "math",
                    "scene_type": "generic",
                    "objects": [],
                    "relations": [],
                    "render_targets": [],
                    "fallback_text": "This question is not structured enough for a reliable graph yet.",
                },
            )

        artifact_types = {artifact.artifact_type for artifact in artifacts}
        self.assertIn("manim_job", artifact_types)
        self.assertNotIn("text_explanation", artifact_types)

    def test_frontend_physics_card_uses_manim_artifacts(self) -> None:
        source = (ROOT / "frontend" / "lib" / "screen" / "capture" / "error_edit_screen.dart").read_text(
            encoding="utf-8"
        )

        self.assertIn("bool _hasManimPhysicsArtifact()", source)
        self.assertIn("int _findManimPhysicsArtifactIndex()", source)
        self.assertIn("void _upsertManimPhysicsArtifact", source)
        self.assertIn("ManimVideoPreviewScreen", source)
        self.assertIn("manim_job", source)
        self.assertIn("manim_video", source)
        self.assertNotIn("_findAlgodooArtifactIndex", source)

    def test_backend_physics_animation_prefers_manim_video_jobs(self) -> None:
        source = (ROOT / "ai_engine" / "llm_logic" / "diagnostic_chain.py").read_text(
            encoding="utf-8"
        )
        method_start = source.index("def generate_physics_animation(")
        method_end = source.index("def _generate_geogebra_scene_artifact", method_start)
        method_source = source[method_start:method_end]

        self.assertIn("_build_physics_manim_artifact", method_source)
        self.assertIn("create_manim_job", method_source)
        self.assertIn("manim_job", method_source)
        self.assertIn("Manim", method_source)

    def test_local_manim_renderer_loads_manim_physics_extension(self) -> None:
        source = (ROOT / "backend" / "app" / "rendering" / "manim_renderer.py").read_text(
            encoding="utf-8"
        )

        self.assertIn("from manim_physics import *", source)
        self.assertIn("HAS_MANIM_PHYSICS", source)
        self.assertIn("ElectricField", source)
        self.assertIn("MagneticField", source)
        self.assertIn("StandingWave", source)

    def test_physics_manim_uses_blackboard_layout(self) -> None:
        source = (ROOT / "backend" / "app" / "rendering" / "manim_renderer.py").read_text(
            encoding="utf-8"
        )

        self.assertIn("_draw_professional_physics_scene", source)
        self.assertIn("_build_board_block_teaching_model", source)
        self.assertIn("_professional_scene_type", source)
        self.assertNotIn("第一阶段：全局物理过程预览", source)
        self.assertNotIn("第二阶段：分段拆解与数学推导", source)
        self.assertIn("start_ghost", source)
        self.assertIn("TracedPath", source)
        self.assertIn("chips.arrange(RIGHT", source)
        self.assertIn("question_source = \" \".join", source)
        self.assertIn("header_font_size = 15", source)
        self.assertIn('title = cjk_text("原题", font_size=header_font_size', source)
        self.assertNotIn("max_question_chars", source)
        self.assertIn("question_line_chars = 66", source)
        self.assertIn("question_lines = [question_source[i:i + question_line_chars]", source)
        self.assertIn("question_row = VGroup(title, question_body)", source)
        self.assertIn("meta_row = VGroup(known_label, chips, goal_label, goal_text)", source)
        self.assertIn('known_label = cjk_text("已知", font_size=header_font_size', source)
        self.assertIn('goal_label = cjk_text("目标", font_size=header_font_size', source)
        self.assertIn('goal_text = cjk_text("受力与加速度 · 共速时刻 · 相对位移", font_size=header_font_size', source)
        self.assertIn("content = VGroup(question_row, meta_row)", source)
        self.assertNotIn("story_panel.scale_to_fit_width", source)
        self.assertNotIn("known_panel = VGroup", source)
        self.assertNotIn("goal_panel = VGroup", source)
        self.assertIn("RoundedRectangle(width=13.15", source)
        self.assertIn("group.to_edge(UP", source)
        self.assertIn("derivation_left = 1.05", source)
        self.assertIn("derivation_top = 1.72", source)
        self.assertNotIn("题目区", source)
        self.assertIn("RoundedRectangle", source)
        self.assertIn("fill_opacity=0.82", source)
        self.assertIn("there_and_back", source)
        self.assertIn("width=5.25", source)
        self.assertIn("board.move_to(LEFT * 3.35 + DOWN * 1.08)", source)
        self.assertIn("force_arrow_centered = Arrow(block_final_center, block_final_center + RIGHT * 1.28", source)
        self.assertIn("f_on_b = Arrow(block_final_center, block_final_center + RIGHT * 0.90", source)
        self.assertIn("n_arrow = Arrow(block_final_center", source)
        self.assertIn("g_arrow = Arrow(block_final_center", source)
        self.assertIn('MathTex("m_B g", color=BLUE_B).scale(0.54).move_to(g_arrow.get_center() + RIGHT * 0.62', source)
        self.assertIn('"initial_vectors": VGroup(v_arrow, v_label, force_arrow, force_label)', source)
        self.assertIn('FadeOut(model["initial_vectors"])', source)
        self.assertIn('model["board_group"].animate.shift(LEFT * 0.34)', source)
        self.assertIn('model["block_group"].animate.shift(LEFT * 0.92)', source)
        self.assertIn("_play_local_response", source)
        self.assertIn("_play_derivation_sequence", source)
        self.assertIn("_build_derivation_parts", source)
        self.assertIn("_formula_lines_group", source)
        self.assertIn("_aligned_formula_block", source)
        self.assertIn("_clean_formula_items(formulas, limit=7)", source)
        self.assertIn("for formula_line in formula_lines", source)
        self.assertIn("FadeIn(formula_line", source)
        self.assertIn("Indicate(formula_line", source)
        self.assertNotIn("FadeIn(derivation, shift=LEFT", source)
        self.assertIn("FadeOut(derivation", source)
        self.assertNotIn("@ Zerror", source)
        self.assertIn("self.camera.background_color = BLACK", source)
        self.assertIn(r"f=\\mu m_Bg", source)
        self.assertIn(r'R=\\frac{{mv_0}}{{qB}}', source)

    def test_board_block_manim_uses_extracted_force_and_mu(self) -> None:
        question = (
            "如图所示，光滑水平面上有长木板 A，物块 B 放在木板 A 的右端。"
            "m1=4kg，m2=2kg，v0=12m/s，对 B 施加 F=12N 水平向右恒力，"
            "A、B 间动摩擦因数 μ=0.4。"
        )
        script = build_manim_script(
            {
                "subject": "physics",
                "scene_type": "board_block",
                "fallback_text": question,
                "parameters": {"question_excerpt": question},
                "formula_steps": [r"f=m_2g", r"F=ma", r"x=x_0+v_0t+\frac12at^2"],
            }
        )

        board_section = script[
            script.index("def _board_block_sections") : script.index("def _breakdown_sections")
        ]

        self.assertIn("_board_block_data", script)
        self.assertIn('"block_initial_position": "right_end"', script)
        self.assertIn('self._value_formula("F", board_data.get("F"), "N")', script)
        self.assertIn('self._value_formula("g", board.get("g"), "m/s^2")', board_section)
        self.assertIn(r"a_B=\\frac{F+f}{m_B}", board_section)
        self.assertIn(r"f=\\mu m_Bg", board_section)
        self.assertIn(r"a_{rel}=a_B-a_A", board_section)
        self.assertNotIn(r"F\\rightarrow", board_section)
        self.assertNotIn(r"a_B=-\\frac{f}{m_B}", board_section)
        self.assertNotIn(r"f=m_2g", board_section)
        self.assertNotIn(r"\mu=0.2", board_section)

    def test_math_apollonius_manim_uses_local_professional_template(self) -> None:
        question = (
            "例1(阿波罗尼斯圆) 已知直角坐标平面上点 Q(2,0) 和圆 C:x^2+y^2=1，"
            "动点 M 到圆 C 的切线长与 |MQ| 的比等于常数 λ(λ>0)，"
            "求动点 M 的轨迹方程，说明它表示什么曲线。"
        )
        script = build_manim_script(
            {
                "subject": "math",
                "scene_type": "conic",
                "fallback_text": question,
                "parameters": {"question_excerpt": question},
            }
        )

        self.assertIn("_draw_professional_math_scene", script)
        self.assertIn("apollonius_tangent_circle", script)
        self.assertIn("_build_apollonius_model", script)
        self.assertIn("_play_apollonius_global_preview", script)
        self.assertIn("_play_apollonius_derivation", script)
        self.assertIn("ValueTracker", script)
        self.assertIn("TracedPath", script)
        self.assertIn(r"\frac{MT}{MQ}=\lambda", script)
        self.assertIn(r"MT^2=OM^2-1=x^2+y^2-1", script)
        self.assertIn(r"x^2+y^2-1=\lambda^2[(x-2)^2+y^2]", script)
        self.assertIn(
            r"\left(x+\frac{2\lambda^2}{1-\lambda^2}\right)^2+y^2=\frac{1+3\lambda^2}{(1-\lambda^2)^2}",
            script,
        )
        self.assertIn(r"\lambda=1:\quad x=\frac{5}{4}", script)

    def test_math_ellipse_focus_chord_manim_uses_local_professional_template(self) -> None:
        question = (
            "例1（2008 福建卷·理）椭圆 x^2/a^2+y^2/b^2=1（a>b>0）的一个焦点是 F(1,0)，"
            "O 是坐标原点。设过点 F 的直线 l 交椭圆于 A、B 两点。"
            "若直线 l 绕点 F 任意转动，恒有 |OA|^2+|OB|^2<|AB|^2，求 a 的取值范围。"
        )
        script = build_manim_script(
            {
                "subject": "math",
                "scene_type": "conic",
                "fallback_text": question,
                "parameters": {"question_excerpt": question},
            }
        )

        self.assertIn("ellipse_focus_chord", script)
        self.assertIn("_build_ellipse_focus_chord_model", script)
        self.assertIn("_play_ellipse_focus_chord_global_preview", script)
        self.assertIn("_play_ellipse_focus_chord_derivation", script)
        self.assertIn(r"\frac{x^2}{a^2}+\frac{y^2}{b^2}=1", script)
        self.assertIn(r"|OA|^2+|OB|^2<|AB|^2", script)
        self.assertIn(r"A\cdot B<0", script)
        self.assertIn(r"x_1+x_2=\frac{2a^2k^2}{D}", script)
        self.assertIn(r"A\cdot B=\frac{(-u^2+3u-1)k^2-u(u-1)}{u-1+uk^2}", script)
        self.assertIn(r"a>\sqrt{\frac{3+\sqrt5}{2}}", script)

    def test_geogebra_preview_hides_editor_chrome(self) -> None:
        source = (ROOT / "frontend" / "lib" / "screen" / "capture" / "geogebra_scene_preview_screen.dart").read_text(
            encoding="utf-8"
        )

        self.assertIn("showToolBar: false", source)
        self.assertIn("showAlgebraInput: false", source)
        self.assertIn("showMenuBar: false", source)
        self.assertIn("perspective: 'G'", source)
        self.assertIn("customToolBar: ''", source)
        self.assertIn("api.setAxesVisible(isMathScene, isMathScene)", source)
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

    def test_manim_success_and_repeated_jobs_use_distinct_outputs(self) -> None:
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

                repeated = render_jobs.create_manim_job(scene)
                repeated_completed = self._wait_for_job(repeated["job_id"])
                self.assertEqual(repeated_completed["status"], "succeeded")
                self.assertNotEqual(job["job_id"], repeated["job_id"])
                self.assertNotEqual(completed["video_url"], repeated_completed["video_url"])

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

    def test_math_manim_uses_local_renderer_without_manimcat(self) -> None:
        def fake_local_render(*, scene_spec, job_id, output_dir):
            output_dir.mkdir(parents=True, exist_ok=True)
            output_path = output_dir / f"{job_id}.mp4"
            output_path.write_bytes(b"local math mp4")
            return output_path

        scene = {
            "subject": "math",
            "scene_type": "function_graph",
            "parameters": {"question_excerpt": "y=x^2"},
        }
        with tempfile.TemporaryDirectory() as temp_dir, patch.object(
            render_jobs,
            "MEDIA_ROOT",
            Path(temp_dir),
        ), patch.object(
            render_jobs,
            "render_math_video_with_manimcat",
            side_effect=render_jobs.ManimCatUnavailable("ManimCat missing"),
        ) as manimcat_render, patch.object(
            render_jobs,
            "render_manim_video",
            side_effect=fake_local_render,
        ) as local_render:
            expected_root = Path(temp_dir)
            output_path = render_jobs._render_scene_video(scene_spec=scene, job_id="math-local")

        self.assertEqual(output_path.name, "math-local.mp4")
        manimcat_render.assert_not_called()
        local_render.assert_any_call(scene_spec=scene, job_id="math-local", output_dir=expected_root)

    def test_recovered_manimcat_job_downloads_completed_remote_video(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            media_root = Path(temp_dir)
            job_id = "abc123recovered"
            persisted_job = {
                "job_id": job_id,
                "scene_hash": "abc123",
                "status": "running",
                "progress": 60,
                "video_url": "",
                "duration": None,
                "thumbnail_url": None,
                "message": "Rendering",
                "error": "",
                "scene_spec": {"subject": "math", "scene_type": "conic"},
                "diagnostics": {
                    "renderer_backend": "manimcat",
                    "manimcat_remote_job_id": "remote-1",
                },
                "updated_at": time.time(),
            }
            render_jobs._job_path(job_id).write_text(
                json.dumps(persisted_job, ensure_ascii=False),
                encoding="utf-8",
            )

            def fake_download(video_url, output_path):
                self.assertEqual(video_url, "/video/remote.mp4")
                output_path.write_bytes(b"fake mp4")

            render_jobs._jobs.clear()
            with patch.object(render_jobs, "MEDIA_ROOT", media_root), patch.object(
                render_jobs,
                "get_manimcat_job",
                return_value={"status": "completed", "video_url": "/video/remote.mp4"},
            ), patch.object(render_jobs, "download_manimcat_video", side_effect=fake_download):
                recovered = render_jobs.get_manim_job(job_id)

            self.assertIsNotNone(recovered)
            self.assertEqual(recovered["status"], "succeeded")
            self.assertEqual(recovered["video_url"], f"/static/media/manim/{job_id}.mp4")
            self.assertTrue((media_root / f"{job_id}.mp4").exists())
            self.assertTrue(recovered["diagnostics"]["manimcat_recovered"])
            self.assertNotIn("scene_spec", recovered)

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

    def test_manimcat_cache_key_is_stable_for_same_math_problem(self) -> None:
        scene = {
            "subject": "math",
            "scene_type": "function_graph",
            "parameters": {"question_excerpt": "Draw y=x^2."},
        }

        self.assertEqual(
            manimcat_client._render_cache_key(scene),
            manimcat_client._render_cache_key(dict(scene)),
        )

    def test_manimcat_concept_strips_inline_math_delimiters_from_question(self) -> None:
        concept = manimcat_client._build_math_concept(
            {
                "subject": "math",
                "scene_type": "conic",
                "title": "阿波罗尼斯圆",
                "parameters": {
                    "question_excerpt": "圆C:$x^2+y^2=1$，动点M满足$|MQ|$与$\\lambda>0$。",
                },
            }
        )

        self.assertNotIn("$x^2+y^2=1$", concept)
        self.assertNotIn("$|MQ|$", concept)
        self.assertIn("x^2+y^2=1", concept)
        self.assertIn("Never put dollar-delimited math", concept)

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
