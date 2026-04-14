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
        prompt = self._build_prompt(request, cleaned_question)
        raw_output = self.client.chat_completion(prompt)
        parsed = self._parse_json(raw_output)

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
            cleaned_question=cleaned_question,
            subject=str(parsed.get("subject") or request.subject or "通用"),
            knowledge_points=[str(item) for item in parsed.get("knowledge_points", []) if str(item).strip()],
            solution_summary=str(parsed.get("solution_summary", "请结合详细步骤继续完善解析。")),
            solution_steps=[str(item) for item in parsed.get("solution_steps", []) if str(item).strip()],
            mistake_diagnosis=str(parsed.get("mistake_diagnosis", "当前未能稳定识别错因，请结合用户答题过程补充。")),
            review_plan=review_plan,
            similar_questions=similar_questions,
            rich_artifacts=rich_artifacts,
            source="text",
            raw_model_output=raw_output,
        )

    def _build_prompt(self, request: AnalysisRequest, cleaned_question: str) -> str:
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
5. {extension_hint or "本题无需额外生成复杂扩展内容，rich_artifacts 可返回空数组。"}
6. 如果题目信息不完整，也尽量给出合理分析并指出缺失点。
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
