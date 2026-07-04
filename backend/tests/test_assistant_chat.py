from __future__ import annotations

import json
import unittest
from types import SimpleNamespace

from ai_engine.llm_logic.assistant_chain import AssistantService
from backend.app.schemas.card_schema import (
    AssistantChatRequest,
    AssistantSelectionContext,
)


class _RecordingClient:
    settings = SimpleNamespace(vivo_text_model="Doubao-Seed-2.0-mini")

    def __init__(self, response: dict[str, object] | None = None) -> None:
        self.prompts: list[str] = []
        self.response = response or {
            "title": "自然回复",
            "summary": "你好，我在。你可以直接问我问题。",
            "sections": [],
            "linked_knowledge": [],
            "follow_up_prompts": [],
            "sprint_minutes": 0,
        }

    def chat_completion(self, prompt: str, *_args, **_kwargs) -> str:
        self.prompts.append(prompt)
        return json.dumps(self.response, ensure_ascii=False)


class AssistantChatModelReplyTest(unittest.TestCase):
    def setUp(self) -> None:
        self.client = _RecordingClient()
        self.service = AssistantService(self.client)  # type: ignore[arg-type]

    def test_greeting_calls_model_and_allows_simple_bubble_reply(self) -> None:
        reply = self.service.generate_reply(AssistantChatRequest(message="你好"))

        self.assertIn("你好", reply.summary)
        self.assertNotIn("薄弱", reply.summary)
        self.assertFalse(reply.fallback)
        self.assertEqual(reply.sections, [])
        self.assertEqual(len(self.client.prompts), 1)
        self.assertNotIn("local direct", reply.raw_model_output)

    def test_model_question_prompt_exposes_configured_model(self) -> None:
        self.client.response = {
            "title": "模型说明",
            "summary": "我是 Zerror AI 助教，当前普通聊天模型是 Doubao-Seed-2.0-mini。",
            "sections": [],
            "linked_knowledge": [],
            "follow_up_prompts": [],
            "sprint_minutes": 0,
        }
        reply = self.service.generate_reply(AssistantChatRequest(message="你是什么模型"))

        self.assertIn("Doubao-Seed-2.0-mini", reply.summary)
        self.assertFalse(reply.fallback)
        self.assertIn("当前普通聊天模型：Doubao-Seed-2.0-mini", self.client.prompts[0])

    def test_weekday_question_prompt_includes_current_beijing_date(self) -> None:
        self.client.response = {
            "title": "今天星期几",
            "summary": "按当前北京时间，今天是星期六。",
            "sections": [],
            "linked_knowledge": [],
            "follow_up_prompts": [],
            "sprint_minutes": 0,
        }
        reply = self.service.generate_reply(AssistantChatRequest(message="今天星期几"))

        self.assertIn("星期", reply.summary)
        self.assertFalse(reply.fallback)
        self.assertIn("当前北京时间", self.client.prompts[0])
        self.assertRegex(self.client.prompts[0], r"今天是星期[一二三四五六日]")
        self.assertIn("不要说无法获取实时日期", self.client.prompts[0])

    def test_selection_context_focuses_prompt_on_selected_text(self) -> None:
        self.client.response = {
            "title": "这一步为什么成立",
            "summary": "这一步是在用导数为零定位可能的极值点。",
            "sections": [
                {
                    "title": "局部解释",
                    "body": "令 f'(x)=0 不是直接求最大值，而是先找驻点。",
                    "bullets": ["再结合区间端点或单调性检查。"],
                }
            ],
            "linked_knowledge": [],
            "follow_up_prompts": [],
            "sprint_minutes": 0,
        }
        request = AssistantChatRequest(
            message="为什么这里要令导数为 0？",
            selection_context=AssistantSelectionContext(
                question_text="已知函数 f(x)，求区间上的最值。",
                analysis_summary="先求导，再找驻点和端点。",
                selected_text="令 f'(x)=0 求驻点",
                user_question="为什么要这样做",
                source_section="详细推导步骤",
            ),
        )
        reply = self.service.generate_reply(request)

        self.assertFalse(reply.fallback)
        self.assertEqual("这一步为什么成立", reply.title)
        prompt = self.client.prompts[0]
        self.assertIn("局部追问上下文", prompt)
        self.assertIn("令 f'(x)=0 求驻点", prompt)
        self.assertIn("为什么要这样做", prompt)
        self.assertIn("只围绕 selected_text 和 user_question 解释", prompt)


if __name__ == "__main__":
    unittest.main()
