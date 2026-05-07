from __future__ import annotations

import hashlib
import json
import re
from typing import Any, Dict, Iterable, List


SUPPORTED_OBJECT_TYPES = {
    "point",
    "segment",
    "line",
    "circle",
    "ellipse",
    "parabola",
    "hyperbola",
    "function",
    "moving_point",
    "tangent",
    "text",
    "slider",
}


def build_geogebra_scene(scene_spec: Dict[str, Any]) -> Dict[str, Any]:
    """Convert a trusted scene_spec into a GeoGebra artifact payload."""

    normalized = normalize_scene_spec(scene_spec)
    commands = _dedupe_commands(
        [
            *_commands_from_parameters(normalized.get("parameters")),
            *_commands_from_objects(normalized.get("objects")),
            *_commands_from_relations(normalized.get("relations")),
            *_commands_from_steps(normalized.get("steps")),
            *_string_list(_nested_get(normalized, ("geogebra", "commands"))),
        ]
    )
    metadata = {
        "supported_objects": sorted(SUPPORTED_OBJECT_TYPES),
        "source": "scene_spec",
        "has_commands": bool(commands),
    }
    payload = {
        "scene_id": normalized["scene_id"],
        "scene_spec": normalized,
        "commands": commands,
        "html": "",
        "metadata": metadata,
        "geogebra": {
            "app_name": str(_nested_get(normalized, ("geogebra", "app_name")) or "classic"),
            "commands": commands,
            "caption": str(
                _nested_get(normalized, ("geogebra", "caption"))
                or normalized.get("fallback_text")
                or "拖动图中的点或滑块，观察关系变化。",
            ),
        },
    }
    return payload


def normalize_scene_spec(scene_spec: Dict[str, Any]) -> Dict[str, Any]:
    normalized = dict(scene_spec or {})
    normalized.setdefault("subject", "unknown")
    normalized.setdefault("scene_type", "generic")
    normalized.setdefault("objects", [])
    normalized.setdefault("relations", [])
    normalized.setdefault("steps", [])
    normalized.setdefault("render_targets", ["geogebra", "manim"])
    normalized.setdefault("fallback_text", "")
    if not normalized.get("scene_id"):
        canonical = json.dumps(normalized, sort_keys=True, ensure_ascii=False, default=str)
        normalized["scene_id"] = hashlib.sha256(canonical.encode("utf-8")).hexdigest()[:16]
    return normalized


def _commands_from_parameters(parameters: Any) -> List[str]:
    if not isinstance(parameters, dict):
        return []
    commands: List[str] = []
    for raw_name, raw_value in parameters.items():
        name = _safe_identifier(raw_name)
        value = _safe_expression(raw_value)
        if name and value:
            commands.append(f"{name} = {value}")
    return commands


def _commands_from_objects(objects: Any) -> List[str]:
    if not isinstance(objects, list):
        return []
    commands: List[str] = []
    for item in objects:
        if not isinstance(item, dict):
            continue
        object_type = str(item.get("type") or "").strip().lower()
        if object_type not in SUPPORTED_OBJECT_TYPES:
            continue
        if object_type == "point":
            command = _point_command(item)
        elif object_type == "moving_point":
            command = _moving_point_command(item)
        elif object_type == "segment":
            command = _two_point_command("Segment", item)
        elif object_type == "line":
            command = _two_point_command("Line", item)
        elif object_type == "circle":
            command = _circle_command(item)
        elif object_type in {"ellipse", "parabola", "hyperbola"}:
            command = _equation_command(item)
        elif object_type == "function":
            command = _function_command(item)
        elif object_type == "tangent":
            command = _tangent_command(item)
        elif object_type == "text":
            command = _text_command(item)
        elif object_type == "slider":
            command = _slider_command(item)
        else:
            command = ""
        if command:
            commands.append(command)
    return commands


def _commands_from_relations(relations: Any) -> List[str]:
    if not isinstance(relations, list):
        return []
    commands: List[str] = []
    for item in relations:
        if not isinstance(item, dict):
            continue
        relation_type = str(item.get("type") or "").strip().lower()
        if relation_type == "tangent":
            command = _tangent_command(item)
        elif relation_type == "text":
            command = _text_command(item)
        elif relation_type in {"segment", "line"}:
            command = _two_point_command("Segment" if relation_type == "segment" else "Line", item)
        else:
            command = _equation_command(item) if item.get("equation") else ""
        if command:
            commands.append(command)
    return commands


def _commands_from_steps(steps: Any) -> List[str]:
    if not isinstance(steps, list):
        return []
    commands: List[str] = []
    for step in steps:
        if isinstance(step, dict):
            commands.extend(_string_list(step.get("geogebra_commands")))
    return commands


def _point_command(item: Dict[str, Any]) -> str:
    label = _safe_identifier(item.get("id") or item.get("label") or "P")
    x_value = _safe_expression(item.get("x", 0))
    y_value = _safe_expression(item.get("y", 0))
    return f"{label} = ({x_value}, {y_value})" if label else ""


def _moving_point_command(item: Dict[str, Any]) -> str:
    label = _safe_identifier(item.get("id") or item.get("label") or "M")
    path = _safe_identifier(item.get("path") or item.get("on") or "")
    if label and path:
        return f"{label} = Point({path})"
    return _point_command(item)


def _two_point_command(command_name: str, item: Dict[str, Any]) -> str:
    points = _string_list(item.get("points"))
    if len(points) >= 2:
        p1 = _safe_point_ref(points[0])
        p2 = _safe_point_ref(points[1])
        if p1 and p2:
            return f"{command_name}({p1}, {p2})"
    start = _safe_point_ref(item.get("start") or item.get("from"))
    end = _safe_point_ref(item.get("end") or item.get("to"))
    if start and end:
        return f"{command_name}({start}, {end})"
    return ""


def _circle_command(item: Dict[str, Any]) -> str:
    center = _safe_point_ref(item.get("center") or "O")
    radius = _safe_expression(item.get("radius") or item.get("r") or 1)
    if center and radius:
        return f"Circle({center}, {radius})"
    return ""


def _equation_command(item: Dict[str, Any]) -> str:
    equation = _safe_equation(item.get("equation") or item.get("value"))
    if not equation:
        return ""
    label = _safe_identifier(item.get("id") or item.get("label") or "")
    return f"{label}: {equation}" if label else equation


def _function_command(item: Dict[str, Any]) -> str:
    label = _safe_identifier(item.get("id") or item.get("label") or "f")
    expression = _safe_expression(item.get("expression") or item.get("formula") or item.get("equation"))
    if not expression:
        return ""
    if "=" in expression:
        return f"{label}: {expression}"
    return f"{label}(x) = {expression}"


def _tangent_command(item: Dict[str, Any]) -> str:
    point = _safe_point_ref(item.get("point") or "")
    target = _safe_identifier(item.get("target") or item.get("curve") or "")
    if point and target:
        return f"Tangent({point}, {target})"
    return ""


def _text_command(item: Dict[str, Any]) -> str:
    text = str(item.get("text") or item.get("label") or "").replace('"', "'").strip()
    if not text:
        return ""
    at = item.get("at") or item.get("position")
    if isinstance(at, dict):
        x_value = _safe_expression(at.get("x", 0))
        y_value = _safe_expression(at.get("y", 0))
        return f'Text("{text}", ({x_value}, {y_value}))'
    point = _safe_point_ref(at or "")
    return f'Text("{text}", {point})' if point else f'Text("{text}")'


def _slider_command(item: Dict[str, Any]) -> str:
    name = _safe_identifier(item.get("id") or item.get("label") or "")
    minimum = _safe_expression(item.get("min", 0))
    maximum = _safe_expression(item.get("max", 10))
    step = _safe_expression(item.get("step", 0.1))
    if name:
        return f"{name} = Slider({minimum}, {maximum}, {step})"
    return ""


def _safe_identifier(value: Any) -> str:
    text = str(value or "").strip()
    if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", text):
        return text
    return ""


def _safe_point_ref(value: Any) -> str:
    if isinstance(value, dict):
        x_value = _safe_expression(value.get("x", 0))
        y_value = _safe_expression(value.get("y", 0))
        return f"({x_value}, {y_value})" if x_value and y_value else ""
    return _safe_identifier(value)


def _safe_expression(value: Any) -> str:
    text = str(value if value is not None else "").strip()
    if not text:
        return ""
    if len(text) > 160:
        return ""
    if re.search(r"[;{}]|\\|import|while|for|eval|exec|__|\n|\r", text, re.IGNORECASE):
        return ""
    if re.fullmatch(r"[A-Za-z0-9_+\-*/^()., <>=]+", text):
        return text
    return ""


def _safe_equation(value: Any) -> str:
    text = _safe_expression(value)
    if not text:
        return ""
    return text


def _string_list(value: Any) -> List[str]:
    if not isinstance(value, list):
        return []
    return [str(item).strip() for item in value if str(item).strip()]


def _nested_get(data: Dict[str, Any], keys: Iterable[str]) -> Any:
    value: Any = data
    for key in keys:
        if not isinstance(value, dict):
            return None
        value = value.get(key)
    return value


def _dedupe_commands(commands: List[str]) -> List[str]:
    seen = set()
    result: List[str] = []
    for command in commands:
        normalized = command.strip()
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        result.append(normalized)
    return result[:80]

