from __future__ import annotations

import html
import json
import logging
import re
import time
from typing import Any, Dict, List

from backend.app.schemas.card_schema import (
    AnalysisRequest,
    AnalysisResponse,
    ReviewPlan,
    RichArtifact,
    SimilarQuestion,
)

from .ocr_parser import normalize_ocr_text
from .subject_extensions import (
    _physics_scene_type,
    _build_physics_html,
    build_subject_extension_artifacts,
    filter_subject_extension_artifacts,
)
from .vivo_client import VivoLMClient


logger = logging.getLogger(__name__)


SUBJECT_EXTENSION_HINTS: Dict[str, str] = {
    "物理": "可以额外返回一个 rich_artifacts 项，artifact_type 用 interactive_html，内容为一个可直接嵌入 WebView 的单文件 HTML 动画页面，必须围绕这道题的具体物理情景来做，不要套泛化模板。",
    "化学": "可以额外返回一个 rich_artifacts 项，展示反应流程、实验步骤或分子结构变化，可用 interactive_html 或 chart_spec。",
    "数学": "可以额外返回一个 rich_artifacts 项，用 chart_spec 或 interactive_html 展示函数图像、几何构型或步骤可视化。",
    "编程": "可以额外返回一个 rich_artifacts 项，提供 code_snippet 类型，展示关键代码、执行轨迹或输入输出示例。",
    "生物": "可以额外返回一个 rich_artifacts 项，展示 timeline 或 interactive_html，演示过程流转如代谢、遗传或生态循环。",
}


class DiagnosticService:
    def __init__(self, client: VivoLMClient) -> None:
        self.client = client

    def analyze_text(self, request: AnalysisRequest) -> AnalysisResponse:
        started_at = time.perf_counter()
        cleaned_question = normalize_ocr_text(request.question_text)
        prompt = self._build_text_prompt(request, cleaned_question)
        model_started_at = time.perf_counter()
        raw_output = self.client.chat_completion(prompt)
        logger.info(
            "analysis text model subject=%s elapsed=%.2fs",
            request.subject,
            time.perf_counter() - model_started_at,
        )
        response = self._build_response(
            request=request,
            raw_output=raw_output,
            default_cleaned_question=cleaned_question,
            source="text",
        )
        logger.info(
            "analysis text total subject=%s elapsed=%.2fs",
            response.subject,
            time.perf_counter() - started_at,
        )
        return response

    def analyze_image(
        self,
        request: AnalysisRequest,
        image_bytes: bytes,
        mime_type: str,
        ocr_draft: str,
    ) -> AnalysisResponse:
        started_at = time.perf_counter()
        cleaned_ocr_draft = normalize_ocr_text(ocr_draft)
        prompt = self._build_vision_prompt(request, cleaned_ocr_draft)
        model_started_at = time.perf_counter()
        raw_output = self.client.vision_completion(
            prompt=prompt,
            image_bytes=image_bytes,
            mime_type=mime_type,
        )
        logger.info(
            "analysis image vision subject=%s image_kb=%.1f elapsed=%.2fs",
            request.subject,
            len(image_bytes) / 1024,
            time.perf_counter() - model_started_at,
        )
        response = self._build_response(
            request=request,
            raw_output=raw_output,
            default_cleaned_question=cleaned_ocr_draft,
            source="image",
        )
        logger.info(
            "analysis image total subject=%s resolved_subject=%s elapsed=%.2fs",
            request.subject,
            response.subject,
            time.perf_counter() - started_at,
        )
        return response

    def _build_response(
        self,
        request: AnalysisRequest,
        raw_output: str,
        default_cleaned_question: str,
        source: str,
    ) -> AnalysisResponse:
        started_at = time.perf_counter()
        parse_started_at = time.perf_counter()
        parsed = self._parse_json(raw_output)
        parse_elapsed = time.perf_counter() - parse_started_at
        normalize_started_at = time.perf_counter()
        parsed = self._normalize_math_fields(parsed)
        normalize_elapsed = time.perf_counter() - normalize_started_at
        subject = str(parsed.get("subject") or request.subject or "通用")
        cleaned_question = str(parsed.get("cleaned_question") or default_cleaned_question)
        knowledge_points = [str(item) for item in parsed.get("knowledge_points", []) if str(item).strip()]
        solution_steps = [str(item) for item in parsed.get("solution_steps", []) if str(item).strip()]
        solution_summary = str(parsed.get("solution_summary", "请结合详细步骤继续完善解析。"))

        review_data = parsed.get("review_plan") or {}
        review_plan = ReviewPlan(
            next_review_in_days=int(review_data.get("next_review_in_days", 1)),
            focus=str(review_data.get("focus", "回顾本题核心概念与易错步骤")),
            schedule=list(review_data.get("schedule", [1, 3, 7, 15])),
        )

        similar_questions: List[SimilarQuestion] = [
            SimilarQuestion(
                prompt=str(item.get("prompt", "")),
                answer_outline=str(item.get("answer_outline", "")),
            )
            for item in parsed.get("similar_questions", [])
            if item.get("prompt")
        ]

        rich_artifacts: List[RichArtifact] = [
            RichArtifact(
                artifact_type=item.get("artifact_type", "study_card"),
                title=str(item.get("title", "扩展内容")),
                description=str(item.get("description", "")),
                mime_type=str(item.get("mime_type", "text/plain")),
                content=str(item.get("content", "")),
            )
            for item in parsed.get("rich_artifacts", [])
            if item.get("content")
        ]
        rich_artifacts = filter_subject_extension_artifacts(
            subject=subject,
            cleaned_question=cleaned_question,
            artifacts=rich_artifacts,
        )
        if "物理" in subject:
            rich_artifacts = [
                artifact for artifact in rich_artifacts if artifact.artifact_type != "interactive_html"
            ]
        physics_html_elapsed = 0.0
        if request.enable_subject_extensions:
            if "物理" not in subject:
                rich_artifacts.extend(
                    build_subject_extension_artifacts(
                        subject=subject,
                        cleaned_question=cleaned_question,
                        knowledge_points=knowledge_points,
                        solution_steps=solution_steps,
                        existing_artifacts=rich_artifacts,
                    )
                )

        response = AnalysisResponse(
            question_text=request.question_text,
            cleaned_question=cleaned_question,
            subject=subject,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            solution_steps=solution_steps,
            mistake_diagnosis=str(parsed.get("mistake_diagnosis", "当前未能稳定识别错因，请结合用户答题过程补充。")),
            review_plan=review_plan,
            similar_questions=similar_questions,
            rich_artifacts=rich_artifacts,
            source=source,
            raw_model_output=raw_output,
        )
        logger.info(
            "build response source=%s subject=%s parse_json=%.2fs normalize=%.2fs physics_html=%.2fs artifacts=%s total=%.2fs",
            source,
            response.subject,
            parse_elapsed,
            normalize_elapsed,
            physics_html_elapsed,
            len(response.rich_artifacts),
            time.perf_counter() - started_at,
        )
        return response

    def generate_physics_animation(
        self,
        *,
        cleaned_question: str,
        subject: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> RichArtifact | None:
        normalized_subject = subject or "物理"
        if "物理" not in normalized_subject:
            return None
        scene_type = self._physics_scene_type_from_context(
            cleaned_question=cleaned_question,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            solution_steps=solution_steps,
        )
        logger.info("physics animation scene_type=%s", scene_type)
        if scene_type == "circuit":
            artifact = self._generate_circuit_scene_artifact(
                cleaned_question=cleaned_question,
                knowledge_points=knowledge_points,
                solution_summary=solution_summary,
                solution_steps=solution_steps,
            )
            if artifact is not None:
                logger.info("physics animation used circuit scene spec renderer")
                return artifact
            artifact = self._build_physics_template_artifact(
                cleaned_question=cleaned_question,
                knowledge_points=knowledge_points,
                solution_steps=solution_steps,
            )
            if artifact is not None:
                logger.info("physics animation fell back to local circuit template")
                return artifact
        if scene_type == "electromagnetism":
            artifact = self._generate_electromagnetism_scene_artifact(
                cleaned_question=cleaned_question,
                knowledge_points=knowledge_points,
                solution_summary=solution_summary,
                solution_steps=solution_steps,
            )
            if artifact is not None:
                logger.info("physics animation used electromagnetism scene spec renderer")
                return artifact
            artifact = self._build_electromagnetism_template_artifact(
                cleaned_question=cleaned_question,
                knowledge_points=knowledge_points,
                solution_summary=solution_summary,
                solution_steps=solution_steps,
            )
            if artifact is not None:
                logger.info("physics animation fell back to local electromagnetism template")
                return artifact
        if not self._should_generate_physics_html(
            cleaned_question=cleaned_question,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            solution_steps=solution_steps,
        ):
            return None
        artifact = self._generate_physics_html_artifact(
            cleaned_question=cleaned_question,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            solution_steps=solution_steps,
        )
        return artifact

    def _should_generate_physics_html(
        self,
        *,
        cleaned_question: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> bool:
        scene_type = self._physics_scene_type_from_context(
            cleaned_question=cleaned_question,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            solution_steps=solution_steps,
        )
        return scene_type in {
            "board_block",
            "incline",
            "projectile",
            "collision",
            "mechanics",
            "circuit",
            "electromagnetism",
            "optics",
        }

    def explain_physics_animation_unavailable(
        self,
        *,
        cleaned_question: str,
        subject: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> str:
        normalized_subject = subject or "é—â•ƒæ‚Š"
        if "é—â•ƒæ‚Š" not in normalized_subject:
            return "当前题目未被识别为物理题，暂不支持生成物理动画演示。"

        scene_type = self._physics_scene_type_from_context(
            cleaned_question=cleaned_question,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            solution_steps=solution_steps,
        )
        if scene_type == "unknown":
            return "当前题目没有识别出明确的物理场景关键词，暂不支持自动生成动画。可以补充电路、电流、电压、受力、斜面、碰撞、光路等关键词后重试。"

        return "物理动画生成失败，请稍后重试。"

    def _physics_scene_type_from_context(
        self,
        *,
        cleaned_question: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> str:
        scene_source = " ".join(
            part.strip()
            for part in [
                cleaned_question,
                " ".join(knowledge_points),
                solution_summary,
                " ".join(solution_steps),
            ]
            if part and part.strip()
        )
        return _physics_scene_type(scene_source)

    def _build_text_prompt(self, request: AnalysisRequest, cleaned_question: str) -> str:
        extension_hint = ""
        extension_detail = ""
        if request.enable_subject_extensions:
            for subject_name, hint in SUBJECT_EXTENSION_HINTS.items():
                if subject_name in request.subject:
                    extension_hint = hint
                    extension_detail = self._subject_extension_detail(subject_name)
                    break

        return f"""
你是“错题都队”的学科辅导 AI，需要稳定输出适合前端直接消费的 JSON。

请基于以下输入，输出一个 JSON 对象，不要输出 Markdown，不要加代码块围栏。

输入信息：
- 学科：{request.subject}
- 题目：{cleaned_question}
- 用户答案：{request.user_answer or "未提供"}
- 用户自述错因：{request.wrong_reason_hint or "未提供"}

输出 JSON 字段要求：
{{
  "cleaned_question": "清洗后的题目文本",
  "subject": "学科名",
  "knowledge_points": ["知识点1", "知识点2"],
  "solution_summary": "100字以内总结",
  "solution_steps": ["步骤1", "步骤2", "步骤3"],
  "mistake_diagnosis": "对错因的简明诊断",
  "review_plan": {{
    "next_review_in_days": 1,
    "focus": "本次复习重点",
    "schedule": [1, 3, 7, 15]
  }},
  "similar_questions": [
    {{
      "prompt": "变式题1",
      "answer_outline": "答案提纲"
    }},
    {{
      "prompt": "变式题2",
      "answer_outline": "答案提纲"
    }}
  ],
  "rich_artifacts": [
    {{
      "artifact_type": "interactive_html",
      "title": "扩展展示标题",
      "description": "给前端的简短说明",
      "mime_type": "text/html",
      "content": "<html>...</html>"
    }}
  ]
}}

要求：
1. 所有字段必须返回，没有内容时返回空数组或空字符串。
2. solution_steps 要可读、分步清晰，适合学生复盘。
3. similar_questions 最多返回 2 个。
4. rich_artifacts 默认可为空数组。
5. 凡是公式、方程、积分、根号、分式、上下标、区间、向量、希腊字母，请优先使用 LaTeX 形式表达。
6. 行内公式请用 $...$ 包裹，独立大公式可用 $$...$$ 包裹。
7. 即使整段是中文说明，只要其中出现数学表达式，也请把数学表达式单独写成 LaTeX。
8. {extension_hint or "本题无需额外生成复杂扩展内容，rich_artifacts 可返回空数组。"}
9. {extension_detail or "如果没有把握生成高质量扩展内容，可以让 rich_artifacts 返回空数组。"}
10. 如果题目信息不完整，也尽量给出合理分析并指出缺失点。
""".strip()

    def _build_vision_prompt(self, request: AnalysisRequest, cleaned_ocr_draft: str) -> str:
        extension_hint = ""
        extension_detail = ""
        if request.enable_subject_extensions:
            for subject_name, hint in SUBJECT_EXTENSION_HINTS.items():
                if subject_name in request.subject:
                    extension_hint = hint
                    extension_detail = self._subject_extension_detail(subject_name)
                    break

        return f"""
你是“错题都队”的多模态学科辅导 AI，需要基于“题目图片 + OCR 草稿”输出稳定的 JSON。

请把“图片内容”作为第一信息源，把“OCR 草稿”作为辅助参考，优先纠正 OCR 中的错字、公式、上下标、积分符号、根号、分式、图形标注和换行错误。
不要机械复述 OCR 草稿，如果图片明显更清晰，请以图片为准。

输入信息：
- 学科：{request.subject}
- OCR 草稿：{cleaned_ocr_draft or "未提供"}
- 用户答案：{request.user_answer or "未提供"}
- 用户自述错因：{request.wrong_reason_hint or "未提供"}

输出 JSON 字段要求：
{{
  "cleaned_question": "根据图片纠正后的完整题目文本",
  "subject": "学科名",
  "knowledge_points": ["知识点1", "知识点2"],
  "solution_summary": "100字以内总结",
  "solution_steps": ["步骤1", "步骤2", "步骤3"],
  "mistake_diagnosis": "对错因的简明诊断",
  "review_plan": {{
    "next_review_in_days": 1,
    "focus": "本次复习重点",
    "schedule": [1, 3, 7, 15]
  }},
  "similar_questions": [
    {{
      "prompt": "变式题1",
      "answer_outline": "答案提纲"
    }},
    {{
      "prompt": "变式题2",
      "answer_outline": "答案提纲"
    }}
  ],
  "rich_artifacts": [
    {{
      "artifact_type": "interactive_html",
      "title": "扩展展示标题",
      "description": "给前端的简短说明",
      "mime_type": "text/html",
      "content": "<html>...</html>"
    }}
  ]
}}

要求：
1. 只输出 JSON，不要加 Markdown 代码块。
2. cleaned_question 必须尽量还原图片里的原题；如果仍有局部不确定，可保守表达但不要照搬明显错误的 OCR。
3. 如果是数学、物理、化学题，优先纠正公式、符号、单位和结构。
4. solution_steps 要分步清晰，适合学生复盘。
5. similar_questions 最多返回 2 个。
6. 凡是公式、方程、积分、根号、分式、上下标、区间、向量、希腊字母，请优先使用 LaTeX 形式表达。
7. 行内公式请用 $...$ 包裹，独立大公式可用 $$...$$ 包裹。
8. rich_artifacts 默认可为空数组。
9. {extension_hint or "本题无需额外生成复杂扩展内容，rich_artifacts 可返回空数组。"}
10. {extension_detail or "如果没有把握生成高质量扩展内容，可以让 rich_artifacts 返回空数组。"}
11. 如果图片信息仍不足，也要在 solution_summary 或 mistake_diagnosis 中明确说明不确定点。
""".strip()

    def _parse_json(self, raw_output: str) -> dict:
        cleaned = raw_output.strip()
        if cleaned.startswith("```"):
            match = re.search(r"```(?:json)?\s*(.*?)```", cleaned, re.DOTALL)
            if match:
                cleaned = match.group(1).strip()

        try:
            return self._load_json_with_repairs(cleaned)
        except json.JSONDecodeError:
            # Try to recover the first JSON object if the model wrapped extra prose.
            match = re.search(r"\{.*\}", cleaned, re.DOTALL)
            if not match:
                raise ValueError(f"模型输出不是合法 JSON：{raw_output}")
            return self._load_json_with_repairs(match.group(0))

    def _load_json_with_repairs(self, text: str) -> dict:
        try:
            parsed = json.loads(text)
            if isinstance(parsed, dict):
                return parsed
            raise ValueError("模型输出不是 JSON 对象。")
        except json.JSONDecodeError:
            repaired = self._repair_common_json_issues(text)
            parsed = json.loads(repaired)
            if isinstance(parsed, dict):
                return parsed
            raise ValueError("模型输出不是 JSON 对象。")

    def _repair_common_json_issues(self, text: str) -> str:
        repaired = self._escape_invalid_backslashes_in_json_strings(text)
        repaired = re.sub(r",(\s*[}\]])", r"\1", repaired)
        return repaired

    def _escape_invalid_backslashes_in_json_strings(self, text: str) -> str:
        result: List[str] = []
        in_string = False
        escape_active = False
        index = 0
        length = len(text)
        valid_escapes = {'"', "\\", "/", "b", "f", "n", "r", "t", "u"}

        while index < length:
            char = text[index]

            if not in_string:
                result.append(char)
                if char == '"':
                    in_string = True
                    escape_active = False
                index += 1
                continue

            if escape_active:
                result.append(char)
                escape_active = False
                index += 1
                continue

            if char == "\\":
                next_char = text[index + 1] if index + 1 < length else ""
                if next_char in valid_escapes:
                    result.append(char)
                    escape_active = True
                else:
                    result.append("\\\\")
                index += 1
                continue

            result.append(char)
            if char == '"':
                in_string = False
            index += 1

        return "".join(result)

    def _subject_extension_detail(self, subject_name: str) -> str:
        if subject_name == "物理":
            return (
                "如果返回 interactive_html，请严格满足以下要求："
                "1. 必须是完整单文件 HTML，内联 CSS 和 JavaScript，不依赖外部 CDN、图片或脚本；"
                "2. 页面主体以动画和交互展示为主，不要大段重复题干，不要把整道题原文塞进页面；"
                "3. 必须围绕题目里的具体对象和过程来演示，例如木板-物块相对运动、受力方向、速度变化、电路状态或真实光路；"
                "4. 页面默认适配手机竖屏，建议包含开始/暂停、重置、参数滑块或状态切换；"
                "5. 如果题目是板块运动、斜面、连接体、摩擦或碰撞，必须优先生成力学情景动画，不能误生成光学模板；"
                "6. 页面中的标签、按钮和参数说明请直接使用普通文本或 Unicode 字符，不要输出未渲染的 LaTeX 源码；"
                "7. 只保留简短标题、关键参数和必要标签，重点展示动态过程。"
            )
        if subject_name == "数学":
            return (
                "如果返回 chart_spec 或 interactive_html，请优先围绕函数图像、几何构型、统计图或步骤可视化来设计，不要只返回文字摘要。"
            )
        if subject_name == "化学":
            return (
                "如果返回 study_card 或 interactive_html，请优先呈现反应条件、实验现象、守恒关系和关键步骤，不要只重复题干。"
            )
        if subject_name == "编程":
            return (
                "如果返回 code_snippet，请包含代码骨架、关键状态说明、样例输入输出或调试要点。"
            )
        if subject_name == "生物":
            return (
                "如果返回 timeline 或 interactive_html，请突出过程阶段、场所变化、物质或结构变化。"
            )
        return ""

    def _generate_physics_html_artifact(
        self,
        *,
        cleaned_question: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> RichArtifact | None:
        prompt = self._build_physics_html_prompt(
            cleaned_question=cleaned_question,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            solution_steps=solution_steps,
        )
        started_at = time.perf_counter()
        try:
            raw_html = self.client.chat_completion(prompt)
        except Exception as exc:
            logger.warning(
                "physics html generation failed elapsed=%.2fs error=%s",
                time.perf_counter() - started_at,
                exc,
            )
            return None

        html_document = self._extract_html_document(raw_html)
        if not html_document:
            logger.warning(
                "physics html generation returned empty html elapsed=%.2fs",
                time.perf_counter() - started_at,
            )
            return None

        candidate = RichArtifact(
            artifact_type="interactive_html",
            title="题目情景动画演示",
            description="根据题目具体情景生成的物理交互演示页面。",
            mime_type="text/html",
            content=html_document,
        )
        validated = filter_subject_extension_artifacts(
            subject="物理",
            cleaned_question=cleaned_question,
            artifacts=[candidate],
        )
        return validated[0] if validated else None

    def _generate_circuit_scene_artifact(
        self,
        *,
        cleaned_question: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> RichArtifact | None:
        prompt = self._build_circuit_scene_prompt(
            cleaned_question=cleaned_question,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            solution_steps=solution_steps,
        )
        started_at = time.perf_counter()
        try:
            raw_spec = self.client.chat_completion(prompt)
        except Exception as exc:
            logger.warning(
                "circuit scene spec generation failed elapsed=%.2fs error=%s",
                time.perf_counter() - started_at,
                exc,
            )
            return None

        try:
            scene_spec = self._parse_json(raw_spec)
        except Exception as exc:
            logger.warning(
                "circuit scene spec parse failed elapsed=%.2fs error=%s",
                time.perf_counter() - started_at,
                exc,
            )
            return None

        html_document = self._render_circuit_scene_html(
            cleaned_question=cleaned_question,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            scene_spec=scene_spec,
        )
        candidate = RichArtifact(
            artifact_type="interactive_html",
            title=str(scene_spec.get("title") or "电路过程演示"),
            description="电学题使用轻量场景规格驱动的本地渲染页面。",
            mime_type="text/html",
            content=html_document,
        )
        validated = filter_subject_extension_artifacts(
            subject="物理",
            cleaned_question=cleaned_question,
            artifacts=[candidate],
        )
        return validated[0] if validated else None

    def _build_circuit_scene_prompt(
        self,
        *,
        cleaned_question: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> str:
        points = ", ".join(knowledge_points[:4]) or "电路分析"
        steps = "\n".join(f"- {step}" for step in solution_steps[:3]) or "- 提炼连接方式、电流路径和表计变化。"
        return f"""
You are generating a compact circuit scene specification for a mobile WebView.
Return JSON only. Do not output HTML. Do not output Markdown.

Question:
{cleaned_question}

Knowledge points:
{points}

Solution summary:
{solution_summary}

Key steps:
{steps}

Return a JSON object with this shape:
{{
  "title": "short Chinese title",
  "layout": "series|parallel|mixed",
  "components": ["battery", "switch", "resistor", "bulb", "ammeter", "voltmeter"],
  "focus_points": ["point 1", "point 2", "point 3"],
  "phenomenon_summary": "one short sentence",
  "interaction_hint": "one short sentence",
  "current_direction": "clockwise|counterclockwise"
}}

Requirements:
1. Keep it short and specific to the question.
2. `components` should contain at most 6 items.
3. `focus_points` should contain 2 to 4 short items.
4. Prefer `parallel` when the question clearly mentions parallel branches, otherwise use `series` or `mixed`.
5. All values should be plain strings or string arrays.
""".strip()

    def _render_circuit_scene_html(
        self,
        *,
        cleaned_question: str,
        knowledge_points: List[str],
        solution_summary: str,
        scene_spec: Dict[str, Any],
    ) -> str:
        title = html.escape(
            str(scene_spec.get("title") or cleaned_question[:28] or "电路过程演示")
        )
        layout = str(scene_spec.get("layout") or self._guess_circuit_layout(cleaned_question)).lower()
        if layout not in {"series", "parallel", "mixed"}:
            layout = "mixed"

        raw_components = scene_spec.get("components")
        components = [
            str(item).strip()
            for item in raw_components
            if str(item).strip()
        ] if isinstance(raw_components, list) else []
        if not components:
            components = self._guess_circuit_components(cleaned_question, knowledge_points)

        raw_focus_points = scene_spec.get("focus_points")
        focus_points = [
            str(item).strip()
            for item in raw_focus_points
            if str(item).strip()
        ] if isinstance(raw_focus_points, list) else []
        if not focus_points:
            focus_points = [item for item in knowledge_points[:3] if item.strip()]
        if not focus_points:
            focus_points = ["先判断连接方式", "再看电流路径", "最后分析表计变化"]

        phenomenon_summary = html.escape(
            str(scene_spec.get("phenomenon_summary") or solution_summary or "观察开关状态与电流路径变化。")
        )
        interaction_hint = html.escape(
            str(scene_spec.get("interaction_hint") or "切换开关并拖动电流强度，观察灯泡亮度和电流路径。")
        )
        current_direction = str(scene_spec.get("current_direction") or "clockwise").lower()
        direction_label = "顺时针" if current_direction != "counterclockwise" else "逆时针"

        component_labels = [html.escape(item) for item in components[:6]]
        chips_html = "".join(f'<span class="chip">{label}</span>' for label in component_labels)
        focus_html = "".join(
            f"<li>{html.escape(item)}</li>" for item in focus_points[:4]
        )
        summary_line = html.escape(cleaned_question[:84])

        if layout == "parallel":
            svg_markup = """
      <svg viewBox="0 0 520 260" aria-label="并联电路演示图">
        <rect x="30" y="28" width="460" height="190" rx="24" fill="rgba(255,255,255,0.03)" />
        <line x1="78" y1="122" x2="108" y2="122" class="wire" />
        <line x1="108" y1="94" x2="108" y2="150" class="wire" />
        <line x1="92" y1="100" x2="92" y2="144" class="wire thin" />
        <path d="M108 122 H170 V78 H360 V122" class="wire" fill="none" />
        <path d="M170 122 V168 H360 V122" class="wire" fill="none" />
        <circle cx="394" cy="122" r="28" class="meter" />
        <rect x="212" y="62" width="72" height="22" rx="11" class="resistor" />
        <rect x="212" y="156" width="72" height="22" rx="11" class="resistor alt" />
        <circle cx="318" cy="78" r="18" class="lamp" id="lampUpper" />
        <circle cx="318" cy="168" r="18" class="lamp" id="lampLower" />
        <circle class="charge">
          <animateMotion dur="2.8s" repeatCount="indefinite" path="M108 122 H170 V78 H360 V122" />
        </circle>
        <circle class="charge alt">
          <animateMotion dur="3.1s" repeatCount="indefinite" path="M108 122 H170 V168 H360 V122" />
        </circle>
        <text x="62" y="92" class="label">电源</text>
        <text x="382" y="128" class="label">A</text>
        <text x="220" y="58" class="label subtle">支路 1</text>
        <text x="220" y="152" class="label subtle">支路 2</text>
      </svg>
"""
        else:
            svg_markup = """
      <svg viewBox="0 0 520 260" aria-label="串联电路演示图">
        <rect x="30" y="28" width="460" height="190" rx="24" fill="rgba(255,255,255,0.03)" />
        <line x1="80" y1="122" x2="110" y2="122" class="wire" />
        <line x1="110" y1="92" x2="110" y2="152" class="wire" />
        <line x1="94" y1="100" x2="94" y2="144" class="wire thin" />
        <path d="M110 122 H186" class="wire" />
        <line x1="186" y1="122" x2="218" y2="122" class="wire switch-base" />
        <line x1="218" y1="122" x2="248" y2="106" class="switch-blade" id="switchBlade" />
        <line x1="254" y1="122" x2="320" y2="122" class="wire" />
        <rect x="320" y="108" width="72" height="28" rx="14" class="resistor" />
        <circle cx="430" cy="122" r="24" class="lamp" id="lampMain" />
        <path d="M454 122 H470 V182 H110 V152" class="wire" fill="none" />
        <circle class="charge">
          <animateMotion dur="2.9s" repeatCount="indefinite" path="M110 122 H186 L248 106 H320 H392 A38 38 0 0 1 454 122 H470 V182 H110 V152" />
        </circle>
        <text x="62" y="92" class="label">电源</text>
        <text x="176" y="98" class="label subtle">S</text>
        <text x="334" y="104" class="label subtle">R</text>
        <text x="422" y="128" class="label">L</text>
      </svg>
"""

        state_closed = json.dumps(
            str(scene_spec.get("phenomenon_summary") or "闭合开关后形成完整回路，观察电流通过主要元件的路径。"),
            ensure_ascii=False,
        )
        state_open = json.dumps(
            "断开开关后回路被切断，电荷动画减弱，灯泡亮度下降。",
            ensure_ascii=False,
        )

        return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{title}</title>
  <style>
    :root {{
      color-scheme: dark;
      --accent: #ffd6a0;
      --accent-2: #a7d7c5;
      --panel: rgba(255,255,255,0.08);
      --line: rgba(255,255,255,0.12);
      --glow: 0.65;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font-family: "Noto Sans SC", "Microsoft YaHei", sans-serif;
      background:
        radial-gradient(circle at top, rgba(109,176,154,0.18), transparent 32%),
        linear-gradient(180deg, #142220, #0e1514 72%);
      color: #f5efe5;
      padding: 14px;
    }}
    .shell {{ display: grid; gap: 12px; }}
    .card {{
      border-radius: 22px;
      padding: 16px;
      background: var(--panel);
      border: 1px solid var(--line);
      backdrop-filter: blur(10px);
    }}
    .headline {{
      display: flex;
      justify-content: space-between;
      align-items: start;
      gap: 12px;
    }}
    .title {{
      margin: 0;
      font-size: 20px;
      font-weight: 700;
      line-height: 1.3;
    }}
    .layout-badge {{
      border-radius: 999px;
      padding: 6px 10px;
      background: rgba(255,214,160,0.12);
      color: #fff3de;
      font-size: 12px;
      white-space: nowrap;
    }}
    .subtitle {{
      margin-top: 8px;
      color: #d6ddd7;
      font-size: 13px;
      line-height: 1.6;
    }}
    .chips {{
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-top: 12px;
    }}
    .chip {{
      border-radius: 999px;
      padding: 6px 10px;
      background: rgba(167,215,197,0.12);
      color: #edf5f0;
      font-size: 12px;
    }}
    .stage {{
      border-radius: 22px;
      overflow: hidden;
      background: linear-gradient(180deg, rgba(255,255,255,0.04), rgba(255,255,255,0.015));
    }}
    svg {{
      width: 100%;
      height: 280px;
      display: block;
    }}
    .wire {{
      stroke: #ecdcb7;
      stroke-width: 6;
      stroke-linecap: round;
      stroke-linejoin: round;
      fill: none;
    }}
    .wire.thin {{
      stroke-width: 3;
    }}
    .resistor {{
      fill: #3f6760;
      stroke: #9cd4c2;
      stroke-width: 3;
    }}
    .resistor.alt {{
      fill: #41586f;
      stroke: #b0d0ff;
    }}
    .meter {{
      fill: rgba(255,214,160,0.18);
      stroke: var(--accent);
      stroke-width: 5;
    }}
    .lamp {{
      fill: rgba(255,214,160,0.18);
      stroke: var(--accent);
      stroke-width: 5;
      filter: drop-shadow(0 0 calc(10px + 18px * var(--glow)) rgba(255,214,160,0.45));
    }}
    .charge {{
      r: 6;
      fill: #ffd6a0;
      opacity: 0.92;
    }}
    .charge.alt {{
      fill: #a7d7c5;
    }}
    .label {{
      fill: #f9f4ea;
      font-size: 14px;
    }}
    .label.subtle {{
      fill: #ced9d2;
      font-size: 12px;
    }}
    .switch-blade {{
      stroke: #ffd6a0;
      stroke-width: 6;
      stroke-linecap: round;
      transition: transform 220ms ease;
      transform-origin: 218px 122px;
    }}
    body[data-switch="open"] .switch-blade {{
      transform: rotate(-18deg);
    }}
    body[data-switch="open"] .charge {{
      opacity: 0.12;
    }}
    body[data-switch="open"] .lamp {{
      filter: drop-shadow(0 0 0 rgba(255,214,160,0));
      fill: rgba(255,214,160,0.08);
    }}
    .panel-grid {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 10px;
    }}
    .mini {{
      border-radius: 16px;
      background: rgba(0,0,0,0.12);
      padding: 12px;
    }}
    .mini-key {{
      color: #c8d2cc;
      font-size: 12px;
      margin-bottom: 6px;
    }}
    .mini-value {{
      color: #fff3de;
      font-size: 16px;
      font-weight: 700;
      line-height: 1.6;
    }}
    .controls {{
      display: grid;
      gap: 10px;
    }}
    .buttons {{
      display: flex;
      gap: 10px;
    }}
    button {{
      flex: 1;
      border: 0;
      border-radius: 14px;
      padding: 12px 14px;
      font-size: 14px;
      font-weight: 700;
      cursor: pointer;
    }}
    .primary {{
      background: var(--accent);
      color: #171712;
    }}
    .secondary {{
      background: rgba(255,255,255,0.07);
      color: #eef3ea;
      border: 1px solid rgba(255,255,255,0.1);
    }}
    .slider-row {{
      display: grid;
      gap: 6px;
    }}
    .slider-label {{
      display: flex;
      justify-content: space-between;
      font-size: 12px;
      color: #d3ddd6;
    }}
    input[type="range"] {{
      width: 100%;
      accent-color: var(--accent);
    }}
    ul {{
      margin: 0;
      padding-left: 18px;
      color: #e7efe9;
      line-height: 1.7;
      font-size: 13px;
    }}
  </style>
</head>
<body data-scene="circuit" data-layout="{layout}" data-switch="closed">
  <div class="shell">
    <section class="card">
      <div class="headline">
        <h2 class="title">{title}</h2>
        <div class="layout-badge">{html.escape(layout)} / 电流方向 {direction_label}</div>
      </div>
      <div class="subtitle">{summary_line}</div>
      <div class="chips">{chips_html}</div>
    </section>

    <section class="card stage">
{svg_markup}
    </section>

    <section class="card">
      <div class="panel-grid">
        <div class="mini">
          <div class="mini-key">关键现象</div>
          <div class="mini-value" id="stateText">{phenomenon_summary}</div>
        </div>
        <div class="mini">
          <div class="mini-key">交互提示</div>
          <div class="mini-value">{interaction_hint}</div>
        </div>
      </div>
    </section>

    <section class="card controls">
      <div class="buttons">
        <button class="primary" id="switchBtn">断开开关</button>
        <button class="secondary" id="resetBtn">恢复默认</button>
      </div>
      <label class="slider-row">
        <div class="slider-label"><span>电流强度</span><span id="strengthValue">3</span></div>
        <input id="strengthSlider" type="range" min="1" max="5" step="1" value="3" />
      </label>
      <div class="mini">
        <div class="mini-key">复盘重点</div>
        <ul>{focus_html}</ul>
      </div>
    </section>
  </div>

  <script>
    const root = document.body;
    const switchBtn = document.getElementById('switchBtn');
    const resetBtn = document.getElementById('resetBtn');
    const strengthSlider = document.getElementById('strengthSlider');
    const strengthValue = document.getElementById('strengthValue');
    const stateText = document.getElementById('stateText');
    const stateClosed = {state_closed};
    const stateOpen = {state_open};

    function setGlow(level) {{
      const glow = 0.2 + level * 0.16;
      root.style.setProperty('--glow', glow.toFixed(2));
      strengthValue.textContent = String(level);
    }}

    function setSwitchState(opened) {{
      root.dataset.switch = opened ? 'open' : 'closed';
      switchBtn.textContent = opened ? '闭合开关' : '断开开关';
      stateText.textContent = opened ? stateOpen : stateClosed;
    }}

    switchBtn.addEventListener('click', () => {{
      setSwitchState(root.dataset.switch !== 'open');
    }});

    resetBtn.addEventListener('click', () => {{
      strengthSlider.value = '3';
      setGlow(3);
      setSwitchState(false);
    }});

    strengthSlider.addEventListener('input', () => {{
      setGlow(Number(strengthSlider.value));
    }});

    setGlow(3);
    setSwitchState(false);
  </script>
</body>
</html>"""

    def _guess_circuit_layout(self, cleaned_question: str) -> str:
        lowered = cleaned_question.lower()
        if any(token in lowered for token in ["并联", "支路", "两灯", "两个支路"]):
            return "parallel"
        if any(token in lowered for token in ["混联", "复杂电路", "滑动变阻器"]):
            return "mixed"
        return "series"

    def _guess_circuit_components(
        self,
        cleaned_question: str,
        knowledge_points: List[str],
    ) -> List[str]:
        lowered = f"{cleaned_question} {' '.join(knowledge_points)}".lower()
        components = ["电源", "开关"]
        mapping = [
            ("电阻", ["电阻", "定值电阻", "r"]),
            ("灯泡", ["灯泡", "小灯泡"]),
            ("电流表", ["电流表", "电流计", "a表"]),
            ("电压表", ["电压表", "v表"]),
            ("滑动变阻器", ["滑动变阻器", "变阻器"]),
        ]
        for label, keywords in mapping:
            if any(keyword in lowered for keyword in keywords):
                components.append(label)
        return components[:6]

    def _generate_electromagnetism_scene_artifact(
        self,
        *,
        cleaned_question: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> RichArtifact | None:
        prompt = self._build_electromagnetism_scene_prompt(
            cleaned_question=cleaned_question,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            solution_steps=solution_steps,
        )
        started_at = time.perf_counter()
        try:
            raw_spec = self.client.chat_completion(prompt)
        except Exception as exc:
            logger.warning(
                "electromagnetism scene spec generation failed elapsed=%.2fs error=%s",
                time.perf_counter() - started_at,
                exc,
            )
            return None

        try:
            scene_spec = self._parse_json(raw_spec)
        except Exception as exc:
            logger.warning(
                "electromagnetism scene spec parse failed elapsed=%.2fs error=%s",
                time.perf_counter() - started_at,
                exc,
            )
            return None

        html_document = self._render_electromagnetism_scene_html_v2(
            cleaned_question=cleaned_question,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            scene_spec=scene_spec,
        )
        candidate = RichArtifact(
            artifact_type="interactive_html",
            title=str(scene_spec.get("title") or "电磁过程演示"),
            description="电磁题使用轻量场景规格驱动的本地渲染页面。",
            mime_type="text/html",
            content=html_document,
        )
        validated = filter_subject_extension_artifacts(
            subject="物理",
            cleaned_question=cleaned_question,
            artifacts=[candidate],
        )
        return validated[0] if validated else None

    def _build_electromagnetism_scene_prompt(
        self,
        *,
        cleaned_question: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> str:
        points = ", ".join(knowledge_points[:4]) or "电磁分析"
        steps = "\n".join(f"- {step}" for step in solution_steps[:3]) or "- 提炼场的方向、受力方向和关键现象。"
        return f"""
You are generating a compact electromagnetism scene specification for a mobile WebView.
Return JSON only. Do not output HTML. Do not output Markdown.

Question:
{cleaned_question}

Knowledge points:
{points}

Solution summary:
{solution_summary}

Key steps:
{steps}

Return a JSON object with this shape:
{{
  "title": "short Chinese title",
  "subtype": "charged_particle|electromagnetic_induction",
  "field_type": "magnetic|electric|mixed",
  "field_marker": "cross|dot|line",
  "trajectory": "arc_up|arc_down|straight|circle",
  "charge_sign": "positive|negative|unknown",
  "velocity_direction": "left|right|up|down",
  "force_direction": "up|down|left|right|none",
  "rod_motion_direction": "left|right",
  "focus_points": ["point 1", "point 2", "point 3"],
  "phenomenon_summary": "one short sentence",
  "interaction_hint": "one short sentence",
  "direction_hint": "one short sentence"
}}

Requirements:
1. Keep it short and specific to the question.
2. Prefer `charged_particle` for 粒子偏转、洛伦兹力、圆周轨迹.
3. Prefer `electromagnetic_induction` for 导体棒、线圈、磁通量、感应电流.
4. `focus_points` should contain 2 to 4 short items.
5. Use `field_marker=cross` for magnetic field into the page, `dot` for out of the page.
6. Use `trajectory` and `force_direction` only when they are clear from the question or the solution.
7. All values should be plain strings or string arrays.
""".strip()

    def _render_electromagnetism_scene_html(
        self,
        *,
        cleaned_question: str,
        knowledge_points: List[str],
        solution_summary: str,
        scene_spec: Dict[str, Any],
    ) -> str:
        title = html.escape(
            str(scene_spec.get("title") or cleaned_question[:28] or "电磁过程演示")
        )
        subtype = str(scene_spec.get("subtype") or self._guess_electromagnetism_subtype(cleaned_question)).lower()
        if subtype not in {"charged_particle", "electromagnetic_induction"}:
            subtype = self._guess_electromagnetism_subtype(cleaned_question)

        field_type = str(scene_spec.get("field_type") or "magnetic").lower()
        if field_type not in {"magnetic", "electric", "mixed"}:
            field_type = "magnetic"
        field_marker = self._electromagnetism_choice(
            scene_spec.get("field_marker"),
            {"cross", "dot", "line"},
            "cross" if field_type == "magnetic" else "line",
        )
        trajectory = self._electromagnetism_choice(
            scene_spec.get("trajectory"),
            {"arc_up", "arc_down", "straight", "circle"},
            "arc_up" if subtype == "charged_particle" else "straight",
        )
        charge_sign = self._electromagnetism_choice(
            scene_spec.get("charge_sign"),
            {"positive", "negative", "unknown"},
            "positive",
        )
        velocity_direction = self._electromagnetism_choice(
            scene_spec.get("velocity_direction"),
            {"left", "right", "up", "down"},
            "right",
        )
        force_direction = self._electromagnetism_choice(
            scene_spec.get("force_direction"),
            {"up", "down", "left", "right", "none"},
            "up",
        )
        rod_motion_direction = self._electromagnetism_choice(
            scene_spec.get("rod_motion_direction"),
            {"left", "right"},
            "right",
        )

        raw_focus_points = scene_spec.get("focus_points")
        focus_points = [
            str(item).strip()
            for item in raw_focus_points
            if str(item).strip()
        ] if isinstance(raw_focus_points, list) else []
        if not focus_points:
            focus_points = [item for item in knowledge_points[:3] if item.strip()]
        if not focus_points:
            focus_points = ["先判断场方向", "再定受力方向", "最后观察轨迹或感应电流变化"]

        phenomenon_summary = html.escape(
            str(scene_spec.get("phenomenon_summary") or solution_summary or "观察场方向变化带来的运动或电流变化。")
        )
        interaction_hint = html.escape(
            str(scene_spec.get("interaction_hint") or "拖动滑块改变场强，观察轨迹弯曲程度或感应效果。")
        )
        direction_hint = html.escape(
            str(scene_spec.get("direction_hint") or "结合右手定则或左手定则判断方向。")
        )
        summary_line = html.escape(cleaned_question[:84])
        focus_html = "".join(f"<li>{html.escape(item)}</li>" for item in focus_points[:4])
        subtype_label = "带电粒子偏转" if subtype == "charged_particle" else "电磁感应"
        field_badge = {
            "magnetic": "磁场",
            "electric": "电场",
            "mixed": "复合场",
        }[field_type]

        if subtype == "charged_particle":
            particle_path = self._electromagnetism_particle_path(trajectory, velocity_direction)
            velocity_arrow = self._electromagnetism_arrow_line(
                kind="velocity",
                direction=velocity_direction,
                x=92,
                y=144,
                length=72,
            )
            force_arrow = self._electromagnetism_arrow_line(
                kind="force",
                direction=force_direction,
                x=286,
                y=118,
                length=54,
            )
            charge_label = {"positive": "q+", "negative": "q-", "unknown": "q"}[charge_sign]
            field_marks = self._electromagnetism_field_marks(
                field_marker=field_marker,
                x_positions=(238, 286, 334, 382),
                y_positions=(86, 126, 166),
            )
            scene_markup = """
      <svg viewBox="0 0 520 260" aria-label="带电粒子偏转演示图">
        <defs>
          <marker id="arrowHead" markerWidth="10" markerHeight="10" refX="7" refY="3.5" orient="auto">
            <polygon points="0 0, 8 3.5, 0 7" fill="currentColor" />
          </marker>
        </defs>
        <rect x="28" y="28" width="464" height="190" rx="24" fill="rgba(255,255,255,0.03)" />
        <rect x="204" y="54" width="220" height="138" rx="18" fill="rgba(142,188,198,0.08)" stroke="rgba(167,215,197,0.35)" />
        __FIELD_MARKS__
        <path id="particlePath" d="__PARTICLE_PATH__" fill="none" stroke="#ffd6a0" stroke-width="5" stroke-dasharray="10 10" />
        <circle id="particle" r="9" fill="#ffd6a0">
          <animateMotion id="particleMotion" dur="3.2s" repeatCount="indefinite" path="__PARTICLE_PATH__" />
        </circle>
        __VELOCITY_ARROW__
        __FORCE_ARROW__
        <text x="94" y="132" class="label">v</text>
        <text x="294" y="96" class="label">F</text>
        <text x="250" y="48" class="label subtle">__FIELD_BADGE__ 区域</text>
        <text x="46" y="164" class="label subtle">带电粒子 __CHARGE_LABEL__</text>
      </svg>
"""
            scene_markup = (
                scene_markup
                .replace("__FIELD_MARKS__", field_marks)
                .replace("__PARTICLE_PATH__", particle_path)
                .replace("__VELOCITY_ARROW__", velocity_arrow)
                .replace("__FORCE_ARROW__", force_arrow)
                .replace("__FIELD_BADGE__", field_badge)
                .replace("__CHARGE_LABEL__", charge_label)
            )
        else:
            field_marks = self._electromagnetism_field_marks(
                field_marker=field_marker,
                x_positions=(72, 276, 454),
                y_positions=(104, 148),
            )
            rod_arrow = self._electromagnetism_arrow_line(
                kind="velocity",
                direction=rod_motion_direction,
                x=250,
                y=86,
                length=76,
            )
            scene_markup = """
      <svg viewBox="0 0 520 260" aria-label="电磁感应演示图">
        <defs>
          <marker id="arrowHead" markerWidth="10" markerHeight="10" refX="7" refY="3.5" orient="auto">
            <polygon points="0 0, 8 3.5, 0 7" fill="currentColor" />
          </marker>
        </defs>
        <rect x="28" y="28" width="464" height="190" rx="24" fill="rgba(255,255,255,0.03)" />
        <line x1="120" y1="64" x2="120" y2="196" class="rail" />
        <line x1="380" y1="64" x2="380" y2="196" class="rail" />
        <line x1="120" y1="64" x2="380" y2="64" class="wire" />
        <line x1="120" y1="196" x2="380" y2="196" class="wire" />
        <rect id="rod" x="226" y="74" width="24" height="112" rx="12" class="rod" />
        <circle cx="430" cy="130" r="24" class="meter" />
        <path d="M380 64 H430 V196 H380" class="wire" fill="none" />
        __FIELD_MARKS__
        __ROD_ARROW__
        <text x="338" y="92" class="label">v</text>
        <text x="420" y="136" class="label">G</text>
        <text x="188" y="52" class="label subtle">切割__FIELD_BADGE__线</text>
      </svg>
"""
            scene_markup = (
                scene_markup
                .replace("__FIELD_MARKS__", field_marks)
                .replace("__ROD_ARROW__", rod_arrow)
                .replace("__FIELD_BADGE__", field_badge)
            )

        state_closed = json.dumps(
            str(scene_spec.get("phenomenon_summary") or phenomenon_summary),
            ensure_ascii=False,
        )
        state_alt = json.dumps(
            direction_hint,
            ensure_ascii=False,
        )

        return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{title}</title>
  <style>
    :root {{
      color-scheme: dark;
      --accent: #ffd6a0;
      --accent-2: #9ed6ff;
      --panel: rgba(255,255,255,0.08);
      --line: rgba(255,255,255,0.12);
      --curve: 1;
      --field-opacity: 0.7;
      --rod-x: 0px;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font-family: "Noto Sans SC", "Microsoft YaHei", sans-serif;
      background:
        radial-gradient(circle at top, rgba(122, 191, 223, 0.18), transparent 36%),
        linear-gradient(180deg, #101b24, #0c1318 72%);
      color: #f3efe7;
      padding: 14px;
    }}
    .shell {{ display: grid; gap: 12px; }}
    .card {{
      border-radius: 22px;
      padding: 16px;
      background: var(--panel);
      border: 1px solid var(--line);
      backdrop-filter: blur(10px);
    }}
    .headline {{
      display: flex;
      justify-content: space-between;
      align-items: start;
      gap: 12px;
    }}
    .title {{
      margin: 0;
      font-size: 20px;
      font-weight: 700;
      line-height: 1.3;
    }}
    .badge {{
      border-radius: 999px;
      padding: 6px 10px;
      background: rgba(255,214,160,0.12);
      color: #fff3de;
      font-size: 12px;
      white-space: nowrap;
    }}
    .subtitle {{
      margin-top: 8px;
      color: #d2dde0;
      font-size: 13px;
      line-height: 1.6;
    }}
    .stage {{
      border-radius: 22px;
      overflow: hidden;
      background: linear-gradient(180deg, rgba(255,255,255,0.04), rgba(255,255,255,0.015));
    }}
    svg {{
      width: 100%;
      height: 280px;
      display: block;
    }}
    .label {{
      fill: #f9f4ea;
      font-size: 14px;
    }}
    .label.subtle {{
      fill: #cfd9dc;
      font-size: 12px;
    }}
    .arrow-line {{
      stroke-width: 5;
      stroke-linecap: round;
      marker-end: url(#arrowHead);
    }}
    .velocity {{ stroke: #ffd6a0; }}
    .force {{ stroke: #9ed6ff; }}
    .wire, .rail {{
      stroke: #ecdcb7;
      stroke-width: 6;
      stroke-linecap: round;
      fill: none;
    }}
    .rail {{ stroke: #9dc6d3; }}
    .rod {{
      fill: #4f717c;
      stroke: #bde5f0;
      stroke-width: 3;
      transform: translateX(var(--rod-x));
    }}
    .meter {{
      fill: rgba(255,214,160,0.18);
      stroke: var(--accent);
      stroke-width: 5;
    }}
    .panel-grid {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 10px;
    }}
    .mini {{
      border-radius: 16px;
      background: rgba(0,0,0,0.12);
      padding: 12px;
    }}
    .mini-key {{
      color: #c7d3d7;
      font-size: 12px;
      margin-bottom: 6px;
    }}
    .mini-value {{
      color: #fff3de;
      font-size: 16px;
      font-weight: 700;
      line-height: 1.6;
    }}
    .controls {{
      display: grid;
      gap: 10px;
    }}
    .buttons {{
      display: flex;
      gap: 10px;
    }}
    button {{
      flex: 1;
      border: 0;
      border-radius: 14px;
      padding: 12px 14px;
      font-size: 14px;
      font-weight: 700;
      cursor: pointer;
    }}
    .primary {{
      background: var(--accent);
      color: #171712;
    }}
    .secondary {{
      background: rgba(255,255,255,0.07);
      color: #eef3ea;
      border: 1px solid rgba(255,255,255,0.1);
    }}
    .slider-row {{
      display: grid;
      gap: 6px;
    }}
    .slider-label {{
      display: flex;
      justify-content: space-between;
      font-size: 12px;
      color: #d3dde2;
    }}
    input[type="range"] {{
      width: 100%;
      accent-color: var(--accent);
    }}
    ul {{
      margin: 0;
      padding-left: 18px;
      color: #e7eef1;
      line-height: 1.7;
      font-size: 13px;
    }}
  </style>
</head>
<body data-scene="electromagnetism" data-subtype="{subtype}" data-field="{field_type}">
  <div class="shell">
    <section class="card">
      <div class="headline">
        <h2 class="title">{title}</h2>
        <div class="badge">{subtype_label} / {html.escape(field_type)}</div>
      </div>
      <div class="subtitle">{summary_line}</div>
    </section>

    <section class="card stage">
{scene_markup}
    </section>

    <section class="card">
      <div class="panel-grid">
        <div class="mini">
          <div class="mini-key">关键现象</div>
          <div class="mini-value" id="stateText">{phenomenon_summary}</div>
        </div>
        <div class="mini">
          <div class="mini-key">方向提示</div>
          <div class="mini-value" id="directionText">{direction_hint}</div>
        </div>
      </div>
    </section>

    <section class="card controls">
      <div class="buttons">
        <button class="primary" id="toggleBtn">切换说明</button>
        <button class="secondary" id="resetBtn">恢复默认</button>
      </div>
      <label class="slider-row">
        <div class="slider-label"><span>场强 / 运动强度</span><span id="strengthValue">3</span></div>
        <input id="strengthSlider" type="range" min="1" max="5" step="1" value="3" />
      </label>
      <div class="mini">
        <div class="mini-key">复盘重点</div>
        <ul>{focus_html}</ul>
      </div>
      <div style="font-size:12px;color:#c7d3d7;">{interaction_hint}</div>
    </section>
  </div>

  <script>
    const root = document.documentElement;
    const body = document.body;
    const toggleBtn = document.getElementById('toggleBtn');
    const resetBtn = document.getElementById('resetBtn');
    const strengthSlider = document.getElementById('strengthSlider');
    const strengthValue = document.getElementById('strengthValue');
    const stateText = document.getElementById('stateText');
    const directionText = document.getElementById('directionText');
    const statePrimary = {state_closed};
    const stateSecondary = {state_alt};
    let showingPrimary = true;

    function applyStrength(level) {{
      strengthValue.textContent = String(level);
      root.style.setProperty('--curve', (0.55 + level * 0.18).toFixed(2));
      root.style.setProperty('--field-opacity', (0.35 + level * 0.1).toFixed(2));
      root.style.setProperty('--rod-x', `${{(level - 3) * 16}}px`);
    }}

    function resetView() {{
      showingPrimary = true;
      stateText.textContent = statePrimary;
      directionText.textContent = stateSecondary;
      strengthSlider.value = '3';
      applyStrength(3);
    }}

    toggleBtn.addEventListener('click', () => {{
      showingPrimary = !showingPrimary;
      stateText.textContent = showingPrimary ? statePrimary : stateSecondary;
      directionText.textContent = showingPrimary ? stateSecondary : statePrimary;
    }});
    resetBtn.addEventListener('click', resetView);
    strengthSlider.addEventListener('input', () => applyStrength(Number(strengthSlider.value)));
    resetView();
  </script>
</body>
</html>"""

    def _render_electromagnetism_scene_html_v2(
        self,
        *,
        cleaned_question: str,
        knowledge_points: List[str],
        solution_summary: str,
        scene_spec: Dict[str, Any],
    ) -> str:
        subtype = str(
            scene_spec.get("subtype")
            or self._guess_electromagnetism_subtype(cleaned_question)
        ).lower()
        if subtype not in {"charged_particle", "electromagnetic_induction"}:
            subtype = self._guess_electromagnetism_subtype(cleaned_question)

        guessed_field_type = self._guess_electromagnetism_field_type(
            cleaned_question=cleaned_question,
            knowledge_points=knowledge_points,
        )
        field_type = str(scene_spec.get("field_type") or guessed_field_type).lower()
        if field_type not in {"magnetic", "electric", "mixed"}:
            field_type = guessed_field_type

        field_marker = self._electromagnetism_choice(
            scene_spec.get("field_marker"),
            {"cross", "dot", "line"},
            "cross" if field_type != "electric" else "line",
        )
        trajectory = self._electromagnetism_choice(
            scene_spec.get("trajectory"),
            {"arc_up", "arc_down", "straight", "circle"},
            "arc_up" if subtype == "charged_particle" else "straight",
        )
        charge_sign = self._electromagnetism_choice(
            scene_spec.get("charge_sign"),
            {"positive", "negative", "unknown"},
            "positive",
        )
        velocity_direction = self._electromagnetism_choice(
            scene_spec.get("velocity_direction"),
            {"left", "right", "up", "down"},
            "right",
        )
        force_direction = self._electromagnetism_choice(
            scene_spec.get("force_direction"),
            {"up", "down", "left", "right", "none"},
            "up",
        )
        rod_motion_direction = self._electromagnetism_choice(
            scene_spec.get("rod_motion_direction"),
            {"left", "right"},
            "right",
        )

        raw_focus_points = scene_spec.get("focus_points")
        focus_points = [
            str(item).strip()
            for item in raw_focus_points
            if str(item).strip()
        ] if isinstance(raw_focus_points, list) else []
        if not focus_points:
            focus_points = [item for item in knowledge_points[:3] if item.strip()]
        if not focus_points:
            focus_points = ["受力方向", "场方向判断", "运动与偏转关系"]

        title_text = self._display_plain_text(
            str(scene_spec.get("title") or ""),
            limit=18,
        ) or self._guess_electromagnetism_title(
            cleaned_question=cleaned_question,
            subtype=subtype,
            field_type=field_type,
        )
        title = html.escape(title_text)
        phenomenon_summary_text = self._display_plain_text(
            str(scene_spec.get("phenomenon_summary") or solution_summary),
            limit=52,
        ) or self._guess_electromagnetism_summary(
            cleaned_question=cleaned_question,
            subtype=subtype,
            field_type=field_type,
        )
        interaction_hint_text = self._display_plain_text(
            str(scene_spec.get("interaction_hint") or ""),
            limit=48,
        ) or "拖动强度滑块，对比轨迹弯曲、感应强弱或电流变化。"
        direction_hint_text = self._display_plain_text(
            str(scene_spec.get("direction_hint") or ""),
            limit=48,
        ) or "结合受力方向、场方向和运动方向，判断粒子偏转或感应电流方向。"
        question_hint_text = self._display_plain_text(cleaned_question, limit=42)

        phenomenon_summary = html.escape(phenomenon_summary_text)
        interaction_hint = html.escape(interaction_hint_text)
        direction_hint = html.escape(direction_hint_text)
        question_hint = html.escape(question_hint_text)
        focus_html = "".join(
            f"<li>{html.escape(self._display_plain_text(item, limit=22) or item)}</li>"
            for item in focus_points[:4]
        )
        badge_html = "".join(
            f'<span class="scene-chip">{html.escape(self._display_plain_text(item, limit=18) or item)}</span>'
            for item in focus_points[:3]
        )
        subtype_label = "带电粒子运动" if subtype == "charged_particle" else "电磁感应过程"
        field_badge = {
            "magnetic": "磁场",
            "electric": "电场",
            "mixed": "复合场",
        }[field_type]

        if subtype == "charged_particle" and field_type == "electric":
            particle_path = {
                "arc_up": "M68 170 Q180 170 248 148 T430 76",
                "arc_down": "M68 88 Q180 88 248 112 T430 186",
                "straight": "M68 130 H430",
                "circle": "M120 132 Q230 42 340 132 Q230 220 120 132",
            }[trajectory]
            field_arrows = "".join(
                f'<line x1="198" y1="{y}" x2="322" y2="{y}" class="field-arrow" />'
                for y in (92, 122, 152, 182)
            )
            velocity_arrow = self._electromagnetism_arrow_line(
                kind="velocity",
                direction=velocity_direction,
                x=94,
                y=128,
                length=70,
            )
            force_arrow = self._electromagnetism_arrow_line(
                kind="force",
                direction=force_direction,
                x=264,
                y=124,
                length=56,
            )
            charge_label = {"positive": "q+", "negative": "q-", "unknown": "q"}[charge_sign]
            scene_markup = """
      <svg viewBox="0 0 520 260" aria-label="电场中带电粒子运动示意">
        <defs>
          <marker id="arrowHead" markerWidth="10" markerHeight="10" refX="7" refY="3.5" orient="auto">
            <polygon points="0 0, 8 3.5, 0 7" fill="currentColor" />
          </marker>
        </defs>
        <rect x="28" y="28" width="464" height="190" rx="28" class="stage-shell" />
        <rect x="170" y="68" width="180" height="118" rx="20" class="field-zone electric-zone" />
        <rect x="188" y="76" width="18" height="102" rx="9" class="plate positive-plate" />
        <rect x="314" y="76" width="18" height="102" rx="9" class="plate negative-plate" />
        __FIELD_ARROWS__
        <path d="__PARTICLE_PATH__" class="trace electric-trace" />
        <circle class="particle electric-particle" r="9">
          <animateMotion dur="3.4s" repeatCount="indefinite" path="__PARTICLE_PATH__" />
        </circle>
        __VELOCITY_ARROW__
        __FORCE_ARROW__
        <text x="88" y="114" class="label">v</text>
        <text x="276" y="112" class="label">F</text>
        <text x="194" y="68" class="label subtle">正极板</text>
        <text x="306" y="68" class="label subtle">负极板</text>
        <text x="60" y="184" class="label subtle">粒子 {charge_label}</text>
        <text x="196" y="202" class="label subtle">电场方向</text>
      </svg>
"""
            scene_markup = (
                scene_markup
                .replace("__FIELD_ARROWS__", field_arrows)
                .replace("__PARTICLE_PATH__", particle_path)
                .replace("__VELOCITY_ARROW__", velocity_arrow)
                .replace("__FORCE_ARROW__", force_arrow)
            )
        elif subtype == "charged_particle":
            particle_path = self._electromagnetism_particle_path(
                trajectory,
                velocity_direction,
            )
            velocity_arrow = self._electromagnetism_arrow_line(
                kind="velocity",
                direction=velocity_direction,
                x=92,
                y=144,
                length=72,
            )
            force_arrow = self._electromagnetism_arrow_line(
                kind="force",
                direction=force_direction,
                x=288,
                y=116,
                length=58,
            )
            charge_label = {"positive": "q+", "negative": "q-", "unknown": "q"}[charge_sign]
            field_marks = self._electromagnetism_field_marks(
                field_marker=field_marker,
                x_positions=(232, 280, 328, 376),
                y_positions=(84, 124, 164),
            )
            plate_outline = ""
            if field_type == "mixed":
                plate_outline = """
        <rect x="176" y="72" width="18" height="96" rx="9" class="plate positive-plate faint-plate" />
        <rect x="396" y="72" width="18" height="96" rx="9" class="plate negative-plate faint-plate" />
"""
            scene_markup = """
      <svg viewBox="0 0 520 260" aria-label="磁场中带电粒子运动示意">
        <defs>
          <marker id="arrowHead" markerWidth="10" markerHeight="10" refX="7" refY="3.5" orient="auto">
            <polygon points="0 0, 8 3.5, 0 7" fill="currentColor" />
          </marker>
        </defs>
        <rect x="28" y="28" width="464" height="190" rx="28" class="stage-shell" />
        <rect x="198" y="54" width="232" height="138" rx="24" class="field-zone magnetic-zone" />
        __PLATE_OUTLINE__
        __FIELD_MARKS__
        <path d="__PARTICLE_PATH__" class="trace magnetic-trace" />
        <circle class="particle magnetic-particle" r="9">
          <animateMotion dur="3.2s" repeatCount="indefinite" path="__PARTICLE_PATH__" />
        </circle>
        __VELOCITY_ARROW__
        __FORCE_ARROW__
        <text x="94" y="132" class="label">v</text>
        <text x="296" y="94" class="label">F</text>
        <text x="236" y="48" class="label subtle">{field_badge}区域</text>
        <text x="46" y="164" class="label subtle">粒子 {charge_label}</text>
      </svg>
"""
            scene_markup = (
                scene_markup
                .replace("__PLATE_OUTLINE__", plate_outline)
                .replace("__FIELD_MARKS__", field_marks)
                .replace("__PARTICLE_PATH__", particle_path)
                .replace("__VELOCITY_ARROW__", velocity_arrow)
                .replace("__FORCE_ARROW__", force_arrow)
            )
        else:
            field_marks = self._electromagnetism_field_marks(
                field_marker=field_marker,
                x_positions=(124, 176, 228, 280, 332, 384),
                y_positions=(84, 126, 168),
            )
            rod_arrow = self._electromagnetism_arrow_line(
                kind="velocity",
                direction=rod_motion_direction,
                x=260,
                y=76,
                length=86,
            )
            scene_markup = """
      <svg viewBox="0 0 520 260" aria-label="电磁感应过程示意">
        <defs>
          <marker id="arrowHead" markerWidth="10" markerHeight="10" refX="7" refY="3.5" orient="auto">
            <polygon points="0 0, 8 3.5, 0 7" fill="currentColor" />
          </marker>
        </defs>
        <rect x="28" y="28" width="464" height="190" rx="28" class="stage-shell" />
        <rect x="92" y="52" width="312" height="144" rx="24" class="field-zone induction-zone" />
        <line x1="120" y1="62" x2="120" y2="198" class="rail" />
        <line x1="380" y1="62" x2="380" y2="198" class="rail" />
        <line x1="120" y1="62" x2="380" y2="62" class="wire" />
        <line x1="120" y1="198" x2="380" y2="198" class="wire" />
        <path d="M380 62 H432 V198 H380" class="wire" fill="none" />
        __FIELD_MARKS__
        <rect id="rod" x="236" y="74" width="26" height="112" rx="13" class="rod" />
        <circle cx="432" cy="130" r="28" class="meter" />
        <line x1="432" y1="130" x2="448" y2="116" class="needle" />
        <circle cx="432" cy="130" r="4" class="needle-cap" />
        <circle class="charge induction-charge" r="6">
          <animateMotion dur="2.8s" repeatCount="indefinite" path="M120 62 H380 H432 V198 H120 Z" />
        </circle>
        __ROD_ARROW__
        <text x="348" y="80" class="label">v</text>
        <text x="422" y="136" class="label">G</text>
        <text x="182" y="48" class="label subtle">{field_badge}区域</text>
        <text x="238" y="206" class="label subtle">导体棒切割磁感线</text>
      </svg>
"""
            scene_markup = (
                scene_markup
                .replace("__FIELD_MARKS__", field_marks)
                .replace("__ROD_ARROW__", rod_arrow)
            )

        state_closed = json.dumps(phenomenon_summary_text, ensure_ascii=False)
        state_alt = json.dumps(direction_hint_text, ensure_ascii=False)

        return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{title}</title>
  <style>
    :root {{
      color-scheme: dark;
      --accent: #ffd6a0;
      --accent-2: #9ed6ff;
      --accent-3: #8fe0c2;
      --panel: rgba(255,255,255,0.08);
      --line: rgba(255,255,255,0.12);
      --curve: 1;
      --field-opacity: 0.7;
      --rod-x: 0px;
      --needle-rotate: 18deg;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      font-family: "Noto Sans SC", "Microsoft YaHei", sans-serif;
      background:
        radial-gradient(circle at top, rgba(122, 191, 223, 0.18), transparent 36%),
        linear-gradient(180deg, #101b24, #0c1318 72%);
      color: #f3efe7;
      padding: 14px;
    }}
    .shell {{
      display: grid;
      gap: 12px;
      max-width: 760px;
      margin: 0 auto;
    }}
    .card {{
      border-radius: 22px;
      padding: 16px;
      background: var(--panel);
      border: 1px solid var(--line);
      backdrop-filter: blur(10px);
    }}
    .hero {{
      display: grid;
      gap: 10px;
    }}
    .kicker {{
      font-size: 11px;
      letter-spacing: 0.16em;
      text-transform: uppercase;
      color: #c4d7db;
    }}
    .headline {{
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      flex-wrap: wrap;
      gap: 12px;
    }}
    .title {{
      margin: 0;
      font-size: 24px;
      font-weight: 700;
      line-height: 1.25;
      max-width: 520px;
    }}
    .badge {{
      border-radius: 999px;
      padding: 6px 10px;
      background: rgba(255,214,160,0.12);
      color: #fff3de;
      font-size: 12px;
      white-space: nowrap;
    }}
    .subtitle {{
      color: #d2dde0;
      font-size: 14px;
      line-height: 1.6;
    }}
    .question-hint {{
      color: #afc3c8;
      font-size: 12px;
      line-height: 1.5;
    }}
    .scene-chips {{
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }}
    .scene-chip {{
      border-radius: 999px;
      padding: 6px 10px;
      background: rgba(143, 224, 194, 0.10);
      color: #ecf6f1;
      font-size: 12px;
    }}
    .stage {{
      border-radius: 22px;
      overflow: hidden;
      background: linear-gradient(180deg, rgba(255,255,255,0.04), rgba(255,255,255,0.015));
    }}
    svg {{
      width: 100%;
      height: 280px;
      display: block;
    }}
    .label {{
      fill: #f9f4ea;
      font-size: 14px;
    }}
    .label.subtle {{
      fill: #cfd9dc;
      font-size: 12px;
    }}
    .stage-shell {{
      fill: rgba(255,255,255,0.03);
      stroke: rgba(255,255,255,0.06);
    }}
    .field-zone {{
      fill: rgba(134, 182, 201, 0.08);
      stroke: rgba(167, 215, 197, 0.26);
    }}
    .electric-zone {{
      fill: rgba(158,214,255,0.08);
      stroke: rgba(158,214,255,0.24);
    }}
    .magnetic-zone {{
      fill: rgba(143,224,194,0.08);
    }}
    .induction-zone {{
      fill: rgba(143,224,194,0.06);
    }}
    .arrow-line {{
      stroke-width: 5;
      stroke-linecap: round;
      marker-end: url(#arrowHead);
    }}
    .velocity {{ stroke: #ffd6a0; }}
    .force {{ stroke: #9ed6ff; }}
    .wire, .rail {{
      stroke: #ecdcb7;
      stroke-width: 6;
      stroke-linecap: round;
      fill: none;
    }}
    .rail {{ stroke: #9dc6d3; }}
    .rod {{
      fill: #466978;
      stroke: #bde5f0;
      stroke-width: 3;
      transform: translateX(var(--rod-x));
      filter: drop-shadow(0 10px 24px rgba(0,0,0,0.28));
    }}
    .meter {{
      fill: rgba(255,214,160,0.18);
      stroke: var(--accent);
      stroke-width: 5;
    }}
    .needle {{
      stroke: var(--accent-2);
      stroke-width: 4;
      stroke-linecap: round;
      transform-origin: 432px 130px;
      transform: rotate(var(--needle-rotate));
      transition: transform 180ms ease;
    }}
    .needle-cap {{
      fill: #f8f3ea;
    }}
    .trace {{
      fill: none;
      stroke-width: 5;
      stroke-dasharray: 10 10;
      stroke-linecap: round;
      animation: dash 2.6s linear infinite;
    }}
    .magnetic-trace {{ stroke: #ffd6a0; }}
    .electric-trace {{ stroke: #9ed6ff; }}
    .particle {{
      filter: drop-shadow(0 0 16px rgba(255,214,160,0.55));
    }}
    .magnetic-particle {{ fill: #ffd6a0; }}
    .electric-particle {{ fill: #9ed6ff; }}
    .charge.induction-charge {{
      fill: #ffd6a0;
      opacity: 0.9;
    }}
    .field-arrow {{
      stroke: rgba(158,214,255,var(--field-opacity));
      stroke-width: 4;
      stroke-linecap: round;
      marker-end: url(#arrowHead);
    }}
    .plate {{
      stroke-width: 3;
    }}
    .positive-plate {{
      fill: rgba(255,214,160,0.22);
      stroke: rgba(255,214,160,0.72);
    }}
    .negative-plate {{
      fill: rgba(158,214,255,0.20);
      stroke: rgba(158,214,255,0.68);
    }}
    .faint-plate {{
      opacity: 0.6;
    }}
    .panel-grid {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 10px;
    }}
    .mini {{
      border-radius: 16px;
      background: rgba(0,0,0,0.12);
      padding: 12px;
    }}
    .mini-key {{
      color: #c7d3d7;
      font-size: 12px;
      margin-bottom: 6px;
    }}
    .mini-value {{
      color: #fff3de;
      font-size: 16px;
      font-weight: 700;
      line-height: 1.6;
    }}
    .controls {{
      display: grid;
      gap: 10px;
    }}
    .buttons {{
      display: flex;
      gap: 10px;
    }}
    button {{
      flex: 1;
      border: 0;
      border-radius: 14px;
      padding: 12px 14px;
      font-size: 14px;
      font-weight: 700;
      cursor: pointer;
    }}
    .primary {{
      background: var(--accent);
      color: #171712;
    }}
    .secondary {{
      background: rgba(255,255,255,0.07);
      color: #eef3ea;
      border: 1px solid rgba(255,255,255,0.1);
    }}
    .slider-row {{
      display: grid;
      gap: 6px;
    }}
    .slider-label {{
      display: flex;
      justify-content: space-between;
      font-size: 12px;
      color: #d3dde2;
    }}
    input[type="range"] {{
      width: 100%;
      accent-color: var(--accent);
    }}
    ul {{
      margin: 0;
      padding-left: 18px;
      color: #e7eef1;
      line-height: 1.7;
      font-size: 13px;
    }}
    @keyframes dash {{
      to {{
        stroke-dashoffset: -40;
      }}
    }}
    @media (max-width: 640px) {{
      body {{
        padding: 10px;
      }}
      .title {{
        font-size: 20px;
        max-width: none;
      }}
      .panel-grid {{
        grid-template-columns: 1fr;
      }}
      svg {{
        height: 250px;
      }}
    }}
  </style>
</head>
<body data-scene="electromagnetism" data-subtype="{subtype}" data-field="{field_type}">
  <div class="shell">
    <section class="card hero">
      <div class="kicker">PHYSICS SCENE</div>
      <div class="headline">
        <h2 class="title">{title}</h2>
        <div class="badge">{subtype_label} / {field_badge}</div>
      </div>
      <div class="subtitle">{phenomenon_summary}</div>
      <div class="scene-chips">
        <span class="scene-chip">{subtype_label}</span>
        <span class="scene-chip">{field_badge}</span>
        {badge_html}
      </div>
      <div class="question-hint">题干聚焦：{question_hint}</div>
    </section>

    <section class="card stage">
{scene_markup}
    </section>

    <section class="card">
      <div class="panel-grid">
        <div class="mini">
          <div class="mini-key">现象观察</div>
          <div class="mini-value" id="stateText">{phenomenon_summary}</div>
        </div>
        <div class="mini">
          <div class="mini-key">方向判断</div>
          <div class="mini-value" id="directionText">{direction_hint}</div>
        </div>
      </div>
    </section>

    <section class="card controls">
      <div class="buttons">
        <button class="primary" id="toggleBtn">切换提示</button>
        <button class="secondary" id="resetBtn">恢复默认</button>
      </div>
      <label class="slider-row">
        <div class="slider-label"><span>场强 / 运动强度</span><span id="strengthValue">3</span></div>
        <input id="strengthSlider" type="range" min="1" max="5" step="1" value="3" />
      </label>
      <div class="mini">
        <div class="mini-key">复盘要点</div>
        <ul>{focus_html}</ul>
      </div>
      <div style="font-size:12px;color:#c7d3d7;">{interaction_hint}</div>
    </section>
  </div>

  <script>
    const root = document.documentElement;
    const toggleBtn = document.getElementById('toggleBtn');
    const resetBtn = document.getElementById('resetBtn');
    const strengthSlider = document.getElementById('strengthSlider');
    const strengthValue = document.getElementById('strengthValue');
    const stateText = document.getElementById('stateText');
    const directionText = document.getElementById('directionText');
    const statePrimary = {state_closed};
    const stateSecondary = {state_alt};
    let showingPrimary = true;

    function applyStrength(level) {{
      strengthValue.textContent = String(level);
      root.style.setProperty('--curve', (0.55 + level * 0.18).toFixed(2));
      root.style.setProperty('--field-opacity', (0.35 + level * 0.1).toFixed(2));
      root.style.setProperty('--rod-x', `${{(level - 3) * 16}}px`);
      root.style.setProperty('--needle-rotate', `${{(level - 3) * 10 + 18}}deg`);
    }}

    function resetView() {{
      showingPrimary = true;
      stateText.textContent = statePrimary;
      directionText.textContent = stateSecondary;
      strengthSlider.value = '3';
      applyStrength(3);
    }}

    toggleBtn.addEventListener('click', () => {{
      showingPrimary = !showingPrimary;
      stateText.textContent = showingPrimary ? statePrimary : stateSecondary;
      directionText.textContent = showingPrimary ? stateSecondary : statePrimary;
    }});
    resetBtn.addEventListener('click', resetView);
    strengthSlider.addEventListener('input', () => applyStrength(Number(strengthSlider.value)));
    resetView();
  </script>
</body>
</html>"""

    def _guess_electromagnetism_subtype(self, cleaned_question: str) -> str:
        lowered = cleaned_question.lower()
        induction_keywords = [
            "电磁感应",
            "感应电流",
            "感应电动势",
            "磁通量",
            "导体棒",
            "线圈",
        ]
        if any(keyword in lowered for keyword in induction_keywords):
            return "electromagnetic_induction"
        return "charged_particle"

    def _electromagnetism_choice(
        self,
        value: Any,
        allowed: set[str],
        default: str,
    ) -> str:
        normalized = str(value or "").strip().lower()
        return normalized if normalized in allowed else default

    def _electromagnetism_particle_path(
        self,
        trajectory: str,
        velocity_direction: str,
    ) -> str:
        if velocity_direction in {"up", "down"}:
            return {
                "straight": "M170 196 V76",
                "arc_up": "M170 196 V146 Q170 118 204 102 T282 78",
                "arc_down": "M170 76 V126 Q170 154 204 170 T282 194",
                "circle": "M170 170 A54 54 0 1 1 171 170",
            }[trajectory]
        return {
            "straight": "M74 144 H430",
            "arc_up": "M74 144 H186 Q238 144 266 122 T356 86 Q392 74 430 70",
            "arc_down": "M74 118 H186 Q238 118 266 140 T356 176 Q392 188 430 192",
            "circle": "M188 144 A66 66 0 1 1 189 144",
        }[trajectory]

    def _electromagnetism_arrow_line(
        self,
        *,
        kind: str,
        direction: str,
        x: int,
        y: int,
        length: int,
    ) -> str:
        offsets = {
            "right": (length, 0),
            "left": (-length, 0),
            "up": (0, -length),
            "down": (0, length),
            "none": (0, 0),
        }
        dx, dy = offsets[direction]
        x2 = x + dx
        y2 = y + dy
        color_class = "velocity" if kind == "velocity" else "force"
        return (
            f'<line x1="{x}" y1="{y}" x2="{x2}" y2="{y2}" '
            f'class="arrow-line {color_class}" />'
        )

    def _electromagnetism_field_marks(
        self,
        *,
        field_marker: str,
        x_positions: tuple[int, ...],
        y_positions: tuple[int, ...],
    ) -> str:
        marks = []
        glyph = {"cross": "×", "dot": "•", "line": "|"}[field_marker]
        for x_pos in x_positions:
            for y_pos in y_positions:
                marks.append(
                    f'<text x="{x_pos}" y="{y_pos}" class="label subtle">{glyph}</text>'
                )
        return '<g class="fieldMarks">' + "".join(marks) + "</g>"

    def _display_plain_text(self, text: str, *, limit: int = 48) -> str:
        if not text:
            return ""

        normalized = text
        normalized = re.sub(r"\$\$(.*?)\$\$", r"\1", normalized, flags=re.DOTALL)
        normalized = re.sub(r"\$(.*?)\$", r"\1", normalized, flags=re.DOTALL)
        normalized = normalized.replace("\\(", "").replace("\\)", "")
        normalized = normalized.replace("\\[", "").replace("\\]", "")
        normalized = re.sub(r"\\text\{([^{}]*)\}", r"\1", normalized)
        normalized = re.sub(r"\\frac\{([^{}]+)\}\{([^{}]+)\}", r"\1/\2", normalized)
        normalized = re.sub(r"\\sqrt\{([^{}]+)\}", r"√(\1)", normalized)
        normalized = re.sub(r"\\[A-Za-z]+", "", normalized)
        normalized = normalized.replace("{", "").replace("}", "")
        normalized = re.sub(r"\s+", " ", normalized).strip(" ,，。；;：:")
        if len(normalized) > limit:
            normalized = normalized[: limit - 1].rstrip() + "…"
        return normalized

    def _guess_electromagnetism_field_type(
        self,
        *,
        cleaned_question: str,
        knowledge_points: List[str],
    ) -> str:
        lowered = f"{cleaned_question} {' '.join(knowledge_points)}".lower()
        has_electric = any(
            token in lowered
            for token in ["电场", "电势", "电压", "平行板", "极板", "带电", "匀强电场"]
        )
        has_magnetic = any(
            token in lowered
            for token in ["磁场", "磁感应", "洛伦兹", "磁通量", "感应电流", "安培力", "导体棒", "线圈", "磁感线"]
        )
        if has_electric and has_magnetic:
            return "mixed"
        if has_electric:
            return "electric"
        return "magnetic"

    def _guess_electromagnetism_title(
        self,
        *,
        cleaned_question: str,
        subtype: str,
        field_type: str,
    ) -> str:
        lowered = cleaned_question.lower()
        if subtype == "electromagnetic_induction":
            if any(token in lowered for token in ["导体棒", "金属棒", "切割磁感线"]):
                return "导体棒切割磁感线"
            if any(token in lowered for token in ["线圈", "磁通量", "穿过线圈"]):
                return "线圈磁通量变化"
            return "电磁感应过程演示"

        if field_type == "electric":
            if any(token in lowered for token in ["平行板", "极板"]):
                return "平行板间粒子偏转"
            return "电场中粒子运动"
        if field_type == "mixed":
            return "复合场中粒子运动"
        if any(token in lowered for token in ["圆周", "半径", "回旋"]):
            return "磁场中圆周偏转"
        return "磁场中粒子偏转"

    def _guess_electromagnetism_summary(
        self,
        *,
        cleaned_question: str,
        subtype: str,
        field_type: str,
    ) -> str:
        lowered = cleaned_question.lower()
        if subtype == "electromagnetic_induction":
            if any(token in lowered for token in ["导体棒", "切割磁感线", "金属棒"]):
                return "观察导体棒运动、磁场方向和感应电流方向之间的对应关系。"
            return "观察磁通量变化如何触发感应电流与偏转现象。"

        if field_type == "electric":
            return "观察带电粒子进入电场后受到电场力作用而产生的偏转轨迹。"
        if field_type == "mixed":
            return "综合比较电场力、洛伦兹力与初速度方向对轨迹的共同影响。"
        return "观察带电粒子在磁场中受洛伦兹力作用后的偏转与轨迹变化。"

    def _build_electromagnetism_template_artifact(
        self,
        *,
        cleaned_question: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> RichArtifact | None:
        guessed_subtype = self._guess_electromagnetism_subtype(cleaned_question)
        guessed_field_type = self._guess_electromagnetism_field_type(
            cleaned_question=cleaned_question,
            knowledge_points=knowledge_points,
        )
        scene_spec = {
            "title": cleaned_question[:24] or "电磁过程演示",
            "subtype": self._guess_electromagnetism_subtype(cleaned_question),
            "field_type": "magnetic",
            "focus_points": [item for item in knowledge_points[:3] if item.strip()],
            "phenomenon_summary": solution_summary or (solution_steps[0] if solution_steps else "观察场方向和运动变化。"),
            "interaction_hint": "拖动滑块改变场强或运动强度，观察受力方向和轨迹变化。",
            "direction_hint": "结合左手定则、右手定则或洛伦兹力方向判断。",
        }
        html_document = self._render_electromagnetism_scene_html_v2(
            cleaned_question=cleaned_question,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            scene_spec=scene_spec,
        )
        candidate = RichArtifact(
            artifact_type="interactive_html",
            title=str(
                self._display_plain_text(str(scene_spec["title"]), limit=18)
                or scene_spec["title"]
            ),
            description="电磁题使用本地模板渲染的演示页面。",
            mime_type="text/html",
            content=html_document,
        )
        validated = filter_subject_extension_artifacts(
            subject="物理",
            cleaned_question=cleaned_question,
            artifacts=[candidate],
        )
        return validated[0] if validated else None

    def _build_physics_template_artifact(
        self,
        *,
        cleaned_question: str,
        knowledge_points: List[str],
        solution_steps: List[str],
    ) -> RichArtifact | None:
        candidate = _build_physics_html(
            cleaned_question=cleaned_question,
            knowledge_points=knowledge_points,
            solution_steps=solution_steps,
        )
        validated = filter_subject_extension_artifacts(
            subject="物理",
            cleaned_question=cleaned_question,
            artifacts=[candidate],
        )
        if validated:
            logger.info(
                "physics html fallback template used scene=%s",
                _physics_scene_type(f"{cleaned_question} {' '.join(knowledge_points)}"),
            )
            return validated[0]
        return None

    def _build_physics_html_prompt(
        self,
        *,
        cleaned_question: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> str:
        lowered = " ".join(
            part.strip()
            for part in [
                cleaned_question,
                " ".join(knowledge_points),
                solution_summary,
                " ".join(solution_steps),
            ]
            if part and part.strip()
        ).lower()
        if any(token in lowered for token in ["木板", "板块", "物块", "滑块", "摩擦", "传送带", "连接体"]):
            scene_hint = "board_block"
            scene_label = "木板-物块相对运动"
            scene_requirements = (
                "- 画面里必须出现木板和物块两个对象\n"
                "- 必须体现相对滑动或共同运动\n"
                "- 必须体现摩擦力方向和速度/位移变化"
            )
        elif any(token in lowered for token in ["斜面", "斜坡", "倾角", "沿斜面"]):
            scene_hint = "incline"
            scene_label = "斜面运动"
            scene_requirements = (
                "- 画面里必须出现斜面和物体\n"
                "- 必须体现重力、支持力、摩擦力或沿斜面运动趋势\n"
                "- 参数控制优先选择角度、摩擦系数、质量"
            )
        elif any(token in lowered for token in ["平抛", "斜抛", "抛体", "抛出", "射程", "落点"]):
            scene_hint = "projectile"
            scene_label = "抛体运动"
            scene_requirements = (
                "- 画面里必须出现轨迹、落点或飞行过程\n"
                "- 参数控制优先选择初速度、角度、发射高度\n"
                "- 不要退化成静态受力图"
            )
        elif any(token in lowered for token in ["碰撞", "相碰", "弹性碰撞", "非弹性碰撞", "对心碰撞"]):
            scene_hint = "collision"
            scene_label = "碰撞过程"
            scene_requirements = (
                "- 画面里必须出现两个对象碰撞前后状态\n"
                "- 必须体现碰撞瞬间和碰后速度变化\n"
                "- 参数控制优先选择质量、初速度、恢复系数"
            )
        elif any(token in lowered for token in ["光路", "透镜", "折射", "反射", "焦距", "成像"]):
            scene_hint = "optics"
            scene_label = "光学成像/光路"
            scene_requirements = "- 必须出现真实光路、透镜或反射/折射过程"
        elif any(token in lowered for token in ["电路", "电流", "电压", "电阻", "串联", "并联"]):
            scene_hint = "circuit"
            scene_label = "电路过程"
            scene_requirements = "- 必须出现真实电路结构、电流状态或开关变化"
        else:
            scene_hint = "mechanics"
            scene_label = "一般力学过程"
            scene_requirements = "- 画面要围绕题目里的对象和过程，不要做成无关模板"

        focus_points = "；".join(knowledge_points[:4]) or "受力分析、运动过程、关键参数变化"
        step_text = "\n".join(f"- {step}" for step in solution_steps[:4]) or "- 根据题目情景设计合适的动态演示"
        return f"""
你是一个移动端物理可视化页面生成器。请只输出一个完整可运行的单文件 HTML 页面，不要输出 JSON，不要输出 Markdown 代码块，不要加任何解释文字。

目标：
为下面这道具体物理题生成一个适合手机 WebView 直接加载的动画演示页面。页面的重点是“还原题目情景并展示过程”，不是复述题干。

题目信息：
- 题目：{cleaned_question}
- 当前识别场景：{scene_label}
- body 标签必须包含：data-scene="{scene_hint}"
- 核心知识点：{focus_points}
- 解析摘要：{solution_summary}
- 关键步骤：
{step_text}

硬性要求：
1. 只输出 HTML 源码，从 <!DOCTYPE html> 开始，到 </html> 结束。
2. 必须是单文件 HTML，所有 CSS 和 JavaScript 内联，不依赖外部 CDN、外部图片、外部字体、外部脚本。
3. 页面适配手机竖屏，默认宽度友好，动画区域清晰。
4. 不要在页面里重复大段题干，不要塞满文字说明；只保留简短标题、少量关键参数、必要按钮和标签。
5. 页面中的文本必须是普通可读文本或 Unicode 字符，不要出现 $...$、\\frac、\\sqrt 这类 LaTeX 源码。
6. 动画必须贴合题目情景。如果是木板-物块、板块运动、摩擦、连接体、斜面、碰撞、平抛等题，必须体现对应对象、相对运动、受力方向或关键状态变化。
7. 页面建议包含开始/暂停、重置，以及 1 到 3 个与题目相关的参数控制项，例如质量、初速度、摩擦系数、角度、外力等。
8. 画面以对象和过程为主，不要做成通用光路、电路或无关模板。
9. 动画与标签要尽量符合题目场景，宁可简洁，也不要错场景。
10. 请在 `<body>` 标签上显式写出 `data-scene="{scene_hint}"`，方便前端校验场景是否匹配。

当前场景必须满足：
{scene_requirements}

如果题目属于板块运动或木板-物块模型，请优先展示：
- 木板和物块两个对象
- 相对滑动或共同运动
- 摩擦力方向
- 速度/位移/相对位置变化

再次强调：只输出完整 HTML，不要输出任何额外说明。
""".strip()

    def _extract_html_document(self, raw_output: str) -> str:
        cleaned = raw_output.strip()
        if cleaned.startswith("```"):
            match = re.search(r"```(?:html)?\s*(.*?)```", cleaned, re.DOTALL | re.IGNORECASE)
            if match:
                cleaned = match.group(1).strip()

        doctype_match = re.search(
            r"<!DOCTYPE html>.*?</html>",
            cleaned,
            re.DOTALL | re.IGNORECASE,
        )
        if doctype_match:
            return doctype_match.group(0).strip()

        html_match = re.search(
            r"<html.*?</html>",
            cleaned,
            re.DOTALL | re.IGNORECASE,
        )
        if html_match:
            return html_match.group(0).strip()
        return ""

    def _normalize_math_fields(self, parsed: dict) -> dict:
        normalized = dict(parsed)
        text_fields = [
            "cleaned_question",
            "solution_summary",
            "mistake_diagnosis",
        ]

        for field in text_fields:
            normalized[field] = self._latexize_mixed_text(str(normalized.get(field, "")))

        normalized["solution_steps"] = [
            self._latexize_mixed_text(str(item))
            for item in normalized.get("solution_steps", [])
            if str(item).strip()
        ]

        review_plan = dict(normalized.get("review_plan") or {})
        review_plan["focus"] = self._latexize_mixed_text(str(review_plan.get("focus", "")))
        normalized["review_plan"] = review_plan

        similar_questions = []
        for item in normalized.get("similar_questions", []):
            prompt = self._latexize_mixed_text(str(item.get("prompt", "")))
            answer_outline = self._latexize_mixed_text(str(item.get("answer_outline", "")))
            similar_questions.append(
                {
                    **item,
                    "prompt": prompt,
                    "answer_outline": answer_outline,
                }
            )
        normalized["similar_questions"] = similar_questions
        normalized["rich_artifacts"] = self._normalize_rich_artifacts(
            normalized.get("rich_artifacts", [])
        )

        return normalized

    def _normalize_rich_artifacts(self, artifacts: list) -> list:
        normalized_artifacts = []
        for item in artifacts:
            if not isinstance(item, dict):
                continue

            normalized_item = dict(item)
            normalized_item["title"] = self._latexize_mixed_text(str(item.get("title", "")))
            normalized_item["description"] = self._latexize_mixed_text(
                str(item.get("description", ""))
            )

            mime_type = str(item.get("mime_type", "text/plain"))
            content = str(item.get("content", ""))
            if content.strip():
                if mime_type == "application/json":
                    normalized_item["content"] = self._latexize_json_content(content)
                elif mime_type != "text/html":
                    normalized_item["content"] = self._latexize_mixed_text(content)
                else:
                    normalized_item["content"] = content

            normalized_artifacts.append(normalized_item)

        return normalized_artifacts

    def _latexize_json_content(self, content: str) -> str:
        try:
            parsed = json.loads(content)
        except json.JSONDecodeError:
            return content

        normalized = self._normalize_nested_strings(parsed)
        return json.dumps(normalized, ensure_ascii=False, indent=2)

    def _normalize_nested_strings(self, value: Any) -> Any:
        if isinstance(value, str):
            return self._latexize_mixed_text(value)
        if isinstance(value, list):
            return [self._normalize_nested_strings(item) for item in value]
        if isinstance(value, dict):
            return {
                key: self._normalize_nested_strings(item)
                for key, item in value.items()
            }
        return value

    def _latexize_mixed_text(self, text: str) -> str:
        if not text.strip():
            return text

        parts = re.split(r"(\$\$.*?\$\$|\$.*?\$)", text, flags=re.DOTALL)
        converted: List[str] = []
        for part in parts:
            if not part:
                continue
            if part.startswith("$$") or part.startswith("$"):
                converted.append(part)
                continue
            converted.append(self._wrap_math_segments(part))
        return "".join(converted)

    def _wrap_math_segments(self, text: str) -> str:
        pattern = re.compile(r"[A-Za-z0-9π∞α-ωΑ-Ω∫∑√≤≥≠≈±×÷·\-\+\=\^\(\)\[\]\{\}/\\|_,.:%]+")

        def replacer(match: re.Match[str]) -> str:
            segment = match.group(0)
            stripped = segment.strip()
            if not stripped or not self._looks_like_math(stripped):
                return segment

            leading = segment[: len(segment) - len(segment.lstrip())]
            trailing = segment[len(segment.rstrip()) :]
            body = segment[len(leading) : len(segment) - len(trailing)]
            normalized = self._normalize_math_segment(body)
            if not normalized:
                return segment
            return f"{leading}${normalized}${trailing}"

        wrapped = pattern.sub(replacer, text)
        wrapped = re.sub(r"\$(\s+)", r"$\1", wrapped)
        wrapped = re.sub(r"(\s+)\$", r"\1$", wrapped)
        return wrapped

    def _looks_like_math(self, segment: str) -> bool:
        indicator_patterns = [
            r"[π∞α-ωΑ-Ω∫∑√≤≥≠≈±×÷]",
            r"[\^=<>/\[\]\(\)\{\}]",
            r"\b(?:sin|cos|tan|cot|sec|csc|log|ln|lim|max|min)\b",
            r"\b[a-zA-Z]\s*_\s*\d+",
            r"\b[a-zA-Z]\d+\b",
            r"\d+\s*[%°]",
        ]
        if not any(re.search(pattern, segment) for pattern in indicator_patterns):
            return False

        if re.fullmatch(r"[A-Za-z]+", segment):
            return False
        return True

    def _normalize_math_segment(self, segment: str) -> str:
        normalized = segment.strip()
        if not normalized:
            return normalized

        replacements = {
            "π": r"\pi",
            "∞": r"\infty",
            "≤": r"\le",
            "≥": r"\ge",
            "≠": r"\ne",
            "≈": r"\approx",
            "±": r"\pm",
            "×": r"\times",
            "÷": r"\div",
            "·": r"\cdot",
            "∫": r"\int",
            "∑": r"\sum",
            "∈": r"\in",
            "∉": r"\notin",
            "∪": r"\cup",
            "∩": r"\cap",
            "→": r"\to",
            "⇒": r"\Rightarrow",
            "⇔": r"\Leftrightarrow",
            "°": r"^\circ",
            "α": r"\alpha",
            "β": r"\beta",
            "γ": r"\gamma",
            "θ": r"\theta",
            "λ": r"\lambda",
            "μ": r"\mu",
            "σ": r"\sigma",
            "ω": r"\omega",
            "Δ": r"\Delta",
        }
        for source, target in replacements.items():
            normalized = normalized.replace(source, target)

        superscripts = {
            "²": "^2",
            "³": "^3",
            "⁴": "^4",
            "⁵": "^5",
            "⁶": "^6",
            "⁷": "^7",
            "⁸": "^8",
            "⁹": "^9",
            "⁰": "^0",
            "⁻": "^-",
            "¹": "^1",
        }
        for source, target in superscripts.items():
            normalized = normalized.replace(source, target)

        normalized = re.sub(r"(?<!\\)\b(sin|cos|tan|cot|sec|csc|log|ln|lim|max|min)\b", r"\\\1", normalized)
        normalized = re.sub(r"(?<!\\)(\\sin|\\cos|\\tan|\\cot|\\sec|\\csc|\\log|\\ln)(\^[-]?\d+)?([A-Za-z\\])", r"\1\2 \3", normalized)
        normalized = re.sub(r"(?<!\\)(\\sin|\\cos|\\tan|\\cot|\\sec|\\csc|\\log|\\ln)\s*\^\s*([-\d]+)", r"\1^\2", normalized)
        normalized = re.sub(r"(?<!\\)√\s*\(([^()]+)\)", r"\\sqrt{\1}", normalized)
        normalized = re.sub(r"(?<!\\)√\s*([A-Za-z0-9\\]+)", r"\\sqrt{\1}", normalized)
        normalized = re.sub(r"(?<![\\A-Za-z])([A-Za-z])(\d+)", r"\1_\2", normalized)
        normalized = re.sub(r"\\pi_(\d+)", r"\\pi_{\1}", normalized)
        normalized = re.sub(r"\\lambda_(\d+)", r"\\lambda_{\1}", normalized)
        normalized = re.sub(r"(?<!\\)\b([a-zA-Z])\s*\^\s*([-\d]+)", r"\1^\2", normalized)
        normalized = re.sub(r"\s+", " ", normalized).strip()
        return normalized
