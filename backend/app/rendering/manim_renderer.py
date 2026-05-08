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
        timeout=420,
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

        self._show_intro_panel(spec)

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

        self._show_solution_walkthrough(spec)
        self._show_formula_review(spec)

        if spec.get("show_summary"):
            summary = str(spec.get("fallback_text") or "根据结构化场景生成讲解动画。")
            note = self._caption(summary[:58], color=YELLOW)
            self.play(FadeIn(note, shift=UP * 0.15))
            self.wait(2.2)
            self.play(FadeOut(note))
        self.wait(1.8)

    def _show_intro_panel(self, spec):
        params = spec.get("parameters") or {{}}
        question = str(params.get("question_excerpt") or spec.get("fallback_text") or "").strip()
        focus_points = [str(item) for item in params.get("focus_points") or [] if str(item).strip()]
        steps = [str(item) for item in spec.get("steps") or [] if str(item).strip()]
        lines = []
        if question:
            lines.append("题意：" + question[:42])
        for point in focus_points[:2]:
            lines.append("关键：" + point[:24])
        for step in steps[:2]:
            lines.append("思路：" + step[:32])
        if not lines:
            return
        panel = VGroup(*[cjk_text(line, font_size=20, color=WHITE) for line in lines[:5]])
        panel.arrange(DOWN, aligned_edge=LEFT, buff=0.16)
        box = RoundedRectangle(
            width=min(11.2, max(5.2, panel.width + 0.7)),
            height=panel.height + 0.45,
            corner_radius=0.12,
            color=GREY_B,
            fill_color=BLACK,
            fill_opacity=0.55,
        )
        group = VGroup(box, panel)
        group.to_edge(DOWN, buff=0.28)
        panel.move_to(box.get_center())
        self.play(FadeIn(group, shift=UP * 0.18), run_time=0.7)
        self.wait(2.0)
        self.play(FadeOut(group, shift=DOWN * 0.12), run_time=0.5)

    def _caption(self, text, color=WHITE):
        value = str(text).strip()
        if len(value) > 62:
            value = value[:59] + "..."
        caption = cjk_text(value, font_size=21, color=color)
        caption.to_edge(DOWN, buff=0.32)
        return caption

    def _show_step_caption(self, text, color=WHITE, wait_time=1.35):
        caption = self._caption(text, color=color)
        self.play(FadeIn(caption, shift=UP * 0.12), run_time=0.35)
        self.wait(wait_time)
        self.play(FadeOut(caption, shift=DOWN * 0.08), run_time=0.25)

    def _show_solution_walkthrough(self, spec):
        steps = [str(item).strip() for item in spec.get("steps") or [] if str(item).strip()]
        if not steps:
            return
        heading = cjk_text("按详解步骤复盘", font_size=27, color=YELLOW).to_edge(UP, buff=0.82)
        self.play(FadeIn(heading), run_time=0.45)
        visible_steps = steps[:8]
        for group_start in range(0, len(visible_steps), 2):
            rows = VGroup()
            for local_index, step in enumerate(visible_steps[group_start:group_start + 2], start=group_start + 1):
                text = str(local_index) + ". " + step[:58]
                label = cjk_text(text, font_size=21, color=WHITE)
                card = VGroup(
                    RoundedRectangle(width=10.4, height=0.82, corner_radius=0.10, color=GREY_B, fill_color=BLACK, fill_opacity=0.46),
                    label,
                )
                label.move_to(card[0].get_center())
                rows.add(card)
            rows.arrange(DOWN, buff=0.20).next_to(heading, DOWN, buff=0.46)
            self.play(FadeIn(rows, shift=UP * 0.12), run_time=0.55)
            self.wait(3.2)
            self.play(FadeOut(rows, shift=DOWN * 0.10), run_time=0.45)
        self.play(FadeOut(heading), run_time=0.35)

    def _show_formula_review(self, spec):
        formulas = [str(item).strip() for item in spec.get("formula_steps") or [] if str(item).strip()]
        steps = [str(item).strip() for item in spec.get("steps") or [] if str(item).strip()]
        review_items = formulas[:5]
        if not review_items and steps:
            review_items = steps[-5:]
        if not review_items:
            return
        heading = cjk_text("把动画对应回解题关系", font_size=26, color=YELLOW).to_edge(UP, buff=0.85)
        cards = VGroup()
        for index, item in enumerate(review_items, start=1):
            label = cjk_text(f"{{index}}. {{item[:54]}}", font_size=22, color=WHITE)
            card = VGroup(
                RoundedRectangle(width=10.2, height=0.58, corner_radius=0.10, color=BLUE_E, fill_color=BLUE_E, fill_opacity=0.28),
                label,
            )
            label.move_to(card[0].get_center())
            cards.add(card)
        cards.arrange(DOWN, buff=0.18).next_to(heading, DOWN, buff=0.34)
        self.play(FadeIn(heading), run_time=0.4)
        for card in cards:
            self.play(FadeIn(card, shift=RIGHT * 0.12), run_time=0.45)
            self.wait(0.8)
        self.wait(1.8)
        self.play(FadeOut(VGroup(heading, cards)), run_time=0.55)

    def _draw_board_block_scene(self, spec):
        steps = [str(item) for item in spec.get("steps") or [] if str(item).strip()]
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

        self._show_step_caption(steps[0] if steps else "先分清木板 A 和物块 B 两个研究对象", color=YELLOW, wait_time=1.4)
        self.play(Create(ground), FadeIn(board), FadeIn(block), FadeIn(board_label), FadeIn(block_label), run_time=1.0)
        self.wait(0.5)
        self._show_step_caption(steps[1] if len(steps) > 1 else "再标出初速度、外力和接触面摩擦力", color=WHITE, wait_time=1.4)
        self.play(
            GrowArrow(velocity_arrow),
            FadeIn(velocity_label),
            GrowArrow(force_arrow),
            FadeIn(force_label),
            GrowArrow(block_friction),
            FadeIn(block_friction_label),
            GrowArrow(board_friction),
            FadeIn(board_friction_label),
            run_time=1.1,
        )
        self.wait(0.6)
        self._show_step_caption(steps[2] if len(steps) > 2 else "物块相对木板滑动时，两者位移变化不同", color=WHITE, wait_time=1.4)
        self.play(
            board_group.animate.shift(LEFT * 0.85),
            block_group.animate.shift(LEFT * 2.45),
            run_time=2.4,
            rate_func=smooth,
        )
        self._show_step_caption(steps[3] if len(steps) > 3 else "最后把相对运动关系代回公式判断", color=YELLOW, wait_time=1.4)
        self.play(VGroup(board_group, block_group).animate.shift(LEFT * 0.45), run_time=1.2, rate_func=linear)
        self.wait(1.0)

    def _draw_electromagnetism_scene(self, spec):
        steps = [str(item) for item in spec.get("steps") or [] if str(item).strip()]
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
        self._show_step_caption(steps[0] if steps else "先确定磁场区域和粒子入射方向", color=YELLOW, wait_time=1.4)
        self.play(FadeIn(field), FadeIn(marks), GrowArrow(velocity), run_time=1.1)
        self.wait(0.5)
        self._show_step_caption(steps[1] if len(steps) > 1 else "洛伦兹力始终垂直速度方向，轨迹开始弯曲", color=WHITE, wait_time=1.5)
        self.play(Create(path), run_time=1.1)
        self.play(MoveAlongPath(particle, path), GrowArrow(force), run_time=3.4, rate_func=linear)
        self._show_step_caption(steps[2] if len(steps) > 2 else "用半径、周期或偏转关系连接题目条件", color=YELLOW, wait_time=1.6)
        self.wait(1.0)

    def _draw_physics_motion_scene(self, spec):
        steps = [str(item) for item in spec.get("steps") or [] if str(item).strip()]
        ground = Line(LEFT * 5.0, RIGHT * 5.0, color=GREY_B).shift(DOWN * 1.3)
        body = RoundedRectangle(width=1.2, height=0.8, corner_radius=0.12, color=BLUE, fill_color=BLUE_E, fill_opacity=0.9)
        body.shift(LEFT * 3.2 + DOWN * 0.85)
        velocity = Arrow(body.get_right(), body.get_right() + RIGHT * 1.0, buff=0, color=ORANGE)
        force = Arrow(body.get_top(), body.get_top() + UP * 0.9, buff=0, color=YELLOW)
        trace = TracedPath(body.get_center, stroke_color=YELLOW, stroke_width=4)
        self.add(trace)
        self._show_step_caption(steps[0] if steps else "先画出研究对象和运动方向", color=YELLOW, wait_time=1.4)
        self.play(Create(ground), FadeIn(body), GrowArrow(velocity), run_time=1.0)
        self.wait(0.4)
        self._show_step_caption(steps[1] if len(steps) > 1 else "再加入合力方向，判断加速度如何改变运动", color=WHITE, wait_time=1.4)
        self.play(GrowArrow(force), run_time=0.7)
        self.play(body.animate.shift(RIGHT * 2.1 + UP * 0.08), velocity.animate.shift(RIGHT * 2.1 + UP * 0.08), force.animate.shift(RIGHT * 2.1 + UP * 0.08), run_time=1.6, rate_func=smooth)
        self._show_step_caption(steps[2] if len(steps) > 2 else "观察位移、速度和受力在同一过程中的对应关系", color=WHITE, wait_time=1.4)
        self.play(body.animate.shift(RIGHT * 2.7 + UP * 0.17), velocity.animate.shift(RIGHT * 2.7 + UP * 0.17), force.animate.shift(RIGHT * 2.7 + UP * 0.17), run_time=2.0, rate_func=smooth)
        self._show_step_caption(steps[3] if len(steps) > 3 else "最后把过程图转成方程求解", color=YELLOW, wait_time=1.6)
        self.wait(1.0)

    def _draw_axes_scene(self, spec):
        steps = [str(item) for item in spec.get("steps") or [] if str(item).strip()]
        axes = Axes(
            x_range=[-1, 10, 1],
            y_range=[-1, 6, 1],
            x_length=8,
            y_length=4.8,
            tips=True,
        ).shift(DOWN * 0.2)
        self._show_step_caption(steps[0] if steps else "先建立坐标或示意图，把条件放到图上", color=YELLOW, wait_time=1.4)
        self.play(Create(axes), run_time=1.0)

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
