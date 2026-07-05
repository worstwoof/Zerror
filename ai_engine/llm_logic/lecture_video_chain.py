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
你是 Zerror 的知识点视频讲解导演。目标是把学生的一句话需求拆成 2-4 分钟的 Manim 分阶段动画讲解。

用户原话：{request.prompt}
学科提示：{subject}
主题提示：{topic}

要求：
- 只规划讲解分镜，不要写 Python、HTML、JavaScript 或 Manim 代码。
- 适合学生看懂一个知识点：先讲定义/图像/模型，再讲关键关系，最后讲易错点。
- 视频重点是图形变换演示，不是大段文字讲解；每个阶段都要先发生可见的图像变化，再出现短字幕。
- 每个阶段必须先规定画面分区：左侧/中左放图像、坐标轴、运动对象、轨迹、变形对比；右侧只放 1-2 条短结论或公式卡；底部只放当前阶段字幕。
- 图像元素移动必须有目的：先定位关键对象，再高亮关系，再移动/变形/扫过参数展示变化过程，最后才把变化对应到文字或公式。
- 数学图像必须包含动态过程：点沿曲线运动、曲线拉伸/压缩、切线或割线滑动、参数从小到大变化、边界位置对比等，至少 6 个阶段要有明显运动或变形。
- 物理图像必须包含动态过程：物体位移、受力箭头切换、轨迹生成、相对运动、光线传播或波形振动等，至少 6 个阶段要有明显运动或变形。
- 不要把长文字、公式卡、标题压在图像上；文字解析每条短而具体，不能空泛。右侧文字是辅助，不能替代动画。
- 分镜要饱满：每个阶段都要让学生学到一个明确结论、判定方法或易错边界。
- 数学和物理可以给公式；其他学科公式数组留空。
- 数学题必须选具体 scene_type：椭圆/双曲线/抛物线/离心率/焦点选 conic；函数/导数/单调/图像选 function_graph；平面几何选 geometry。不要把数学题写成 generic。
- teaching_stages 必须 8 到 12 条，不能少于 8 条。
- 每个 teaching_stage 都要包含 visual_action、visual_transform、narration、key_conclusion、checkpoint 五个字段。
- visual_action 写本阶段图像/公式卡如何出现；visual_transform 必须写清楚实际运动/变形/扫过/对比过程，不能写“展示文字”；narration 写底部字幕；key_conclusion 写学生该记住的二级结论；checkpoint 写易错提醒或自检问题。
- steps 是 teaching_stages 的短字幕摘要，每条控制在 36 字以内，8 到 12 条。
- formula_steps 每条只放纯公式或很短的数学/物理关系，不要放长中文。
- summary 用一句话说明这个视频会讲什么。

输出 JSON 字段：
{{
  "title": "视频标题",
  "subject": "学科",
  "topic": "知识点",
  "scene_type": "generic/function_graph/conic/geometry/mechanics/electromagnetism/optics/wave/board_block",
  "summary": "一句话简介",
  "focus_points": ["核心点1", "核心点2", "核心点3"],
  "teaching_stages": [
    {{
      "visual_action": "左侧图像/公式/对象如何变化",
      "visual_transform": "具体图形变换、运动轨迹、参数扫过或形状对比",
      "narration": "底部字幕讲解",
      "key_conclusion": "本阶段必须学会的结论",
      "checkpoint": "易错提醒或自检问题"
    }}
  ],
  "steps": ["阶段字幕1", "阶段字幕2", "阶段字幕3", "阶段字幕4", "阶段字幕5", "阶段字幕6", "阶段字幕7", "阶段字幕8"],
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
        traps = self._list(parsed.get("common_traps"), limit=3, item_limit=32)
        focus_points = self._list(parsed.get("focus_points"), limit=4, item_limit=24)
        if not focus_points:
            focus_points = [topic or "核心概念", "关键关系", "易错边界"]
        formulas = self._formula_list(parsed.get("formula_steps"), limit=8)
        stages = self._teaching_stages(
            parsed.get("teaching_stages"),
            fallback_steps=self._list(parsed.get("steps"), limit=12, item_limit=52),
            topic=topic or prompt,
            subject=subject_text,
            focus_points=focus_points,
            traps=traps,
        )
        steps = [stage["narration"] for stage in stages]
        target_duration_seconds = max(150, min(240, len(stages) * 18))
        scene_type = self._scene_type(
            raw=str(parsed.get("scene_type") or ""),
            subject=subject_text,
            content=" ".join([prompt, topic, summary, " ".join(steps)]),
        )
        content_for_subject = " ".join([prompt, topic, summary, " ".join(steps)])
        if self._is_physics(subject_text, content_for_subject):
            scene_subject = "physics"
        elif self._is_math(subject_text, content_for_subject):
            scene_subject = "math"
        else:
            scene_subject = "general"
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
                "target_duration_seconds": target_duration_seconds,
            },
            "layout": {
                "title_region": "top",
                "visual_region": "left",
                "explanation_region": "right",
                "caption_region": "bottom",
            },
            "background_music": True,
            "formula_steps": formulas,
            "steps": steps,
            "teaching_stages": stages,
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
        math_allowed = {"function_graph", "conic", "geometry", "generic"}
        if self._is_math(subject, content):
            if normalized in math_allowed and normalized != "generic":
                return normalized
            if any(token in content for token in ("椭圆", "双曲线", "抛物线", "圆锥曲线", "离心率", "焦点", "准线", "长轴", "短轴")):
                return "conic"
            if any(token in content for token in ("函数", "导数", "单调", "图像", "极值", "零点", "切线")):
                return "function_graph"
            if any(token in content for token in ("三角形", "圆", "相似", "全等", "角", "垂直", "平行")):
                return "geometry"
            if normalized == "generic":
                return "generic"
            return "generic"
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

    def _is_math(self, subject: str, content: str) -> bool:
        combined = f"{subject} {content}".lower()
        return any(
            token in combined
            for token in (
                "数学",
                "函数",
                "导数",
                "单调",
                "极值",
                "零点",
                "椭圆",
                "双曲线",
                "抛物线",
                "圆锥曲线",
                "离心率",
                "焦点",
                "准线",
                "三角形",
                "几何",
            )
        )

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

    def _teaching_stages(
        self,
        value: Any,
        *,
        fallback_steps: list[str],
        topic: str,
        subject: str,
        focus_points: list[str],
        traps: list[str],
    ) -> list[dict[str, str]]:
        stages: list[dict[str, str]] = []
        if isinstance(value, list):
            for item in value:
                if not isinstance(item, dict):
                    continue
                narration = self._clip(
                    str(item.get("narration") or item.get("subtitle") or ""),
                    52,
                )
                visual_action = self._clip(str(item.get("visual_action") or ""), 56)
                visual_transform = self._clip(
                    str(item.get("visual_transform") or item.get("animation") or ""),
                    72,
                )
                key_conclusion = self._clip(str(item.get("key_conclusion") or ""), 56)
                checkpoint = self._clip(str(item.get("checkpoint") or ""), 56)
                if not any([narration, visual_action, visual_transform, key_conclusion, checkpoint]):
                    continue
                stages.append(
                    {
                        "visual_action": visual_action or "左侧图像区突出当前对象和关系。",
                        "visual_transform": visual_transform
                        or "让关键点、曲线或箭头发生一次可见移动，并同步高亮不变量。",
                        "narration": narration or key_conclusion or "观察当前阶段的关键变化。",
                        "key_conclusion": key_conclusion or narration or "本阶段抓住一个可复述的判断。",
                        "checkpoint": checkpoint or "停一下检查这一步的前提是否满足。",
                    }
                )
                if len(stages) >= 12:
                    break

        for step in fallback_steps:
            if len(stages) >= 8:
                break
            cleaned = self._clip(step, 52)
            if not cleaned:
                continue
            stages.append(
                {
                    "visual_action": "左侧图像区同步高亮这一步对应的对象或公式。",
                    "visual_transform": "移动关键点或扫过参数，让图形变化先发生，再读出结论。",
                    "narration": cleaned,
                    "key_conclusion": cleaned,
                    "checkpoint": "回到题干确认这一步用到的条件。",
                }
            )

        if len(stages) >= 8:
            return stages[:12]

        subject_hint = subject or "这个知识点"
        topic_hint = self._clip(topic or "核心知识点", 16)
        focus_a = focus_points[0] if focus_points else "核心定义"
        focus_b = focus_points[1] if len(focus_points) > 1 else "关键关系"
        focus_c = focus_points[2] if len(focus_points) > 2 else "易错边界"
        trap = traps[0] if traps else "不要把局部结论直接当成全局结论"
        templates = [
            (
                "左侧先放标题和问题对象，右侧列学习目标。",
                "用镜头从完整图形扫到关键对象，先让学生知道看哪里。",
                f"先明确「{topic_hint}」到底要解决什么。",
                f"{topic_hint}不是背结论，要知道它回答哪类问题。",
                "能不能一句话说出本节要判断什么？",
            ),
            (
                "把定义或基础模型放到图像区，并标出关键词。",
                "让点、线、轴或受力箭头依次出现，建立最小模型。",
                f"先把{subject_hint}里的{focus_a}放到图上。",
                "定义是后面判断的出发点，不能跳过。",
                "题干中哪个条件对应这个定义？",
            ),
            (
                "用箭头连接已知条件和待求目标。",
                "用高亮线段或轨迹把已知量连接到目标量。",
                f"看清{focus_b}如何连接题干和结论。",
                "关键关系负责把文字条件转成可操作判断。",
                "这一步有没有偷换变量或区间？",
            ),
            (
                "让图像或对象发生一次有目的的移动。",
                "拖动关键点或参数，从小到大扫一遍，观察结论怎样变。",
                "观察量变化时，结论为什么跟着变化。",
                "动画里的变化要对应到一个明确判断。",
                "变化前后保持不变的量是什么？",
            ),
            (
                "右侧公式卡逐行出现，左侧同步高亮来源。",
                "公式卡只显示一行，左侧同步闪烁公式对应的图形量。",
                "把图像观察翻译成公式或判定规则。",
                "公式不是孤立出现，每一项都要有来源。",
                "公式里的每个符号在题干中代表什么？",
            ),
            (
                "加入一个边界位置或特殊情况做对比。",
                "把图形切到边界位置，再和普通位置做并排对比。",
                f"专门检查{focus_c}，避免结论用过头。",
                "边界情况常常决定答案是否完整。",
                "端点、零点、临界值是否要单独讨论？",
            ),
            (
                "展示一条常见错误路径，再用标记划掉。",
                "让错误路径以灰色虚线出现，再用正确轨迹覆盖。",
                f"易错提醒：{trap}。",
                "识别错法比记住答案更能防止复错。",
                "这类题最容易漏掉哪一个前提？",
            ),
            (
                "最后把图像、公式和检查点收束成清单。",
                "依次闪回三个关键图形状态，形成复习路线。",
                "用三步清单复述：识别、判断、检查。",
                "能复述流程，才算真正看懂这个知识点。",
                "合上视频后能不能独立说出解题路线？",
            ),
        ]
        for visual_action, visual_transform, narration, key_conclusion, checkpoint in templates:
            if len(stages) >= 8:
                break
            stages.append(
                {
                    "visual_action": self._clip(visual_action, 56),
                    "visual_transform": self._clip(visual_transform, 72),
                    "narration": self._clip(narration, 52),
                    "key_conclusion": self._clip(key_conclusion, 56),
                    "checkpoint": self._clip(checkpoint, 56),
                }
            )
        return stages[:12]

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
