from __future__ import annotations

import unittest
from types import SimpleNamespace

from ai_engine.llm_logic.assistant_chain import AssistantService
from backend.app.schemas.card_schema import AssistantChatRequest


class _NoCallClient:
    settings = SimpleNamespace(vivo_text_model="Doubao-Seed-2.0-mini")

    def chat_completion(self, *_args, **_kwargs) -> str:
        raise AssertionError("direct assistant replies should not call the model")


class AssistantChatDirectReplyTest(unittest.TestCase):
    def setUp(self) -> None:
        self.service = AssistantService(_NoCallClient())  # type: ignore[arg-type]

    def test_greeting_stays_conversational(self) -> None:
        reply = self.service.generate_reply(AssistantChatRequest(message="你好"))

        self.assertIn("你好", reply.summary)
        self.assertNotIn("薄弱", reply.summary)
        self.assertFalse(reply.fallback)

    def test_model_question_answers_configured_model(self) -> None:
        reply = self.service.generate_reply(AssistantChatRequest(message="你是什么模型"))

        self.assertIn("Doubao-Seed-2.0-mini", reply.summary)
        self.assertIn("Zerror", reply.title)
        self.assertFalse(reply.fallback)

    def test_capability_question_is_not_forced_to_error_archive(self) -> None:
        reply = self.service.generate_reply(AssistantChatRequest(message="你能做什么"))

        combined = reply.summary + " ".join(section.body for section in reply.sections)
        self.assertIn("普通对话", combined)
        self.assertIn("讲义", combined)
        self.assertNotIn("最弱知识点", combined)


if __name__ == "__main__":
    unittest.main()
