from __future__ import annotations

import json
import unittest
from types import SimpleNamespace

from ai_engine.llm_logic.practice_paper_chain import PracticePaperService
from backend.app.schemas.card_schema import PracticePaperRequest


class _FakeClient:
    def __init__(self, raw_output: str) -> None:
        self.raw_output = raw_output
        self.settings = SimpleNamespace(
            vivo_timeout_seconds=120,
            vivo_max_tokens=4096,
        )

    def chat_completion(self, *_args, **_kwargs) -> str:
        return self.raw_output


class PracticePaperServiceTest(unittest.TestCase):
    def test_prompt_like_worked_examples_are_replaced_with_real_questions(self) -> None:
        raw = json.dumps(
            {
                "title": "椭圆的标准方程与性质专题针对性练习",
                "subtitle": "混合提升卷 · 针对性专题练习",
                "subject_focus": ["数学"],
                "topic_focus": ["椭圆的标准方程与性质"],
                "worked_examples": [
                    "例题：围绕“椭圆的标准方程与性质”设计一道同类例题；解答思路：先列条件，再选模型；步骤/计算过程：分步推导并检查适用条件；答案：写出最终结论。",
                    "例题：从原错题中抽取一个变式情境；解答思路：找出易错入口；步骤/计算过程：写清代入、化简和结论；答案：写出最终答案。",
                ],
                "questions": [
                    {
                        "id": "q1",
                        "type": "单选题",
                        "subject": "数学",
                        "topic": "椭圆的标准方程与性质",
                        "stem": "已知椭圆 \\(\\frac{x^2}{9}+\\frac{y^2}{4}=1\\)，则它的长轴长为多少？",
                        "options": ["6", "4", "3", "2"],
                        "answer": "6",
                        "answer_index": 0,
                        "solution_outline": "先由标准方程确定 \\(a^2=9\\)，再求长轴长 \\(2a\\)。",
                        "solution_steps": [
                            "比较标准方程可得 \\(a^2=9\\)，所以 \\(a=3\\)。",
                            "长轴长为 \\(2a=6\\)。",
                        ],
                    }
                ],
            },
            ensure_ascii=False,
        )
        service = PracticePaperService(_FakeClient(raw))  # type: ignore[arg-type]

        response = service.generate_practice_paper(
            PracticePaperRequest(
                question_count=3,
                strategy_label="混合提升卷",
            )
        )

        html = response.printable_html
        self.assertIn("已知椭圆", html)
        self.assertIn("长轴长", html)
        self.assertIn("答案：</span>6", html)
        self.assertNotIn("设计一道同类例题", html)
        self.assertNotIn("抽取一个变式情境", html)
        self.assertNotIn("写出最终答案", html)


if __name__ == "__main__":
    unittest.main()
