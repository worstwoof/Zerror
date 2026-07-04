from __future__ import annotations

import json
import unittest
from types import SimpleNamespace

from ai_engine.llm_logic.assistant_chain import AssistantService
from backend.app.schemas.card_schema import AssistantChatRequest


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


if __name__ == "__main__":
    unittest.main()
