from __future__ import annotations

import html
import json
import logging
import re
import string
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
    "数学": "数学题可以返回一个 chart_spec，但只能用于坐标图、函数图像、几何示意或圆锥曲线草图；不要在 rich_artifacts 中写解题步骤、核心思路、易错提醒或复习清单。",
    "编程": "可以额外返回一个 rich_artifacts 项，提供 code_snippet 类型，展示关键代码、执行轨迹或输入输出示例。",
    "生物": "可以额外返回一个 rich_artifacts 项，展示 timeline 或 interactive_html，演示过程流转如代谢、遗传或生态循环。",
}

ANALYSIS_FIELD_GUIDANCE = """
前端展示顺序固定为：破题关键与最终结论 → 详细推导步骤 → 学科拓展（仅物理动画或真正高质量可视化）→ 举一反三。

必须严格分工，禁止同一内容在多个字段重复出现：
- solution_summary：只写“破题关键 + 最终结论”。控制在 60-100 字。必须包含最终答案、轨迹方程、结论或核心判断。不要写详细推导过程，不要分点，不要写“首先/然后/接着”。
- mistake_diagnosis：字段仅为兼容旧 schema 保留，前端不展示。除非用户明确提供了错误答案或自述错因，否则返回空字符串；不要生成独立错因板块。
- review_plan.focus：字段仅为兼容旧 schema 保留，前端不展示。默认返回空字符串；不要生成独立复习建议板块。
- solution_steps：只写详细推导步骤，建议 5-7 步。每一步控制在 70-160 字。每一步都要写清“为什么这样做”和关键等式/代换/条件来源。每个核心公式必须单独用 $$...$$ 包裹并独占一行，公式前后配一句简短文字讲解。不要在每一步末尾重复最终答案。不要把错因、复习建议、拓展知识写进步骤里。
- similar_questions：最多返回 1 个变式题。prompt 控制在 60 字以内，answer_outline 控制在 80 字以内。不要返回多道相似题。
- rich_artifacts：默认返回空数组。只有当能提供真正可视化内容时才返回，例如函数图像、几何图、物理动画、化学流程图。不要返回 study_card 类型的纯文字知识卡片。不要把“学科拓展说明”“知识点总结”“关键联系”塞进 rich_artifacts。如果没有高质量图表或交互内容，必须返回 []。
如果题目要求“说明它表示什么曲线/物理含义/化学意义”，这个解释属于 solution_summary 的结尾，不属于 rich_artifacts。
整体输出要克制，适合手机端阅读。宁可短而清楚，不要完整讲义式长答案。
""".strip()


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
        scene_brief = str(parsed.get("scene_brief", "")).strip()
        knowledge_points = [str(item) for item in parsed.get("knowledge_points", []) if str(item).strip()]
        solution_steps = [str(item) for item in parsed.get("solution_steps", []) if str(item).strip()]
        solution_summary = str(parsed.get("solution_summary", "请结合详细步骤继续完善解析。"))

        scene_brief_source = "model"
        if not scene_brief:
            scene_brief_source = "fallback"
            scene_brief = self._fallback_scene_brief(
                cleaned_question=cleaned_question,
                knowledge_points=knowledge_points,
                solution_summary=solution_summary,
            )
        logger.info(
            "analysis response scene_brief source=%s len=%s preview=%r",
            scene_brief_source,
            len(scene_brief),
            self._log_preview(scene_brief, limit=220),
        )

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
            should_auto_build_extension = "物理" not in subject
            if should_auto_build_extension:
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
            scene_brief=scene_brief,
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
        scene_brief: str,
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
            scene_brief=scene_brief,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            solution_steps=solution_steps,
        )
        logger.info("physics animation scene_type=%s", scene_type)
        artifact = self._generate_native_physics_scene_spec_artifact(
            cleaned_question=cleaned_question,
            scene_brief=scene_brief,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            solution_steps=solution_steps,
        )
        if artifact is not None:
            logger.info("physics animation used native scene spec")
            return artifact

        logger.info("physics animation attempting direct html generation")
        artifact = self._generate_physics_html_artifact(
            cleaned_question=cleaned_question,
            scene_brief=scene_brief,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            solution_steps=solution_steps,
        )
        if artifact is not None:
            logger.info("physics animation used direct html generation")
            return artifact

        if scene_type == "circuit":
            artifact = self._generate_circuit_scene_artifact(
                cleaned_question=cleaned_question,
                scene_brief=scene_brief,
                knowledge_points=knowledge_points,
                solution_summary=solution_summary,
                solution_steps=solution_steps,
            )
            if artifact is not None:
                logger.info("physics animation fell back to circuit scene spec renderer")
                return artifact
        if scene_type == "electromagnetism":
            artifact = self._generate_electromagnetism_scene_artifact(
                cleaned_question=cleaned_question,
                scene_brief=scene_brief,
                knowledge_points=knowledge_points,
                solution_summary=solution_summary,
                solution_steps=solution_steps,
            )
            if artifact is not None:
                logger.info("physics animation fell back to electromagnetism scene spec renderer")
                return artifact
        if scene_type == "circuit":
            artifact = self._build_physics_template_artifact(
                cleaned_question=cleaned_question,
                knowledge_points=knowledge_points,
                solution_steps=solution_steps,
            )
            if artifact is not None:
                logger.info("physics animation fell back to local circuit template")
                return artifact
        if scene_type == "electromagnetism":
            artifact = self._build_electromagnetism_template_artifact(
                cleaned_question=cleaned_question,
                knowledge_points=knowledge_points,
                solution_summary=solution_summary,
                solution_steps=solution_steps,
            )
            if artifact is not None:
                logger.info("physics animation fell back to local electromagnetism template")
                return artifact
        return None

    def _generate_native_physics_scene_spec_artifact(
        self,
        *,
        cleaned_question: str,
        scene_brief: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> RichArtifact | None:
        scene_type = self._physics_scene_type_from_context(
            cleaned_question=cleaned_question,
            scene_brief=scene_brief,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            solution_steps=solution_steps,
        )
        combined_context = " ".join(
            part.strip()
            for part in [
                cleaned_question,
                scene_brief,
                solution_summary,
                " ".join(knowledge_points),
                " ".join(solution_steps),
            ]
            if part and part.strip()
        )
        if scene_type != "electromagnetism" and not self._looks_like_electromagnetism(
            combined_context
        ):
            return None

        subtype = self._guess_electromagnetism_subtype(combined_context)
        field_type = self._guess_electromagnetism_field_type(
            cleaned_question=combined_context,
            knowledge_points=[],
        )
        if subtype != "charged_particle":
            return None

        field_marker = self._infer_electromagnetism_field_marker(
            combined_context=combined_context,
            field_type=field_type,
        )
        charge_sign = self._infer_electromagnetism_charge_sign(combined_context)
        velocity_direction = self._infer_electromagnetism_velocity_direction(
            combined_context,
            subtype,
        )
        force_direction = self._infer_electromagnetism_force_direction(combined_context)
        focus_points = self._build_electromagnetism_focus_points(
            scene_brief=scene_brief,
            knowledge_points=knowledge_points,
            subtype=subtype,
            field_type=field_type,
        )
        title = self._guess_electromagnetism_title(
            cleaned_question=combined_context or cleaned_question,
            subtype=subtype,
            field_type=field_type,
        )
        summary = (
            self._display_plain_text(solution_summary, limit=80)
            or self._guess_electromagnetism_summary(
                cleaned_question=combined_context or cleaned_question,
                subtype=subtype,
                field_type=field_type,
            )
        )
        params = {
            "a": self._extract_named_number(combined_context, "a"),
            "b": self._extract_named_number(combined_context, "b"),
            "L": self._extract_named_number(combined_context, "L"),
            "R": "mv0/(eB)",
        }
        spec = {
            "version": 1,
            "template_id": "charged_particle_field",
            "scene_type": "electromagnetism",
            "subtype": subtype,
            "field_type": field_type,
            "title": title,
            "summary": summary,
            "field": {
                "marker": field_marker,
                "direction_label": self._field_marker_label(field_marker),
            },
            "particle": {
                "label": self._particle_label(charge_sign),
                "charge_sign": charge_sign,
                "velocity_direction": velocity_direction,
                "force_direction": force_direction,
            },
            "geometry": {
                "start_label": "P",
                "target_label": "Q",
                "start_point": {"x": "0", "y": "a"},
                "target_point": {"x": "b", "y": "0"},
                "field_width": "L",
                "radius": "R",
            },
            "parameters": {key: value for key, value in params.items() if value},
            "formula_steps": [
                {"label": "圆周半径", "formula": "R = mv0/(eB)"},
                {"label": "几何关系", "formula": "L = R sin(theta)"},
                {"label": "竖直位移", "formula": "Delta y = R(1 - cos(theta))"},
                {"label": "最终关系", "formula": "tan(theta) = (a - Delta y) / x1"},
            ],
            "focus_points": focus_points[:4],
        }
        return RichArtifact(
            artifact_type="physics_scene_spec",
            title=title,
            description="使用 App 内置物理模板渲染的题目情景动画。",
            mime_type="application/json",
            content=json.dumps(spec, ensure_ascii=False),
        )

    def _looks_like_electromagnetism(self, text: str) -> bool:
        lowered = text.lower()
        return any(
            token in lowered
            for token in [
                "磁场",
                "电场",
                "带电",
                "电子",
                "电荷",
                "洛伦兹",
                "安培力",
                "电磁",
                "感应电流",
                "磁通量",
                "导体棒",
                "线圈",
            ]
        )

    def _extract_named_number(self, text: str, name: str) -> str:
        if not text:
            return ""
        pattern = re.compile(
            rf"(?<![A-Za-z]){re.escape(name)}\s*[=＝]\s*([0-9]+(?:\.[0-9]+)?)",
            re.IGNORECASE,
        )
        match = pattern.search(text)
        if not match:
            return ""
        return match.group(1)

    def _field_marker_label(self, marker: str) -> str:
        if marker == "dot":
            return "磁场垂直纸面向外"
        if marker == "cross":
            return "磁场垂直纸面向里"
        return "电场方向"

    def _particle_label(self, charge_sign: str) -> str:
        if charge_sign == "negative":
            return "电子"
        if charge_sign == "positive":
            return "带正电粒子"
        return "带电粒子"

    def _should_generate_physics_html(
        self,
        *,
        cleaned_question: str,
        scene_brief: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> bool:
        scene_type = self._physics_scene_type_from_context(
            cleaned_question=cleaned_question,
            scene_brief=scene_brief,
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
        scene_brief: str,
        subject: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> str:
        normalized_subject = subject or "物理"
        if "物理" not in normalized_subject:
            return "当前题目未被识别为物理题，暂不支持生成物理动画演示。"

        scene_type = self._physics_scene_type_from_context(
            cleaned_question=cleaned_question,
            scene_brief=scene_brief,
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
        scene_brief: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> str:
        scene_source = " ".join(
            part.strip()
            for part in [
                cleaned_question,
                scene_brief,
                " ".join(knowledge_points),
                solution_summary,
                " ".join(solution_steps),
            ]
            if part and part.strip()
        )
        return _physics_scene_type(scene_source)

    def _fallback_scene_brief(
        self,
        *,
        cleaned_question: str,
        knowledge_points: List[str],
        solution_summary: str,
    ) -> str:
        scene_type = _physics_scene_type(
            " ".join(
                part.strip()
                for part in [
                    cleaned_question,
                    " ".join(knowledge_points),
                    solution_summary,
                ]
                if part and part.strip()
            )
        )
        scene_templates = {
            "board_block": "画面重点放在木板与物块的相对位置、运动方向和摩擦作用。",
            "incline": "画面重点放在斜面、物体位置、速度方向和沿斜面的受力关系。",
            "projectile": "画面重点放在抛射轨迹、关键位置和速度方向变化。",
            "collision": "画面重点放在多个物体的接触过程以及碰撞前后状态变化。",
            "optics": "画面重点放在光路、透镜或镜面位置，以及像或光线方向变化。",
            "circuit": "画面重点放在元件连接关系、电流路径、开关或表计状态变化。",
            "electromagnetism": "画面重点放在场区范围、粒子或导体位置、运动方向和受力方向。",
            "mechanics": "画面重点放在题目对象、空间位置关系和主要运动过程。",
            "unknown": "画面重点放在题目对象、空间位置关系和主要运动过程。",
        }
        question_excerpt = self._display_plain_text(cleaned_question, limit=72)
        focus_points = [
            self._display_plain_text(item, limit=14)
            for item in knowledge_points[:3]
            if str(item).strip()
        ]
        focus_text = "、".join(item for item in focus_points if item)
        summary_excerpt = self._display_plain_text(solution_summary, limit=48)

        parts = [scene_templates.get(scene_type, scene_templates["unknown"])]
        if question_excerpt:
            parts.append(f"题目片段：{question_excerpt}")
        if focus_text:
            parts.append(f"关注：{focus_text}")
        if summary_excerpt:
            parts.append(f"解析提示：{summary_excerpt}")
        return " ".join(parts).strip()

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
只返回 JSON。
必须包含 `scene_brief`。
`scene_brief` 应描述图像中的场景结构，而不是泛泛解释。
优先描述：对象、相对位置、箭头、方向、边界、轨迹、场区、极板、导轨、光路、电路连接、标签。
如果图像里无法清楚看出场景结构，就让 `scene_brief` 返回空字符串。
你是“错题都队”的学科辅导 AI，需要稳定输出适合前端直接消费的 JSON。

请基于以下输入，输出一个 JSON 对象，不要输出 Markdown，不要加代码块围栏。

输入信息：
- 学科：{request.subject}
- 题目：{cleaned_question}
- 用户答案：{request.user_answer or "未提供"}
- 用户自述错因：{request.wrong_reason_hint or "未提供"}

字段职责与前端展示顺序：
{ANALYSIS_FIELD_GUIDANCE}

输出 JSON 字段要求：
{{
  "cleaned_question": "清洗后的题目文本",
  "subject": "学科名",
  "knowledge_points": ["知识点1", "知识点2"],
  "solution_summary": "破题关键和最终结论，60-100字",
  "solution_steps": ["讲解文字。\\n$$核心公式1$$\\n继续说明公式来源。", "讲解文字。\\n$$核心公式2$$\\n继续说明代换依据。", "讲解文字。\\n$$核心公式3$$\\n继续说明结论。"],
  "mistake_diagnosis": "",
  "review_plan": {{
    "next_review_in_days": 1,
    "focus": "",
    "schedule": [1, 3, 7, 15]
  }},
  "similar_questions": [
    {{
      "prompt": "1道变式题，60字以内",
      "answer_outline": "答案提纲，80字以内"
    }}
  ],
  "rich_artifacts": []
}}

要求：
1. 所有字段必须返回，没有内容时返回空数组或空字符串。
2. 禁止把同一段推导、结论、错因或复习建议重复写进多个字段。
3. solution_summary 只写关键突破口和最终结论，60-100字。
4. mistake_diagnosis 和 review_plan.focus 默认返回空字符串，不要生成独立错因诊断或复习建议。
5. solution_steps 建议 5-7 步，每步 70-160 字，只写推导；必须写出关键等式、代换依据和条件来源。每个核心公式必须单独用 $$...$$ 包裹并独占一行，公式前后配简短文字讲解。
6. similar_questions 最多返回 1 个。
7. rich_artifacts 默认返回空数组；禁止返回纯文字 study_card。
8. 只有真正需要函数图像、几何示意、物理动画、化学流程图时，才返回 rich_artifacts；数学 rich_artifacts 只能用于坐标图或几何图，不要写二次解析文字。
9. 凡是公式、方程、积分、根号、分式、上下标、区间、向量、希腊字母，请优先使用 LaTeX 形式表达。
10. 行内公式请用 $...$ 包裹，独立大公式可用 $$...$$ 包裹。
11. 即使整段是中文说明，只要其中出现数学表达式，也请把数学表达式单独写成 LaTeX。
12. {extension_hint or "本题无需额外生成复杂扩展内容，rich_artifacts 必须返回空数组。"}
13. {extension_detail or "如果没有把握生成高质量可视化扩展内容，rich_artifacts 必须返回空数组。"}
14. 如果题目信息不完整，也尽量给出合理分析并指出缺失点。
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
只返回 JSON。
必须包含 `scene_brief`。
`scene_brief` 应描述图像中的场景结构，而不是泛泛解释。
优先描述：对象、相对位置、箭头、方向、边界、轨迹、场区、极板、导轨、光路、电路连接、标签。
如果图像里无法清楚看出场景结构，就让 `scene_brief` 返回空字符串。

你是“错题都队”的多模态学科辅导 AI，需要基于“题目图片 + OCR 草稿”输出稳定的 JSON。

请把“图片内容”作为第一信息源，把“OCR 草稿”作为辅助参考，优先纠正 OCR 中的错字、公式、上下标、积分符号、根号、分式、图形标注和换行错误。
不要机械复述 OCR 草稿，如果图片明显更清晰，请以图片为准。

输入信息：
- 学科：{request.subject}
- OCR 草稿：{cleaned_ocr_draft or "未提供"}
- 用户答案：{request.user_answer or "未提供"}
- 用户自述错因：{request.wrong_reason_hint or "未提供"}

字段职责与前端展示顺序：
{ANALYSIS_FIELD_GUIDANCE}

输出 JSON 字段要求：
{{
  "cleaned_question": "根据图片纠正后的完整题目文本",
  "subject": "学科名",
  "knowledge_points": ["知识点1", "知识点2"],
  "solution_summary": "破题关键和最终结论，60-100字",
  "solution_steps": ["讲解文字。\\n$$核心公式1$$\\n继续说明公式来源。", "讲解文字。\\n$$核心公式2$$\\n继续说明代换依据。", "讲解文字。\\n$$核心公式3$$\\n继续说明结论。"],
  "mistake_diagnosis": "",
  "review_plan": {{
    "next_review_in_days": 1,
    "focus": "",
    "schedule": [1, 3, 7, 15]
  }},
  "similar_questions": [
    {{
      "prompt": "1道变式题，60字以内",
      "answer_outline": "答案提纲，80字以内"
    }}
  ],
  "rich_artifacts": []
}}

要求：
1. 只输出 JSON，不要加 Markdown 代码块。
2. cleaned_question 必须尽量还原图片里的原题；如果仍有局部不确定，可保守表达但不要照搬明显错误的 OCR。
3. 如果是数学、物理、化学题，优先纠正公式、符号、单位和结构。
4. 禁止把同一段推导、结论、错因或复习建议重复写进多个字段。
5. solution_summary 只写关键突破口和最终结论，60-100字。
6. mistake_diagnosis 和 review_plan.focus 默认返回空字符串，不要生成独立错因诊断或复习建议。
7. solution_steps 建议 5-7 步，每步 70-160 字，只写推导；必须写出关键等式、代换依据和条件来源。每个核心公式必须单独用 $$...$$ 包裹并独占一行，公式前后配简短文字讲解。
8. similar_questions 最多返回 1 个。
9. rich_artifacts 默认返回空数组；禁止返回纯文字 study_card。
10. 只有真正需要函数图像、几何示意、物理动画、化学流程图时，才返回 rich_artifacts；数学 rich_artifacts 只能用于坐标图或几何图，不要写二次解析文字。
11. 凡是公式、方程、积分、根号、分式、上下标、区间、向量、希腊字母，请优先使用 LaTeX 形式表达。
12. 行内公式请用 $...$ 包裹，独立大公式可用 $$...$$ 包裹。
13. {extension_hint or "本题无需额外生成复杂扩展内容，rich_artifacts 必须返回空数组。"}
14. {extension_detail or "如果没有把握生成高质量可视化扩展内容，rich_artifacts 必须返回空数组。"}
15. 如果图片信息仍不足，也要在 solution_summary 或 mistake_diagnosis 中明确说明不确定点。
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
                if (
                    next_char in valid_escapes
                    and not self._is_latex_command_escape(text, index)
                    and not self._is_broken_unicode_escape(text, index)
                ):
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

    def _is_latex_command_escape(self, text: str, slash_index: int) -> bool:
        command_start = slash_index + 1
        if command_start >= len(text) or not text[command_start].isalpha():
            return False

        command_end = command_start
        while command_end < len(text) and text[command_end].isalpha():
            command_end += 1

        command = text[command_start:command_end]
        common_latex_commands = {
            "alpha",
            "approx",
            "bar",
            "because",
            "begin",
            "beta",
            "boxed",
            "cdot",
            "circ",
            "cos",
            "cot",
            "csc",
            "Delta",
            "delta",
            "displaystyle",
            "div",
            "dot",
            "dfrac",
            "end",
            "epsilon",
            "eta",
            "exists",
            "exp",
            "forall",
            "frac",
            "gamma",
            "Gamma",
            "ge",
            "geq",
            "hat",
            "iint",
            "in",
            "infty",
            "int",
            "iota",
            "kappa",
            "lambda",
            "Lambda",
            "ldots",
            "left",
            "le",
            "leq",
            "lim",
            "ln",
            "log",
            "max",
            "min",
            "mu",
            "nabla",
            "neq",
            "notin",
            "omega",
            "Omega",
            "oint",
            "operatorname",
            "overbrace",
            "overleftarrow",
            "overline",
            "overrightarrow",
            "partial",
            "perp",
            "phi",
            "Phi",
            "pi",
            "Pi",
            "pm",
            "prod",
            "propto",
            "psi",
            "Psi",
            "quad",
            "qquad",
            "rho",
            "rightarrow",
            "Rightarrow",
            "right",
            "sec",
            "sigma",
            "Sigma",
            "sim",
            "sin",
            "sqrt",
            "subset",
            "subseteq",
            "sum",
            "tan",
            "tau",
            "text",
            "textbf",
            "textit",
            "theta",
            "Theta",
            "times",
            "to",
            "triangle",
            "underline",
            "underbrace",
            "varDelta",
            "varepsilon",
            "varphi",
            "varpi",
            "varrho",
            "varsigma",
            "vartheta",
            "vec",
            "widehat",
        }
        return command in common_latex_commands

    def _is_broken_unicode_escape(self, text: str, slash_index: int) -> bool:
        if slash_index + 1 >= len(text) or text[slash_index + 1] != "u":
            return False

        unicode_digits = text[slash_index + 2:slash_index + 6]
        if len(unicode_digits) != 4:
            return True
        return any(char not in string.hexdigits for char in unicode_digits)

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
                "数学题如果返回 chart_spec，只允许用于坐标图、函数图像、几何示意或圆锥曲线草图；content 必须是 JSON 字符串并包含 coordinate_graph。不要在 chart_spec 中承载解题步骤、核心思路、易错提醒或复习清单。"
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
        scene_brief: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> RichArtifact | None:
        prompt = self._build_physics_html_prompt_relaxed(
            cleaned_question=cleaned_question,
            scene_brief=scene_brief,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            solution_steps=solution_steps,
        )
        started_at = time.perf_counter()
        try:
            raw_html = self.client.animation_chat_completion(prompt)
        except Exception as exc:
            logger.warning(
                "physics html generation failed elapsed=%.2fs error=%s",
                time.perf_counter() - started_at,
                exc,
            )
            return None

        html_document = self._extract_html_document(raw_html)
        if not html_document:
            lowered_raw = raw_html.lower()
            logger.warning(
                "physics html generation returned empty html elapsed=%.2fs raw_len=%s has_doctype=%s has_html=%s has_body=%s has_closing_html=%s preview=%r",
                time.perf_counter() - started_at,
                len(raw_html),
                "<!doctype html" in lowered_raw,
                "<html" in lowered_raw,
                "<body" in lowered_raw,
                "</html>" in lowered_raw,
                self._log_preview(raw_html),
            )
            return None

        logger.info(
            "physics html extracted elapsed=%.2fs raw_len=%s html_len=%s preview=%r",
            time.perf_counter() - started_at,
            len(raw_html),
            len(html_document),
            self._log_preview(html_document),
        )
        question_scene = self._physics_scene_type_from_context(
            cleaned_question=cleaned_question,
            scene_brief=scene_brief,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            solution_steps=solution_steps,
        )
        html_document = self._ensure_physics_scene_marker(
            html_document,
            scene_type=question_scene,
        )

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
        if not validated:
            marker_match = re.search(
                r'data-scene=["\']([a-z_]+)["\']',
                html_document,
                re.IGNORECASE,
            )
            html_scene = (
                marker_match.group(1).lower()
                if marker_match
                else _physics_scene_type(html_document)
            )
            logger.warning(
                "physics html artifact filtered elapsed=%.2fs question_scene=%s html_scene=%s preview=%r",
                time.perf_counter() - started_at,
                question_scene,
                html_scene,
                self._log_preview(html_document),
            )
        return validated[0] if validated else None

    def _generate_circuit_scene_artifact(
        self,
        *,
        cleaned_question: str,
        scene_brief: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> RichArtifact | None:
        prompt = self._build_circuit_scene_prompt(
            cleaned_question=cleaned_question,
            scene_brief=scene_brief,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            solution_steps=solution_steps,
        )
        started_at = time.perf_counter()
        try:
            raw_spec = self.client.animation_chat_completion(prompt)
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
        scene_brief: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> str:
        points = ", ".join(knowledge_points[:4]) or "电路分析"
        steps = "\n".join(f"- {step}" for step in solution_steps[:3]) or "- 提炼连接方式、电流路径和表计变化。"
        scene_brief_text = self._display_plain_text(scene_brief, limit=180) or "未提供可靠图示摘要"
        return f"""
你正在为移动端 WebView 生成一份精简的电路场景规格。
只返回 JSON，不要输出 HTML，也不要输出 Markdown。

题目：
{cleaned_question}

图像场景摘要：
{scene_brief_text}

知识点：
{points}

解题摘要：
{solution_summary}

关键步骤：
{steps}

按下面的结构返回一个 JSON 对象：
{{
  "title": "short Chinese title",
  "layout": "series|parallel|mixed",
  "components": ["battery", "switch", "resistor", "bulb", "ammeter", "voltmeter"],
  "focus_points": ["point 1", "point 2", "point 3"],
  "phenomenon_summary": "one short sentence",
  "interaction_hint": "one short sentence",
  "current_direction": "clockwise|counterclockwise"
}}

要求：
1. 内容要简短，并且紧扣这道题。
2. 把图像场景摘要视为高优先级证据，用来判断接线布局、支路结构、表计位置、开关状态和电流路径。
3. 如果题干与图像场景摘要冲突，优先采用图像场景摘要中的空间布局和连接结构。
4. `components` 最多包含 6 项。
5. `focus_points` 需要包含 2 到 4 个简短要点。
6. 如果题目或图像摘要明确提到并联支路，优先使用 `parallel`，否则用 `series` 或 `mixed`。
7. 所有值都应为普通字符串或字符串数组。
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
        scene_brief: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> RichArtifact | None:
        prompt = self._build_electromagnetism_scene_prompt(
            cleaned_question=cleaned_question,
            scene_brief=scene_brief,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            solution_steps=solution_steps,
        )
        started_at = time.perf_counter()
        try:
            raw_spec = self.client.animation_chat_completion(prompt)
        except Exception as exc:
            logger.warning(
                "electromagnetism scene spec generation failed elapsed=%.2fs error=%s",
                time.perf_counter() - started_at,
                exc,
            )
            return None
        logger.info(
            "electromagnetism raw spec elapsed=%.2fs preview=%s",
            time.perf_counter() - started_at,
            self._log_preview(raw_spec, limit=1200),
        )

        try:
            scene_spec = self._parse_json(raw_spec)
        except Exception as exc:
            logger.warning(
                "electromagnetism scene spec parse failed elapsed=%.2fs error=%s",
                time.perf_counter() - started_at,
                exc,
            )
            return None
        logger.info(
            "electromagnetism parsed spec elapsed=%.2fs content=%s",
            time.perf_counter() - started_at,
            self._log_preview(json.dumps(scene_spec, ensure_ascii=False), limit=1200),
        )

        scene_spec = self._enrich_electromagnetism_scene_spec(
            scene_spec=scene_spec,
            cleaned_question=cleaned_question,
            scene_brief=scene_brief,
            knowledge_points=knowledge_points,
            solution_summary=solution_summary,
            solution_steps=solution_steps,
        )
        logger.info(
            "electromagnetism final spec subtype=%s field=%s marker=%s trajectory=%s velocity=%s force=%s rod=%s title=%s",
            scene_spec.get("subtype"),
            scene_spec.get("field_type"),
            scene_spec.get("field_marker"),
            scene_spec.get("trajectory"),
            scene_spec.get("velocity_direction"),
            scene_spec.get("force_direction"),
            scene_spec.get("rod_motion_direction"),
            self._display_plain_text(str(scene_spec.get("title") or ""), limit=24),
        )

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
        scene_brief: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> str:
        points = ", ".join(knowledge_points[:4]) or "电磁分析"
        steps = "\n".join(f"- {step}" for step in solution_steps[:3]) or "- 提炼场的方向、受力方向和关键现象。"
        scene_brief_text = self._display_plain_text(scene_brief, limit=180) or "未提供可靠图示摘要"
        return f"""
你正在为移动端 WebView 生成一份精简的电磁场景规格。
只返回 JSON，不要输出 HTML，也不要输出 Markdown。

题目：
{cleaned_question}

图像场景摘要：
{scene_brief_text}

知识点：
{points}

解题摘要：
{solution_summary}

关键步骤：
{steps}

按下面的结构返回一个 JSON 对象：
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

要求：
1. 内容要简短，并且紧扣这道题。
2. 把图像场景摘要视为高优先级证据，用来判断场方向、场区范围、粒子或导体棒位置、运动方向和受力方向。
3. 如果题干与图像场景摘要冲突，优先采用图像场景摘要中的空间布局和方向信息。
4. 粒子偏转、洛伦兹力、圆周轨迹相关题优先使用 `charged_particle`。
5. 导体棒、线圈、磁通量、感应电流相关题优先使用 `electromagnetic_induction`。
6. `focus_points` 需要包含 2 到 4 个简短要点。
7. 磁场垂直纸面向里时使用 `field_marker=cross`，垂直纸面向外时使用 `dot`。
8. 只有当题干、图像摘要或解题摘要中能明确判断时，才填写具体的 `trajectory` 和 `force_direction`。
9. 所有值都应为普通字符串或字符串数组。
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

    def _enrich_electromagnetism_scene_spec(
        self,
        *,
        scene_spec: Dict[str, Any],
        cleaned_question: str,
        scene_brief: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> Dict[str, Any]:
        enriched = dict(scene_spec)
        combined_context = " ".join(
            part.strip()
            for part in [
                cleaned_question,
                scene_brief,
                solution_summary,
                " ".join(knowledge_points),
                " ".join(solution_steps),
            ]
            if part and part.strip()
        )
        guessed_subtype = self._guess_electromagnetism_subtype(combined_context)
        guessed_field_type = self._guess_electromagnetism_field_type(
            cleaned_question=combined_context,
            knowledge_points=[],
        )
        subtype = self._electromagnetism_choice(
            enriched.get("subtype"),
            {"charged_particle", "electromagnetic_induction"},
            guessed_subtype,
        )
        field_type = self._electromagnetism_choice(
            enriched.get("field_type"),
            {"magnetic", "electric", "mixed"},
            guessed_field_type,
        )

        enriched["subtype"] = subtype
        enriched["field_type"] = field_type
        enriched["field_marker"] = self._electromagnetism_choice(
            enriched.get("field_marker"),
            {"cross", "dot", "line"},
            self._infer_electromagnetism_field_marker(
                combined_context=combined_context,
                field_type=field_type,
            ),
        )
        enriched["trajectory"] = self._electromagnetism_choice(
            enriched.get("trajectory"),
            {"arc_up", "arc_down", "straight", "circle"},
            self._infer_electromagnetism_trajectory(combined_context),
        )
        enriched["charge_sign"] = self._electromagnetism_choice(
            enriched.get("charge_sign"),
            {"positive", "negative", "unknown"},
            self._infer_electromagnetism_charge_sign(combined_context),
        )
        enriched["velocity_direction"] = self._electromagnetism_choice(
            enriched.get("velocity_direction"),
            {"left", "right", "up", "down"},
            self._infer_electromagnetism_velocity_direction(
                combined_context,
                subtype,
            ),
        )
        enriched["force_direction"] = self._electromagnetism_choice(
            enriched.get("force_direction"),
            {"up", "down", "left", "right", "none"},
            self._infer_electromagnetism_force_direction(combined_context),
        )
        enriched["rod_motion_direction"] = self._electromagnetism_choice(
            enriched.get("rod_motion_direction"),
            {"left", "right"},
            self._infer_electromagnetism_rod_direction(combined_context),
        )

        if not self._display_plain_text(str(enriched.get("title") or ""), limit=24):
            enriched["title"] = self._guess_electromagnetism_title(
                cleaned_question=combined_context or cleaned_question,
                subtype=subtype,
                field_type=field_type,
            )
        if not self._display_plain_text(
            str(enriched.get("phenomenon_summary") or ""),
            limit=60,
        ):
            enriched["phenomenon_summary"] = (
                self._display_plain_text(solution_summary, limit=60)
                or self._guess_electromagnetism_summary(
                    cleaned_question=combined_context or cleaned_question,
                    subtype=subtype,
                    field_type=field_type,
                )
            )
        if not self._display_plain_text(
            str(enriched.get("interaction_hint") or ""),
            limit=48,
        ):
            if subtype == "electromagnetic_induction":
                enriched["interaction_hint"] = "拖动导体棒速度或磁场强度，观察感应电流和指针偏转变化。"
            elif field_type == "electric":
                enriched["interaction_hint"] = "调节电场强度和初速度，观察粒子偏转轨迹与受力方向变化。"
            else:
                enriched["interaction_hint"] = "调节磁场强度和速度，观察粒子轨迹弯曲程度与受力方向变化。"
        if not self._display_plain_text(
            str(enriched.get("direction_hint") or ""),
            limit=48,
        ):
            enriched["direction_hint"] = self._build_electromagnetism_direction_hint(
                combined_context=combined_context,
                subtype=subtype,
                velocity_direction=str(enriched["velocity_direction"]),
                force_direction=str(enriched["force_direction"]),
                rod_motion_direction=str(enriched["rod_motion_direction"]),
            )

        raw_focus_points = enriched.get("focus_points")
        focus_points = [
            str(item).strip()
            for item in raw_focus_points
            if str(item).strip()
        ] if isinstance(raw_focus_points, list) else []
        if not focus_points:
            focus_points = self._build_electromagnetism_focus_points(
                scene_brief=scene_brief,
                knowledge_points=knowledge_points,
                subtype=subtype,
                field_type=field_type,
            )
        enriched["focus_points"] = focus_points[:4]
        return enriched

    def _infer_electromagnetism_field_marker(
        self,
        *,
        combined_context: str,
        field_type: str,
    ) -> str:
        lowered = combined_context.lower()
        if field_type == "electric":
            return "line"
        if any(
            token in lowered
            for token in ["垂直纸面向里", "进入纸面", "入纸面", "纸面向里", "向里", "叉", "×"]
        ):
            return "cross"
        if any(
            token in lowered
            for token in ["垂直纸面向外", "离开纸面", "出纸面", "纸面向外", "向外", "点", "·", "⊙"]
        ):
            return "dot"
        return "cross" if field_type == "magnetic" else "line"

    def _infer_electromagnetism_trajectory(self, combined_context: str) -> str:
        lowered = combined_context.lower()
        if any(token in lowered for token in ["圆周", "圆形", "圆轨道", "圆周运动", "回旋"]):
            return "circle"
        if any(token in lowered for token in ["直线", "不偏转", "匀速", "沿直线"]):
            return "straight"
        if any(token in lowered for token in ["向上偏", "上偏", "向上弯", "向上偏转", "向上弯曲"]):
            return "arc_up"
        if any(token in lowered for token in ["向下偏", "下偏", "向下弯", "向下偏转", "向下弯曲"]):
            return "arc_down"
        return "arc_up"

    def _infer_electromagnetism_charge_sign(self, combined_context: str) -> str:
        lowered = combined_context.lower()
        if any(token in lowered for token in ["负电", "带负电", "负粒子", "电子"]):
            return "negative"
        if any(token in lowered for token in ["正电", "带正电", "正粒子", "正离子", "质子"]):
            return "positive"
        return "unknown"

    def _infer_electromagnetism_velocity_direction(
        self,
        combined_context: str,
        subtype: str,
    ) -> str:
        direction = self._infer_direction_from_context(
            combined_context,
            keywords=["速度", "初速度", "射入", "飞入", "进入", "粒子", "带电粒子"],
            allowed={"right", "left", "up", "down"},
        )
        if direction:
            return direction
        direction = self._infer_direction_from_context(
            combined_context,
            keywords=["导体棒", "金属棒", "棒", "滑杆"],
            allowed={"right", "left"},
        )
        if direction:
            return direction
        if subtype == "electromagnetic_induction":
            return "right"
        return "right"

    def _infer_electromagnetism_force_direction(self, combined_context: str) -> str:
        direction = self._infer_direction_from_context(
            combined_context,
            keywords=["受力", "洛伦兹力", "安培力", "电场力", "偏转"],
            allowed={"right", "left", "up", "down"},
        )
        if direction:
            return direction
        if any(token in combined_context.lower() for token in ["不受力", "受力为零", "无偏转"]):
            return "none"
        return "up"

    def _infer_electromagnetism_rod_direction(self, combined_context: str) -> str:
        direction = self._infer_direction_from_context(
            combined_context,
            keywords=["导体棒", "金属棒", "棒", "滑杆"],
            allowed={"right", "left"},
        )
        return direction or "right"

    def _infer_direction_from_context(
        self,
        text: str,
        *,
        keywords: List[str],
        allowed: set[str],
    ) -> str:
        direction_patterns = [
            ("right", ["向右", "从左向右", "自左向右", "朝右"]),
            ("left", ["向左", "从右向左", "自右向左", "朝左"]),
            ("up", ["向上", "自下向上", "从下向上", "朝上"]),
            ("down", ["向下", "自上向下", "从上向下", "朝下"]),
        ]

        normalized = re.sub(r"\s+", "", text)
        for keyword in keywords:
            for direction, aliases in direction_patterns:
                if direction not in allowed:
                    continue
                for alias in aliases:
                    if re.search(rf"{re.escape(keyword)}[^，。；,.:\n]{{0,12}}{re.escape(alias)}", normalized):
                        return direction
                    if re.search(rf"{re.escape(alias)}[^，。；,.:\n]{{0,8}}{re.escape(keyword)}", normalized):
                        return direction
        return ""

    def _build_electromagnetism_direction_hint(
        self,
        *,
        combined_context: str,
        subtype: str,
        velocity_direction: str,
        force_direction: str,
        rod_motion_direction: str,
    ) -> str:
        direction_labels = {
            "left": "左",
            "right": "右",
            "up": "上",
            "down": "下",
        }
        if subtype == "electromagnetic_induction":
            if rod_motion_direction in direction_labels:
                return f"先看导体棒向{direction_labels[rod_motion_direction]}运动，再结合磁场方向判断感应电流方向。"
            return "先看导体棒运动方向，再结合磁场方向判断感应电流方向。"
        if force_direction == "none":
            return "粒子合力接近零，重点观察它是否保持直线运动。"
        if velocity_direction in direction_labels and force_direction in direction_labels:
            return (
                f"先看速度方向向{direction_labels[velocity_direction]}，再结合场方向判断受力是否指向"
                f"{direction_labels[force_direction]}。"
            )
        if "右手定则" in combined_context or "左手定则" in combined_context:
            return "结合题目中的手指定则，按场方向和运动方向判断受力或电流方向。"
        return "结合场方向、运动方向和受力方向，判断粒子偏转或感应电流的变化。"

    def _build_electromagnetism_focus_points(
        self,
        *,
        scene_brief: str,
        knowledge_points: List[str],
        subtype: str,
        field_type: str,
    ) -> List[str]:
        focus_points = [
            self._display_plain_text(item, limit=20)
            for item in [scene_brief, *knowledge_points]
        ]
        normalized = [item for item in focus_points if item]
        if normalized:
            return normalized[:4]
        if subtype == "electromagnetic_induction":
            return ["导体棒运动方向", "磁场区域范围", "感应电流方向"]
        if field_type == "electric":
            return ["极板位置关系", "粒子入场方向", "电场力方向"]
        return ["磁场方向", "粒子速度方向", "洛伦兹力方向"]

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
            "field_type": guessed_field_type,
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
        scene_brief: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> str:
        combined_text = " ".join(
            part.strip()
            for part in [
                cleaned_question,
                scene_brief,
                " ".join(knowledge_points[:3]),
                solution_summary,
            ]
            if part and part.strip()
        )
        scene_hint = _physics_scene_type(combined_text)
        if scene_hint == "unknown":
            scene_hint = "mechanics"

        scene_labels = {
            "board_block": "木板与物块",
            "incline": "斜面运动",
            "projectile": "抛体运动",
            "collision": "碰撞过程",
            "optics": "光学成像",
            "circuit": "电路过程",
            "electromagnetism": "电磁过程",
            "mechanics": "力学过程",
        }
        scene_goals = {
            "board_block": "突出木板、物块、相对滑动趋势和关键受力变化。",
            "incline": "突出物体沿斜面的运动、受力方向和速度变化。",
            "projectile": "突出轨迹、速度方向变化和关键位置关系。",
            "collision": "突出碰撞前后速度、形变或动量变化。",
            "optics": "突出光线传播路径、成像位置或反射折射过程。",
            "circuit": "突出电路连接关系、电流方向和元件状态变化。",
            "electromagnetism": "突出电场/磁场方向、粒子或导体运动以及力的方向。",
            "mechanics": "突出题目中的主要物体、运动过程和关键物理量变化。",
        }
        scene_direction = {
            "board_block": "必须把木板和物块都画出来，动画围绕相对运动或摩擦作用展开。",
            "incline": "必须出现斜面、物体和沿斜面的运动，不要改成平地模板。",
            "projectile": "必须出现抛射轨迹或曲线运动，不要退化成普通平移方块。",
            "collision": "必须出现两个或多个相互作用对象，体现碰撞前后状态变化。",
            "optics": "必须出现真实光路、透镜/镜面或像的位置，不要改成力学场景。",
            "circuit": "必须出现真实电路结构与元件连接，不要改成受力示意图。",
            "electromagnetism": "必须出现电场线、磁场区域、粒子/导体运动轨迹或受力方向，不要改成木板小车模板。",
            "mechanics": "动画必须围绕题目里的对象和过程，不要生成无关的通用页面。",
        }
        control_hint = {
            "board_block": "可提供 1 到 2 个控件，例如推力或摩擦因数。",
            "incline": "可提供 1 到 2 个控件，例如倾角或初速度。",
            "projectile": "可提供 1 到 2 个控件，例如初速度或发射角。",
            "collision": "可提供 1 到 2 个控件，例如质量比或碰撞前速度。",
            "optics": "可提供 1 到 2 个控件，例如物距或焦距。",
            "circuit": "可提供 1 到 2 个控件，例如开关状态或电阻大小。",
            "electromagnetism": "可提供 1 到 2 个控件，例如场强、磁感应强度、速度或电荷量。",
            "mechanics": "可提供 1 到 2 个最关键的参数控件。",
        }

        focus_points = [
            self._display_plain_text(point, limit=14)
            for point in knowledge_points[:2]
            if str(point).strip()
        ]
        focus_text = " / ".join(point for point in focus_points if point) or "对象、方向、关键物理量变化"

        animation_goal = self._display_plain_text(solution_summary, limit=140)
        if not animation_goal:
            animation_goal = scene_goals.get(scene_hint, scene_goals["mechanics"])

        question_excerpt = self._display_plain_text(cleaned_question, limit=220)
        scene_brief_text = self._display_plain_text(scene_brief, limit=260)
        if scene_brief_text:
            animation_goal = f"{scene_brief_text} {animation_goal}".strip()
        scene_label = scene_labels.get(scene_hint, "物理过程")
        return f"""
你是一个擅长把物理题情景压缩成移动端交互动画的前端工程师。
只输出完整 HTML，不要输出 JSON、Markdown、解释、注释或代码围栏。

题目摘录：{question_excerpt}
场景类型：{scene_label}
场景提示：{scene_direction.get(scene_hint, scene_direction["mechanics"])}
知识聚焦：{focus_text}
动画目标：{animation_goal}

生成要求：
1. 输出必须从 `<!DOCTYPE html>` 开始，到 `</html>` 结束，且 `<body>` 必须包含 `data-scene="{scene_hint}"`。
2. 只做单文件、最小可运行 HTML：内联 CSS 和 JS，不依赖外部 CDN、图片、字体、脚本。
3. 页面以动画区域为主，文字极少；只保留短标题、1 句短提示、1 到 2 个必要控件。{control_hint.get(scene_hint, control_hint["mechanics"])}
4. 动画必须贴合这道题的具体对象、方向、运动、场或连接关系，不要套通用木板/方块模板。
5. 不要复述题干，不要展示解题步骤，不要长段说明，不要 LaTeX 源码，不要多余装饰。
6. 优先用简洁的 SVG、Canvas 或少量 DOM 实现，CSS 和 JS 都尽量短。
7. 控制整体体量，尽量不超过 250 行，不超过约 6000 个英文字符；宁可简洁，也要保证完整闭合并可运行。
8. 如果内容过多，优先保留动画本体、对象标签和关键控件，删掉解释文字。
""".strip()

    def _build_physics_html_prompt_relaxed(
        self,
        *,
        cleaned_question: str,
        scene_brief: str,
        knowledge_points: List[str],
        solution_summary: str,
        solution_steps: List[str],
    ) -> str:
        combined_text = " ".join(
            part.strip()
            for part in [
                cleaned_question,
                scene_brief,
                " ".join(knowledge_points[:4]),
                solution_summary,
                " ".join(solution_steps[:3]),
            ]
            if part and part.strip()
        )
        scene_hint = _physics_scene_type(combined_text)
        if scene_hint == "unknown":
            scene_hint = "mechanics"

        scene_labels = {
            "board_block": "木板与物块",
            "incline": "斜面运动",
            "projectile": "抛体运动",
            "collision": "碰撞过程",
            "optics": "光学成像",
            "circuit": "电路过程",
            "electromagnetism": "电磁过程",
            "mechanics": "力学过程",
        }
        focus_points = [
            self._display_plain_text(point, limit=28)
            for point in knowledge_points[:4]
            if str(point).strip()
        ]
        focus_text = " / ".join(point for point in focus_points if point) or "对象、方向、关键物理量变化"
        question_excerpt = self._display_plain_text(cleaned_question, limit=320)
        scene_brief_text = self._display_plain_text(scene_brief, limit=420)
        summary_text = self._display_plain_text(solution_summary, limit=220)
        steps_text = "\n".join(
            f"- {self._display_plain_text(step, limit=80)}"
            for step in solution_steps[:3]
            if self._display_plain_text(step, limit=80)
        ) or "- 暂未提取到可靠的分步摘要。"

        return f"""
你是一名擅长把物理题图和题目情景转化为移动端交互动画的前端工程师。
只输出完整 HTML，不要输出 JSON、Markdown、解释、注释或代码围栏。

题目摘录：
{question_excerpt}

场景类型：
{scene_labels.get(scene_hint, "物理过程")}

图像场景摘要：
{scene_brief_text or "未提取到可靠的图像场景摘要。"}

知识聚焦：
{focus_text}

解题摘要：
{summary_text or "暂未提取到简明解题摘要。"}

关键步骤：
{steps_text}

生成要求：
1. 输出必须从 `<!DOCTYPE html>` 开始，到 `</html>` 结束，并且 `<body>` 必须包含 `data-scene="{scene_hint}"`。
2. 生成完整的单文件页面，只使用内联 CSS 和 JavaScript，不依赖外部 CDN、图片、字体或脚本。
3. 优先还原这道题的具体情景，不要生成通用物理演示壳。
4. 如果题目或图像摘要中出现坐标轴、象限、边界、标记点、场区、轨迹、角度、标签、箭头、极板、导轨、透镜、电路支路等空间结构，必须尽量直接画在页面里。
5. 不要默认生成“黑色背景 + 中央 canvas + 底部滑块栏”的通用布局，除非这种布局确实最适合当前题目。
6. 页面可以适当丰富和完整，只要有助于准确呈现题目情景；不要为了极简而牺牲场景还原度。
7. 可以使用 SVG、Canvas，或 DOM/CSS/JS 的组合，选择最能准确表达该题场景的实现方式。优先保证场景还原和视觉清晰，而不是极端简短。
8. 必要时加入标签、箭头、坐标轴、点名、场方向标记、区域块、状态卡片或少量控件，但重点仍然是动画和图形本身，不要变成长篇文字解析页。
9. 不要复述完整题干或完整推导过程，不要输出未渲染的 LaTeX 源码；可以显示简洁的物理量、点名、轴名和参数符号。
10. 让页面看起来像是专门为这道题设计的，而不是可以套到任何物理动画上的通用模板。
11. 如果场景结构复杂，可以多花一些布局和细节把真实情景画清楚，不要把复杂题压缩成泛化模板。
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

    def _ensure_physics_scene_marker(self, html_document: str, *, scene_type: str) -> str:
        if not html_document or scene_type == "unknown":
            return html_document

        existing_match = re.search(
            r'data-scene=["\']([a-z_]+)["\']',
            html_document,
            re.IGNORECASE,
        )
        if existing_match:
            current_scene = existing_match.group(1).lower()
            if current_scene == scene_type:
                return html_document
            updated = re.sub(
                r'data-scene=["\'][a-z_]+["\']',
                f'data-scene="{scene_type}"',
                html_document,
                count=1,
                flags=re.IGNORECASE,
            )
            logger.info(
                "physics html replaced scene marker from=%s to=%s",
                current_scene,
                scene_type,
            )
            return updated

        updated = re.sub(
            r"<body(?![^>]*data-scene)([^>]*)>",
            lambda match: f'<body{match.group(1)} data-scene="{scene_type}">',
            html_document,
            count=1,
            flags=re.IGNORECASE,
        )
        if updated != html_document:
            logger.info("physics html injected scene marker scene_type=%s", scene_type)
            return updated
        logger.warning(
            "physics html scene marker injection skipped scene_type=%s reason=no_body_tag",
            scene_type,
        )
        return updated

    def _log_preview(self, text: str, limit: int = 800) -> str:
        preview = (text or "").strip()
        preview = re.sub(r"\s+", " ", preview)
        if len(preview) > limit:
            return preview[: limit - 1] + "…"
        return preview

    def _normalize_math_fields(self, parsed: dict) -> dict:
        normalized = dict(parsed)
        text_fields = [
            "cleaned_question",
            "scene_brief",
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

