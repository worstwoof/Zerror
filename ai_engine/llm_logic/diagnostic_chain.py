from __future__ import annotations

import json
import re
from typing import Dict, List

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
    "物理": "可以额外返回一个 rich_artifacts 项，artifact_type 用 interactive_html，内容为一个可直接嵌入 WebView 的简洁 HTML 动画，用于演示受力、运动、光路或电路变化。",
    "化学": "可以额外返回一个 rich_artifacts 项，展示反应流程、实验步骤或分子结构变化，可用 interactive_html 或 chart_spec。",
    "数学": "可以额外返回一个 rich_artifacts 项，用 chart_spec 或 interactive_html 展示函数图像、几何构型或步骤可视化。",
    "编程": "可以额外返回一个 rich_artifacts 项，提供 code_snippet 类型，展示关键代码、执行轨迹或输入输出示例。",
    "生物": "可以额外返回一个 rich_artifacts 项，展示 timeline 或 interactive_html，演示过程流转如代谢、遗传或生态循环。",
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
        parsed = self._parse_json(raw_output)
        parsed = self._normalize_math_fields(parsed)
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

        return AnalysisResponse(
            question_text=request.question_text,
            cleaned_question=str(parsed.get("cleaned_question") or default_cleaned_question),
            subject=str(parsed.get("subject") or request.subject or "通用"),
            knowledge_points=[str(item) for item in parsed.get("knowledge_points", []) if str(item).strip()],
            solution_summary=str(parsed.get("solution_summary", "请结合详细步骤继续完善解析。")),
            solution_steps=[str(item) for item in parsed.get("solution_steps", []) if str(item).strip()],
            mistake_diagnosis=str(parsed.get("mistake_diagnosis", "当前未能稳定识别错因，请结合用户答题过程补充。")),
            review_plan=review_plan,
            similar_questions=similar_questions,
            rich_artifacts=rich_artifacts,
            source=source,
            raw_model_output=raw_output,
        )

    def _build_text_prompt(self, request: AnalysisRequest, cleaned_question: str) -> str:
        extension_hint = ""
        if request.enable_subject_extensions:
            for subject_name, hint in SUBJECT_EXTENSION_HINTS.items():
                if subject_name in request.subject:
                    extension_hint = hint
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
9. 如果题目信息不完整，也尽量给出合理分析并指出缺失点。
""".strip()

    def _build_vision_prompt(self, request: AnalysisRequest, cleaned_ocr_draft: str) -> str:
        extension_hint = ""
        if request.enable_subject_extensions:
            for subject_name, hint in SUBJECT_EXTENSION_HINTS.items():
                if subject_name in request.subject:
                    extension_hint = hint
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
10. 如果图片信息仍不足，也要在 solution_summary 或 mistake_diagnosis 中明确说明不确定点。
""".strip()

    def _parse_json(self, raw_output: str) -> dict:
        cleaned = raw_output.strip()
        if cleaned.startswith("```"):
            match = re.search(r"```(?:json)?\s*(.*?)```", cleaned, re.DOTALL)
            if match:
                cleaned = match.group(1).strip()

        try:
            return json.loads(cleaned)
        except json.JSONDecodeError:
            # Try to recover the first JSON object if the model wrapped extra prose.
            match = re.search(r"\{.*\}", cleaned, re.DOTALL)
            if not match:
                raise ValueError(f"模型输出不是合法 JSON：{raw_output}")
            return json.loads(match.group(0))

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

        return normalized

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
