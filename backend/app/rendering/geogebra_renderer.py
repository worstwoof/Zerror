from __future__ import annotations

import hashlib
import json
import re
from typing import Any, Dict, Iterable, List


SCENE_SPEC_VERSION = 2

SUPPORTED_SCENE_TYPES = {
    "generic",
    "geometry",
    "conic",
    "circle",
    "ellipse",
    "hyperbola",
    "parabola",
    "function_graph",
    "locus_tangent",
    "electromagnetism",
    "charged_particle_magnetic_field",
}

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
    "magnetic_field",
    "vector",
    "trajectory",
}

CONIC_OBJECT_TYPES = {"circle", "ellipse", "hyperbola", "parabola"}


def build_geogebra_scene(scene_spec: Dict[str, Any]) -> Dict[str, Any]:
    """Convert a v2 scene_spec into a safe GeoGebra artifact payload."""

    normalized = normalize_scene_spec(scene_spec)
    validation = validate_scene_spec(normalized)
    commands: List[str] = []
    variants: List[Dict[str, Any]] = []

    if validation["valid"]:
        commands, variants = _commands_from_template(normalized)

    explicit_commands = _safe_command_list(_nested_get(normalized, ("geogebra", "commands")))
    commands = _dedupe_commands([*commands, *explicit_commands])

    if variants:
        for variant in variants:
            variant["commands"] = _dedupe_commands(
                [*_string_list(variant.get("commands")), *explicit_commands]
            )
        if not commands:
            commands = _string_list(variants[0].get("commands"))

    if validation["valid"] and not commands and not variants:
        validation["valid"] = False
        validation["errors"].append("scene_spec did not produce safe GeoGebra commands")

    metadata = {
        "schema_version": SCENE_SPEC_VERSION,
        "supported_scene_types": sorted(SUPPORTED_SCENE_TYPES),
        "supported_objects": sorted(SUPPORTED_OBJECT_TYPES),
        "source": "scene_spec_v2",
        "valid": bool(validation["valid"]),
        "errors": validation["errors"],
        "warnings": validation["warnings"],
        "has_commands": bool(commands),
        "command_count": len(commands),
        "variant_count": len(variants),
        "scene_type": normalized.get("scene_type"),
        "object_count": len(normalized.get("objects", [])),
        "relation_count": len(normalized.get("relations", [])),
        "fallback_text": normalized.get("fallback_text", ""),
    }
    caption = str(
        _nested_get(normalized, ("geogebra", "caption"))
        or normalized.get("fallback_text")
        or "拖动图中的点或滑块，观察图形关系变化。"
    )
    return {
        "scene_id": normalized["scene_id"],
        "scene_spec": normalized,
        "commands": commands,
        "scene_variants": variants,
        "html": "",
        "metadata": metadata,
        "geogebra": {
            "app_name": str(_nested_get(normalized, ("geogebra", "app_name")) or "classic"),
            "commands": commands,
            "caption": caption,
        },
    }


def normalize_scene_spec(scene_spec: Dict[str, Any]) -> Dict[str, Any]:
    normalized = dict(scene_spec or {})
    normalized.setdefault("schema_version", SCENE_SPEC_VERSION)
    normalized.setdefault("subject", "unknown")
    normalized.setdefault("scene_type", "generic")
    normalized.setdefault("objects", [])
    normalized.setdefault("relations", [])
    normalized.setdefault("parameters", {})
    normalized.setdefault("formula_steps", [])
    normalized.setdefault("steps", [])
    normalized.setdefault("render_targets", ["geogebra", "manim"])
    normalized.setdefault("fallback_text", "")

    scene_type = str(normalized.get("scene_type") or "generic").strip().lower()
    aliases = {
        "math_conic": "conic",
        "conic_section": "conic",
        "charged_particle": "charged_particle_magnetic_field",
        "electromagnetic": "electromagnetism",
        "magnetic_field": "charged_particle_magnetic_field",
    }
    normalized["scene_type"] = aliases.get(scene_type, scene_type)

    if not isinstance(normalized.get("objects"), list):
        normalized["objects"] = []
    if not isinstance(normalized.get("relations"), list):
        normalized["relations"] = []
    if not isinstance(normalized.get("parameters"), dict):
        normalized["parameters"] = {}
    if not isinstance(normalized.get("formula_steps"), list):
        normalized["formula_steps"] = []
    if not isinstance(normalized.get("steps"), list):
        normalized["steps"] = []

    if not normalized.get("scene_id"):
        canonical = json.dumps(normalized, sort_keys=True, ensure_ascii=False, default=str)
        normalized["scene_id"] = hashlib.sha256(canonical.encode("utf-8")).hexdigest()[:16]
    return normalized


def validate_scene_spec(scene_spec: Dict[str, Any]) -> Dict[str, Any]:
    errors: List[str] = []
    warnings: List[str] = []
    scene_type = str(scene_spec.get("scene_type") or "generic")
    objects = scene_spec.get("objects") if isinstance(scene_spec.get("objects"), list) else []
    relations = scene_spec.get("relations") if isinstance(scene_spec.get("relations"), list) else []
    raw_commands = _nested_get(scene_spec, ("geogebra", "commands"))

    if scene_type not in SUPPORTED_SCENE_TYPES:
        warnings.append(f"unsupported scene_type '{scene_type}', falling back to generic")

    for item in objects:
        if not isinstance(item, dict):
            warnings.append("ignored non-object item")
            continue
        object_type = str(item.get("type") or "").strip().lower()
        if object_type and object_type not in SUPPORTED_OBJECT_TYPES:
            warnings.append(f"ignored unsupported object type '{object_type}'")

    has_supported_object = any(
        isinstance(item, dict)
        and str(item.get("type") or "").strip().lower() in SUPPORTED_OBJECT_TYPES
        for item in objects
    )
    has_supported_relation = any(isinstance(item, dict) for item in relations)
    has_safe_commands = bool(_safe_command_list(raw_commands))
    has_variants = bool(scene_spec.get("scene_variants"))

    if not any([has_supported_object, has_supported_relation, has_safe_commands, has_variants]):
        errors.append("scene_spec has no supported objects, relations, commands, or variants")

    if scene_type in {"conic", "circle", "ellipse", "hyperbola", "parabola", "locus_tangent"}:
        has_conic = any(
            isinstance(item, dict)
            and str(item.get("type") or "").strip().lower() in CONIC_OBJECT_TYPES
            for item in objects
        )
        if not has_conic and not has_safe_commands:
            errors.append("conic scene requires a circle/ellipse/hyperbola/parabola object or safe commands")

    if scene_type in {"electromagnetism", "charged_particle_magnetic_field"}:
        point_ids = {
            str(item.get("id") or item.get("label") or "").strip()
            for item in objects
            if isinstance(item, dict) and str(item.get("type") or "").lower() == "point"
        }
        if not ({"P", "Q"} <= point_ids):
            warnings.append("electromagnetism scene should include P and Q points")

    return {"valid": not errors, "errors": errors, "warnings": warnings}


def _commands_from_template(scene_spec: Dict[str, Any]) -> tuple[List[str], List[Dict[str, Any]]]:
    scene_type = str(scene_spec.get("scene_type") or "generic")
    if scene_type in {"conic", "circle", "ellipse", "hyperbola", "parabola", "locus_tangent"}:
        return _build_conic_commands(scene_spec), []
    if scene_type == "function_graph":
        return _build_function_commands(scene_spec), []
    if scene_type in {"electromagnetism", "charged_particle_magnetic_field"}:
        return _build_electromagnetism_commands(scene_spec)
    return _build_generic_commands(scene_spec), []


def _build_generic_commands(scene_spec: Dict[str, Any]) -> List[str]:
    return _dedupe_commands(
        [
            *_commands_from_parameters(scene_spec.get("parameters")),
            *_commands_from_objects(scene_spec.get("objects")),
            *_commands_from_relations(scene_spec.get("relations")),
            *_commands_from_steps(scene_spec.get("steps")),
        ]
    )


def _build_conic_commands(scene_spec: Dict[str, Any]) -> List[str]:
    commands = [
        *_commands_from_parameters(scene_spec.get("parameters")),
        *_commands_from_objects(scene_spec.get("objects")),
    ]
    curve_ids = [
        _safe_identifier(item.get("id") or item.get("label") or "")
        for item in scene_spec.get("objects", [])
        if isinstance(item, dict)
        and str(item.get("type") or "").strip().lower() in CONIC_OBJECT_TYPES
    ]
    primary_curve = next((curve_id for curve_id in curve_ids if curve_id), "")

    has_moving_point = any(
        isinstance(item, dict) and str(item.get("type") or "").lower() == "moving_point"
        for item in scene_spec.get("objects", [])
    )
    if primary_curve and not has_moving_point and _looks_like_locus_problem(scene_spec):
        commands.append(f"M = Point({primary_curve})")
        commands.append(f"t = Tangent(M, {primary_curve})")

    commands.extend(_commands_from_relations(scene_spec.get("relations")))
    commands.extend(_commands_from_formula_steps(scene_spec.get("formula_steps")))
    return _dedupe_commands(commands)


def _build_function_commands(scene_spec: Dict[str, Any]) -> List[str]:
    commands = [
        *_commands_from_parameters(scene_spec.get("parameters")),
        *_commands_from_objects(scene_spec.get("objects")),
        *_commands_from_relations(scene_spec.get("relations")),
        *_commands_from_formula_steps(scene_spec.get("formula_steps")),
    ]
    return _dedupe_commands(commands)


def _build_electromagnetism_commands(scene_spec: Dict[str, Any]) -> tuple[List[str], List[Dict[str, Any]]]:
    variants_source = scene_spec.get("scene_variants")
    if isinstance(variants_source, list) and variants_source:
        variants = [
            _build_electromagnetism_variant(scene_spec, variant, index)
            for index, variant in enumerate(variants_source)
            if isinstance(variant, dict)
        ]
    else:
        variants = [
            _build_electromagnetism_variant(
                scene_spec,
                {"id": "main", "title": "带电粒子进出磁场", "condition": "示意"},
                0,
            )
        ]
    commands = _string_list(variants[0].get("commands")) if variants else []
    return commands, variants


def _build_electromagnetism_variant(
    scene_spec: Dict[str, Any],
    variant: Dict[str, Any],
    index: int,
) -> Dict[str, Any]:
    params = scene_spec.get("parameters") if isinstance(scene_spec.get("parameters"), dict) else {}
    a_value = _safe_expression(params.get("a", 4)) or "4"
    b_value = _safe_expression(params.get("b", 10)) or "10"
    l_value = _safe_expression(params.get("L", 3)) or "3"
    left_value = _safe_expression(variant.get("left_boundary_x") or variant.get("x_left") or "")
    if not left_value:
        left_value = "b - L" if index == 0 else "b - L/2"
    curve_height = "a" if index == 0 else "a * 0.75"
    title = str(variant.get("title") or variant.get("id") or f"情形 {index + 1}").strip()
    condition = str(variant.get("condition") or "").strip()
    prefix = f"v{index + 1}_"
    commands = [
        "a = Slider(2, 6, 0.1)",
        "b = Slider(7, 13, 0.1)",
        "L = Slider(1, 5, 0.1)",
        "R = Slider(1.5, 6, 0.1)",
        f"SetValue(a, {a_value})",
        f"SetValue(b, {b_value})",
        f"SetValue(L, {l_value})",
        f"{prefix}left = {left_value}",
        f"{prefix}right = {prefix}left + L",
        f"{prefix}mid = ({prefix}left + {prefix}right) / 2",
        f"{prefix}P = (0, a)",
        f"{prefix}Q = (b, 0)",
        f"{prefix}A = ({prefix}left, -0.35)",
        f"{prefix}B = ({prefix}left, a + 1.2)",
        f"{prefix}C = ({prefix}right, a + 1.2)",
        f"{prefix}D = ({prefix}right, -0.35)",
        f"{prefix}E = ({prefix}left, a)",
        f"{prefix}F = (b, 0.35)",
        f"{prefix}Base1 = (-0.5, -0.35)",
        f"{prefix}Base2 = (b + 1.1, -0.35)",
        f"{prefix}Rail = Segment({prefix}Base1, {prefix}Base2)",
        f"{prefix}field = Polygon({prefix}A, {prefix}B, {prefix}C, {prefix}D)",
        f"{prefix}entry = Segment({prefix}P, {prefix}E)",
        f"{prefix}trace = Curve({prefix}left + (b - {prefix}left) * t, a - {curve_height} * t^2 + 0.35 * t, t, 0, 1)",
        f"{prefix}exit = Segment({prefix}F, {prefix}Q)",
        f"{prefix}vTip = ({prefix}left + 1.15, a)",
        f"{prefix}v0 = Vector({prefix}P, {prefix}vTip)",
        f"{prefix}forceStart = ({prefix}mid, a * 0.42)",
        f"{prefix}forceTip = ({prefix}mid + 0.75, a * 0.42 + 1.05)",
        f"{prefix}force = Vector({prefix}forceStart, {prefix}forceTip)",
        f'Text("{title}", ({prefix}left - 0.2, a + 1.75))',
        f'Text("B", ({prefix}mid, -0.85))',
        f'Text("P", {prefix}P)',
        f'Text("Q", {prefix}Q)',
        f'Text("v0", ({prefix}left + 0.8, a + 0.25))',
        f'Text("R", ({prefix}mid + 0.95, a * 0.42 + 1.05))',
    ]
    if condition:
        commands.append(f'Text("{condition}", ({prefix}left - 0.2, a + 1.38))')
    commands.extend(
        [
            f'Text("×", ({prefix}left + L * 0.20, 0.35))',
            f'Text("×", ({prefix}left + L * 0.50, 0.35))',
            f'Text("×", ({prefix}left + L * 0.80, 0.35))',
            f'Text("×", ({prefix}left + L * 0.20, 1.35))',
            f'Text("×", ({prefix}left + L * 0.50, 1.35))',
            f'Text("×", ({prefix}left + L * 0.80, 1.35))',
            f'Text("×", ({prefix}left + L * 0.20, 2.35))',
            f'Text("×", ({prefix}left + L * 0.50, 2.35))',
            f'Text("×", ({prefix}left + L * 0.80, 2.35))',
        ]
    )
    return {
        "id": str(variant.get("id") or f"case_{index + 1}"),
        "title": title,
        "condition": condition,
        "commands": _dedupe_commands(commands),
        "metadata": {
            "layout": "single_variant",
            "field_direction": str(scene_spec.get("field_direction") or "into_page"),
        },
    }


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
        elif object_type == "vector":
            command = _vector_command(item)
        elif object_type == "trajectory":
            command = _trajectory_command(item)
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
        elif relation_type == "vector":
            command = _vector_command(item)
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
            commands.extend(_safe_command_list(step.get("geogebra_commands")))
    return commands


def _commands_from_formula_steps(steps: Any) -> List[str]:
    if not isinstance(steps, list):
        return []
    commands: List[str] = []
    for index, step in enumerate(steps[:6]):
        if not isinstance(step, dict):
            continue
        label = str(step.get("label") or step.get("text") or "").replace('"', "'").strip()
        formula = str(step.get("formula") or "").replace('"', "'").strip()
        if label:
            commands.append(f'Text("{label}", (-4, {-1 - index * 0.5}))')
        if formula:
            commands.append(f'Text("{formula}", (-1.5, {-1 - index * 0.5}))')
    return commands


def _point_command(item: Dict[str, Any]) -> str:
    label = _safe_identifier(item.get("id") or item.get("label") or "P")
    x_value = _safe_expression(item.get("x", 0))
    y_value = _safe_expression(item.get("y", 0))
    return f"{label} = ({x_value}, {y_value})" if label and x_value and y_value else ""


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
    equation = _safe_equation(item.get("equation") or "")
    if equation:
        label = _safe_identifier(item.get("id") or item.get("label") or "c")
        return f"{label}: {equation}" if label else equation
    center = _safe_point_ref(item.get("center") or "O")
    radius = _safe_expression(item.get("radius") or item.get("r") or 1)
    label = _safe_identifier(item.get("id") or item.get("label") or "")
    command = f"Circle({center}, {radius})" if center and radius else ""
    return f"{label} = {command}" if label and command else command


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
    label = _safe_identifier(item.get("id") or item.get("label") or "")
    if point and target:
        command = f"Tangent({point}, {target})"
        return f"{label} = {command}" if label else command
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


def _vector_command(item: Dict[str, Any]) -> str:
    start = _safe_point_ref(item.get("start") or item.get("from"))
    end = _safe_point_ref(item.get("end") or item.get("to"))
    label = _safe_identifier(item.get("id") or item.get("label") or "")
    if start and end:
        command = f"Vector({start}, {end})"
        return f"{label} = {command}" if label else command
    return ""


def _trajectory_command(item: Dict[str, Any]) -> str:
    expression_x = _safe_expression(item.get("x") or "")
    expression_y = _safe_expression(item.get("y") or "")
    start = _safe_expression(item.get("t_min") or 0)
    end = _safe_expression(item.get("t_max") or 1)
    label = _safe_identifier(item.get("id") or item.get("label") or "trace")
    if expression_x and expression_y:
        return f"{label} = Curve({expression_x}, {expression_y}, t, {start}, {end})"
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
    if len(text) > 180:
        return ""
    if re.search(r"[;{}\\]|import|while|for|eval|exec|__|\n|\r", text, re.IGNORECASE):
        return ""
    if re.fullmatch(r"[A-Za-z0-9_+\-*/^()., <>=]+", text):
        return text
    return ""


def _safe_equation(value: Any) -> str:
    text = _safe_expression(value)
    if not text or "=" not in text:
        return ""
    return text


def _safe_command_list(value: Any) -> List[str]:
    commands = []
    for command in _string_list(value):
        if len(command) > 240:
            continue
        if re.search(r"[;{}\\]|import|while|for|eval|exec|__|\n|\r", command, re.IGNORECASE):
            continue
        commands.append(command)
    return commands


def _looks_like_locus_problem(scene_spec: Dict[str, Any]) -> bool:
    text = " ".join(
        str(part)
        for part in [
            scene_spec.get("title", ""),
            scene_spec.get("fallback_text", ""),
            json.dumps(scene_spec.get("relations", []), ensure_ascii=False),
        ]
    )
    return any(token in text for token in ["轨迹", "切线", "动点", "locus", "tangent"])


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
    return result[:100]
