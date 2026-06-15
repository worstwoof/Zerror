from __future__ import annotations

import json
import logging
import re
from collections import Counter
from typing import Any

from backend.app.schemas.card_schema import (
    AssistantChatRequest,
    AssistantChatResponse,
    AssistantChatSection,
    PracticePaperSourceError,
)

from .vivo_client import VivoLMClient


logger = logging.getLogger(__name__)


class AssistantService:
    def __init__(self, client: VivoLMClient) -> None:
        self.client = client

    def generate_reply(self, request: AssistantChatRequest) -> AssistantChatResponse:
        prompt = self._build_prompt(request)
        raw_output = self.client.chat_completion(prompt)
        parsed = self._parse_json(raw_output)
        response = self._build_response(
            request=request,
            parsed=parsed,
            raw_output=raw_output,
        )
        logger.info(
            "assistant reply mode=%s errors=%s sections=%s fallback=%s",
            request.mode,
            len(request.errors),
            len(response.sections),
            response.fallback,
        )
        return response

    def fallback_reply(
        self,
        request: AssistantChatRequest,
        *,
        service_note: str = "",
    ) -> AssistantChatResponse:
        return self._fallback_response(
            request,
            service_note=service_note,
            raw_output="",
        )

    def _build_prompt(self, request: AssistantChatRequest) -> str:
        context_json = json.dumps(
            request.context.model_dump(),
            ensure_ascii=False,
            indent=2,
        )
        errors_json = json.dumps(
            self._source_errors_for_prompt(request.errors),
            ensure_ascii=False,
            indent=2,
        )
        mode_label = self._mode_label(request.mode)
        mode_instruction = self._mode_instruction(request.mode)

        return f"""
只返回 JSON，不要 Markdown，不要代码围栏。
你是 Zerror 的 AI 助教，目标是让学生在很短时间内看懂下一步该怎么学。你的语气要像靠谱的学长：简洁、直接、能落地。

当前模式：{mode_label}
模式要求：
{mode_instruction}

学生的问题：
{request.message}

学习画像：
{context_json}

错题档案节选：
{errors_json}

回答要求：
- 必须利用错题档案中的学科、知识点、错因和已有解析；没有档案时，要先给可执行的第一步。
- 不要空泛鼓励，不要写长篇大论；每个 section 控制在 80 字以内。
- “主动关联知识点”要指出前置知识、相邻知识和容易混淆点。
- “考前短时复习”要给出分钟级安排，适合 10 到 45 分钟内执行。
- 如果用户问具体题目，先给快答，再说明需要补充哪些条件。

输出 JSON 字段：
{{
  "title": "一句话标题",
  "summary": "给学生的直接回答，60 字以内",
  "sections": [
    {{
      "title": "结论/档案记忆/关联知识点/下一步动作/考前安排",
      "body": "这一段的主要说明",
      "bullets": ["最多 3 条动作或判断"]
    }}
  ],
  "linked_knowledge": ["知识点1", "知识点2", "知识点3"],
  "follow_up_prompts": ["下一句可以这样问", "另一个追问"],
  "sprint_minutes": 20
}}
""".strip()

    def _build_response(
        self,
        *,
        request: AssistantChatRequest,
        parsed: dict[str, Any],
        raw_output: str,
    ) -> AssistantChatResponse:
        sections = self._sections(parsed.get("sections"))
        if not sections:
            return self._fallback_response(request, raw_output=raw_output)

        linked_knowledge = self._string_list(parsed.get("linked_knowledge"))[:8]
        if not linked_knowledge:
            linked_knowledge = self._knowledge_candidates(request.errors, limit=6)

        follow_up_prompts = self._string_list(parsed.get("follow_up_prompts"))[:4]
        if not follow_up_prompts:
            follow_up_prompts = self._default_follow_ups(request)

        return AssistantChatResponse(
            mode=request.mode,
            title=self._clip(str(parsed.get("title") or self._mode_label(request.mode)), 40),
            summary=self._clip(
                str(parsed.get("summary") or sections[0].body or request.message),
                120,
            ),
            sections=sections[:5],
            linked_knowledge=linked_knowledge,
            follow_up_prompts=follow_up_prompts,
            sprint_minutes=self._positive_int(parsed.get("sprint_minutes"), default=0),
            fallback=False,
            raw_model_output=raw_output,
        )

    def _fallback_response(
        self,
        request: AssistantChatRequest,
        *,
        service_note: str = "",
        raw_output: str = "",
    ) -> AssistantChatResponse:
        top_subject = self._top_subject(request)
        top_topic = self._top_topic(request)
        knowledge = self._knowledge_candidates(request.errors, limit=6)
        pending = request.context.pending_review_count
        note = service_note.strip()

        if request.mode == "error_memory":
            sections = [
                AssistantChatSection(
                    title="错题档案记忆",
                    body=f"目前待复习 {pending} 道，最集中的模块是「{top_subject} · {top_topic}」。",
                    bullets=[
                        "先回看最近 3 道同专题错题，找共同错因。",
                        "把每道题用一句话写出“我当时卡在哪里”。",
                        "再做 1 道同类题，确认不是只记住答案。",
                    ],
                ),
                AssistantChatSection(
                    title="可以马上问我",
                    body="把其中一道题的题干或你的错误步骤发来，我会按档案上下文继续追问。",
                    bullets=[],
                ),
            ]
        elif request.mode == "knowledge_link":
            sections = [
                AssistantChatSection(
                    title="主动关联知识点",
                    body=f"先围绕「{top_topic}」向前补定义，向后连题型变化。",
                    bullets=[
                        "前置：定义、公式适用条件、基本图像或模型。",
                        "相邻：同一公式在选择、填空、解答题里的变形。",
                        "混淆：符号方向、边界条件、单位或隐含限制。",
                    ],
                ),
                AssistantChatSection(
                    title="下一步动作",
                    body="从错题里挑一题，标出题干条件、用到的公式、最后检查点。",
                    bullets=[],
                ),
            ]
        elif request.mode == "exam_sprint":
            sections = [
                AssistantChatSection(
                    title="30 分钟考前短复习",
                    body=f"只抓「{top_subject} · {top_topic}」，不要临时铺太多内容。",
                    bullets=[
                        "0-8 分钟：看错因和公式条件，不重新抄完整解析。",
                        "8-22 分钟：做 2 道同类题，一道基础一道变式。",
                        "22-30 分钟：复述步骤，整理 3 条进考场提醒。",
                    ],
                )
            ]
        else:
            sections = [
                AssistantChatSection(
                    title="快问快答",
                    body="先把问题压成三步：问什么、已知什么、下一步怎么算或怎么判断。",
                    bullets=[
                        f"如果和错题有关，优先回到「{top_topic}」。",
                        "如果是具体题目，把题干和你的卡点发来。",
                        "如果是复习安排，就先定一个 20 分钟的小目标。",
                    ],
                )
            ]

        if note:
            sections.insert(
                0,
                AssistantChatSection(
                    title="服务状态",
                    body=note,
                    bullets=["我先用本地错题档案给你整理，不中断当前学习节奏。"],
                ),
            )

        return AssistantChatResponse(
            mode=request.mode,
            title=self._mode_label(request.mode),
            summary=self._fallback_summary(request, top_subject=top_subject, top_topic=top_topic),
            sections=sections,
            linked_knowledge=knowledge,
            follow_up_prompts=self._default_follow_ups(request),
            sprint_minutes=30 if request.mode == "exam_sprint" else 0,
            fallback=True,
            raw_model_output=raw_output,
        )

    def _source_errors_for_prompt(
        self,
        errors: list[PracticePaperSourceError],
    ) -> list[dict[str, Any]]:
        source = []
        for item in errors[:10]:
            source.append(
                {
                    "id": item.id,
                    "subject": item.subject,
                    "topic": item.topic,
                    "question": self._clip(item.question, 260),
                    "reason": self._clip(item.reason, 120),
                    "tags": item.tags[:6],
                    "my_answer": self._clip(item.my_answer, 120),
                    "ai_analysis": self._clip(item.ai_analysis, 220),
                }
            )
        return source

    def _sections(self, value: Any) -> list[AssistantChatSection]:
        if not isinstance(value, list):
            return []
        sections: list[AssistantChatSection] = []
        for item in value:
            if not isinstance(item, dict):
                continue
            title = str(item.get("title") or "").strip()
            body = str(item.get("body") or "").strip()
            bullets = self._string_list(item.get("bullets"))[:3]
            if not title and not body and not bullets:
                continue
            sections.append(
                AssistantChatSection(
                    title=title or "助教建议",
                    body=self._clip(body, 180),
                    bullets=[self._clip(bullet, 120) for bullet in bullets],
                )
            )
        return sections

    def _knowledge_candidates(
        self,
        errors: list[PracticePaperSourceError],
        *,
        limit: int,
    ) -> list[str]:
        counter: Counter[str] = Counter()
        for item in errors:
            for value in [item.topic, *item.tags]:
                cleaned = str(value or "").strip()
                if cleaned:
                    counter[cleaned] += 1
        return [item for item, _ in counter.most_common(limit)]

    def _top_subject(self, request: AssistantChatRequest) -> str:
        if request.context.weakest_subject and request.context.weakest_subject != "暂无":
            return request.context.weakest_subject
        subjects = [item.subject for item in request.errors if item.subject.strip()]
        return self._most_common(subjects, fallback="当前学科")

    def _top_topic(self, request: AssistantChatRequest) -> str:
        if request.context.weakest_topic and request.context.weakest_topic != "核心错题回收":
            return request.context.weakest_topic
        topics = [item.topic for item in request.errors if item.topic.strip()]
        return self._most_common(topics, fallback="核心错题回收")

    def _fallback_summary(
        self,
        request: AssistantChatRequest,
        *,
        top_subject: str,
        top_topic: str,
    ) -> str:
        if request.context.total_errors <= 0:
            return "先录入或发来一道题，我会从题干、错因和复习动作三步帮你建档。"
        if request.mode == "exam_sprint":
            return f"考前短复习先抓「{top_subject} · {top_topic}」，用 30 分钟完成回看、练习、复述。"
        if request.mode == "knowledge_link":
            return f"我会把「{top_topic}」向前连定义条件，向后连题型变式和易混点。"
        if request.mode == "error_memory":
            return f"错题档案显示当前最该回收的是「{top_subject} · {top_topic}」。"
        return "可以直接问具体题，也可以让我按错题档案快速判断下一步该复习哪里。"

    def _default_follow_ups(self, request: AssistantChatRequest) -> list[str]:
        topic = self._top_topic(request)
        return [
            f"把「{topic}」讲得更简单一点",
            "按我的错题生成 3 个追问题",
            "给我安排 20 分钟复习",
        ]

    def _mode_label(self, mode: str) -> str:
        return {
            "quick_answer": "快问快答",
            "error_memory": "错题档案记忆",
            "knowledge_link": "主动关联知识点",
            "exam_sprint": "考前短时复习",
        }.get(mode, "AI 助教")

    def _mode_instruction(self, mode: str) -> str:
        if mode == "error_memory":
            return "- 先引用错题档案中的重复学科/知识点/错因。\n- 回答要体现“你之前在这些地方错过”。\n- 给 1 到 3 个可追问的问题。"
        if mode == "knowledge_link":
            return "- 主动补出前置知识、相邻题型、混淆点。\n- 不只回答当前问题，要告诉学生还能连到哪里。\n- 关联知识点要短而准。"
        if mode == "exam_sprint":
            return "- 给分钟级短时复习计划。\n- 只保留考前最值钱的动作。\n- 必须说明先做什么、跳过什么、最后检查什么。"
        return "- 用最短路径回答。\n- 先给结论，再给下一步。\n- 不确定时说明还缺什么条件。"

    def _parse_json(self, raw_output: str) -> dict[str, Any]:
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

    def _string_list(self, value: Any) -> list[str]:
        if not isinstance(value, list):
            return []
        return [str(item).strip() for item in value if str(item).strip()]

    def _positive_int(self, value: Any, *, default: int) -> int:
        try:
            parsed = int(value)
        except (TypeError, ValueError):
            return default
        return parsed if parsed > 0 else default

    def _most_common(self, values: list[str], *, fallback: str) -> str:
        counter = Counter(item.strip() for item in values if item and item.strip())
        if not counter:
            return fallback
        return counter.most_common(1)[0][0]

    def _clip(self, text: str, limit: int) -> str:
        normalized = re.sub(r"\s+", " ", (text or "").strip())
        if len(normalized) <= limit:
            return normalized
        return normalized[: limit - 1] + "…"
