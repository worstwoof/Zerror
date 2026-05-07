from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List


class ManimUnavailable(RuntimeError):
    pass


def is_manim_available() -> bool:
    return shutil.which("manim") is not None or _python_manim_available()


def render_manim_video(
    *,
    scene_spec: Dict[str, Any],
    job_id: str,
    output_dir: Path,
) -> Path:
    """Render a controlled Manim template to MP4 and return the final path."""

    output_dir.mkdir(parents=True, exist_ok=True)
    if not is_manim_available():
        raise ManimUnavailable("Manim is not installed or not available on PATH.")

    script_path = output_dir / f"{job_id}.py"
    script_path.write_text(build_manim_script(scene_spec), encoding="utf-8")

    command = _manim_command(script_path, output_dir)
    completed = subprocess.run(
        command,
        cwd=output_dir,
        capture_output=True,
        text=True,
        timeout=180,
        check=False,
    )
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout or "").strip()
        raise RuntimeError(detail[-1200:] or "Manim render failed.")

    candidates = sorted(
        output_dir.rglob("LearningScene.mp4"),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    if not candidates:
        candidates = sorted(
            output_dir.rglob("*.mp4"),
            key=lambda path: path.stat().st_mtime,
            reverse=True,
        )
    if not candidates:
        raise RuntimeError("Manim finished but no MP4 output was found.")

    final_path = output_dir / f"{job_id}.mp4"
    if candidates[0] != final_path:
        final_path.write_bytes(candidates[0].read_bytes())
    return final_path


def build_manim_script(scene_spec: Dict[str, Any]) -> str:
    safe_spec = _safe_scene_spec(scene_spec)
    spec_json = json.dumps(safe_spec, ensure_ascii=False)
    return f'''
import json
from manim import *

SCENE_SPEC = {spec_json!r}
TEXT_FONT_CANDIDATES = [
    "Noto Sans CJK SC",
    "Noto Sans CJK",
    "Source Han Sans SC",
    "Source Han Sans CN",
    "WenQuanYi Micro Hei",
    "WenQuanYi Zen Hei",
    "Microsoft YaHei",
    "SimHei",
    "Arial Unicode MS",
]
_CHOSEN_CJK_FONT = None


def choose_cjk_font():
    global _CHOSEN_CJK_FONT
    if _CHOSEN_CJK_FONT is not None:
        return _CHOSEN_CJK_FONT or None
    try:
        from manimpango import list_fonts
        fonts = [str(font) for font in list_fonts()]
    except Exception:
        fonts = []
    by_lower_name = {{font.lower(): font for font in fonts}}
    for candidate in TEXT_FONT_CANDIDATES:
        match = by_lower_name.get(candidate.lower())
        if match:
            _CHOSEN_CJK_FONT = match
            return _CHOSEN_CJK_FONT
    for candidate in TEXT_FONT_CANDIDATES:
        needle = candidate.lower()
        for font in fonts:
            if needle in font.lower():
                _CHOSEN_CJK_FONT = font
                return _CHOSEN_CJK_FONT
    _CHOSEN_CJK_FONT = ""
    return None


def cjk_text(value, font_size=24, color=WHITE, **kwargs):
    text = str(value)
    font = choose_cjk_font()
    if font:
        return Text(text, font=font, font_size=font_size, color=color, **kwargs)
    return Text(text, font_size=font_size, color=color, **kwargs)


class LearningScene(Scene):
    def construct(self):
        spec = json.loads(SCENE_SPEC)
        scene_type = str(spec.get("scene_type") or "generic")
        if spec.get("show_title"):
            title = cjk_text(str(spec.get("title") or spec.get("fallback_text") or "题目讲解"), font_size=32)
            title.to_edge(UP)
            self.play(FadeIn(title, shift=DOWN * 0.2))

        if scene_type == "board_block":
            self._draw_board_block_scene(spec)
        elif scene_type in {{"electromagnetism", "charged_particle_magnetic_field"}}:
            self._draw_electromagnetism_scene(spec)
        elif scene_type in {{"mechanics", "incline", "projectile", "collision", "circuit", "optics"}}:
            self._draw_physics_motion_scene(spec)
        elif scene_type in {{"function_graph", "conic", "geometry", "generic"}}:
            self._draw_axes_scene(spec)
        else:
            self._draw_axes_scene(spec)

        if spec.get("show_summary"):
            summary = str(spec.get("fallback_text") or "根据结构化场景生成讲解动画。")
            note = cjk_text(summary[:48], font_size=22, color=YELLOW).to_edge(DOWN)
            self.play(FadeIn(note))
        self.wait(1)

    def _draw_board_block_scene(self, spec):
        ground = Line(LEFT * 5.8, RIGHT * 5.8, color=GREY_B).shift(DOWN * 1.75)
        board = RoundedRectangle(width=5.2, height=0.42, corner_radius=0.14, color=GOLD, fill_color=GOLD_E, fill_opacity=0.88)
        board.move_to(DOWN * 1.45)
        block = RoundedRectangle(width=0.85, height=0.9, corner_radius=0.10, color=GREEN, fill_color=GREEN_E, fill_opacity=0.92)
        block.move_to(board.get_right() + LEFT * 0.48 + UP * 0.66)

        board_label = cjk_text("A", font_size=24).move_to(board.get_center() + UP * 0.03)
        block_label = cjk_text("B", font_size=24).move_to(block.get_center())

        velocity_arrow = Arrow(block.get_top() + UP * 0.34 + RIGHT * 0.18, block.get_top() + UP * 0.34 + LEFT * 0.82, buff=0, color=BLUE)
        velocity_label = cjk_text("v0", font_size=22, color=BLUE).next_to(velocity_arrow, UP, buff=0.04)
        force_arrow = Arrow(block.get_right() + RIGHT * 0.06, block.get_right() + RIGHT * 1.0, buff=0, color=ORANGE)
        force_label = cjk_text("F", font_size=24, color=ORANGE).next_to(force_arrow, UP, buff=0.04)
        block_friction = Arrow(block.get_left() + DOWN * 0.1, block.get_left() + RIGHT * 0.72 + DOWN * 0.1, buff=0, color=RED)
        block_friction_label = cjk_text("f", font_size=21, color=RED).next_to(block_friction, DOWN, buff=0.04)
        board_friction = Arrow(board.get_center() + UP * 0.5, board.get_center() + LEFT * 1.1 + UP * 0.5, buff=0, color=TEAL_A)
        board_friction_label = cjk_text("f", font_size=21, color=TEAL_A).next_to(board_friction, UP, buff=0.04)

        board_group = VGroup(board, board_label, board_friction, board_friction_label)
        block_group = VGroup(block, block_label, velocity_arrow, velocity_label, force_arrow, force_label, block_friction, block_friction_label)

        self.play(Create(ground), FadeIn(board), FadeIn(block), FadeIn(board_label), FadeIn(block_label))
        self.play(
            GrowArrow(velocity_arrow),
            FadeIn(velocity_label),
            GrowArrow(force_arrow),
            FadeIn(force_label),
            GrowArrow(block_friction),
            FadeIn(block_friction_label),
            GrowArrow(board_friction),
            FadeIn(board_friction_label),
        )
        self.play(
            board_group.animate.shift(LEFT * 0.85),
            block_group.animate.shift(LEFT * 2.45),
            run_time=2.4,
            rate_func=smooth,
        )
        self.play(VGroup(board_group, block_group).animate.shift(LEFT * 0.45), run_time=0.9, rate_func=linear)
        self.wait(0.8)

    def _draw_electromagnetism_scene(self, spec):
        field = RoundedRectangle(width=4.2, height=2.4, corner_radius=0.25, color=TEAL, fill_color=TEAL_E, fill_opacity=0.25)
        field.shift(RIGHT * 0.8)
        marks = VGroup()
        for x in [-0.5, 0.4, 1.3, 2.2]:
            for y in [-0.65, 0.0, 0.65]:
                cross = VGroup(
                    Line(LEFT * 0.08 + DOWN * 0.08, RIGHT * 0.08 + UP * 0.08, color=TEAL_A),
                    Line(LEFT * 0.08 + UP * 0.08, RIGHT * 0.08 + DOWN * 0.08, color=TEAL_A),
                ).move_to(RIGHT * x + UP * y)
                marks.add(cross)
        path = VMobject(color=YELLOW)
        path.set_points_smoothly([
            LEFT * 4 + DOWN * 0.4,
            LEFT * 2.0 + DOWN * 0.4,
            LEFT * 0.5 + DOWN * 0.15,
            RIGHT * 1.0 + UP * 0.65,
            RIGHT * 3.0 + UP * 0.85,
        ])
        particle = Dot(path.get_start(), color=ORANGE)
        velocity = Arrow(LEFT * 4.4 + DOWN * 0.8, LEFT * 3.3 + DOWN * 0.8, color=ORANGE, buff=0)
        force = Arrow(RIGHT * 0.4 + DOWN * 0.15, RIGHT * 0.4 + UP * 0.8, color=BLUE, buff=0)
        self.play(FadeIn(field), FadeIn(marks), GrowArrow(velocity), Create(path))
        self.play(MoveAlongPath(particle, path), GrowArrow(force), run_time=2.8, rate_func=linear)
        self.wait(0.8)

    def _draw_physics_motion_scene(self, spec):
        ground = Line(LEFT * 5.0, RIGHT * 5.0, color=GREY_B).shift(DOWN * 1.3)
        body = RoundedRectangle(width=1.2, height=0.8, corner_radius=0.12, color=BLUE, fill_color=BLUE_E, fill_opacity=0.9)
        body.shift(LEFT * 3.2 + DOWN * 0.85)
        velocity = Arrow(body.get_right(), body.get_right() + RIGHT * 1.0, buff=0, color=ORANGE)
        force = Arrow(body.get_top(), body.get_top() + UP * 0.9, buff=0, color=YELLOW)
        trace = TracedPath(body.get_center, stroke_color=YELLOW, stroke_width=4)
        self.add(trace)
        self.play(Create(ground), FadeIn(body), GrowArrow(velocity), GrowArrow(force))
        self.play(body.animate.shift(RIGHT * 4.8 + UP * 0.25), velocity.animate.shift(RIGHT * 4.8 + UP * 0.25), force.animate.shift(RIGHT * 4.8 + UP * 0.25), run_time=2.6, rate_func=smooth)
        self.wait(0.8)

    def _draw_axes_scene(self, spec):
        axes = Axes(
            x_range=[-1, 10, 1],
            y_range=[-1, 6, 1],
            x_length=8,
            y_length=4.8,
            tips=True,
        ).shift(DOWN * 0.2)
        self.play(Create(axes))

        objects = spec.get("objects") or []
        rendered_points = {{}}
        for item in objects:
            if not isinstance(item, dict):
                continue
            kind = str(item.get("type") or "")
            if kind == "point":
                point = self._point_from_item(axes, item)
                dot = Dot(point, color=ORANGE)
                label = cjk_text(str(item.get("label") or item.get("id") or ""), font_size=22)
                label.next_to(dot, UP + RIGHT, buff=0.08)
                self.play(FadeIn(dot), FadeIn(label), run_time=0.35)
                rendered_points[str(item.get("id") or item.get("label") or "")] = dot
            elif kind == "function":
                expression = str(item.get("expression") or "x")
                graph = axes.plot(lambda x: self._eval_function(expression, x), x_range=[-0.5, 7.5], color=YELLOW)
                self.play(Create(graph), run_time=1)

        for relation in spec.get("relations") or []:
            if not isinstance(relation, dict):
                continue
            kind = str(relation.get("type") or "")
            if kind == "segment":
                points = relation.get("points") or []
                if len(points) >= 2 and points[0] in rendered_points and points[1] in rendered_points:
                    line = Line(rendered_points[points[0]].get_center(), rendered_points[points[1]].get_center(), color=BLUE)
                    self.play(Create(line), run_time=0.5)
            elif kind == "circle":
                center = relation.get("center")
                radius = float(relation.get("radius") or 1)
                if center in rendered_points:
                    circle = Circle(radius=radius * 0.35, color=BLUE).move_to(rendered_points[center].get_center())
                    self.play(Create(circle), run_time=0.8)
            elif kind == "arrow":
                start = self._xy_to_point(axes, relation.get("start") or {{}})
                end = self._xy_to_point(axes, relation.get("end") or {{}})
                arrow = Arrow(start, end, buff=0, color=YELLOW)
                self.play(GrowArrow(arrow), run_time=0.5)

    def _point_from_item(self, axes, item):
        return self._xy_to_point(axes, {{"x": item.get("x", 0), "y": item.get("y", 0)}})

    def _xy_to_point(self, axes, xy):
        try:
            x_value = float(xy.get("x", 0))
            y_value = float(xy.get("y", 0))
        except Exception:
            x_value, y_value = 0, 0
        return axes.c2p(x_value, y_value)

    def _eval_function(self, expression, x):
        allowed = {{"x": x, "sin": np.sin, "cos": np.cos, "sqrt": np.sqrt, "abs": abs}}
        try:
            return float(eval(expression.replace("^", "**"), {{"__builtins__": {{}}}}, allowed))
        except Exception:
            return x
'''


def _python_manim_available() -> bool:
    completed = subprocess.run(
        [sys.executable, "-c", "import manim"],
        capture_output=True,
        text=True,
        timeout=15,
        check=False,
    )
    return completed.returncode == 0


def _manim_command(script_path: Path, output_dir: Path) -> List[str]:
    if shutil.which("manim"):
        return [
            "manim",
            "-ql",
            "--media_dir",
            str(output_dir),
            str(script_path),
            "LearningScene",
        ]
    return [
        sys.executable,
        "-m",
        "manim",
        "-ql",
        "--media_dir",
        str(output_dir),
        str(script_path),
        "LearningScene",
    ]


def _safe_scene_spec(scene_spec: Dict[str, Any]) -> Dict[str, Any]:
    safe = dict(scene_spec or {})
    safe["objects"] = [
        item
        for item in safe.get("objects", [])
        if isinstance(item, dict) and str(item.get("type") or "") in {"point", "function"}
    ][:20]
    safe["relations"] = [
        item
        for item in safe.get("relations", [])
        if isinstance(item, dict) and str(item.get("type") or "") in {"segment", "circle", "arrow"}
    ][:20]
    safe.pop("code", None)
    safe.pop("script", None)
    return safe
