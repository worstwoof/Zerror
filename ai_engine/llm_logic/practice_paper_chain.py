from __future__ import annotations

import html
import json
import logging
import re
from collections import Counter
from typing import Any

from backend.app.schemas.card_schema import (
    PracticePaperRequest,
    PracticePaperResponse,
    PracticeQuestion,
)

from .vivo_client import VivoLMClient


logger = logging.getLogger(__name__)

_MATH_SPAN_PATTERN = re.compile(
    r"(\\\(.*?\\\)|\\\[.*?\\\]|\$\$.*?\$\$|\$[^$\n]+\$)",
    re.DOTALL,
)
_BARE_TEX_PATTERN = re.compile(
    r"(?<![\w\\])"
    r"(?:[A-Za-z]\s*=\s*)?"
    r"(?:[-+]?\d+(?:\.\d+)?\s*)?"
    r"(?:"
    r"\\(?:sqrt|frac|dfrac|tfrac|cdot|times|div|le|ge|neq|pm|mp|angle|triangle|parallel|perp|sin|cos|tan|log|ln|lim|sum|int)\b"
    r"(?:\s*\{[^{}]*\}){0,3}"
    r"(?:\s*[+\-*/=]\s*(?:[A-Za-z]|\d+(?:\.\d+)?|\\[A-Za-z]+(?:\s*\{[^{}]*\}){0,3}))*"
    r")"
)


class PracticePaperService:
    def __init__(self, client: VivoLMClient) -> None:
        self.client = client

    def generate_practice_paper(self, request: PracticePaperRequest) -> PracticePaperResponse:
        prompt = self._build_prompt(request)
        raw_output = self.client.chat_completion(prompt)
        parsed = self._parse_json(raw_output)
        response = self._build_response(
            request=request,
            parsed=parsed,
            raw_output=raw_output,
        )
        logger.info(
            "practice paper generated questions=%s subjects=%s topics=%s",
            len(response.questions),
            len(response.subject_focus),
            len(response.topic_focus),
        )
        return response

    def _build_prompt(self, request: PracticePaperRequest) -> str:
        source_errors = self._source_errors_for_prompt(request)
        subjects = [
            item
            for item in request.selected_subjects
            if item.strip() and item.strip() not in {"全部", "全部学科"}
        ]
        subject_hint = "、".join(subjects) if subjects else "从错题档案中自动判断"
        source_json = json.dumps(source_errors, ensure_ascii=False, indent=2)

        return f"""
只返回 JSON，不要 Markdown，不要代码围栏。
你是“错题都队”的教辅编辑和学科命题老师。请基于用户错题档案，生成一份可打印的专题针对性练习讲义。

组卷要求：
- 题量：{request.question_count} 题。
- 选定学科：{subject_hint}。
- 策略：{request.strategy_label}。
- 题目必须围绕错题暴露出的知识点、错因和相近专题生成，不要复刻原题。
- 难度应包含基础回收、变式巩固、综合迁移，适合学生打印后手写完成。
- 讲义不能只有习题，必须先给出公式梳理、题型模型、例题讲解和易错提醒。
- 题干要完整清晰；选择题必须提供 4 个选项和 0-based answer_index；非选择题 answer_index 返回 null。
- options 里只写选项内容，不要带 A.、B.、C.、D.、（A）、A、 等序号前缀。
- LaTeX 输出规范：所有数学公式、变量、方程、分式、根式、指数、坐标、角度、向量和带数学意义的数字都用 MathJax 可渲染格式包裹；行内公式用 \\( ... \\)，展示公式用 \\[ ... \\]。例如必须写成 \\(2\\sqrt{{6}}\\)、\\(x=\\frac{{13}}{{6}}\\)、\\(a^2=b^2+c^2-2bc\\cos A\\)，不要裸写 2\\sqrt{{6}} 或 x=\\frac{{13}}{{6}}。
- 答案 answer、solution_outline、solution_steps 以及讲义的公式卡片、例题讲解、易错提醒中也必须遵守上述 LaTeX 规范；普通解释文字用中文，数学对象进入公式环境。
- 答案解析要像教辅答案栏一样完整，给出 2 到 5 个分步 solution_steps；不要只写一句答案。
- 每道题先判断是否有“视觉结构”：图形位置关系、函数/圆锥曲线图像、运动或力的方向、电路连接、光路、化学流程、统计图表等。
- 如果存在视觉结构，必须在 diagram_svg 返回一个简洁 SVG 示意图；纯代数运算、纯概念辨析、无需图像辅助的题目返回空字符串。
- 圆锥曲线/椭圆/双曲线/抛物线、几何证明、函数图像题通常需要图；若判断需要图，至少标出坐标轴、中心/顶点、焦点、关键点、长短轴、准线、辅助线等核心元素。
- diagram_svg 必须是单个 <svg>...</svg>，不要包含 script、foreignObject、外链图片或事件属性。
- diagram_svg 的 viewBox 建议控制在 320x180 或 360x200 内，画成讲义小图，不要做成占满整页的大图。
- 示意图必须服务解题：标出已知点、关键线段/角度/坐标轴、运动方向、受力方向、电场/磁场方向、电流方向或光路方向等关键标记。
- 物理图不要只画物块/圆点；必须用箭头和文字标注 v、F、a、B、E、I、N、mg 等必要方向。磁场垂直纸面时用 ⊙/⊗ 或点/叉阵列表示，并写清“B 出纸面/入纸面”。
- 函数或几何图要标出坐标轴、关键点、辅助线、角度或长度关系；电路图要标出电源、开关、电流方向和关键表计/电阻。

错题档案：
{source_json}

输出 JSON 字段：
{{
  "title": "专题讲义标题",
  "subtitle": "一行副标题",
  "subject_focus": ["学科"],
  "topic_focus": ["知识点"],
  "estimated_minutes": 25,
  "handout_overview": "这份讲义针对什么问题，80 字以内",
  "learning_targets": ["目标1", "目标2", "目标3"],
  "warmup_notes": ["做题提醒1", "做题提醒2"],
  "concept_review": ["核心概念讲解1", "核心概念讲解2"],
  "formula_cards": ["公式/性质/判定条件1", "公式/性质/判定条件2"],
  "method_models": ["题型模型：识别条件 -> 建模 -> 运算 -> 检验", "常用解题路径"],
  "worked_examples": ["例题：题干摘要；讲解：关键步骤和结论"],
  "common_traps": ["易错提醒1", "易错提醒2"],
  "questions": [
    {{
      "id": "q1",
      "type": "单选题/填空题/解答题/应用题",
      "subject": "学科",
      "topic": "知识点",
      "stem": "题干",
      "options": ["A", "B", "C", "D"],
      "answer": "标准答案",
      "answer_index": 0,
      "solution_outline": "答案要点",
      "solution_steps": ["步骤1", "步骤2", "步骤3"],
      "diagram_svg": "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 360 180\">...</svg>",
      "diagram_caption": "示意图说明",
      "reason_hint": "这题主要回收的错因",
      "difficulty": "基础/中等/提高",
      "estimated_minutes": 3,
      "source_error_ids": ["错题 id"]
    }}
  ],
  "answer_key": ["1. ...", "2. ..."]
}}
""".strip()

    def _source_errors_for_prompt(self, request: PracticePaperRequest) -> list[dict[str, Any]]:
        selected_subjects = {
            item.strip()
            for item in request.selected_subjects
            if item.strip() and item.strip() not in {"全部", "全部学科"}
        }
        errors = request.errors
        if selected_subjects:
            filtered = [
                item
                for item in errors
                if item.subject.strip() in selected_subjects
            ]
            if filtered:
                errors = filtered

        source = []
        for item in errors[:12]:
            source.append(
                {
                    "id": item.id,
                    "subject": item.subject,
                    "topic": item.topic,
                    "question": self._clip(item.question, 320),
                    "reason": self._clip(item.reason, 120),
                    "tags": item.tags[:6],
                    "my_answer": self._clip(item.my_answer, 160),
                    "ai_analysis": self._clip(item.ai_analysis, 240),
                }
            )
        return source

    def _build_response(
        self,
        *,
        request: PracticePaperRequest,
        parsed: dict[str, Any],
        raw_output: str,
    ) -> PracticePaperResponse:
        questions = self._build_questions(request, parsed)
        subject_focus = self._string_list(parsed.get("subject_focus"))
        topic_focus = self._string_list(parsed.get("topic_focus"))

        if not subject_focus:
            subject_focus = self._most_common([item.subject for item in request.errors], limit=3)
        if not topic_focus:
            topic_focus = self._most_common([item.topic for item in request.errors], limit=5)

        answer_key = self._string_list(parsed.get("answer_key"))
        if len(answer_key) < len(questions):
            answer_key = [
                f"{index + 1}. {question.answer}。{question.solution_outline}".strip()
                for index, question in enumerate(questions)
            ]

        estimated_minutes = self._positive_int(
            parsed.get("estimated_minutes"),
            default=sum(q.estimated_minutes for q in questions) or 20,
        )
        response = PracticePaperResponse(
            title=str(parsed.get("title") or self._default_title(request, topic_focus)),
            subtitle=str(parsed.get("subtitle") or f"{request.strategy_label} · 针对性专题练习"),
            subject_focus=subject_focus,
            topic_focus=topic_focus,
            strategy_label=request.strategy_label,
            estimated_minutes=max(1, estimated_minutes),
            handout_overview=str(
                parsed.get("handout_overview")
                or "根据错题档案自动生成的专题讲义，适合打印后进行一轮针对性巩固。"
            ),
            learning_targets=self._string_list(parsed.get("learning_targets"))[:5],
            warmup_notes=self._string_list(parsed.get("warmup_notes"))[:5],
            concept_review=self._string_list(parsed.get("concept_review"))[:6],
            formula_cards=self._string_list(parsed.get("formula_cards"))[:8],
            method_models=self._string_list(parsed.get("method_models"))[:6],
            worked_examples=self._string_list(parsed.get("worked_examples"))[:4],
            common_traps=self._string_list(parsed.get("common_traps"))[:6],
            questions=questions,
            answer_key=answer_key,
            raw_model_output=raw_output,
        )
        return response.model_copy(
            update={"printable_html": self._build_printable_html(response)}
        )

    def _build_questions(
        self,
        request: PracticePaperRequest,
        parsed: dict[str, Any],
    ) -> list[PracticeQuestion]:
        questions = []
        raw_questions = parsed.get("questions")
        if not isinstance(raw_questions, list):
            raw_questions = []

        for index, item in enumerate(raw_questions[: request.question_count]):
            if not isinstance(item, dict):
                continue
            stem = str(item.get("stem") or "").strip()
            answer = str(item.get("answer") or "").strip()
            if not stem or not answer:
                continue
            answer_index = self._optional_int(item.get("answer_index"))
            options = [
                self._normalize_option(item)
                for item in self._string_list(item.get("options"))[:4]
            ]
            if options and answer_index is not None and not 0 <= answer_index < len(options):
                answer_index = None

            question = PracticeQuestion(
                id=str(item.get("id") or f"q{index + 1}"),
                type=str(item.get("type") or "简答题"),
                subject=str(item.get("subject") or ""),
                topic=str(item.get("topic") or ""),
                stem=stem,
                options=options,
                answer=answer,
                answer_index=answer_index,
                solution_outline=str(item.get("solution_outline") or ""),
                solution_steps=self._string_list(item.get("solution_steps"))[:5],
                diagram_svg=self._sanitize_svg(str(item.get("diagram_svg") or "")),
                diagram_caption=str(item.get("diagram_caption") or ""),
                reason_hint=str(item.get("reason_hint") or ""),
                difficulty=str(item.get("difficulty") or "中等"),
                estimated_minutes=max(
                    1,
                    min(30, self._positive_int(item.get("estimated_minutes"), default=4)),
                ),
                source_error_ids=self._string_list(item.get("source_error_ids")),
            )
            questions.append(self._with_fallback_diagram(question))

        if questions:
            return questions
        return self._fallback_questions(request)

    def _fallback_questions(self, request: PracticePaperRequest) -> list[PracticeQuestion]:
        source_errors = request.errors or []
        if not source_errors:
            return [
                PracticeQuestion(
                    id="q1",
                    type="简答题",
                    subject="综合",
                    topic="错题回收",
                    stem="请选择最近一道错题，写出当时出错的关键步骤，并说明下一次如何避免。",
                    answer="应指出原错误步骤、正确思路和可执行的检查方法。",
                    solution_outline="重点看错因是否具体，纠正策略是否可执行。",
                    solution_steps=[
                        "写出原错误步骤，并说明它为什么不成立。",
                        "补上正确概念或公式的适用条件。",
                        "给出下一次做题时可以执行的检查动作。",
                    ],
                    reason_hint="错因复盘不够具体",
                    source_error_ids=[],
                )
            ]

        questions = []
        for index in range(request.question_count):
            source = source_errors[index % len(source_errors)]
            questions.append(
                PracticeQuestion(
                    id=f"q{index + 1}",
                    type="变式简答题",
                    subject=source.subject or "综合",
                    topic=source.topic or "错题回收",
                    stem=(
                        f"围绕“{source.topic or source.subject or '当前错题'}”重新设计一道同类变式题，"
                        "并写出完整解题步骤。"
                    ),
                    answer="答案需覆盖核心概念、关键步骤和易错点检查。",
                    solution_outline=source.ai_analysis or "先定位考点，再按步骤推导，最后回看易错条件。",
                    solution_steps=[
                        "先标出题目所属考点和已知条件。",
                        "选择对应模型或公式，逐步完成推导。",
                        "最后检查原错因是否已经被规避。",
                    ],
                    reason_hint=source.reason or "原错题暴露出的薄弱点",
                    source_error_ids=[source.id],
                    estimated_minutes=4,
                )
            )
        return questions

    def _build_printable_html(self, response: PracticePaperResponse) -> str:
        question_blocks = "\n".join(
            self._question_html(index, question)
            for index, question in enumerate(response.questions)
        )
        answer_blocks = self._answer_key_html(response)
        targets = self._list_items_html(response.learning_targets)
        notes = self._list_items_html(response.warmup_notes)
        topics = " / ".join(response.topic_focus) or "专题巩固"
        subjects = " / ".join(response.subject_focus) or "综合"
        primary_topic = response.topic_focus[0] if response.topic_focus else "本专题"
        concepts = self._list_items_html(
            response.concept_review
            or [
                f"围绕“{primary_topic}”先确认定义、适用条件和常见变式。",
                "把原错题中的已知条件、目标结论和关键限制分开标注，避免直接套题型。",
            ]
        )
        formulas = self._list_items_html(
            response.formula_cards
            or [
                f"{primary_topic}相关公式要先检查适用条件，再代入计算。",
                "遇到等价变形时保留中间步骤，便于回查符号、单位或定义域。",
            ]
        )
        methods = self._list_items_html(
            response.method_models
            or [
                "识别题型 -> 提取条件 -> 选择模型 -> 分步运算 -> 回代检验。",
                "先做基础回收题确认概念，再做变式题检查迁移能力。",
            ]
        )
        examples = self._list_items_html(
            response.worked_examples
            or [
                f"例题讲解：选择一道“{primary_topic}”同类题，先写出条件表，再按模型完成推导。",
                "讲解重点：每一步都说明为什么能这样变形，并在最后标出最容易错的检查点。",
            ]
        )
        traps = self._list_items_html(
            response.common_traps
            or [
                "不要只记结论；先判断题目是否满足公式或模型的前提。",
                "计算完成后至少检查一次符号、范围、单位或选项对应关系。",
            ]
        )

        return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{html.escape(response.title)}</title>
  <style>
    @page {{ size: A4; margin: 14mm; }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      background: #ece7dc;
      color: #1f2924;
      font-family: "Noto Serif SC", "Songti SC", "SimSun", serif;
      line-height: 1.65;
    }}
    .sheet {{
      width: 210mm;
      min-height: 297mm;
      margin: 0 auto;
      padding: 18mm 17mm;
      background: #fffdf7;
    }}
    header {{
      border-bottom: 2px solid #1f2924;
      padding-bottom: 14px;
      margin-bottom: 18px;
    }}
    h1 {{ margin: 0; font-size: 28px; letter-spacing: 0; }}
    .subtitle {{ margin-top: 6px; color: #5f6b60; font-size: 13px; }}
    .meta {{
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 8px;
      margin: 14px 0;
      font-size: 12px;
    }}
    .meta div {{
      border: 1px solid #cfc7b7;
      padding: 8px;
      background: #faf6ec;
    }}
    h2 {{
      margin: 22px 0 10px;
      font-size: 17px;
      border-left: 5px solid #6f9b7d;
      padding-left: 10px;
    }}
    .overview {{ color: #34433b; }}
    .twocol {{
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 14px;
    }}
    .teach-grid {{
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
    }}
    .teach-box {{
      break-inside: avoid;
      border: 1px solid #d9d0bd;
      background: #fffaf0;
      padding: 10px 12px;
      margin-bottom: 12px;
    }}
    .teach-box h3 {{
      margin: 0 0 6px;
      font-size: 14px;
      color: #284b36;
    }}
    ul {{ margin: 8px 0 0 18px; padding: 0; }}
    .question {{
      break-inside: avoid;
      padding: 13px 0;
      border-bottom: 1px dashed #cfc7b7;
    }}
    .q-head {{
      display: flex;
      gap: 8px;
      align-items: center;
      font-weight: 700;
      margin-bottom: 6px;
    }}
    .tag {{
      border: 1px solid #88a891;
      color: #42634c;
      padding: 1px 7px;
      font-size: 11px;
      border-radius: 999px;
      font-weight: 400;
    }}
    .stem {{ margin: 6px 0 8px; white-space: pre-wrap; }}
    .options {{
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 6px 18px;
      margin: 6px 0;
    }}
    .diagram {{
      margin: 10px 0;
      padding: 6px;
      border: 1px solid #d9d0bd;
      background: #fffaf0;
      text-align: center;
    }}
    .diagram svg {{
      width: min(100%, 330px);
      max-width: 330px;
      max-height: 190px;
      height: auto;
    }}
    .caption {{
      margin-top: 4px;
      color: #6f746c;
      font-size: 11px;
      text-align: center;
    }}
    .answer-space {{
      height: 46px;
      border-bottom: 1px solid #d8d0bf;
      margin-top: 6px;
    }}
    .answer-key {{
      break-before: page;
      font-size: 13px;
    }}
    .answer-item {{
      break-inside: avoid;
      margin-bottom: 14px;
    }}
    .answer-item h3 {{
      margin: 0 0 6px;
      font-size: 14px;
      color: #284b36;
    }}
    @media print {{
      body {{ background: white; }}
      .sheet {{ width: auto; min-height: auto; margin: 0; padding: 0; }}
    }}
  </style>
</head>
<body>
  <main class="sheet">
    <header>
      <h1>{html.escape(response.title)}</h1>
      <div class="subtitle">{html.escape(response.subtitle)}</div>
      <section class="meta">
        <div><strong>学科</strong><br />{html.escape(subjects)}</div>
        <div><strong>专题</strong><br />{html.escape(topics)}</div>
        <div><strong>建议用时</strong><br />{response.estimated_minutes} 分钟</div>
      </section>
      <p class="overview">{html.escape(response.handout_overview)}</p>
    </header>
    <section class="twocol">
      <div>
        <h2>学习目标</h2>
        <ul>{targets}</ul>
      </div>
      <div>
        <h2>作答提醒</h2>
        <ul>{notes}</ul>
      </div>
    </section>
    <h2>专题精讲</h2>
    <section class="teach-grid">
      <div class="teach-box">
        <h3>核心概念</h3>
        <ul>{concepts}</ul>
      </div>
      <div class="teach-box">
        <h3>公式与条件</h3>
        <ul>{formulas}</ul>
      </div>
      <div class="teach-box">
        <h3>题型模型</h3>
        <ul>{methods}</ul>
      </div>
      <div class="teach-box">
        <h3>易错提醒</h3>
        <ul>{traps}</ul>
      </div>
    </section>
    <h2>例题讲解</h2>
    <div class="teach-box">
      <ul>{examples}</ul>
    </div>
    <h2>专题练习</h2>
    {question_blocks}
    <section class="answer-key">
      <h2>参考答案与要点</h2>
      {answer_blocks}
    </section>
  </main>
</body>
</html>"""

    def _question_html(self, index: int, question: PracticeQuestion) -> str:
        options = ""
        if question.options:
            labels = ["A", "B", "C", "D"]
            option_items = [
                f"<div>{labels[i]}. {self._math_text_html(option)}</div>"
                for i, option in enumerate(question.options)
            ]
            options = f"<div class=\"options\">{''.join(option_items)}</div>"
        diagram = self._diagram_html(question)
        return f"""
<section class="question">
  <div class="q-head">
    <span>{index + 1}. {self._math_text_html(question.type)}</span>
    <span class="tag">{self._math_text_html(question.difficulty)}</span>
    <span class="tag">{self._math_text_html(question.topic or question.subject or "专题")}</span>
  </div>
  <div class="stem">{self._math_text_html(question.stem)}</div>
  {diagram}
  {options}
  <div class="answer-space"></div>
</section>"""

    def _answer_key_html(self, response: PracticePaperResponse) -> str:
        blocks = []
        for index, question in enumerate(response.questions):
            steps = question.solution_steps
            if not steps and question.solution_outline:
                steps = [question.solution_outline]
            step_items = "".join(f"<li>{self._math_text_html(step)}</li>" for step in steps if step.strip())
            diagram = self._diagram_html(question)
            blocks.append(
                f"""
<section class="answer-item">
  <h3>{index + 1}. {self._math_text_html(question.type)}答案</h3>
  <p><strong>答案：</strong>{self._math_text_html(question.answer)}</p>
  {diagram}
  <ol>{step_items}</ol>
</section>"""
            )
        if blocks:
            return "\n".join(blocks)
        return "<p>暂无参考答案。</p>"

    def _diagram_html(self, question: PracticeQuestion) -> str:
        if not question.diagram_svg.strip():
            return ""
        caption = (
            f"<div class=\"caption\">{html.escape(question.diagram_caption)}</div>"
            if question.diagram_caption.strip()
            else ""
        )
        return f"<div class=\"diagram\">{question.diagram_svg}{caption}</div>"

    def _with_fallback_diagram(self, question: PracticeQuestion) -> PracticeQuestion:
        if question.diagram_svg.strip():
            return question
        diagram_svg = self._fallback_diagram_svg(question)
        if not diagram_svg:
            return question
        caption = question.diagram_caption.strip() or self._fallback_diagram_caption(question)
        return question.model_copy(
            update={
                "diagram_svg": diagram_svg,
                "diagram_caption": caption,
            }
        )

    def _fallback_diagram_svg(self, question: PracticeQuestion) -> str:
        text = f"{question.subject} {question.topic} {question.stem}".lower()
        if any(keyword in text for keyword in ("椭圆", "圆锥曲线", "焦点", "离心率")):
            return self._ellipse_diagram_svg()
        return ""

    def _fallback_diagram_caption(self, question: PracticeQuestion) -> str:
        text = f"{question.subject} {question.topic} {question.stem}".lower()
        if any(keyword in text for keyword in ("椭圆", "圆锥曲线", "焦点", "离心率")):
            return "椭圆标准示意图：标出长轴、短轴、中心、焦点和动点，便于对应题目条件。"
        return "题目关键关系示意图。"

    def _ellipse_diagram_svg(self) -> str:
        return """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 200" role="img" aria-label="椭圆示意图">
  <defs>
    <marker id="arrow" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
      <path d="M0,0 L8,4 L0,8 Z" fill="#52635a"/>
    </marker>
  </defs>
  <rect x="0" y="0" width="360" height="200" fill="#fffaf0"/>
  <line x1="32" y1="100" x2="328" y2="100" stroke="#52635a" stroke-width="1.5" marker-end="url(#arrow)"/>
  <line x1="180" y1="176" x2="180" y2="24" stroke="#52635a" stroke-width="1.5" marker-end="url(#arrow)"/>
  <ellipse cx="180" cy="100" rx="112" ry="58" fill="#dfeadc" stroke="#284b36" stroke-width="2.5"/>
  <line x1="68" y1="100" x2="292" y2="100" stroke="#88a891" stroke-width="2" stroke-dasharray="5 5"/>
  <line x1="180" y1="42" x2="180" y2="158" stroke="#88a891" stroke-width="2" stroke-dasharray="5 5"/>
  <circle cx="128" cy="100" r="4" fill="#b15d3a"/>
  <circle cx="232" cy="100" r="4" fill="#b15d3a"/>
  <circle cx="180" cy="100" r="3.5" fill="#1f2924"/>
  <circle cx="245" cy="63" r="4" fill="#2f6f9f"/>
  <line x1="128" y1="100" x2="245" y2="63" stroke="#d79c4a" stroke-width="1.5"/>
  <line x1="232" y1="100" x2="245" y2="63" stroke="#d79c4a" stroke-width="1.5"/>
  <text x="326" y="94" font-size="13" fill="#52635a">x</text>
  <text x="187" y="30" font-size="13" fill="#52635a">y</text>
  <text x="184" y="114" font-size="12" fill="#1f2924">O</text>
  <text x="112" y="94" font-size="12" fill="#b15d3a">F1</text>
  <text x="238" y="94" font-size="12" fill="#b15d3a">F2</text>
  <text x="251" y="58" font-size="12" fill="#2f6f9f">P(x,y)</text>
  <text x="284" y="117" font-size="12" fill="#284b36">长轴 2a</text>
  <text x="188" y="48" font-size="12" fill="#284b36">短轴 2b</text>
</svg>
""".strip()

    def _list_items_html(self, items: list[str]) -> str:
        if not items:
            return "<li>结合本讲义专题，先回看定义、条件和解题步骤，再进入练习。</li>"
        return "".join(f"<li>{self._math_text_html(item)}</li>" for item in items)

    def _math_text_html(self, value: str) -> str:
        escaped = html.escape(str(value or ""))
        if not escaped:
            return ""

        parts = _MATH_SPAN_PATTERN.split(escaped)
        for index, part in enumerate(parts):
            if not part or _MATH_SPAN_PATTERN.fullmatch(part):
                continue
            parts[index] = _BARE_TEX_PATTERN.sub(r"\\(\g<0>\\)", part)
        return "".join(parts)

    def _normalize_option(self, option: str) -> str:
        cleaned = option.strip()
        cleaned = re.sub(
            r"^\s*(?:[\(\[（【]?\s*[A-Fa-f]\s*[\)\]）】]?[\.\、．:：]?\s+|[A-Fa-f][\.\、．:：]\s*)",
            "",
            cleaned,
        ).strip()
        return cleaned or option.strip()

    def _sanitize_svg(self, raw_svg: str) -> str:
        if not raw_svg.strip():
            return ""
        match = re.search(r"<svg\b[^>]*>.*?</svg>", raw_svg, re.IGNORECASE | re.DOTALL)
        if not match:
            return ""
        svg = match.group(0)
        svg = re.sub(r"<script\b[^>]*>.*?</script>", "", svg, flags=re.IGNORECASE | re.DOTALL)
        svg = re.sub(r"<foreignObject\b[^>]*>.*?</foreignObject>", "", svg, flags=re.IGNORECASE | re.DOTALL)
        svg = re.sub(r"\s+on[a-zA-Z]+\s*=\s*(['\"]).*?\1", "", svg, flags=re.IGNORECASE | re.DOTALL)
        svg = re.sub(r"\s+(?:href|xlink:href)\s*=\s*(['\"])\s*(?:https?:|data:).*?\1", "", svg, flags=re.IGNORECASE | re.DOTALL)
        return svg.strip()

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

    def _optional_int(self, value: Any) -> int | None:
        if value is None:
            return None
        try:
            return int(value)
        except (TypeError, ValueError):
            return None

    def _positive_int(self, value: Any, *, default: int) -> int:
        parsed = self._optional_int(value)
        if parsed is None or parsed <= 0:
            return default
        return parsed

    def _most_common(self, values: list[str], *, limit: int) -> list[str]:
        counter = Counter(item.strip() for item in values if item and item.strip())
        return [item for item, _ in counter.most_common(limit)]

    def _default_title(self, request: PracticePaperRequest, topics: list[str]) -> str:
        topic = topics[0] if topics else "错题回收"
        return f"{topic}专题针对性练习"

    def _clip(self, text: str, limit: int) -> str:
        normalized = re.sub(r"\s+", " ", (text or "").strip())
        if len(normalized) <= limit:
            return normalized
        return normalized[: limit - 1] + "…"
