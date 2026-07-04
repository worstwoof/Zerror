from __future__ import annotations

import html
import json
import logging
import re
from typing import Any

from backend.app.schemas.card_schema import (
    LectureHandoutExample,
    LectureHandoutModelCard,
    LectureHandoutRequest,
    LectureHandoutResponse,
    LectureHandoutSection,
    LectureHandoutSummaryTable,
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
    r"\\(?:sqrt|frac|dfrac|tfrac|cdot|times|div|le|ge|leq|geq|neq|pm|mp|angle|triangle|parallel|perp|sin|cos|tan|log|ln|lim|sum|int)\b"
    r"(?:\s*\{[^{}]*\}){0,3}"
    r"(?:\s*[+\-*/=]\s*(?:[A-Za-z]|\d+(?:\.\d+)?|\\[A-Za-z]+(?:\s*\{[^{}]*\}){0,3}))*"
    r")"
)
_JSON_INVALID_BACKSLASH_PATTERN = re.compile(r'(?<!\\)\\(?!["\\/bfnrtu])')
_JSON_LATEX_COMMAND_BACKSLASH_PATTERN = re.compile(
    r"(?<!\\)\\(?=(?:sqrt|frac|dfrac|tfrac|cdot|times|div|le|ge|leq|geq|neq|pm|mp|angle|triangle|parallel|perp|sin|cos|tan|log|ln|lim|sum|int|alpha|beta|gamma|lambda|mu|theta|pi|Delta|Omega|vec|bar|hat|overline)\b)"
)
_JSON_MATH_DELIMITER_BACKSLASH_PATTERN = re.compile(r"(?<!\\)\\(?=[()\[\]])")
_JSON_MISSING_COLON_FIELD_PATTERN = re.compile(
    r'"(title|subtitle|subject|topic|overview|exam_analysis|knowledge_map|sections|model_cards|secondary_conclusions|example_walkthroughs|summary_tables|key_points|formula_cards|method_notes|common_traps|recap_checklist|body|bullets|feature|logic|procedure|examples|notes|traps|source|stem|answer|analysis|solution_steps|headers|rows)"\s+(?=[\[{"]|null|-?\d)'
)


class LectureHandoutService:
    def __init__(self, client: VivoLMClient) -> None:
        self.client = client

    def generate_handout(self, request: LectureHandoutRequest) -> LectureHandoutResponse:
        if not request.prompt.strip():
            raise ValueError("讲义主题不能为空。")

        raw_output = self.client.chat_completion(
            self._build_prompt(request),
            model_name=self.client.settings.vivo_handout_model,
            thinking_mode=self.client.settings.vivo_handout_thinking_mode,
            reasoning_effort=self.client.settings.vivo_handout_reasoning_effort,
            max_tokens=self.client.settings.vivo_handout_max_tokens,
            timeout_seconds=self.client.settings.vivo_handout_timeout_seconds,
        )
        parsed = self._parse_json(raw_output)
        response = self._build_response(
            request=request,
            parsed=parsed,
            raw_output=raw_output,
        )
        logger.info(
            "lecture handout generated subject=%s topic=%s sections=%s",
            response.subject,
            response.topic,
            len(response.sections),
        )
        return response

    def _build_prompt(self, request: LectureHandoutRequest) -> str:
        subject_hint = request.subject.strip() or "从用户输入中判断"
        topic_hint = request.topic.strip() or "从用户输入中判断"
        return f"""你是“错题都队”的教辅讲义主编。请根据用户原话生成一份可打印的中文教辅书式知识讲义。

用户原话：
{request.prompt.strip()}

学科提示：{subject_hint}
主题提示：{topic_hint}

要求：
1. 只做知识讲义，不布置课后练习，不留下待作答题目；可以加入“例题精讲”，但例题必须给完整答案和解析。
2. 只使用用户输入的学科/主题，不读取错题档案，不编造用户个人历史。
3. 风格参考高质量高考/中考教辅：蓝色章节标题、内容提要、考情剖析、知识地图、核心模型、二级结论、例题精讲、题型总结、易错提醒。
4. 数学/物理/化学公式用 LaTeX，可放在字符串中，例如 "\\(y=kx+b\\)"。
5. 核心模型中不要出现“考场思维还原”这个板块，也不要使用这个标题。
6. 不要因为篇幅较长而压缩成概要；不设页数上限，按主题完整覆盖。输出会被后端渲染为多页 A4 讲义。
7. 不要返回 HTML，不要 Markdown，不要代码块，只返回一个 JSON 对象。

JSON 字段：
{{
  "title": "讲义标题",
  "subtitle": "一行副标题",
  "subject": "学科",
  "topic": "知识主题",
  "overview": "内容提要：讲义覆盖范围、核心思想、复习价值",
  "exam_analysis": "考情剖析与命题背景：说明该主题常见考法、分值位置、能力要求；非考试学科可写应用背景",
  "knowledge_map": ["知识地图节点1", "知识地图节点2"],
  "sections": [
    {{"title": "基础铺垫/概念辨析/题型总览等小节标题", "body": "讲解正文", "bullets": ["要点1", "要点2"]}}
  ],
  "model_cards": [
    {{
      "title": "核心模型一：模型名称",
      "feature": "识别特征：题目中出现哪些信号时用这个模型",
      "logic": "核心逻辑：为什么这样做，关键等价转化或思想",
      "procedure": ["标准操作程序第1步", "标准操作程序第2步"],
      "secondary_conclusions": ["二级结论1：可直接使用的小结论", "二级结论2"],
      "examples": [
        {{
          "title": "例题标题",
          "source": "可选来源，如经典母题/改编题",
          "stem": "题干",
          "answer": "答案",
          "analysis": "分析：说明为什么想到这个模型",
          "solution_steps": ["详解步骤1", "详解步骤2"],
          "notes": ["笔记/提醒"]
        }}
      ],
      "notes": ["笔记：进阶认知、避坑指南、模型迁移"],
      "traps": ["易错雷区1", "易错雷区2"]
    }}
  ],
  "secondary_conclusions": ["全章通用二级结论1", "全章通用二级结论2"],
  "example_walkthroughs": [
    {{
      "title": "综合例题",
      "source": "可选来源",
      "stem": "题干",
      "answer": "答案",
      "analysis": "分析",
      "solution_steps": ["详解步骤1"],
      "notes": ["点评"]
    }}
  ],
  "summary_tables": [
    {{
      "title": "表格标题",
      "headers": ["类型", "识别信号", "处理方法"],
      "rows": [["类型A", "信号A", "方法A"]]
    }}
  ],
  "key_points": ["核心知识点1", "核心知识点2"],
  "formula_cards": ["公式或概念卡1"],
  "method_notes": ["方法步骤1"],
  "common_traps": ["易错提醒1"],
  "recap_checklist": ["复盘确认项1"]
}}

结构要求：
- 先写清“内容提要”和“考情/应用背景”，再展开知识。
- 每个核心模型都要包含：识别特征、核心逻辑、标准操作程序、二级结论、例题精讲、易错雷区。
- 二级结论要像教辅书旁批：短、准、可直接用于判断或化简。
- 例题必须服务于方法讲解，不能只给题目不给解析。
- 可以根据主题生成任意数量的小节、核心模型、表格和例题；不要设置页数上限或小节上限。
"""

    def _build_response(
        self,
        *,
        request: LectureHandoutRequest,
        parsed: dict[str, Any],
        raw_output: str,
    ) -> LectureHandoutResponse:
        topic = str(parsed.get("topic") or request.topic or self._topic_from_prompt(request.prompt)).strip()
        subject = str(parsed.get("subject") or request.subject or self._subject_from_prompt(request.prompt)).strip()
        title = str(parsed.get("title") or f"{topic}知识讲义").strip()
        subtitle = str(parsed.get("subtitle") or f"{subject} · 知识梳理").strip()
        sections = self._sections(parsed.get("sections"))
        if not sections:
            sections = self._fallback_sections(topic)
        model_cards = self._model_cards(parsed.get("model_cards"))
        example_walkthroughs = self._examples(parsed.get("example_walkthroughs"))
        summary_tables = self._summary_tables(parsed.get("summary_tables"))

        response = LectureHandoutResponse(
            title=title,
            subtitle=subtitle,
            subject=subject,
            topic=topic,
            overview=str(
                parsed.get("overview")
                or f"这份讲义围绕“{topic}”梳理核心概念、常用方法和易错边界，适合打印后进行一轮集中复习。"
            ).strip(),
            exam_analysis=str(parsed.get("exam_analysis") or "").strip(),
            knowledge_map=self._string_list(parsed.get("knowledge_map")),
            sections=sections,
            model_cards=model_cards,
            secondary_conclusions=self._string_list(parsed.get("secondary_conclusions")),
            example_walkthroughs=example_walkthroughs,
            summary_tables=summary_tables,
            key_points=self._string_list(parsed.get("key_points"))
            or [f"理解“{topic}”的定义、适用条件和常见表示方式。"],
            formula_cards=self._string_list(parsed.get("formula_cards")),
            method_notes=self._string_list(parsed.get("method_notes"))
            or ["先确认概念和条件，再选择方法；最后用特殊值、单位或边界检查结论。"],
            common_traps=self._string_list(parsed.get("common_traps"))
            or ["不要只背结论，使用公式前先检查适用条件。"],
            recap_checklist=self._string_list(parsed.get("recap_checklist"))
            or [f"能用自己的话解释“{topic}”的核心概念。"],
            raw_model_output=raw_output,
        )
        return response.model_copy(
            update={"printable_html": self._build_printable_html(response)}
        )

    def _build_printable_html(self, response: LectureHandoutResponse) -> str:
        sections = "\n".join(
            self._section_html(index, section)
            for index, section in enumerate(response.sections)
        )
        model_cards = "\n".join(
            self._model_card_html(index, card)
            for index, card in enumerate(response.model_cards)
        )
        examples = "\n".join(
            self._example_html(example, prefix=f"综合例题 {index + 1}")
            for index, example in enumerate(response.example_walkthroughs)
        )
        summary_tables = "\n".join(
            self._summary_table_html(table) for table in response.summary_tables
        )
        knowledge_map = ""
        if response.knowledge_map:
            knowledge_map = f"""
    <section class="knowledge-map">
      <h2>知识地图</h2>
      <div class="map-list">{self._chip_items_html(response.knowledge_map)}</div>
    </section>"""
        secondary_conclusions = ""
        if response.secondary_conclusions:
            secondary_conclusions = f"""
    <section class="conclusion-band">
      <h2>二级结论速记</h2>
      <ol>{self._ordered_items_html(response.secondary_conclusions)}</ol>
    </section>"""
        examples_section = ""
        if examples:
            examples_section = f"""
    <section class="examples-section">
      <h2>综合例题精讲</h2>
      {examples}
    </section>"""
        tables_section = ""
        if summary_tables:
            tables_section = f"""
    <section class="tables-section">
      <h2>题型总结</h2>
      {summary_tables}
    </section>"""
        return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>{html.escape(response.title)}</title>
  <script>
    window.MathJax = {{
      tex: {{
        inlineMath: [['\\\\(', '\\\\)'], ['$', '$']],
        displayMath: [['\\\\[', '\\\\]'], ['$$', '$$']],
        processEscapes: true
      }},
      svg: {{ fontCache: 'global' }}
    }};
  </script>
  <script async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-svg.js"></script>
  <style>
    @page {{ size: A4; margin: 14mm 15mm; }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      background: #eef3f8;
      color: #2b3037;
      font-family: "Noto Serif SC", "Songti SC", "SimSun", serif;
      line-height: 1.78;
    }}
    .sheet {{
      width: 210mm;
      min-height: 297mm;
      margin: 0 auto;
      padding: 16mm 17mm 18mm;
      background: #fff;
    }}
    header {{
      text-align: center;
      padding-bottom: 18px;
      margin-bottom: 18px;
    }}
    h1 {{
      margin: 0;
      color: #3f78aa;
      font-size: 25px;
      font-weight: 700;
      line-height: 1.3;
      letter-spacing: 0;
    }}
    .subtitle {{
      margin-top: 7px;
      color: #6a7f95;
      font-size: 13px;
    }}
    .digest {{
      position: relative;
      margin: 10px 0 24px;
      padding: 23px 18px 16px;
      border-top: 2px solid #92b1cc;
      border-bottom: 2px solid #92b1cc;
      background: #e9f2fa;
      font-size: 13.5px;
      break-inside: avoid;
    }}
    .digest-badge {{
      position: absolute;
      top: -14px;
      left: 50%;
      transform: translateX(-50%);
      padding: 5px 18px;
      border-radius: 5px;
      background: #3f78aa;
      color: #fff;
      font-weight: 700;
      font-size: 14px;
    }}
    .digest-grid {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 18px;
    }}
    .digest p {{ margin: 0; text-align: justify; }}
    .digest strong {{ color: #2e638f; }}
    .knowledge-map, .conclusion-band, .examples-section, .tables-section {{
      margin: 20px 0 0;
    }}
    .knowledge-map h2, .conclusion-band h2, .examples-section h2, .tables-section h2 {{
      margin: 0 0 10px;
      color: #4a83b2;
      font-size: 18px;
    }}
    .map-list {{
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }}
    .chip {{
      display: inline-block;
      padding: 4px 9px;
      border: 1px solid #bdd2e4;
      border-radius: 999px;
      background: #f7fbff;
      color: #355d7e;
      font-size: 12.5px;
    }}
    .part {{
      margin: 22px 0 0;
      break-inside: auto;
    }}
    .part-title {{
      margin: 0 0 9px;
      color: #4a83b2;
      font-size: 20px;
      font-weight: 700;
      line-height: 1.35;
    }}
    .body {{
      margin: 0 0 7px;
      font-size: 13.5px;
      color: #202722;
      white-space: pre-wrap;
    }}
    .model-card {{
      margin: 24px 0 0;
      break-inside: auto;
    }}
    .model-title {{
      margin: 0 0 12px;
      color: #4a83b2;
      font-size: 20px;
      font-weight: 700;
    }}
    .model-block {{
      margin: 10px 0;
      padding: 10px 12px;
      border-left: 4px solid #79a8cf;
      background: #f6faff;
      break-inside: avoid;
    }}
    .model-block h3 {{
      margin: 0 0 5px;
      color: #32809f;
      font-size: 14.5px;
      font-weight: 700;
    }}
    .model-block p {{ margin: 0; font-size: 13.5px; }}
    .procedure {{
      margin: 7px 0 0 20px;
      padding: 0;
    }}
    .procedure li {{ margin: 4px 0; }}
    .conclusion-band {{
      padding: 12px 14px;
      border: 1px solid #bdd2e4;
      background: #f7fbff;
      break-inside: avoid;
    }}
    .conclusion-band ol, .conclusion-list {{
      margin: 6px 0 0 22px;
      padding: 0;
    }}
    .conclusion-list li, .conclusion-band li {{
      margin: 4px 0;
    }}
    .example {{
      margin: 13px 0;
      padding: 12px 14px;
      border-top: 1px solid #c7d9e8;
      border-bottom: 1px solid #c7d9e8;
      break-inside: auto;
    }}
    .example-title {{
      color: #1f9b78;
      font-weight: 700;
      margin-bottom: 5px;
    }}
    .source {{
      color: #f08a24;
      font-weight: 700;
    }}
    .label {{
      color: #111;
      font-weight: 700;
    }}
    .answer {{
      color: #1b8b68;
      font-weight: 700;
    }}
    .note-list li::marker {{
      color: #f08a24;
    }}
    table {{
      width: 100%;
      border-collapse: collapse;
      margin: 10px 0 14px;
      break-inside: avoid;
      font-size: 13px;
    }}
    th, td {{
      border: 1px solid #8c98a3;
      padding: 7px 8px;
      vertical-align: top;
    }}
    th {{
      background: #eef6fd;
      color: #345f83;
      font-weight: 700;
    }}
    .table-title {{
      margin: 12px 0 4px;
      color: #4a83b2;
      font-size: 15px;
      font-weight: 700;
    }}
    .panel-grid {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 11px;
      margin-top: 16px;
    }}
    .panel {{
      break-inside: avoid;
      border: 1px solid #c7d9e8;
      background: #fbfdff;
      padding: 10px 12px;
      min-height: 34mm;
    }}
    .panel h2 {{
      margin: 0 0 7px;
      color: #4a83b2;
      font-size: 15px;
      font-weight: 700;
    }}
    ul {{ margin: 6px 0 0 20px; padding: 0; }}
    li {{ margin: 3px 0; }}
    .checklist {{
      margin-top: 18px;
      border-top: 1px dashed #a9c3d8;
      padding-top: 12px;
      break-inside: avoid;
    }}
    .checklist h2 {{
      margin: 0 0 8px;
      color: #4a83b2;
      font-size: 16px;
    }}
    .checklist li {{
      list-style: none;
      margin-left: -18px;
    }}
    .checklist li::before {{
      content: "□";
      margin-right: 7px;
      color: #4a83b2;
    }}
    mjx-container {{
      font-size: 92% !important;
      overflow-wrap: normal;
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
    </header>
    <section class="digest">
      <div class="digest-badge">内容提要</div>
      <div class="digest-grid">
        <p><strong>讲义定位：</strong>{self._math_text_html(response.overview)}</p>
        <p><strong>考情/应用：</strong>{self._math_text_html(response.exam_analysis or "围绕本主题的概念、模型、方法和易错边界进行系统梳理。")}</p>
      </div>
    </section>
    {knowledge_map}
    {sections}
    {model_cards}
    {secondary_conclusions}
    {examples_section}
    {tables_section}
    <section class="panel-grid">
      {self._panel_html("核心知识点", response.key_points)}
      {self._panel_html("公式/概念卡", response.formula_cards)}
      {self._panel_html("方法步骤", response.method_notes)}
      {self._panel_html("易错提醒", response.common_traps)}
    </section>
    <section class="checklist">
      <h2>复盘清单</h2>
      <ul>{self._list_items_html(response.recap_checklist)}</ul>
    </section>
  </main>
</body>
</html>"""

    def _section_html(self, index: int, section: LectureHandoutSection) -> str:
        bullets = ""
        if section.bullets:
            bullets = f"<ul>{self._list_items_html(section.bullets)}</ul>"
        return f"""
<section class="part">
  <h2 class="part-title">{index + 1}. {self._math_text_html(section.title)}</h2>
  <p class="body">{self._math_text_html(section.body)}</p>
  {bullets}
</section>"""

    def _model_card_html(self, index: int, card: LectureHandoutModelCard) -> str:
        feature = self._model_block_html("识别特征", card.feature)
        logic = self._model_block_html("核心逻辑", card.logic)
        procedure = ""
        if card.procedure:
            procedure = f"""
  <div class="model-block">
    <h3>标准操作程序</h3>
    <ol class="procedure">{self._ordered_items_html(card.procedure)}</ol>
  </div>"""
        secondary = ""
        if card.secondary_conclusions:
            secondary = f"""
  <div class="model-block">
    <h3>二级结论</h3>
    <ol class="conclusion-list">{self._ordered_items_html(card.secondary_conclusions)}</ol>
  </div>"""
        examples = "\n".join(
            self._example_html(example, prefix=f"例题 {example_index + 1}")
            for example_index, example in enumerate(card.examples)
        )
        if examples:
            examples = f"""
  <div class="model-block">
    <h3>例题精讲</h3>
  </div>
  {examples}"""
        notes = self._model_list_block_html("笔记", card.notes, class_name="note-list")
        traps = self._model_list_block_html("易错雷区", card.traps)
        return f"""
<section class="model-card">
  <h2 class="model-title">{index + 1}. {self._math_text_html(card.title)}</h2>
  {feature}
  {logic}
  {procedure}
  {secondary}
  {examples}
  {notes}
  {traps}
</section>"""

    def _model_block_html(self, title: str, body: str) -> str:
        if not body.strip():
            return ""
        return f"""
  <div class="model-block">
    <h3>{html.escape(title)}</h3>
    <p>{self._math_text_html(body)}</p>
  </div>"""

    def _model_list_block_html(
        self,
        title: str,
        items: list[str],
        *,
        class_name: str = "",
    ) -> str:
        if not items:
            return ""
        class_attr = f' class="{html.escape(class_name)}"' if class_name else ""
        return f"""
  <div class="model-block">
    <h3>{html.escape(title)}</h3>
    <ul{class_attr}>{self._list_items_html(items)}</ul>
  </div>"""

    def _example_html(self, example: LectureHandoutExample, *, prefix: str) -> str:
        title = example.title.strip() or prefix
        source = (
            f" <span class=\"source\">{self._math_text_html(example.source)}</span>"
            if example.source.strip()
            else ""
        )
        answer = ""
        if example.answer.strip():
            answer = f"""
  <p><span class="label">答案：</span><span class="answer">{self._math_text_html(example.answer)}</span></p>"""
        analysis = ""
        if example.analysis.strip():
            analysis = f"""
  <p><span class="label">分析：</span>{self._math_text_html(example.analysis)}</p>"""
        solution = ""
        if example.solution_steps:
            solution = f"""
  <p><span class="label">详解：</span></p>
  <ol class="procedure">{self._ordered_items_html(example.solution_steps)}</ol>"""
        notes = ""
        if example.notes:
            notes = f"""
  <p><span class="label">笔记：</span></p>
  <ul class="note-list">{self._list_items_html(example.notes)}</ul>"""
        return f"""
<section class="example">
  <div class="example-title">{self._math_text_html(title)}{source}</div>
  <p><span class="label">题干：</span>{self._math_text_html(example.stem)}</p>
  {answer}
  {analysis}
  {solution}
  {notes}
</section>"""

    def _summary_table_html(self, table: LectureHandoutSummaryTable) -> str:
        title = (
            f'<div class="table-title">{self._math_text_html(table.title)}</div>'
            if table.title.strip()
            else ""
        )
        headers = table.headers
        if not headers and table.rows:
            headers = [f"列 {index + 1}" for index in range(len(table.rows[0]))]
        if not headers:
            return ""
        head = "".join(f"<th>{self._math_text_html(item)}</th>" for item in headers)
        rows = []
        for row in table.rows:
            cells = list(row)
            if len(cells) < len(headers):
                cells.extend([""] * (len(headers) - len(cells)))
            rows.append(
                "<tr>"
                + "".join(
                    f"<td>{self._math_text_html(cell)}</td>"
                    for cell in cells[: len(headers)]
                )
                + "</tr>"
            )
        body = "".join(rows)
        return f"""
{title}
<table>
  <thead><tr>{head}</tr></thead>
  <tbody>{body}</tbody>
</table>"""

    def _panel_html(self, title: str, items: list[str]) -> str:
        return f"""
<section class="panel">
  <h2>{html.escape(title)}</h2>
  <ul>{self._list_items_html(items)}</ul>
</section>"""

    def _list_items_html(self, items: list[str]) -> str:
        cleaned = [item for item in items if str(item).strip()]
        if not cleaned:
            return "<li>围绕本讲义主题，回看定义、条件、方法和易错边界。</li>"
        return "".join(f"<li>{self._math_text_html(item)}</li>" for item in cleaned)

    def _ordered_items_html(self, items: list[str]) -> str:
        cleaned = [item for item in items if str(item).strip()]
        return "".join(f"<li>{self._math_text_html(item)}</li>" for item in cleaned)

    def _chip_items_html(self, items: list[str]) -> str:
        cleaned = [item for item in items if str(item).strip()]
        return "".join(f'<span class="chip">{self._math_text_html(item)}</span>' for item in cleaned)

    def _sections(self, value: Any) -> list[LectureHandoutSection]:
        if not isinstance(value, list):
            return []
        sections: list[LectureHandoutSection] = []
        for item in value:
            if not isinstance(item, dict):
                continue
            title = str(item.get("title") or "").strip()
            body = str(item.get("body") or "").strip()
            bullets = self._string_list(item.get("bullets"))
            if not title and not body and not bullets:
                continue
            sections.append(
                LectureHandoutSection(
                    title=title or "知识梳理",
                    body=body,
                    bullets=bullets,
                )
            )
        return sections

    def _model_cards(self, value: Any) -> list[LectureHandoutModelCard]:
        if not isinstance(value, list):
            return []
        cards: list[LectureHandoutModelCard] = []
        for item in value:
            if not isinstance(item, dict):
                continue
            title = str(item.get("title") or "").strip()
            if not title:
                continue
            cards.append(
                LectureHandoutModelCard(
                    title=title,
                    feature=str(item.get("feature") or "").strip(),
                    logic=str(item.get("logic") or "").strip(),
                    procedure=self._string_list(item.get("procedure")),
                    secondary_conclusions=self._string_list(
                        item.get("secondary_conclusions")
                    ),
                    examples=self._examples(item.get("examples")),
                    notes=self._string_list(item.get("notes")),
                    traps=self._string_list(item.get("traps")),
                )
            )
        return cards

    def _examples(self, value: Any) -> list[LectureHandoutExample]:
        if not isinstance(value, list):
            return []
        examples: list[LectureHandoutExample] = []
        for item in value:
            if not isinstance(item, dict):
                continue
            stem = str(item.get("stem") or "").strip()
            title = str(item.get("title") or "").strip()
            analysis = str(item.get("analysis") or "").strip()
            solution_steps = self._string_list(item.get("solution_steps"))
            if not stem and not title and not analysis and not solution_steps:
                continue
            examples.append(
                LectureHandoutExample(
                    title=title,
                    source=str(item.get("source") or "").strip(),
                    stem=stem,
                    answer=str(item.get("answer") or "").strip(),
                    analysis=analysis,
                    solution_steps=solution_steps,
                    notes=self._string_list(item.get("notes")),
                )
            )
        return examples

    def _summary_tables(self, value: Any) -> list[LectureHandoutSummaryTable]:
        if not isinstance(value, list):
            return []
        tables: list[LectureHandoutSummaryTable] = []
        for item in value:
            if not isinstance(item, dict):
                continue
            headers = self._string_list(item.get("headers"))
            rows = self._table_rows(item.get("rows"))
            if not headers and not rows:
                continue
            tables.append(
                LectureHandoutSummaryTable(
                    title=str(item.get("title") or "").strip(),
                    headers=headers,
                    rows=rows,
                )
            )
        return tables

    def _table_rows(self, value: Any) -> list[list[str]]:
        if not isinstance(value, list):
            return []
        rows: list[list[str]] = []
        for row in value:
            if isinstance(row, list):
                cells = [str(cell).strip() for cell in row]
            elif isinstance(row, dict):
                cells = [str(cell).strip() for cell in row.values()]
            else:
                continue
            if any(cells):
                rows.append(cells)
        return rows

    def _parse_json(self, raw_output: str) -> dict[str, Any]:
        cleaned = raw_output.strip()
        candidates = []
        fence_match = re.search(r"```(?:json)?\s*(.*?)```", cleaned, re.DOTALL | re.IGNORECASE)
        if fence_match:
            candidates.append(fence_match.group(1).strip())
        candidates.append(cleaned)
        object_match = re.search(r"\{.*\}", cleaned, re.DOTALL)
        if object_match:
            candidates.append(object_match.group(0).strip())

        seen: set[str] = set()
        for candidate in candidates:
            if not candidate or candidate in seen:
                continue
            seen.add(candidate)
            for attempt in (candidate, self._repair_json(candidate)):
                try:
                    parsed = json.loads(attempt)
                except json.JSONDecodeError:
                    continue
                if isinstance(parsed, dict):
                    return parsed
        logger.warning("lecture handout json parse failed content_len=%s", len(raw_output))
        return {}

    def _repair_json(self, value: str) -> str:
        repaired = _JSON_MISSING_COLON_FIELD_PATTERN.sub(r'"\1": ', value)
        repaired = _JSON_MATH_DELIMITER_BACKSLASH_PATTERN.sub(r"\\\\", repaired)
        repaired = _JSON_LATEX_COMMAND_BACKSLASH_PATTERN.sub(r"\\\\", repaired)
        return _JSON_INVALID_BACKSLASH_PATTERN.sub(r"\\\\", repaired)

    def _string_list(self, value: Any) -> list[str]:
        if not isinstance(value, list):
            return []
        return [str(item).strip() for item in value if str(item).strip()]

    def _math_text_html(self, value: str) -> str:
        text = str(value or "")
        text = re.sub(r"\\(leq|geq|neq|lt|gt)(?=[A-Za-z])", r"\\\1 ", text)
        escaped = html.escape(text)
        if not escaped:
            return ""
        parts = _MATH_SPAN_PATTERN.split(escaped)
        for index, part in enumerate(parts):
            if not part or _MATH_SPAN_PATTERN.fullmatch(part):
                continue
            parts[index] = _BARE_TEX_PATTERN.sub(r"\\(\g<0>\\)", part)
        return "".join(parts)

    def _subject_from_prompt(self, prompt: str) -> str:
        for subject in ("数学", "语文", "英语", "物理", "化学", "生物", "历史", "地理", "政治"):
            if subject in prompt:
                return subject
        return "通用"

    def _topic_from_prompt(self, prompt: str) -> str:
        cleaned = re.sub(
            r"(帮我|请|整理一下|帮我整理|整理|生成|一份|讲义|知识点|知识梳理|的)",
            " ",
            prompt,
        )
        cleaned = re.sub(r"\s+", " ", cleaned).strip(" ，。；;、")
        return cleaned[:30] or "核心知识点"

    def _fallback_sections(self, topic: str) -> list[LectureHandoutSection]:
        return [
            LectureHandoutSection(
                title="先抓住定义",
                body=f"复习“{topic}”时，先把定义、符号含义和适用对象说清楚。定义不是背诵材料，而是后面判断条件、选择方法的入口。",
                bullets=["用一句话复述核心概念。", "标出题目中哪些条件对应定义中的关键词。"],
            ),
            LectureHandoutSection(
                title="再整理条件",
                body="很多错误来自条件漏看或公式误用。把必要条件、隐含条件和限制范围分开写，可以减少套公式时的偏差。",
                bullets=["先写已知，再写要求。", "每用一个结论前检查前提是否满足。"],
            ),
            LectureHandoutSection(
                title="最后形成方法",
                body="把常见题型归纳成稳定步骤：识别对象、选择模型、代入计算或推理、检查结果。复习时重点练这条路径。",
                bullets=["把方法写成 3 到 5 步。", "用一个小例子验证自己是否真的会用。"],
            ),
        ]
