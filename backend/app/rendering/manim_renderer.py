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


class LearningScene(Scene):
    def construct(self):
        spec = json.loads(SCENE_SPEC)
        scene_type = str(spec.get("scene_type") or "generic")
        title = Text(str(spec.get("title") or spec.get("fallback_text") or "题目讲解"), font_size=32)
        title.to_edge(UP)
        self.play(FadeIn(title, shift=DOWN * 0.2))

        if scene_type in {{"function_graph", "conic", "geometry", "electromagnetism", "generic"}}:
            self._draw_axes_scene(spec)
        else:
            self._draw_axes_scene(spec)

        summary = str(spec.get("fallback_text") or "根据结构化场景生成讲解动画。")
        note = Text(summary[:48], font_size=22, color=YELLOW).to_edge(DOWN)
        self.play(FadeIn(note))
        self.wait(1)

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
                label = Text(str(item.get("label") or item.get("id") or ""), font_size=22)
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
