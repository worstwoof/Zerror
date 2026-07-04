from __future__ import annotations

import json
import logging
import re
from typing import Any, Dict

from backend.app.schemas.card_schema import (
    LectureVideoRequest,
    LectureVideoResponse,
    RichArtifact,
)
from backend.app.services.render_jobs import create_manim_job

from .vivo_client import VivoLMClient


logger = logging.getLogger(__name__)


class LectureVideoService:
    def __init__(self, client: VivoLMClient) -> None:
        self.client = client

    def generate_video(self, request: LectureVideoRequest) -> LectureVideoResponse:
        prompt = request.prompt.strip()
        if not prompt:
            raise ValueError("视频讲解主题不能为空。")

        raw_output = self.client.animation_chat_completion(
            self._build_prompt(request),
        )
        parsed = self._parse_json(raw_output)
        scene_spec = self._build_scene_spec(request=request, parsed=parsed)
        job = create_manim_job(scene_spec)
        title = self._clip(
            str(parsed.get("title") or scene_spec.get("title") or "知识点视频讲解"),
            42,
        )
        artifact = self._artifact_from_job(job, title=title)
        response = LectureVideoResponse(
            title=title,
            subject=str(parsed.get("subject") or request.subject or "").strip(),
            topic=str(parsed.get("topic") or request.topic or self._topic_from_prompt(prompt)).strip(),
            summary=self._clip(
                str(parsed.get("summary") or scene_spec.get("fallback_text") or prompt),
                160,
            ),
            artifact=artifact,
            raw_model_output=raw_output,
        )
        logger.info(
            "lecture video queued title=%s subject=%s topic=%s artifact=%s",
            response.title,
            response.subject,
            response.topic,
            response.artifact.artifact_type,
        )
        return response

    def _build_prompt(self, request: LectureVideoRequest) -> str:
        subject = request.subject.strip() or "从用户输入判断"
        topic = request.topic.strip() or "从用户输入判断"
        return f"""
只返回 JSON，不要 Markdown，不要代码围栏。
你是 Zerror 的知识点视频讲解导演。目标是把学生的一句话需求拆成 60-120 秒的黑板式 Manim 分镜。

用户原话：{request.prompt}
学科提示：{subject}
主题提示：{topic}

要求：
- 只规划讲解分镜，不要写 Python、HTML、JavaScript 或 Manim 代码。
- 适合学生看懂一个知识点：先讲定义/图像/模型，再讲关键关系，最后讲易错点。
- 每个阶段必须先规定画面分区：左侧/中左只放图像、坐标轴、运动对象；右侧只放文字解析和公式卡；底部只放当前阶段字幕。
- 图像元素移动必须有目的：先定位关键对象，再高亮关系，再移动/变形展示变化过程，最后把变化对应到文字或公式。
- 不要把长文字、公式卡、标题压在图像上；文字解析每条短而具体，不能空泛。
- 分镜要饱满：每个阶段都要让学生学到一个明确结论、判定方法或易错边界。
- 数学和物理可以给公式；其他学科公式数组留空。
- steps 每条控制在 36 字以内，5 到 8 条。
- formula_steps 每条只放纯公式或很短的数学/物理关系，不要放长中文。
- summary 用一句话说明这个视频会讲什么。

输出 JSON 字段：
{{
  "title": "视频标题",
  "subject": "学科",
  "topic": "知识点",
  "scene_type": "generic/mechanics/electromagnetism/optics/wave/board_block",
  "summary": "一句话简介",
  "focus_points": ["核心点1", "核心点2", "核心点3"],
  "steps": ["分镜步骤1", "分镜步骤2", "分镜步骤3", "分镜步骤4", "分镜步骤5"],
  "formula_steps": ["公式1", "公式2"],
  "common_traps": ["易错点1", "易错点2"]
}}
""".strip()

    def _build_scene_spec(
        self,
        *,
        request: LectureVideoRequest,
        parsed: Dict[str, Any],
    ) -> Dict[str, Any]:
        prompt = request.prompt.strip()
        subject_text = str(parsed.get("subject") or request.subject or "").strip()
        topic = str(parsed.get("topic") or request.topic or self._topic_from_prompt(prompt)).strip()
        title = self._clip(
            str(parsed.get("title") or f"{topic or '知识点'}视频讲解"),
            42,
        )
        summary = self._clip(
            str(parsed.get("summary") or f"用动画把「{topic or prompt}」的核心关系讲清楚。"),
            90,
        )
        steps = self._list(parsed.get("steps"), limit=8, item_limit=36)
        if len(steps) < 4:
            steps = self._fallback_steps(topic or prompt, subject_text)
        traps = self._list(parsed.get("common_traps"), limit=3, item_limit=32)
        if traps:
            steps = (steps + [f"最后提醒：{item}" for item in traps])[:8]
        focus_points = self._list(parsed.get("focus_points"), limit=4, item_limit=24)
        if not focus_points:
            focus_points = [topic or "核心概念", "关键关系", "易错边界"]
        formulas = self._formula_list(parsed.get("formula_steps"), limit=8)
        scene_type = self._scene_type(
            raw=str(parsed.get("scene_type") or ""),
            subject=subject_text,
            content=" ".join([prompt, topic, summary, " ".join(steps)]),
        )
        scene_subject = "physics" if scene_type != "generic" and self._is_physics(subject_text, prompt) else "general"
        scene_spec: Dict[str, Any] = {
            "schema_version": 2,
            "subject": scene_subject,
            "scene_type": scene_type,
            "title": title,
            "objects": self._deterministic_objects(prompt=prompt, topic=topic),
            "relations": [],
            "parameters": {
                "question_excerpt": self._clip(prompt, 120),
                "focus_points": focus_points,
                "solution_outline": steps,
                "target_duration_seconds": 70,
            },
            "layout": {
                "title_region": "top",
                "visual_region": "left",
                "explanation_region": "right",
                "caption_region": "bottom",
            },
            "audio": {
                "background_music": True,
                "voiceover": False,
                "narration_outline": [summary, *steps[:6]],
            },
            "background_music": True,
            "formula_steps": formulas,
            "steps": steps,
            "render_targets": ["manim"],
            "fallback_text": summary,
            "show_title": True,
            "show_summary": True,
        }
        if scene_type == "board_block":
            scene_spec.update(
                {
                    "board_label": "木板 A",
                    "block_label": "物块 B",
                    "initial_velocity_direction": "left",
                    "force_target": "block",
                    "force_direction": "right",
                    "friction_on_block_direction": "right",
                    "friction_on_board_direction": "left",
                }
            )
        return scene_spec

    def _scene_type(self, *, raw: str, subject: str, content: str) -> str:
        normalized = raw.strip().lower()
        if not self._is_physics(subject, content):
            return "generic"
        allowed = {
            "mechanics",
            "electromagnetism",
            "optics",
            "wave",
            "board_block",
            "generic",
        }
        if normalized in allowed:
            return normalized
        if any(token in content for token in ("磁场", "电场", "洛伦兹", "电磁", "带电粒子")):
            return "electromagnetism"
        if any(token in content for token in ("光路", "透镜", "折射", "反射", "焦距")):
            return "optics"
        if any(token in content for token in ("波", "波长", "频率", "驻波", "周期")):
            return "wave"
        if any(token in content for token in ("木板", "物块", "滑块", "相对运动")):
            return "board_block"
        return "mechanics"

    def _deterministic_objects(self, *, prompt: str, topic: str) -> list[dict[str, Any]]:
        content = f"{prompt} {topic}"
        if any(token in content for token in ("函数", "导数", "单调", "图像", "一次函数", "二次函数")):
            return [
                {"type": "function", "id": "f", "expression": "0.16*(x-3)^2+1"},
                {"type": "point", "id": "A", "label": "A", "x": 3, "y": 1},
            ]
        return []

    def _artifact_from_job(self, job: Dict[str, Any], *, title: str) -> RichArtifact:
        content = {
            "url": job.get("video_url"),
            "video_url": job.get("video_url"),
            "job_id": job.get("job_id"),
            "status": job.get("status"),
            "progress": job.get("progress"),
            "message": job.get("message"),
            "error": job.get("error"),
            "updated_at": job.get("updated_at"),
            "diagnostics": job.get("diagnostics"),
            "duration": job.get("duration"),
            "thumbnail_url": job.get("thumbnail_url"),
        }
        if job.get("status") == "succeeded" and job.get("video_url"):
            return RichArtifact(
                artifact_type="manim_video",
                title=title,
                description="知识点视频讲解已生成。",
                mime_type="application/json",
                content=json.dumps(content, ensure_ascii=False),
            )
        return RichArtifact(
            artifact_type="manim_job",
            title=title,
            description="后台正在生成知识点视频讲解。",
            mime_type="application/json",
            content=json.dumps(content, ensure_ascii=False),
        )

    def _fallback_steps(self, topic: str, subject: str) -> list[str]:
        subject_hint = subject or "这个知识点"
        return [
            f"先明确「{self._clip(topic, 12)}」要解决什么问题",
            f"把{subject_hint}里的核心定义放到图上",
            "再看关键关系如何一步步变化",
            "最后整理易错边界和检查点",
        ]

    def _topic_from_prompt(self, prompt: str) -> str:
        topic = prompt
        for removal in (
            "帮我",
            "请",
            "用视频",
            "视频讲解",
            "视频讲一下",
            "生成视频",
            "动画讲解",
            "讲一下",
            "讲讲",
            "知识点",
            "这个",
        ):
            topic = topic.replace(removal, " ")
        topic = re.sub(r"[\s，。；;、]+", " ", topic).strip()
        return self._clip(topic or "核心知识点", 32)

    def _is_physics(self, subject: str, content: str) -> bool:
        source = f"{subject} {content}".lower()
        return "物理" in source or "physics" in source

    def _list(self, value: Any, *, limit: int, item_limit: int) -> list[str]:
        if not isinstance(value, list):
            return []
        result: list[str] = []
        for item in value:
            text = self._clip(str(item), item_limit)
            if text:
                result.append(text)
            if len(result) >= limit:
                break
        return result

    def _formula_list(self, value: Any, *, limit: int) -> list[str]:
        if not isinstance(value, list):
            return []
        formulas: list[str] = []
        for item in value:
            text = str(item).replace("$$", "").replace("$", "").strip()
            if not text:
                continue
            if len(text) > 80:
                text = text[:80]
            formulas.append(text)
            if len(formulas) >= limit:
                break
        return formulas

    def _parse_json(self, raw_output: str) -> Dict[str, Any]:
        cleaned = raw_output.strip()
        if cleaned.startswith("```"):
            match = re.search(r"```(?:json)?\s*(.*?)```", cleaned, re.DOTALL | re.IGNORECASE)
            if match:
                cleaned = match.group(1).strip()
        try:
            parsed = json.loads(cleaned)
            return parsed if isinstance(parsed, dict) else {}
        except json.JSONDecodeError:
            pass
        match = re.search(r"\{.*\}", cleaned, re.DOTALL)
        if not match:
            return {}
        try:
            parsed = json.loads(match.group(0))
            return parsed if isinstance(parsed, dict) else {}
        except json.JSONDecodeError:
            return {}

    def _clip(self, text: str, limit: int) -> str:
        normalized = re.sub(r"\s+", " ", (text or "").strip())
        if len(normalized) <= limit:
            return normalized
        return normalized[: limit - 1] + "…"
