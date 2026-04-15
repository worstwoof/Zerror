from __future__ import annotations

import json
import re
from typing import Any, Dict, List

from backend.app.schemas.card_schema import (
    AnalysisRequest,
    AnalysisResponse,
    ReviewPlan,
    RichArtifact,
    SimilarQuestion,
)

from .ocr_parser import normalize_ocr_text
from .vivo_client import VivoLMClient


SUBJECT_EXTENSION_HINTS: Dict[str, str] = {
    "数学": "可选返回 1 个 rich_artifacts，用于展示函数图像、几何构型或步骤可视化。",
    "物理": "可选返回 1 个 rich_artifacts，用于展示受力、运动、光路或电路变化。",
    "化学": "可选返回 1 个 rich_artifacts，用于展示反应流程、实验步骤或结构变化。",
    "生物": "可选返回 1 个 rich_artifacts，用于展示时间线、结构示意或过程流转。",
    "编程": "可选返回 1 个 rich_artifacts，用于展示关键代码片段或输入输出示例。",
}


class DiagnosticService:
    def __init__(self, client: VivoLMClient) -> None:
        self.client = client

    def analyze_text(self, request: AnalysisRequest) -> AnalysisResponse:
        cleaned_question = normalize_ocr_text(request.question_text)
        prompt = self._build_text_prompt(request, cleaned_question)
        raw_output = self.client.chat_completion(prompt)
        return self._build_response(
            request=request,
            raw_output=raw_output,
            default_cleaned_question=cleaned_question,
            source="text",
        )

    def analyze_image(
        self,
        request: AnalysisRequest,
        image_bytes: bytes,
        mime_type: str,
        ocr_draft: str,
    ) -> AnalysisResponse:
        cleaned_ocr_draft = normalize_ocr_text(ocr_draft)
        prompt = self._build_vision_prompt(request, cleaned_ocr_draft)
        raw_output = self.client.vision_completion(
            prompt=prompt,
            image_bytes=image_bytes,
            mime_type=mime_type,
        )
        return self._build_response(
            request=request,
            raw_output=raw_output,
            default_cleaned_question=cleaned_ocr_draft,
            source="image",
        )

    def _build_response(
        self,
        request: AnalysisRequest,
        raw_output: str,
        default_cleaned_question: str,
        source: str,
    ) -> AnalysisResponse:
        parsed = self._parse_json_with_repair(raw_output)
        parsed = self._normalize_payload(parsed)

        review_data = parsed.get("review_plan") or {}
        review_plan = ReviewPlan(
            next_review_in_days=self._to_int(review_data.get("next_review_in_days"), 1),
            focus=str(review_data.get("focus") or "回顾本题核心概念与易错步骤。"),
            schedule=self._to_int_list(review_data.get("schedule"), [1, 3, 7, 15]),
        )

        similar_questions: List[SimilarQuestion] = []
        for item in parsed.get("similar_questions", []):
            if not isinstance(item, dict):
                continue
            prompt = str(item.get("prompt") or "").strip()
            if not prompt:
                continue
            similar_questions.append(
                SimilarQuestion(
                    prompt=prompt,
                    answer_outline=str(item.get("answer_outline") or ""),
                )
            )

        rich_artifacts: List[RichArtifact] = []
        for item in parsed.get("rich_artifacts", []):
            if not isinstance(item, dict):
                continue
            content = str(item.get("content") or "").strip()
            if not content:
                continue
            rich_artifacts.append(
                RichArtifact(
                    artifact_type=str(item.get("artifact_type") or "study_card"),
                    title=str(item.get("title") or "扩展内容"),
                    description=str(item.get("description") or ""),
                    mime_type=str(item.get("mime_type") or "text/plain"),
                    content=content,
                )
            )

        return AnalysisResponse(
            question_text=request.question_text,
            cleaned_question=str(parsed.get("cleaned_question") or default_cleaned_question),
            subject=str(parsed.get("subject") or request.subject or "通用"),
            knowledge_points=self._to_string_list(parsed.get("knowledge_points")),
            solution_summary=str(parsed.get("solution_summary") or "请结合详细步骤继续完善解析。"),
            solution_steps=self._to_string_list(parsed.get("solution_steps")),
            mistake_diagnosis=str(parsed.get("mistake_diagnosis") or "当前未能稳定识别错因，请结合作答过程补充。"),
            review_plan=review_plan,
            similar_questions=similar_questions,
            rich_artifacts=rich_artifacts,
            source=source,
            raw_model_output=raw_output,
        )

    def _build_text_prompt(self, request: AnalysisRequest, cleaned_question: str) -> str:
        extension_hint = self._pick_extension_hint(request.subject, request.enable_subject_extensions)
        return f"""
你是“错题都队”的学科辅导 AI，需要输出一个可直接被程序解析的 JSON 对象。

输入信息：
- 学科：{request.subject}
- 题目：{cleaned_question}
- 用户答案：{request.user_answer or "未提供"}
- 用户自述错因：{request.wrong_reason_hint or "未提供"}

请仅返回一个 JSON 对象，不要输出 markdown，不要加代码块。

JSON 结构如下：
{{
  "cleaned_question": "清洗后的题目文本",
  "subject": "学科名称",
  "knowledge_points": ["知识点1", "知识点2"],
  "solution_summary": "100字以内总结",
  "solution_steps": ["步骤1", "步骤2", "步骤3"],
  "mistake_diagnosis": "错因诊断",
  "review_plan": {{
    "next_review_in_days": 1,
    "focus": "复习重点",
    "schedule": [1, 3, 7, 15]
  }},
  "similar_questions": [
    {{
      "prompt": "变式题",
      "answer_outline": "答案提纲"
    }}
  ],
  "rich_artifacts": []
}}

规则：
1. 所有字段必须返回，没有内容时返回空字符串或空数组。
2. 所有说明文字使用简体中文。
3. 如果要在 JSON 字符串里写 LaTeX，反斜杠必须写成双反斜杠，例如 \\\\pi、\\\\sqrt{{x}}、\\\\frac{{1}}{{2}}。
4. 不要在 JSON 之外补充解释。
5. {extension_hint}
""".strip()

    def _build_vision_prompt(self, request: AnalysisRequest, cleaned_ocr_draft: str) -> str:
        extension_hint = self._pick_extension_hint(request.subject, request.enable_subject_extensions)
        return f"""
你是“错题都队”的多模态学科辅导 AI，需要基于“题目图片 + OCR 草稿”输出一个可直接被程序解析的 JSON 对象。

要求：
- 以图片内容为第一信息源。
- OCR 草稿只作为辅助，优先纠正其中的错字、公式、上下标、根号、分式和换行问题。

输入信息：
- 学科：{request.subject}
- OCR 草稿：{cleaned_ocr_draft or "未提供"}
- 用户答案：{request.user_answer or "未提供"}
- 用户自述错因：{request.wrong_reason_hint or "未提供"}

请仅返回一个 JSON 对象，不要输出 markdown，不要加代码块。

JSON 结构如下：
{{
  "cleaned_question": "根据图片纠正后的完整题目文本",
  "subject": "学科名称",
  "knowledge_points": ["知识点1", "知识点2"],
  "solution_summary": "100字以内总结",
  "solution_steps": ["步骤1", "步骤2", "步骤3"],
  "mistake_diagnosis": "错因诊断",
  "review_plan": {{
    "next_review_in_days": 1,
    "focus": "复习重点",
    "schedule": [1, 3, 7, 15]
  }},
  "similar_questions": [
    {{
      "prompt": "变式题",
      "answer_outline": "答案提纲"
    }}
  ],
  "rich_artifacts": []
}}

规则：
1. 只返回 JSON。
2. 所有字段必须返回，没有内容时返回空字符串或空数组。
3. 如果要在 JSON 字符串里写 LaTeX，反斜杠必须写成双反斜杠，例如 \\\\pi、\\\\sqrt{{x}}、\\\\frac{{1}}{{2}}。
4. 如果题图信息不完整，也请尽量给出保守分析，并在 summary 或 diagnosis 中说明不确定点。
5. {extension_hint}
""".strip()

    def _pick_extension_hint(self, subject: str, enabled: bool) -> str:
        if not enabled:
            return "rich_artifacts 默认返回空数组。"
        for subject_name, hint in SUBJECT_EXTENSION_HINTS.items():
            if subject_name in subject:
                return hint
        return "rich_artifacts 默认返回空数组。"

    def _parse_json_with_repair(self, raw_output: str) -> dict[str, Any]:
        cleaned = raw_output.strip()
        if cleaned.startswith("```"):
            match = re.search(r"```(?:json)?\s*(.*?)```", cleaned, re.DOTALL | re.IGNORECASE)
            if match:
                cleaned = match.group(1).strip()

        candidates = [cleaned]
        object_match = re.search(r"\{.*\}", cleaned, re.DOTALL)
        if object_match:
            object_candidate = object_match.group(0)
            if object_candidate not in candidates:
                candidates.append(object_candidate)

        last_error: Exception | None = None
        for candidate in candidates:
            try:
                return self._load_json_with_repair(candidate)
            except (json.JSONDecodeError, ValueError) as exc:
                last_error = exc

        raise ValueError("Model output is not valid JSON.") from last_error

    def _load_json_with_repair(self, candidate: str) -> dict[str, Any]:
        try:
            parsed = json.loads(candidate)
        except json.JSONDecodeError:
            repaired = self._escape_invalid_backslashes(candidate)
            parsed = json.loads(repaired)

        if not isinstance(parsed, dict):
            raise ValueError("Model output is not a JSON object.")
        return parsed

    def _escape_invalid_backslashes(self, text: str) -> str:
        return re.sub(r'(?<!\\)\\(?!["\\/bfnrtu])', r"\\\\", text)

    def _normalize_payload(self, parsed: dict[str, Any]) -> dict[str, Any]:
        normalized = dict(parsed)
        normalized["cleaned_question"] = str(normalized.get("cleaned_question") or "")
        normalized["subject"] = str(normalized.get("subject") or "")
        normalized["knowledge_points"] = self._to_string_list(normalized.get("knowledge_points"))
        normalized["solution_summary"] = str(normalized.get("solution_summary") or "")
        normalized["solution_steps"] = self._to_string_list(normalized.get("solution_steps"))
        normalized["mistake_diagnosis"] = str(normalized.get("mistake_diagnosis") or "")

        review_plan = normalized.get("review_plan")
        normalized["review_plan"] = review_plan if isinstance(review_plan, dict) else {}

        similar_questions = normalized.get("similar_questions")
        normalized["similar_questions"] = similar_questions if isinstance(similar_questions, list) else []

        rich_artifacts = normalized.get("rich_artifacts")
        normalized["rich_artifacts"] = rich_artifacts if isinstance(rich_artifacts, list) else []
        return normalized

    def _to_string_list(self, value: Any) -> List[str]:
        if not isinstance(value, list):
            return []
        return [str(item) for item in value if str(item).strip()]

    def _to_int_list(self, value: Any, fallback: List[int]) -> List[int]:
        if not isinstance(value, list):
            return fallback
        converted: List[int] = []
        for item in value:
            try:
                parsed = int(str(item))
            except (TypeError, ValueError):
                continue
            if parsed >= 0:
                converted.append(parsed)
        return converted or fallback

    def _to_int(self, value: Any, fallback: int) -> int:
        try:
            return int(str(value))
        except (TypeError, ValueError):
            return fallback
