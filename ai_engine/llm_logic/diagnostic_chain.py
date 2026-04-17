from __future__ import annotations

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
