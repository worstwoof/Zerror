from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any, Dict, List

from backend.app.core.config import PROJECT_ROOT


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
    manim_physics_source = PROJECT_ROOT / "third_party" / "manim-physics"
    return f'''
import json
import re
import sys
from manim import *

for _candidate_path in [{str(manim_physics_source)!r}, {str(PROJECT_ROOT)!r}]:
    if _candidate_path and _candidate_path not in sys.path:
        sys.path.insert(0, _candidate_path)

try:
    from manim_physics import *
    HAS_MANIM_PHYSICS = True
except Exception:
    HAS_MANIM_PHYSICS = False

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
        is_physics_scene = str(spec.get("subject") or "").lower() == "physics" or scene_type in {{
            "board_block",
            "mechanics",
            "incline",
            "projectile",
            "collision",
            "circuit",
            "electromagnetism",
            "charged_particle_magnetic_field",
            "optics",
            "wave",
            "standing_wave",
            "linear_wave",
        }}
        if is_physics_scene:
            self.camera.background_color = BLACK
            self._draw_professional_physics_scene(spec)
            self.wait(1.2)
            return

        if spec.get("show_title"):
            title = cjk_text(str(spec.get("title") or spec.get("fallback_text") or "题目讲解"), font_size=32)
            title.to_edge(UP)
            self.play(FadeIn(title, shift=DOWN * 0.2))

        self._show_intro_panel(spec)

        if scene_type == "board_block":
            self._draw_board_block_scene(spec)
        elif scene_type in {{"electromagnetism", "charged_particle_magnetic_field"}}:
            self._draw_electromagnetism_scene(spec)
        elif scene_type == "optics":
            self._draw_optics_scene(spec)
        elif scene_type in {{"wave", "standing_wave", "linear_wave"}}:
            self._draw_wave_scene(spec)
        elif scene_type in {{"mechanics", "incline", "projectile", "collision", "circuit"}}:
            self._draw_physics_motion_scene(spec)
        elif scene_type in {{"function_graph", "conic", "geometry", "generic"}}:
            if str(spec.get("subject") or "").lower() == "math":
                self._draw_math_story_scene(spec)
            else:
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

    def _draw_professional_physics_scene(self, spec):
        scene_type = self._professional_scene_type(spec)
        board_data = self._board_block_data(spec) if scene_type == "board_block" else None
        self.camera.background_color = BLACK
        question_block = self._build_question_block(spec, compact=False, board_data=board_data)
        self.play(FadeIn(question_block, shift=DOWN * 0.12), run_time=0.65)
        if scene_type in {{"electromagnetism", "charged_particle_magnetic_field"}}:
            model = self._build_em_teaching_model()
        elif scene_type == "board_block":
            model = self._build_board_block_teaching_model(board_data)
        else:
            model = self._build_generic_teaching_model(scene_type)
        preview_title = cjk_text("第一阶段：全局物理过程预览", font_size=25, color=YELLOW)
        preview_title.move_to(RIGHT * 3.55 + UP * 2.95)
        preview_note = cjk_text("先完整看一遍物理过程，不引入计算公式。", font_size=18, color=GREY_A)
        preview_note.next_to(preview_title, DOWN, aligned_edge=LEFT, buff=0.18)
        self.play(FadeIn(preview_title), FadeIn(preview_note), run_time=0.45)
        self._play_global_physics_preview(model, scene_type)
        self.wait(2.0)
        self.play(FadeOut(VGroup(preview_title, preview_note)), question_block.animate.scale(0.86).to_corner(UL, buff=0.28), run_time=0.7)
        self._play_step_breakdown(spec, model, scene_type, board_data=board_data)

    def _professional_scene_type(self, spec):
        scene_type = str(spec.get("scene_type") or "mechanics").strip().lower()
        params = spec.get("parameters") if isinstance(spec.get("parameters"), dict) else {{}}
        question = " ".join([
            str(spec.get("title") or ""),
            str(spec.get("fallback_text") or ""),
            str(params.get("question_excerpt") or ""),
        ])
        if scene_type == "board_block":
            return "board_block"
        board_hits = ["长木板", "木板", "薄板", "板块", "板块模型", "物块", "滑块", "水平面"]
        if any(token in question for token in board_hits) and any(token in question for token in ["木板", "板", "A", "B"]):
            return "board_block"
        if scene_type in {{"electromagnetism", "charged_particle_magnetic_field", "optics", "wave", "standing_wave", "linear_wave"}}:
            return scene_type
        if "斜面" in question:
            return "incline"
        return scene_type or "mechanics"

    def _question_text(self, spec):
        params = spec.get("parameters") if isinstance(spec.get("parameters"), dict) else {{}}
        return str(params.get("question_excerpt") or spec.get("fallback_text") or spec.get("title") or "").strip()

    def _board_block_data(self, spec):
        question = self._question_text(spec)
        joined = " ".join([
            str(spec.get("title") or ""),
            str(spec.get("fallback_text") or ""),
            question,
        ])
        data = {{
            "question": question,
            "m_A": self._find_board_number(joined, [r"m_?1\\s*=\\s*([-+]?\\d+(?:\\.\\d+)?)", r"m_A\\s*=\\s*([-+]?\\d+(?:\\.\\d+)?)"]),
            "m_B": self._find_board_number(joined, [r"m_?2\\s*=\\s*([-+]?\\d+(?:\\.\\d+)?)", r"m_B\\s*=\\s*([-+]?\\d+(?:\\.\\d+)?)"]),
            "v0": self._find_board_number(joined, [r"v_?0\\s*=\\s*([-+]?\\d+(?:\\.\\d+)?)"]),
            "F": self._find_board_number(joined, [r"F\\s*=\\s*([-+]?\\d+(?:\\.\\d+)?)"]),
            "mu": self._find_board_number(joined, [
                r"(?:μ|µ|mu|\\\\mu)\\s*=\\s*([-+]?\\d+(?:\\.\\d+)?)",
                r"(?:动摩擦因数|摩擦因数)[^0-9]*([-+]?\\d+(?:\\.\\d+)?)",
            ]),
            "g": 10.0,
            "block_initial_position": "right_end" if "右端" in joined else "right_end",
            "questions": self._extract_board_questions(question),
            "missing": [],
        }}
        for key in ["m_A", "m_B", "v0", "F", "mu"]:
            if data[key] is None:
                data["missing"].append(key)
        if self._find_board_number(joined, [r"g\\s*=\\s*([-+]?\\d+(?:\\.\\d+)?)"]) is not None:
            data["g"] = self._find_board_number(joined, [r"g\\s*=\\s*([-+]?\\d+(?:\\.\\d+)?)"])
        if all(data[key] is not None for key in ["m_A", "m_B", "v0", "F", "mu"]):
            f = data["mu"] * data["m_B"] * data["g"]
            a_a = -f / data["m_A"]
            a_b = (data["F"] + f) / data["m_B"]
            a_rel = a_b - a_a
            data.update({{
                "f": f,
                "a_A": a_a,
                "a_B": a_b,
                "a_rel": a_rel,
                "t_common": data["v0"] / a_rel if a_rel > 0 else None,
                "s_rel_abs": data["v0"] * data["v0"] / (2 * a_rel) if a_rel > 0 else None,
            }})
        return data

    def _find_board_number(self, text, patterns):
        source = str(text).replace("＝", "=").replace("，", ",").replace("。", ".")
        for pattern in patterns:
            match = re.search(pattern, source, flags=re.IGNORECASE)
            if match:
                try:
                    return float(match.group(1))
                except Exception:
                    return None
        return None

    def _extract_board_questions(self, question):
        text = str(question)
        matches = []
        for match in re.finditer(r"(?:\\(|（)?([123一二三])(?:\\)|）|、|\\.)?\\s*([^。；;？?]{4,46}[？?]?)", text):
            value = match.group(2).strip()
            if value and value not in matches:
                matches.append(value)
        if matches:
            return matches[:3]
        return ["求共速前的运动过程", "分析 A、B 受力和加速度", "判断相对位移与是否滑离"]

    def _fmt_num(self, value):
        if value is None:
            return "?"
        number = float(value)
        if abs(number - round(number)) < 1e-8:
            return str(int(round(number)))
        return f"{{number:.3g}}"

    def _value_formula(self, name, value, unit=""):
        if value is None:
            return name
        suffix = ""
        if unit == "kg":
            suffix = r"\\mathrm{{kg}}"
        elif unit == "N":
            suffix = r"\\mathrm{{N}}"
        elif unit == "m/s":
            suffix = r"\\mathrm{{m/s}}"
        elif unit == "m/s^2":
            suffix = r"\\mathrm{{m/s^2}}"
        elif unit == "s":
            suffix = r"\\mathrm{{s}}"
        elif unit == "m":
            suffix = r"\\mathrm{{m}}"
        return name + "=" + self._fmt_num(value) + suffix

    def _wrap_cjk_lines(self, text, max_chars=24):
        cleaned = " ".join(str(text).replace("\\n", " ").split())
        if not cleaned:
            return ["题目内容识别中，先根据图像建立物理模型。"]
        lines = []
        current = ""
        break_chars = "。；;，,？?！!"
        for char in cleaned:
            current += char
            if len(current) >= max_chars or char in break_chars:
                lines.append(current.strip())
                current = ""
        if current.strip():
            lines.append(current.strip())
        return lines

    def _question_formula_items(self, question, limit=5):
        found = []
        for raw in re.findall(r"[$]([^$]+)[$]", str(question)):
            value = self._latex_from_question_token(raw)
            if value and value not in found:
                found.append(value)
        pattern = r"(?:m|M|v|V|F|a|s|x|t|L|l|μ)(?:_?\\d+)?\\s*=\\s*[-+]?\\d+(?:\\.\\d+)?\\s*(?:kg|m/s|N|m|s)?"
        for raw in re.findall(pattern, str(question)):
            value = self._latex_from_question_token(raw)
            if value and value not in found:
                found.append(value)
        return found[:limit]

    def _latex_from_question_token(self, raw):
        value = str(raw).strip()
        if not value:
            return ""
        value = value.replace("μ", r"\\mu")
        value = re.sub(r"\\b([mMvVaAsStTlL])([0-9])\\b", r"\\1_\\2", value)
        value = value.replace(" ", "")
        value = value.replace("kg", r"\\mathrm{{kg}}")
        value = value.replace("m/s", r"\\mathrm{{m/s}}")
        value = value.replace("N", r"\\mathrm{{N}}")
        return value

    def _build_question_block(self, spec, compact=False, board_data=None):
        if board_data is not None:
            return self._build_board_question_block(board_data, compact=compact)
        question = self._question_text(spec)
        title = cjk_text("题目要点", font_size=21 if not compact else 17, color=YELLOW)
        max_lines = 5 if not compact else 3
        lines = self._wrap_cjk_lines(question, max_chars=20 if not compact else 24)
        if len(lines) > max_lines:
            lines = lines[:max_lines]
            lines[-1] = lines[-1][: max(6, len(lines[-1]) - 1)] + "…"
        body = VGroup(*[cjk_text(line, font_size=15 if not compact else 12, color=WHITE) for line in lines])
        body.arrange(DOWN, aligned_edge=LEFT, buff=0.09 if compact else 0.11)
        formulas = VGroup()
        for item in self._question_formula_items(question, limit=4 if not compact else 3):
            try:
                formulas.add(MathTex(item, color=BLUE_B).scale(0.48 if not compact else 0.38))
            except Exception:
                formulas.add(cjk_text(item[:12], font_size=12 if compact else 14, color=BLUE_B))
        if len(formulas) > 0:
            formulas.arrange(RIGHT, buff=0.22)
            if formulas.width > 5.6:
                formulas.arrange_in_grid(cols=2, buff=(0.20, 0.12), cell_alignment=LEFT)
        group = VGroup(title, body)
        if len(formulas) > 0:
            group.add(formulas)
        group.arrange(DOWN, aligned_edge=LEFT, buff=0.16)
        group.to_corner(UL, buff=0.32)
        if group.width > 5.95:
            group.scale_to_fit_width(5.95)
        return group

    def _build_board_question_block(self, board, compact=False):
        title = cjk_text("题目区", font_size=20 if not compact else 16, color=YELLOW)
        summary_title = cjk_text("情景摘要", font_size=14 if not compact else 12, color=BLUE_B)
        summary = VGroup(
            cjk_text("光滑水平面：长木板 A，物块 B 在右端。", font_size=12 if not compact else 10, color=WHITE),
            cjk_text("B 初速度向左，恒力 F 水平向右。", font_size=12 if not compact else 10, color=WHITE),
        )
        summary.arrange(DOWN, aligned_edge=LEFT, buff=0.05)
        known_title = cjk_text("已知条件", font_size=14 if not compact else 12, color=BLUE_B)
        known = VGroup()
        known_items = [
            self._value_formula("m_A", board.get("m_A"), "kg"),
            self._value_formula("m_B", board.get("m_B"), "kg"),
            self._value_formula("v_0", board.get("v0"), "m/s"),
            self._value_formula("F", board.get("F"), "N"),
            self._value_formula(r"\\mu", board.get("mu")),
            self._value_formula("g", board.get("g"), "m/s^2"),
        ]
        for item in known_items:
            if "?" not in item:
                try:
                    known.add(MathTex(item, color=WHITE).scale(0.36 if not compact else 0.30))
                except Exception:
                    known.add(cjk_text(item[:16], font_size=11 if not compact else 9, color=WHITE))
        known.arrange_in_grid(cols=3 if not compact else 2, buff=(0.16, 0.10), cell_alignment=LEFT)
        q_title = cjk_text("小问列表", font_size=14 if not compact else 12, color=BLUE_B)
        q_lines = []
        for index, item in enumerate(board.get("questions") or [], start=1):
            q_lines.append(cjk_text(str(index) + ". " + str(item)[:20], font_size=11 if not compact else 9, color=GREY_A))
        questions = VGroup(*q_lines)
        if len(questions) > 0:
            questions.arrange(DOWN, aligned_edge=LEFT, buff=0.04)
        group = VGroup(title, summary_title, summary, known_title, known, q_title, questions)
        group.arrange(DOWN, aligned_edge=LEFT, buff=0.08 if not compact else 0.05)
        group.to_corner(UL, buff=0.24)
        if group.width > 6.0:
            group.scale_to_fit_width(6.0)
        if group.height > 2.78:
            group.scale_to_fit_height(2.78)
        return group

    def _build_em_teaching_model(self):
        axes_origin = LEFT * 5.85 + DOWN * 2.35
        x_axis = Arrow(axes_origin, axes_origin + RIGHT * 5.25, buff=0, color=WHITE, stroke_width=3)
        y_axis = Arrow(axes_origin, axes_origin + UP * 3.25, buff=0, color=WHITE, stroke_width=3)
        x_label = self._label("x", x_axis.get_end() + RIGHT * 0.18, 20)
        y_label = self._label("y", y_axis.get_end() + UP * 0.16, 20)
        p = axes_origin + UP * 2.05
        q = axes_origin + RIGHT * 4.35
        p_dot = Dot(p, color=WHITE, radius=0.045)
        q_dot = Dot(q, color=WHITE, radius=0.045)
        p_label = self._label("P", p + LEFT * 0.28 + UP * 0.08, 23)
        q_label = self._label("Q", q + DOWN * 0.26, 23)
        v_arrow = Arrow(p + RIGHT * 0.06, p + RIGHT * 0.70, buff=0, color=WHITE, stroke_width=3)
        v_label = MathTex("v_0", color=WHITE).scale(0.55).next_to(v_arrow, UP, buff=0.03)
        field = Rectangle(width=1.55, height=2.65, color=WHITE, stroke_width=2)
        field.move_to(axes_origin + RIGHT * 3.05 + UP * 1.25)
        marks = VGroup()
        for x in [-0.48, 0.0, 0.48]:
            for y in [-0.82, -0.28, 0.28, 0.82]:
                marks.add(cjk_text("x", font_size=15, color=GREY_B).move_to(field.get_center() + RIGHT * x + UP * y))
        b_label = MathTex("B", color=WHITE).scale(0.62).next_to(field, UP, buff=0.08)
        l_brace = Brace(field, DOWN, color=WHITE)
        l_label = MathTex("L", color=WHITE).scale(0.58).next_to(l_brace, DOWN, buff=0.04)
        path = VMobject(color=WHITE, stroke_width=4)
        path.set_points_smoothly([p, p + RIGHT * 0.95, field.get_left() + UP * 1.00, field.get_center() + DOWN * 0.02, q + UP * 0.24, q])
        local_arc = DashedVMobject(ArcBetweenPoints(field.get_left() + UP * 1.00, field.get_right() + DOWN * 0.40, angle=-PI / 2), num_dashes=16, color=GREY_A)
        particle = Dot(p, color=YELLOW, radius=0.07)
        axes = VGroup(x_axis, y_axis, x_label, y_label)
        points = VGroup(p_dot, q_dot, p_label, q_label, v_arrow, v_label)
        field_group = VGroup(field, marks, b_label, l_brace, l_label)
        path_group = VGroup(path, local_arc)
        full_group = VGroup(axes, points, field_group, path_group)
        return {{
            "type": "em",
            "axes": axes,
            "points": points,
            "field": field_group,
            "field_box": field,
            "path": path,
            "local_arc": local_arc,
            "path_group": path_group,
            "particle": particle,
            "full_group": full_group,
            "p": p,
            "q": q,
        }}

    def _build_board_block_teaching_model(self, board_data=None):
        board_data = board_data or {{}}
        ground = Line(LEFT * 6.05 + DOWN * 2.35, LEFT * 0.40 + DOWN * 2.35, color=WHITE, stroke_width=3)
        board = Rectangle(width=4.25, height=0.34, color=WHITE, stroke_width=4)
        board.move_to(LEFT * 3.25 + DOWN * 2.06)
        block = Square(side_length=0.68, color=WHITE, stroke_width=4)
        block.move_to(board.get_right() + LEFT * 0.50 + UP * 0.51)
        board_label = self._label("A", board.get_center(), 24)
        block_label = self._label("B", block.get_center(), 24)
        v_arrow = Arrow(block.get_top() + UP * 0.30 + RIGHT * 0.18, block.get_top() + UP * 0.30 + LEFT * 1.05, buff=0, color=WHITE, stroke_width=3)
        v_label = MathTex("v_0", color=WHITE).scale(0.55).next_to(v_arrow, UP, buff=0.03)
        f_formula = self._value_formula("F", board_data.get("F"), "N")
        force_arrow = Arrow(block.get_right() + UP * 0.18, block.get_right() + RIGHT * 1.05 + UP * 0.18, buff=0, color=WHITE, stroke_width=3)
        force_label = MathTex(f_formula, color=WHITE).scale(0.48).next_to(force_arrow, UP, buff=0.03)
        board_motion = Arrow(board.get_center() + DOWN * 0.46, board.get_center() + LEFT * 0.95 + DOWN * 0.46, buff=0, color=GREY_A, stroke_width=2)
        block_motion = Arrow(block.get_center() + UP * 0.64, block.get_center() + LEFT * 1.10 + UP * 0.64, buff=0, color=GREY_A, stroke_width=2)
        motion_labels = VGroup(
            cjk_text("A 的运动趋势", font_size=13, color=GREY_A).next_to(board_motion, DOWN, buff=0.04),
            cjk_text("B 的相对滑动", font_size=13, color=GREY_A).next_to(block_motion, UP, buff=0.04),
        )
        f_on_b = Arrow(block.get_bottom() + DOWN * 0.10, block.get_bottom() + RIGHT * 0.85 + DOWN * 0.10, buff=0, color=YELLOW, stroke_width=3)
        f_on_a = Arrow(board.get_center() + UP * 0.32 + RIGHT * 0.45, board.get_center() + LEFT * 0.58 + UP * 0.32, buff=0, color=YELLOW, stroke_width=3)
        n_arrow = Arrow(block.get_top() + LEFT * 0.18, block.get_top() + UP * 0.70 + LEFT * 0.18, buff=0, color=BLUE_B, stroke_width=3)
        g_arrow = Arrow(block.get_center() + RIGHT * 0.24, block.get_center() + DOWN * 0.82 + RIGHT * 0.24, buff=0, color=BLUE_B, stroke_width=3)
        force_labels = VGroup(
            MathTex("f", color=YELLOW).scale(0.52).next_to(f_on_b, DOWN, buff=0.03),
            MathTex("f", color=YELLOW).scale(0.52).next_to(f_on_a, UP, buff=0.03),
            MathTex("N", color=BLUE_B).scale(0.52).next_to(n_arrow, RIGHT, buff=0.03),
            MathTex("m_B g", color=BLUE_B).scale(0.52).next_to(g_arrow, RIGHT, buff=0.03),
        )
        forces = VGroup(f_on_b, f_on_a, n_arrow, g_arrow, force_labels)
        relative_arrow = DoubleArrow(block.get_left() + UP * 0.26, board.get_left() + UP * 0.26, buff=0.05, color=YELLOW, stroke_width=3)
        relative_label = MathTex("s_{{rel}}", color=YELLOW).scale(0.54).next_to(relative_arrow, UP, buff=0.03)
        relative = VGroup(relative_arrow, relative_label)
        board_group = VGroup(board, board_label)
        block_group = VGroup(block, block_label, v_arrow, v_label, force_arrow, force_label)
        motion = VGroup(board_motion, block_motion, motion_labels)
        full_group = VGroup(ground, board_group, block_group)
        moving = VGroup(board_group, block_group, motion)
        moving.save_state()
        return {{
            "type": "board_block",
            "ground": ground,
            "board": board,
            "block": block,
            "board_group": board_group,
            "block_group": block_group,
            "motion": motion,
            "moving": moving,
            "forces": forces,
            "force_arrow": VGroup(force_arrow, force_label),
            "relative": relative,
            "full_group": full_group,
            "board_data": board_data,
            "forces_shown": False,
            "relative_shown": False,
        }}

    def _build_generic_teaching_model(self, scene_type):
        base = Line(LEFT * 5.8 + DOWN * 2.25, LEFT * 0.55 + DOWN * 2.25, color=WHITE, stroke_width=3)
        body = Square(side_length=0.62, color=WHITE, stroke_width=3).move_to(LEFT * 5.0 + DOWN * 1.90)
        velocity = Arrow(body.get_right(), body.get_right() + RIGHT * 0.85, buff=0, color=WHITE)
        force = Arrow(body.get_top(), body.get_top() + UP * 0.78, buff=0, color=WHITE)
        path = VMobject(color=WHITE, stroke_width=4)
        path.set_points_smoothly([body.get_center(), LEFT * 4.0 + DOWN * 1.80, LEFT * 2.65 + DOWN * 1.55, LEFT * 1.15 + DOWN * 1.32])
        labels = VGroup(MathTex("v_0", color=WHITE).scale(0.55).next_to(velocity, UP, buff=0.03), MathTex("F", color=WHITE).scale(0.58).next_to(force, RIGHT, buff=0.04))
        full_group = VGroup(base, body, velocity, force, path, labels)
        return {{
            "type": "generic",
            "base": base,
            "body": body,
            "velocity": velocity,
            "force": force,
            "path": path,
            "labels": labels,
            "full_group": full_group,
        }}

    def _play_global_physics_preview(self, model, scene_type):
        if model.get("type") == "em":
            self.play(Create(model["axes"]), run_time=1.0)
            self.play(FadeIn(model["points"]), Create(model["field"]), run_time=1.5)
            self.play(Create(model["path_group"]), run_time=1.35)
            particle = model["particle"].copy()
            self.add(particle)
            self.play(MoveAlongPath(particle, model["path"]), run_time=4.0, rate_func=linear)
            self.play(FadeOut(particle), run_time=0.25)
            return
        if model.get("type") == "board_block":
            self.play(Create(model["ground"]), FadeIn(model["board_group"]), FadeIn(model["block_group"]), run_time=1.2)
            self.play(FadeIn(model["motion"]), run_time=0.65)
            self.play(
                model["board_group"].animate.shift(LEFT * 0.45),
                model["block_group"].animate.shift(LEFT * 1.35),
                model["motion"].animate.shift(LEFT * 0.20),
                run_time=3.8,
                rate_func=smooth,
            )
            self.play(VGroup(model["board_group"], model["block_group"], model["motion"]).animate.shift(LEFT * 0.34), run_time=1.2, rate_func=linear)
            self.wait(0.55)
            self.play(Restore(model["moving"]), run_time=0.8)
            return
        self.play(Create(VGroup(model["base"], model["body"], model["velocity"], model["force"], model["labels"])), run_time=1.4)
        self.play(Create(model["path"]), model["body"].animate.move_to(model["path"].get_end()), run_time=3.6, rate_func=smooth)

    def _play_step_breakdown(self, spec, model, scene_type, board_data=None):
        stage_title = cjk_text("第二阶段：分段拆解与数学推导", font_size=24, color=YELLOW)
        stage_title.move_to(RIGHT * 3.55 + UP * 3.15)
        self.play(FadeIn(stage_title, shift=DOWN * 0.08), run_time=0.45)
        sections = self._breakdown_sections(spec, scene_type, board_data=board_data)
        for index, section in enumerate(sections, start=1):
            derivation = self._build_derivation_group(index, section)
            self.play(FadeIn(derivation, shift=LEFT * 0.12), run_time=0.55)
            self.wait(1.10)
            self._play_local_response(model, section.get("focus") or "", scene_type)
            self.wait(3.10)
            self.play(FadeOut(derivation, shift=UP * 0.12), run_time=0.45)
        self.play(FadeOut(stage_title), run_time=0.35)

    def _board_block_sections(self, board):
        questions = board.get("questions") or []
        first_question = questions[0] if len(questions) > 0 else "确认板块模型和初始状态"
        second_question = questions[1] if len(questions) > 1 else "求 A、B 的受力和加速度"
        third_question = questions[2] if len(questions) > 2 else "求共速时间和相对位移"
        known_formulas = [
            self._value_formula("m_A", board.get("m_A"), "kg"),
            self._value_formula("m_B", board.get("m_B"), "kg"),
            self._value_formula("v_0", board.get("v0"), "m/s"),
            self._value_formula("F", board.get("F"), "N"),
            self._value_formula(r"\\mu", board.get("mu")),
        ]
        known_formulas = [item for item in known_formulas if "?" not in item]
        complete = not board.get("missing")
        if complete:
            f = board.get("f")
            a_a = board.get("a_A")
            a_b = board.get("a_B")
            a_rel = board.get("a_rel")
            t_common = board.get("t_common")
            s_rel_abs = board.get("s_rel_abs")
            force_formulas = [
                "N_B=m_Bg=" + self._fmt_num(board.get("m_B")) + "\\\\times" + self._fmt_num(board.get("g")) + "=" + self._fmt_num(board.get("m_B") * board.get("g")) + r"\\mathrm{{N}}",
                "f=\\\\mu m_Bg=" + self._fmt_num(board.get("mu")) + "\\\\times" + self._fmt_num(board.get("m_B")) + "\\\\times" + self._fmt_num(board.get("g")) + "=" + self._fmt_num(f) + r"\\mathrm{{N}}",
                "a_A=-\\\\frac{{f}}{{m_A}}=-" + self._fmt_num(f) + "/" + self._fmt_num(board.get("m_A")) + "=" + self._fmt_num(a_a) + r"\\mathrm{{m/s^2}}",
                "a_B=\\\\frac{{F+f}}{{m_B}}=\\\\frac{{" + self._fmt_num(board.get("F")) + "+" + self._fmt_num(f) + "}}{{" + self._fmt_num(board.get("m_B")) + "}}=" + self._fmt_num(a_b) + r"\\mathrm{{m/s^2}}",
            ]
            relative_formulas = [
                "a_{{rel}}=a_B-a_A=" + self._fmt_num(a_rel) + r"\\mathrm{{m/s^2}}",
                "v_{{rel}}=-v_0+a_{{rel}}t",
                "t=\\\\frac{{v_0}}{{a_{{rel}}}}=" + self._fmt_num(t_common) + r"\\mathrm{{s}}",
                "|s_{{rel}}|=\\\\frac{{v_0^2}}{{2a_{{rel}}}}=" + self._fmt_num(s_rel_abs) + r"\\mathrm{{m}}",
            ]
            force_notes = ["水平面光滑，所以地面对 A 没有水平摩擦。", "B 同时受向右恒力 F 和向右摩擦力 f。"]
            relative_notes = ["以向右为正，B 初速度为 -v0。", "当相对速度变为 0 时，A、B 达到共速。"]
        else:
            missing = "、".join(board.get("missing") or [])
            force_formulas = [r"N_B=m_Bg", r"f=\\mu m_Bg", r"a_A=-\\frac{{f}}{{m_A}}", r"a_B=\\frac{{F+f}}{{m_B}}"]
            relative_formulas = [r"a_{{rel}}=a_B-a_A", r"v_{{rel}}=-v_0+a_{{rel}}t", r"s_{{rel}}=-v_0t+\\frac12a_{{rel}}t^2"]
            force_notes = ["题干条件缺失：" + missing + "；这里只保留符号推导。", "不会用 LLM 公式覆盖题干真实条件。"]
            relative_notes = ["条件齐全后再代入数值求共速时间和相对位移。"]
        return [
            {{
                "title": "小问一：" + str(first_question)[:22],
                "focus": "objects",
                "notes": ["B 初始位于木板 A 的右端。", "v0 向左，恒力 F 向右，先把初态画对。"],
                "formulas": [r"v_B(0)=-v_0", r"F\\rightarrow"] + known_formulas[:5],
            }},
            {{
                "title": "小问二：" + str(second_question)[:22],
                "focus": "forces",
                "notes": force_notes,
                "formulas": force_formulas,
            }},
            {{
                "title": "小问三：" + str(third_question)[:22],
                "focus": "relative",
                "notes": relative_notes,
                "formulas": relative_formulas,
            }},
        ]

    def _breakdown_sections(self, spec, scene_type, board_data=None):
        formulas = self._formula_items(spec)
        if scene_type == "board_block":
            return self._board_block_sections(board_data or self._board_block_data(spec))
        elif scene_type in {{"electromagnetism", "charged_particle_magnetic_field"}}:
            fallback = [
                {{
                    "title": "小问一：如何确定入射状态？",
                    "focus": "points",
                    "notes": ["标出 P、Q 两点和初速度方向。", "这一步只建立空间关系，不急着计算。"],
                    "formulas": [r"P(0,a)", r"Q(b,0)", r"\\vec v_0 \\parallel x"],
                }},
                {{
                    "title": "小问二：为什么轨迹是圆弧？",
                    "focus": "field",
                    "notes": ["磁场中洛伦兹力始终垂直速度。", "所以它只改变方向，提供向心力。"],
                    "formulas": [r"qv_0B=\\frac{{mv_0^2}}{{R}}", r"R=\\frac{{mv_0}}{{qB}}"],
                }},
                {{
                    "title": "小问三：怎样求左边界距离？",
                    "focus": "path",
                    "notes": ["把圆弧投影拆成水平、竖直两个关系。", "再结合宽度 L 和 Q 点坐标求边界位置。"],
                    "formulas": [r"a=R(1-\\cos\\theta)", r"\\Delta x=R\\sin\\theta", r"d=b-L+R\\sin\\theta"],
                }},
            ]
        else:
            fallback = [
                {{
                    "title": "小问一：研究对象与初态是什么？",
                    "focus": "state",
                    "notes": ["先画出物体、初速度和受力方向。"],
                    "formulas": [r"x_0,\\ v_0,\\ F"],
                }},
                {{
                    "title": "小问二：运动规律如何建立？",
                    "focus": "motion",
                    "notes": ["用受力决定加速度，再连接速度和位移。"],
                    "formulas": [r"F=ma", r"x=x_0+v_0t+\\frac12at^2"],
                }},
                {{
                    "title": "小问三：题目要求怎样落到答案？",
                    "focus": "result",
                    "notes": ["代入边界条件，检查方向、范围和单位。"],
                    "formulas": [r"\\text{{条件}}\\Rightarrow\\text{{结果}}"],
                }},
            ]
        if formulas:
            if scene_type == "board_block":
                for formula in formulas[:8]:
                    compact = str(formula).replace(" ", "")
                    if compact == "F=ma" or "x=x_0+v_0t" in compact:
                        continue
                    if "f=" in compact and r"\\mu" not in compact and "mu" not in compact:
                        continue
                    if any(token in compact for token in [r"\\mu", "mu", "N_B", "f=", "a_A", "a_B"]):
                        target_index = 1
                    elif any(token in compact for token in ["rel", "s_", "L", "t"]):
                        target_index = 2
                    else:
                        target_index = 0
                    if formula not in fallback[target_index]["formulas"]:
                        fallback[target_index]["formulas"].append(formula)
            elif scene_type in {{"electromagnetism", "charged_particle_magnetic_field"}}:
                for formula in formulas[:8]:
                    compact = str(formula).replace(" ", "")
                    if any(token in compact for token in ["sin", "cos", "theta", "d=", "x=", "L"]):
                        target_index = 2
                    elif any(token in compact for token in ["R=", "qv", "eB", "qB", "B"]):
                        target_index = 1
                    else:
                        target_index = 2
                    if formula not in fallback[target_index]["formulas"]:
                        fallback[target_index]["formulas"].append(formula)
            else:
                for pos, formula in enumerate(formulas[:6]):
                    fallback[min(pos // 2, len(fallback) - 1)]["formulas"].append(formula)
        return fallback

    def _build_derivation_group(self, index, section):
        title = cjk_text(str(index) + ". " + str(section.get("title") or "关键小问"), font_size=22, color=YELLOW)
        notes = VGroup(*[cjk_text(str(item), font_size=17, color=GREY_A) for item in section.get("notes") or []])
        if len(notes) > 0:
            notes.arrange(DOWN, aligned_edge=LEFT, buff=0.10)
        formula = self._aligned_formula_block(section.get("formulas") or [])
        group = VGroup(title)
        if len(notes) > 0:
            group.add(notes)
        if formula is not None:
            group.add(formula)
        group.arrange(DOWN, aligned_edge=LEFT, buff=0.28)
        group.move_to(RIGHT * 3.35 + DOWN * 0.18)
        if group.width > 5.45:
            group.scale_to_fit_width(5.45)
        if group.height > 4.25:
            group.scale_to_fit_height(4.25)
        return group

    def _aligned_formula_block(self, formulas):
        cleaned = []
        for formula in formulas:
            value = str(formula).replace("$$", "").replace("$", "").strip()
            if not value or any("\\u4e00" <= ch <= "\\u9fff" for ch in value):
                continue
            if "=" in value and "&=" not in value:
                value = value.replace("=", "&=", 1)
            cleaned.append(value)
        if not cleaned:
            return None
        body = r"\\begin{{aligned}}" + r"\\\\".join(cleaned[:5]) + r"\\end{{aligned}}"
        try:
            mob = MathTex(body, color=WHITE).scale(0.66)
        except Exception:
            mob = VGroup(*[MathTex(item.replace("&", ""), color=WHITE).scale(0.58) for item in cleaned[:4]])
            mob.arrange(DOWN, aligned_edge=LEFT, buff=0.18)
        return mob

    def _play_local_response(self, model, focus, scene_type):
        if model.get("type") == "em":
            if focus == "points":
                target = model["points"]
                self.play(target.animate.set_color(YELLOW), run_time=0.35)
                self.play(Indicate(target, color=YELLOW, scale_factor=1.04), run_time=1.8)
                self.play(target.animate.set_color(WHITE), run_time=0.35)
            elif focus == "field":
                target = model["field"]
                self.play(target.animate.set_color(YELLOW), run_time=0.35)
                self.play(Circumscribe(model["field_box"], color=YELLOW, time_width=0.8), run_time=2.2)
                self.play(target.animate.set_color(WHITE), run_time=0.35)
            else:
                path = model["path"]
                particle = Dot(model["p"], color=YELLOW, radius=0.07)
                self.play(path.animate.set_color(YELLOW), run_time=0.30)
                self.add(particle)
                self.play(MoveAlongPath(particle, path), run_time=4.2, rate_func=linear)
                self.play(FadeOut(particle), path.animate.set_color(WHITE), run_time=0.35)
            return
        if model.get("type") == "board_block":
            if focus == "objects":
                target = VGroup(model["board_group"], model["block_group"], model["motion"])
                self.play(target.animate.set_color(YELLOW), run_time=0.35)
                self.play(Indicate(model["board_group"], color=YELLOW, scale_factor=1.04), Indicate(model["block_group"], color=YELLOW, scale_factor=1.08), run_time=1.8)
                self.play(target.animate.set_color(WHITE), model["motion"].animate.set_color(GREY_A), run_time=0.35)
            elif focus == "forces":
                if not model.get("forces_shown"):
                    self.play(FadeIn(model["forces"]), run_time=0.9)
                    model["forces_shown"] = True
                self.play(Indicate(VGroup(model["forces"], model["force_arrow"]), color=YELLOW, scale_factor=1.03), run_time=2.0)
            else:
                if not model.get("relative_shown"):
                    self.play(FadeIn(model["relative"]), run_time=0.65)
                    model["relative_shown"] = True
                model["moving"].save_state()
                self.play(
                    model["board_group"].animate.shift(RIGHT * 0.35),
                    model["block_group"].animate.shift(LEFT * 0.85),
                    model["relative"].animate.set_color(YELLOW),
                    run_time=3.2,
                    rate_func=smooth,
                )
                self.play(Restore(model["moving"]), model["relative"].animate.set_color(WHITE), run_time=0.75)
            return
        if focus in {{"state", "motion"}}:
            target = VGroup(model["body"], model["velocity"], model["force"])
            self.play(target.animate.set_color(YELLOW), run_time=0.35)
            self.play(Indicate(target, color=YELLOW, scale_factor=1.05), run_time=1.8)
            self.play(target.animate.set_color(WHITE), run_time=0.35)
        else:
            self.play(model["path"].animate.set_color(YELLOW), run_time=0.35)
            self.wait(2.0)
            self.play(model["path"].animate.set_color(WHITE), run_time=0.35)

    def _draw_blackboard_physics_scene(self, spec):
        scene_type = str(spec.get("scene_type") or "mechanics")
        self._draw_blackboard_header(spec)
        self._show_blackboard_explanation(
            "第一步 读题建模",
            self._blackboard_step_text(spec, 0, "先把题目里的研究对象、已知量和要求量分开，画图只保留对解题有用的信息。"),
            color=YELLOW,
            wait_time=3.1,
        )
        self._show_blackboard_explanation(
            "第二步 建立图像",
            self._blackboard_step_text(spec, 1, "把坐标轴、关键点、速度方向和作用区域依次标出来，后面的方程都从这张图读出。"),
            color=WHITE,
            wait_time=3.0,
        )
        if scene_type in {{"electromagnetism", "charged_particle_magnetic_field"}}:
            self._draw_blackboard_electromagnetism(spec)
        elif scene_type == "optics":
            self._draw_blackboard_optics(spec)
        elif scene_type in {{"wave", "standing_wave", "linear_wave"}}:
            self._draw_blackboard_wave(spec)
        elif scene_type == "board_block":
            self._draw_blackboard_board_block(spec)
        else:
            self._draw_blackboard_mechanics(spec)
        self._show_blackboard_explanation(
            "第三步 分析过程",
            self._blackboard_step_text(spec, 2, "观察运动或光路的变化，找到能把图形条件和物理规律连起来的关键关系。"),
            color=WHITE,
            wait_time=3.2,
        )
        self._show_blackboard_reasoning_steps(spec)
        self._show_blackboard_formula_steps(spec)
        self._show_blackboard_explanation(
            "最后 回到问题",
            self._blackboard_step_text(spec, 5, "把求出的关系代回题目要求，检查范围、方向和单位，得到最终结论。"),
            color=YELLOW,
            wait_time=3.4,
        )

    def _blackboard_step_text(self, spec, index, fallback):
        steps = [str(item).strip() for item in spec.get("steps") or [] if str(item).strip()]
        if index < len(steps):
            return steps[index]
        params = spec.get("parameters") if isinstance(spec.get("parameters"), dict) else {{}}
        focus_points = [str(item).strip() for item in params.get("focus_points") or [] if str(item).strip()]
        if index < len(focus_points):
            return focus_points[index]
        return fallback

    def _show_blackboard_explanation(self, title, body, color=WHITE, wait_time=2.8):
        title_mob = cjk_text(str(title), font_size=24, color=color)
        body_text = str(body).strip()
        if len(body_text) > 68:
            body_text = body_text[:65] + "..."
        body_mob = cjk_text(body_text, font_size=18, color=GREY_A)
        group = VGroup(title_mob, body_mob)
        group.arrange(DOWN, aligned_edge=LEFT, buff=0.14)
        group.to_corner(UR, buff=0.44)
        if group.width > 5.2:
            group.scale_to_fit_width(5.2)
        self.play(FadeIn(group, shift=LEFT * 0.16), run_time=0.55)
        self.wait(wait_time)
        self.play(FadeOut(group, shift=UP * 0.08), run_time=0.35)

    def _show_blackboard_key_question(self, text, color=YELLOW):
        value = str(text).strip()
        if len(value) > 46:
            value = value[:43] + "..."
        tag = cjk_text("关键小问", font_size=17, color=color)
        question = cjk_text(value, font_size=21, color=WHITE)
        question.next_to(tag, DOWN, aligned_edge=LEFT, buff=0.12)
        underline = Line(LEFT * 0.05, RIGHT * 3.55, color=color, stroke_width=2)
        underline.next_to(question, DOWN, aligned_edge=LEFT, buff=0.12)
        group = VGroup(tag, question, underline)
        group.to_corner(DL, buff=0.46).shift(UP * 0.34)
        if group.width > 4.8:
            group.scale_to_fit_width(4.8)
        self.play(FadeIn(group, shift=RIGHT * 0.16), run_time=0.38)
        return group

    def _clear_blackboard_key_question(self, group, wait_time=0.9):
        self.wait(wait_time)
        self.play(FadeOut(group, shift=UP * 0.08), run_time=0.25)

    def _show_blackboard_reasoning_steps(self, spec):
        steps = [str(item).strip() for item in spec.get("steps") or [] if str(item).strip()]
        if len(steps) <= 3:
            steps = steps + [
                "先确定研究对象和初末状态。",
                "再把力学、电磁学或几何约束写成可计算关系。",
                "最后把边界条件代入，判断答案的取值范围。",
            ]
        visible_steps = steps[:6]
        heading = cjk_text("解题拆分", font_size=23, color=YELLOW)
        heading.to_corner(UL, buff=0.48).shift(DOWN * 1.08)
        self.play(FadeIn(heading, shift=DOWN * 0.10), run_time=0.45)
        for index, step in enumerate(visible_steps, start=1):
            line_text = str(index) + ". " + step
            if len(line_text) > 62:
                line_text = line_text[:59] + "..."
            row = cjk_text(line_text, font_size=18, color=WHITE)
            row.next_to(heading, DOWN, aligned_edge=LEFT, buff=0.22)
            if row.width > 5.7:
                row.scale_to_fit_width(5.7)
            self.play(Write(row), run_time=0.70)
            self.wait(2.35)
            self.play(FadeOut(row, shift=UP * 0.05), run_time=0.25)
        self.play(FadeOut(heading), run_time=0.30)

    def _draw_blackboard_header(self, spec):
        params = spec.get("parameters") if isinstance(spec.get("parameters"), dict) else {{}}
        question = str(params.get("question_excerpt") or spec.get("fallback_text") or spec.get("title") or "").strip()
        title = cjk_text("题目区", font_size=26, color=YELLOW).to_corner(UL, buff=0.36)
        self.play(FadeIn(title), run_time=0.5)
        if question:
            question_line = cjk_text(question[:58], font_size=20, color=GREY_A)
            question_line.next_to(title, DOWN, aligned_edge=LEFT, buff=0.30)
            self.play(Write(question_line), run_time=0.8)

    def _label(self, value, point, font_size=26, color=WHITE):
        return cjk_text(str(value), font_size=font_size, color=color).move_to(point)

    def _draw_blackboard_electromagnetism(self, spec):
        axes_origin = LEFT * 4.8 + DOWN * 2.15
        x_axis = Arrow(axes_origin, axes_origin + RIGHT * 8.6, buff=0, color=WHITE, stroke_width=3)
        y_axis = Arrow(axes_origin, axes_origin + UP * 4.0, buff=0, color=WHITE, stroke_width=3)
        x_label = self._label("x", x_axis.get_end() + RIGHT * 0.20, 22)
        y_label = self._label("y", y_axis.get_end() + UP * 0.18, 22)
        p = axes_origin + UP * 2.25
        q = axes_origin + RIGHT * 6.6
        p_dot = Dot(p, color=WHITE, radius=0.045)
        q_dot = Dot(q, color=WHITE, radius=0.045)
        p_label = self._label("P", p + LEFT * 0.28 + UP * 0.08, 24)
        q_label = self._label("Q", q + DOWN * 0.26, 24)
        v_arrow = Arrow(p + RIGHT * 0.08, p + RIGHT * 0.9, buff=0, color=WHITE, stroke_width=3)
        v_label = MathTex("v_0", color=WHITE).scale(0.62).next_to(v_arrow, UP, buff=0.04)
        field = Rectangle(width=2.25, height=3.10, color=WHITE, stroke_width=2)
        field.move_to(axes_origin + RIGHT * 4.27 + UP * 1.48)
        marks = VGroup()
        for x in [-0.75, -0.25, 0.25, 0.75]:
            for y in [-0.95, -0.35, 0.25, 0.85]:
                marks.add(cjk_text("x", font_size=18, color=GREY_B).move_to(field.get_center() + RIGHT * x + UP * y))
        b_label = MathTex("B", color=WHITE).scale(0.7).next_to(field, UP, buff=0.10)
        l_brace = Brace(field, DOWN, color=WHITE)
        l_label = MathTex("L", color=WHITE).scale(0.66).next_to(l_brace, DOWN, buff=0.05)
        path_a = VMobject(color=WHITE, stroke_width=4)
        path_a.set_points_smoothly([p, p + RIGHT * 1.35, field.get_left() + UP * 1.15, field.get_center() + DOWN * 0.10, q + UP * 0.30, q])
        path_b = DashedVMobject(ArcBetweenPoints(field.get_left() + UP * 1.15, field.get_right() + DOWN * 0.48, angle=-PI / 2), num_dashes=18, color=GREY_A)
        particle = Dot(p, color=YELLOW, radius=0.07)
        prompt = self._show_blackboard_key_question("P、Q 和初速度方向分别在哪里？")
        self.play(Create(x_axis), Create(y_axis), FadeIn(x_label), FadeIn(y_label), run_time=1.0)
        self.play(FadeIn(VGroup(p_dot, q_dot, p_label, q_label)), GrowArrow(v_arrow), FadeIn(v_label), run_time=1.2)
        self._clear_blackboard_key_question(prompt, wait_time=1.0)
        prompt = self._show_blackboard_key_question("磁场左右边界和宽度 L 怎么标？")
        self.play(Create(field), FadeIn(marks), FadeIn(b_label), GrowFromCenter(l_brace), FadeIn(l_label), run_time=1.4)
        self._clear_blackboard_key_question(prompt, wait_time=1.2)
        prompt = self._show_blackboard_key_question("进入磁场后为什么走圆弧？")
        self.play(Create(path_a), FadeIn(path_b), run_time=1.5)
        self.play(MoveAlongPath(particle, path_a), run_time=4.2, rate_func=linear)
        self._clear_blackboard_key_question(prompt, wait_time=1.1)
        self.play(FadeOut(particle), run_time=0.2)

    def _draw_blackboard_board_block(self, spec):
        ground = Line(LEFT * 5.8 + DOWN * 1.75, RIGHT * 5.8 + DOWN * 1.75, color=WHITE, stroke_width=4)
        board = Rectangle(width=5.4, height=0.34, color=WHITE, stroke_width=4).shift(DOWN * 1.25)
        block = Square(side_length=0.72, color=WHITE, stroke_width=4).next_to(board, UP, buff=0).shift(RIGHT * 1.65)
        left_arrow = Arrow(block.get_left() + UP * 0.55, block.get_left() + LEFT * 1.2 + UP * 0.55, buff=0, color=WHITE)
        force_arrow = Arrow(block.get_right() + UP * 0.10, block.get_right() + RIGHT * 1.1 + UP * 0.10, buff=0, color=WHITE)
        labels = VGroup(self._label("A", board.get_center(), 24), self._label("B", block.get_center(), 24), MathTex("v_0", color=WHITE).scale(0.62).next_to(left_arrow, UP, buff=0.04), MathTex("F", color=WHITE).scale(0.65).next_to(force_arrow, UP, buff=0.04))
        prompt = self._show_blackboard_key_question("研究对象是哪两个物体？")
        self.play(Create(ground), Create(board), Create(block), FadeIn(labels[:2]), run_time=1.2)
        self._clear_blackboard_key_question(prompt, wait_time=1.0)
        prompt = self._show_blackboard_key_question("速度、外力和相对运动方向怎么标？")
        self.play(GrowArrow(left_arrow), GrowArrow(force_arrow), FadeIn(labels[2:]), run_time=1.3)
        self._clear_blackboard_key_question(prompt, wait_time=1.0)
        prompt = self._show_blackboard_key_question("相对位移关系如何从动画中读出？")
        self.play(VGroup(board, labels[0]).animate.shift(LEFT * 0.7), VGroup(block, labels[1], left_arrow, force_arrow, labels[2], labels[3]).animate.shift(LEFT * 2.0), run_time=3.8, rate_func=smooth)
        self._clear_blackboard_key_question(prompt, wait_time=1.2)

    def _draw_blackboard_mechanics(self, spec):
        base = Line(LEFT * 5.5 + DOWN * 2.0, RIGHT * 5.5 + DOWN * 2.0, color=WHITE, stroke_width=4)
        body = Square(side_length=0.9, color=WHITE, stroke_width=4).shift(LEFT * 3.2 + DOWN * 1.45)
        path = VMobject(color=WHITE, stroke_width=4)
        path.set_points_smoothly([body.get_center(), LEFT * 1.4 + DOWN * 1.28, RIGHT * 0.9 + DOWN * 1.02, RIGHT * 3.5 + DOWN * 0.82])
        velocity = Arrow(body.get_right(), body.get_right() + RIGHT * 1.0, buff=0, color=WHITE)
        force = Arrow(body.get_top(), body.get_top() + UP * 1.0, buff=0, color=WHITE)
        prompt = self._show_blackboard_key_question("物体初态、速度和受力怎么画？")
        self.play(Create(base), Create(body), GrowArrow(velocity), GrowArrow(force), run_time=1.4)
        self._clear_blackboard_key_question(prompt, wait_time=1.0)
        prompt = self._show_blackboard_key_question("轨迹和受力方向如何对应？")
        self.play(Create(path), body.animate.move_to(path.get_end()), velocity.animate.shift(RIGHT * 6.7 + UP * 0.63), force.animate.shift(RIGHT * 6.7 + UP * 0.63), run_time=4.0, rate_func=smooth)
        self._clear_blackboard_key_question(prompt, wait_time=1.1)

    def _draw_blackboard_optics(self, spec):
        axis = Line(LEFT * 5.4 + DOWN * 1.0, RIGHT * 5.4 + DOWN * 1.0, color=WHITE, stroke_width=3)
        lens = Ellipse(width=0.50, height=3.1, color=WHITE, stroke_width=4).shift(DOWN * 1.0)
        rays = VGroup(*[Line(LEFT * 5.0 + UP * y, lens.get_center() + UP * y, color=WHITE, stroke_width=3) for y in [-0.90, -0.35, 0.25, 0.80]])
        refracted = VGroup(*[Line(lens.get_center() + UP * y, RIGHT * 4.5 + DOWN * 0.15, color=WHITE, stroke_width=3) for y in [-0.90, -0.35, 0.25, 0.80]])
        focus = Dot(RIGHT * 2.2 + DOWN * 1.0, color=WHITE)
        prompt = self._show_blackboard_key_question("主光轴、透镜和入射光线在哪里？")
        self.play(Create(axis), Create(lens), Create(rays), run_time=1.5)
        self._clear_blackboard_key_question(prompt, wait_time=1.0)
        prompt = self._show_blackboard_key_question("折射后光线交在哪里？")
        self.play(Create(refracted), FadeIn(focus), run_time=1.8)
        self._clear_blackboard_key_question(prompt, wait_time=1.1)

    def _draw_blackboard_wave(self, spec):
        base = Line(LEFT * 5.2 + DOWN * 1.4, RIGHT * 5.2 + DOWN * 1.4, color=WHITE, stroke_width=3)
        wave = ParametricFunction(lambda t: np.array([t, 0.75 * np.sin(2.2 * t) - 1.4, 0]), t_range=[-5.0, 5.0], color=WHITE, stroke_width=4)
        moving = Dot(wave.point_from_proportion(0), color=YELLOW, radius=0.06)
        prompt = self._show_blackboard_key_question("平衡位置和波形怎么对应？")
        self.play(Create(base), Create(wave), run_time=1.5)
        self._clear_blackboard_key_question(prompt, wait_time=1.0)
        prompt = self._show_blackboard_key_question("质点运动如何体现周期和波长？")
        self.play(MoveAlongPath(moving, wave), run_time=4.2, rate_func=linear)
        self._clear_blackboard_key_question(prompt, wait_time=1.1)
        self.play(FadeOut(moving), run_time=0.2)

    def _show_blackboard_formula_steps(self, spec):
        formulas = self._formula_items(spec)
        if not formulas:
            formulas = [r"R=\\frac{{mv_0}}{{qB}}", r"a=R(1-\\cos\\theta)", r"x=b-L+R\\sin\\theta", r"0\\le x\\le L"]
        notes = self._formula_notes(spec)
        heading = cjk_text("第四步 列式推导", font_size=24, color=YELLOW)
        heading.move_to(RIGHT * 1.35 + UP * 2.72)
        self.play(FadeIn(heading, shift=DOWN * 0.12), run_time=0.45)
        group = VGroup()
        for formula in formulas[:6]:
            try:
                mob = MathTex(formula, color=WHITE).scale(0.68)
            except Exception:
                mob = cjk_text(str(formula)[:42], font_size=24, color=WHITE)
            group.add(mob)
        group.arrange(DOWN, aligned_edge=LEFT, buff=0.23)
        group.move_to(RIGHT * 1.35 + UP * 1.38)
        for index, item in enumerate(group):
            self.play(Write(item), run_time=1.0)
            note = notes[index] if index < len(notes) else "这一步把图中的几何量和物理量对应起来。"
            if len(note) > 54:
                note = note[:51] + "..."
            note_mob = cjk_text(str(index + 1) + ". " + note, font_size=18, color=GREY_A)
            note_mob.next_to(item, DOWN, aligned_edge=LEFT, buff=0.10)
            if note_mob.width > 5.4:
                note_mob.scale_to_fit_width(5.4)
            self.play(FadeIn(note_mob, shift=UP * 0.08), run_time=0.35)
            self.wait(2.35)
            self.play(FadeOut(note_mob, shift=UP * 0.04), run_time=0.25)
        self.wait(1.4)

    def _formula_notes(self, spec):
        steps = [str(item).strip() for item in spec.get("steps") or [] if str(item).strip()]
        notes = []
        for step in steps[2:8]:
            if step:
                notes.append(step)
        if notes:
            return notes
        scene_type = str(spec.get("scene_type") or "")
        if scene_type in {{"electromagnetism", "charged_particle_magnetic_field"}}:
            return [
                "洛伦兹力提供向心力，先得到圆周运动半径。",
                "入射点到目标点的竖直差对应圆弧的余弦关系。",
                "水平距离由磁场宽度、边界位置和圆弧投影共同决定。",
                "左边界必须让粒子在磁场内完成需要的偏转。",
            ]
        return [
            "先写出控制运动的核心物理规律。",
            "再把题目给出的几何或边界条件代入。",
            "整理未知量，判断取值范围。",
            "最后检查结果是否满足题目限制。",
        ]

    def _formula_items(self, spec):
        result = []
        for item in spec.get("formula_steps") or []:
            if isinstance(item, dict):
                value = str(item.get("formula") or item.get("latex") or "").strip()
            else:
                value = str(item).strip()
            value = value.replace("$$", "").replace("$", "").strip()
            if value and not any("\\u4e00" <= ch <= "\\u9fff" for ch in value):
                result.append(value)
        return result

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
        physics_overlay = self._build_manim_physics_field_overlay(spec)
        self.play(FadeIn(field), FadeIn(marks), GrowArrow(velocity), run_time=1.1)
        if physics_overlay is not None:
            self.play(FadeIn(physics_overlay), run_time=0.9)
        self.wait(0.5)
        self._show_step_caption(steps[1] if len(steps) > 1 else "洛伦兹力始终垂直速度方向，轨迹开始弯曲", color=WHITE, wait_time=1.5)
        self.play(Create(path), run_time=1.1)
        self.play(MoveAlongPath(particle, path), GrowArrow(force), run_time=3.4, rate_func=linear)
        self._show_step_caption(steps[2] if len(steps) > 2 else "用半径、周期或偏转关系连接题目条件", color=YELLOW, wait_time=1.6)
        self.wait(1.0)

    def _build_manim_physics_field_overlay(self, spec):
        if not HAS_MANIM_PHYSICS:
            return None
        field_type = str(spec.get("field_type") or spec.get("subtype") or spec.get("scene_type") or "").lower()
        try:
            if "electric" in field_type or "charge" in field_type:
                charge_a = Charge(1.2, LEFT * 1.2 + DOWN * 0.2, add_glow=False)
                charge_b = Charge(-1.0, RIGHT * 2.0 + UP * 0.25, add_glow=False)
                vector_field = ElectricField(
                    charge_a,
                    charge_b,
                    x_range=[-2.8, 3.6, 0.75],
                    y_range=[-1.5, 1.5, 0.75],
                    length_func=lambda norm: min(0.35, norm * 0.10),
                    colors=[BLUE, TEAL, YELLOW],
                )
                return VGroup(vector_field, charge_a, charge_b).set_opacity(0.78)
            wire = Wire(Line(LEFT * 0.4 + DOWN * 1.1, RIGHT * 2.2 + UP * 1.1), current=1.0, samples=8)
            vector_field = MagneticField(
                wire,
                x_range=[-1.2, 3.2, 0.8],
                y_range=[-1.6, 1.6, 0.8],
                length_func=lambda norm: min(0.32, norm * 0.09),
                colors=[TEAL, BLUE, YELLOW],
            )
            wire.set_color(ORANGE)
            return VGroup(vector_field, wire).set_opacity(0.72)
        except Exception:
            return None

    def _draw_optics_scene(self, spec):
        steps = [str(item) for item in spec.get("steps") or [] if str(item).strip()]
        axis = Line(LEFT * 5.2, RIGHT * 5.2, color=GREY_B).shift(DOWN * 0.15)
        lens_group = self._build_manim_physics_lens_group()
        if lens_group is None:
            lens = Ellipse(width=0.58, height=3.0, color=BLUE, fill_color=BLUE_E, fill_opacity=0.25)
            rays = VGroup(*[
                Line(LEFT * 4.7 + UP * y, RIGHT * 4.7 + UP * (y * 0.3), color=YELLOW)
                for y in [-1.1, -0.45, 0.25, 0.95]
            ])
            lens_group = VGroup(lens, rays)
        self._show_step_caption(steps[0] if steps else "Draw the principal axis, lens, and incoming rays.", color=YELLOW, wait_time=1.3)
        self.play(Create(axis), FadeIn(lens_group), run_time=1.2)
        self._show_step_caption(steps[1] if len(steps) > 1 else "Use the ray path to connect focal length, image position, and sign convention.", color=WHITE, wait_time=1.5)
        focus = Dot(RIGHT * 2.5 + DOWN * 0.15, color=ORANGE)
        focus_label = cjk_text("F", font_size=22, color=ORANGE).next_to(focus, DOWN, buff=0.05)
        self.play(FadeIn(focus), FadeIn(focus_label), run_time=0.6)
        for extra_step in steps[2:5]:
            self._show_step_caption(extra_step, color=WHITE, wait_time=1.2)
        self.wait(1.0)

    def _build_manim_physics_lens_group(self):
        if not HAS_MANIM_PHYSICS:
            return None
        try:
            lens = Lens(-5, 1, fill_opacity=0.35, color=BLUE).scale(0.55)
            rays = VGroup(*[
                Ray(LEFT * 4.8 + UP * y, RIGHT, 6.8, [lens], color=YELLOW)
                for y in [-1.2, -0.55, 0.1, 0.75, 1.25]
            ])
            return VGroup(lens, rays).shift(DOWN * 0.15)
        except Exception:
            return None

    def _draw_wave_scene(self, spec):
        steps = [str(item) for item in spec.get("steps") or [] if str(item).strip()]
        baseline = Line(LEFT * 4.5, RIGHT * 4.5, color=GREY_B)
        if HAS_MANIM_PHYSICS:
            try:
                wave = StandingWave(n=2, length=8.0, amplitude=0.85, period=1.6, color=YELLOW)
                wave.start_wave()
            except Exception:
                wave = FunctionGraph(lambda x: 0.75 * np.sin(2 * x), x_range=[-4, 4], color=YELLOW)
        else:
            wave = FunctionGraph(lambda x: 0.75 * np.sin(2 * x), x_range=[-4, 4], color=YELLOW)
        self._show_step_caption(steps[0] if steps else "Show equilibrium, nodes, and antinodes first.", color=YELLOW, wait_time=1.3)
        self.play(Create(baseline), Create(wave), run_time=1.1)
        self._show_step_caption(steps[1] if len(steps) > 1 else "The standing wave mode gives a visual handle for the formula parameters.", color=WHITE, wait_time=1.5)
        self.wait(2.2)

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

    def _draw_math_story_scene(self, spec):
        steps = [str(item) for item in spec.get("steps") or [] if str(item).strip()]
        scene_type = str(spec.get("scene_type") or "geometry")
        axes = Axes(
            x_range=[-5, 5, 1],
            y_range=[-3, 4, 1],
            x_length=8.8,
            y_length=5.2,
            tips=True,
        ).shift(DOWN * 0.25)
        x_label = cjk_text("x", font_size=20).next_to(axes.x_axis.get_end(), RIGHT, buff=0.08)
        y_label = cjk_text("y", font_size=20).next_to(axes.y_axis.get_end(), UP, buff=0.08)
        self._show_step_caption(steps[0] if steps else "先建立图形和坐标系，把题目条件放到图上", color=YELLOW, wait_time=1.4)
        self.play(Create(axes), FadeIn(x_label), FadeIn(y_label), run_time=1.2)

        if scene_type == "conic":
            curve = ParametricFunction(
                lambda t: axes.c2p(3.1 * np.cos(t), 1.65 * np.sin(t)),
                t_range=[0, TAU],
                color=YELLOW,
            )
            focus_l = Dot(axes.c2p(-2.2, 0), color=ORANGE)
            focus_r = Dot(axes.c2p(2.2, 0), color=ORANGE)
            labels = VGroup(
                cjk_text("F1", font_size=20, color=ORANGE).next_to(focus_l, DOWN, buff=0.06),
                cjk_text("F2", font_size=20, color=ORANGE).next_to(focus_r, DOWN, buff=0.06),
            )
            moving_point = Dot(axes.c2p(1.1, 1.55), color=BLUE)
            chord = Line(axes.c2p(-1.8, -1.35), axes.c2p(1.1, 1.55), color=BLUE)
            guide = DashedLine(axes.c2p(1.1, 1.55), axes.c2p(1.1, 0), color=GREY_B)
            self.play(Create(curve), FadeIn(focus_l), FadeIn(focus_r), FadeIn(labels), run_time=1.8)
            self._show_step_caption(steps[1] if len(steps) > 1 else "圆锥曲线题先抓住焦点、弦、切线或对称关系", color=WHITE, wait_time=1.5)
            self.play(FadeIn(moving_point), Create(chord), Create(guide), run_time=1.3)
            self.play(moving_point.animate.move_to(axes.c2p(2.3, 1.1)), chord.animate.put_start_and_end_on(axes.c2p(-1.4, -1.45), axes.c2p(2.3, 1.1)), run_time=2.2, rate_func=smooth)
        elif scene_type == "function_graph":
            graph = axes.plot(lambda x: 0.16 * (x - 0.8) * (x - 0.8) - 1.1, x_range=[-4.2, 4.4], color=YELLOW)
            tangent_point = Dot(axes.c2p(2.0, 0.16 * (2.0 - 0.8) * (2.0 - 0.8) - 1.1), color=ORANGE)
            tangent = Line(axes.c2p(0.3, -1.1), axes.c2p(3.7, 1.0), color=BLUE)
            area = axes.get_area(graph, x_range=[-1.5, 1.8], color=TEAL, opacity=0.32)
            self.play(Create(graph), run_time=1.8)
            self._show_step_caption(steps[1] if len(steps) > 1 else "函数题要把图像、关键点和变化趋势同步看", color=WHITE, wait_time=1.5)
            self.play(FadeIn(tangent_point), Create(tangent), FadeIn(area), run_time=1.4)
            self.play(tangent_point.animate.move_to(axes.c2p(3.0, 0.16 * (3.0 - 0.8) * (3.0 - 0.8) - 1.1)), run_time=1.8, rate_func=smooth)
        else:
            triangle = Polygon(axes.c2p(-2.8, -1.2), axes.c2p(2.0, -1.2), axes.c2p(0.8, 1.6), color=YELLOW)
            altitude = DashedLine(axes.c2p(0.8, 1.6), axes.c2p(0.8, -1.2), color=BLUE)
            angle_arc = Arc(radius=0.55, start_angle=0, angle=0.75, color=ORANGE).move_arc_center_to(axes.c2p(-2.8, -1.2))
            self.play(Create(triangle), run_time=1.4)
            self._show_step_caption(steps[1] if len(steps) > 1 else "几何题要把辅助线、角度和相似关系逐步显出来", color=WHITE, wait_time=1.5)
            self.play(Create(altitude), Create(angle_arc), run_time=1.2)

        for extra_step in steps[2:5]:
            self._show_step_caption(extra_step, color=WHITE, wait_time=1.2)
        self.wait(0.8)

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


_LATEX_COMMANDS = (
    "frac",
    "sqrt",
    "sin",
    "cos",
    "tan",
    "theta",
    "alpha",
    "beta",
    "gamma",
    "Delta",
    "vec",
    "parallel",
    "le",
    "ge",
    "text",
    "Rightarrow",
)


def _normalize_latex_escapes(value: Any) -> str:
    text = str(value)
    for _ in range(4):
        for command in _LATEX_COMMANDS:
            text = text.replace("\\\\" + command, "\\" + command)
    return text


def _safe_formula_step(item: Any) -> Any:
    if isinstance(item, dict):
        safe_item = dict(item)
        for key in ("formula", "latex", "value"):
            if key in safe_item:
                safe_item[key] = _normalize_latex_escapes(safe_item[key])
        return safe_item
    return _normalize_latex_escapes(item)


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
    safe["formula_steps"] = [_safe_formula_step(item) for item in safe.get("formula_steps", [])][:16]
    safe.pop("code", None)
    safe.pop("script", None)
    return safe
