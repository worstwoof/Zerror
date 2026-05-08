from __future__ import annotations

import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Dict, List


class ManimCatUnavailable(RuntimeError):
    pass


def is_manimcat_configured() -> bool:
    return bool(_base_url() and _api_key())


def render_math_video_with_manimcat(
    *,
    scene_spec: Dict[str, Any],
    job_id: str,
    output_dir: Path,
) -> Path:
    """Render a math scene through an optional external ManimCat service.

    ManimCat is treated as a local sidecar renderer instead of a Python library.
    Keeping it behind this adapter lets us use its math animation workflow
    without changing the app-side `manim_job` contract.
    """

    base_url = _base_url()
    api_key = _api_key()
    if not base_url or not api_key:
        raise ManimCatUnavailable("ManimCat is not configured.")

    submit_response = _request_json(
        "POST",
        f"{base_url}/api/generate",
        api_key=api_key,
        payload=_build_generate_payload(scene_spec),
        timeout=_request_timeout(),
    )
    remote_job_id = str(submit_response.get("jobId") or "").strip()
    if not remote_job_id:
        raise ManimCatUnavailable("ManimCat did not return a jobId.")

    remote_result = _poll_job(
        base_url=base_url,
        api_key=api_key,
        remote_job_id=remote_job_id,
    )
    video_url = str(remote_result.get("video_url") or remote_result.get("videoUrl") or "").strip()
    if not video_url:
        raise ManimCatUnavailable("ManimCat completed without a video URL.")

    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / f"{job_id}.mp4"
    _download_video(video_url, output_path, base_url=base_url, api_key=api_key)
    return output_path


def _build_generate_payload(scene_spec: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "concept": _build_math_concept(scene_spec),
        "outputMode": "video",
        "quality": os.getenv("MANIMCAT_QUALITY", "medium"),
        "videoConfig": {
            "duration": int(os.getenv("MANIMCAT_MATH_DURATION_SECONDS", "70")),
            "pace": "slow",
            "aspectRatio": "16:9",
        },
        "renderCacheKey": _render_cache_key(scene_spec),
    }


def _build_math_concept(scene_spec: Dict[str, Any]) -> str:
    params = scene_spec.get("parameters") if isinstance(scene_spec.get("parameters"), dict) else {}
    question = _plain(params.get("question_excerpt") or scene_spec.get("fallback_text"), 420)
    focus_points = _list_text(params.get("focus_points"), limit=6, item_limit=60)
    steps = _list_text(scene_spec.get("steps"), limit=10, item_limit=120)
    formulas = _list_text(scene_spec.get("formula_steps"), limit=8, item_limit=100)
    title = _plain(scene_spec.get("title") or "数学题 Manim 动画讲解", 80)
    return "\n".join(
        part
        for part in [
            "请生成一段面向中学生的数学题 Manim 动画讲解视频。",
            f"标题：{title}",
            f"题目：{question}" if question else "",
            "要求：视频时长约 60-80 秒，节奏慢一点；先还原题意和图形/坐标/函数关系，再按详解步骤逐步动画化推导，最后给出结论回顾。",
            "如果题目有多个小问，请保留第(1)问、第(2)问等标签，不要合并为一问。",
            "视觉重点：坐标轴、函数图像、几何对象、关键点、辅助线、变化过程和公式对应关系要逐步出现。",
            f"知识点：{'；'.join(focus_points)}" if focus_points else "",
            "详解步骤：\n" + "\n".join(f"{index + 1}. {step}" for index, step in enumerate(steps)) if steps else "",
            "关键公式：\n" + "\n".join(f"- {formula}" for formula in formulas) if formulas else "",
        ]
        if part
    )


def _poll_job(*, base_url: str, api_key: str, remote_job_id: str) -> Dict[str, Any]:
    deadline = time.time() + _job_timeout()
    poll_interval = _poll_interval()
    last_payload: Dict[str, Any] = {}
    while time.time() < deadline:
        payload = _request_json(
            "GET",
            f"{base_url}/api/jobs/{urllib.parse.quote(remote_job_id)}",
            api_key=api_key,
            timeout=_request_timeout(),
        )
        last_payload = payload
        status = str(payload.get("status") or "").lower()
        if status == "completed":
            return payload
        if status in {"failed", "cancelled", "canceled"}:
            raise ManimCatUnavailable(_error_text(payload) or "ManimCat render failed.")
        time.sleep(poll_interval)
    raise ManimCatUnavailable(_error_text(last_payload) or "ManimCat render timed out.")


def _request_json(
    method: str,
    url: str,
    *,
    api_key: str,
    payload: Dict[str, Any] | None = None,
    timeout: int,
) -> Dict[str, Any]:
    data = None
    headers = {"Authorization": f"Bearer {api_key}", "Accept": "application/json"}
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read().decode("utf-8")
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:300]
        raise ManimCatUnavailable(f"ManimCat HTTP {exc.code}: {detail}") from exc
    except urllib.error.URLError as exc:
        raise ManimCatUnavailable(f"ManimCat request failed: {exc.reason}") from exc
    try:
        parsed = json.loads(body)
    except json.JSONDecodeError as exc:
        raise ManimCatUnavailable("ManimCat returned non-JSON response.") from exc
    if not isinstance(parsed, dict):
        raise ManimCatUnavailable("ManimCat returned unexpected response.")
    return parsed


def _download_video(video_url: str, output_path: Path, *, base_url: str, api_key: str) -> None:
    absolute_url = urllib.parse.urljoin(f"{base_url}/", video_url)
    request = urllib.request.Request(
        absolute_url,
        headers={"Authorization": f"Bearer {api_key}"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=_download_timeout()) as response:
            data = response.read()
    except urllib.error.HTTPError as exc:
        if exc.code in {401, 403}:
            # Public/static video URLs often do not accept auth headers.
            with urllib.request.urlopen(absolute_url, timeout=_download_timeout()) as response:
                data = response.read()
        else:
            raise ManimCatUnavailable(f"ManimCat video download failed: HTTP {exc.code}") from exc
    if not data:
        raise ManimCatUnavailable("ManimCat video download returned an empty file.")
    output_path.write_bytes(data)


def _base_url() -> str:
    return os.getenv("MANIMCAT_BASE_URL", "").strip().rstrip("/")


def _api_key() -> str:
    return os.getenv("MANIMCAT_API_KEY", "").strip()


def _request_timeout() -> int:
    return int(os.getenv("MANIMCAT_REQUEST_TIMEOUT_SECONDS", "30"))


def _download_timeout() -> int:
    return int(os.getenv("MANIMCAT_DOWNLOAD_TIMEOUT_SECONDS", "120"))


def _job_timeout() -> int:
    return int(os.getenv("MANIMCAT_JOB_TIMEOUT_SECONDS", "480"))


def _poll_interval() -> float:
    return float(os.getenv("MANIMCAT_POLL_INTERVAL_SECONDS", "4"))


def _render_cache_key(scene_spec: Dict[str, Any]) -> str:
    title = _plain(scene_spec.get("title") or "", 60)
    fallback = _plain(scene_spec.get("fallback_text") or "", 120)
    return f"zerror-math:{title}:{fallback}"


def _list_text(value: Any, *, limit: int, item_limit: int) -> List[str]:
    if not isinstance(value, list):
        return []
    return [_plain(item, item_limit) for item in value[:limit] if _plain(item, item_limit)]


def _plain(value: Any, limit: int) -> str:
    text = str(value or "").replace("\n", " ").strip()
    text = " ".join(text.split())
    if len(text) > limit:
        return text[: limit - 3] + "..."
    return text


def _error_text(payload: Dict[str, Any]) -> str:
    for key in ("error", "message", "details"):
        value = payload.get(key)
        if value:
            return _plain(value, 240)
    return ""
