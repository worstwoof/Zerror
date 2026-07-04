from __future__ import annotations

import html
import json
import logging
import re
from typing import Any

from backend.app.schemas.card_schema import (
    LectureHandoutRequest,
    LectureHandoutResponse,
    LectureHandoutSection,
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
    r'"(title|subtitle|subject|topic|overview|sections|key_points|formula_cards|method_notes|common_traps|recap_checklist|body|bullets)"\s+(?=[\[{"]|null|-?\d)'
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
        return f"""你是“错题都队”的知识讲义老师。请根据用户原话生成一份可打印的中文知识讲义。

用户原话：
{request.prompt.strip()}

学科提示：{subject_hint}
主题提示：{topic_hint}

要求：
1. 只做知识讲义，不出练习题，不写答案区，不布置作业。
2. 只使用用户输入的学科/主题，不读取错题档案，不编造用户个人历史。
3. 内容适合初高中学生打印复习：概念、条件、公式解释、方法步骤、易错提醒、复盘清单要清楚。
4. 数学/物理/化学公式用 LaTeX，可放在字符串中，例如 "\\(y=kx+b\\)"。
5. 不要返回 HTML，不要 Markdown，不要代码块，只返回一个 JSON 对象。

JSON 字段：
{{
  "title": "讲义标题",
  "subtitle": "一行副标题",
  "subject": "学科",
  "topic": "知识主题",
  "overview": "120字以内总览",
  "sections": [
    {{"title": "小节标题", "body": "讲解正文", "bullets": ["要点1", "要点2"]}}
  ],
  "key_points": ["核心知识点1", "核心知识点2"],
  "formula_cards": ["公式或概念卡1"],
  "method_notes": ["方法步骤1"],
  "common_traps": ["易错提醒1"],
  "recap_checklist": ["复盘确认项1"]
}}

数量建议：
- sections 4 到 6 个，每个 body 80 到 180 字，bullets 2 到 4 条。
- key_points 5 到 8 条。
- formula_cards、method_notes、common_traps、recap_checklist 各 3 到 6 条。
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

        response = LectureHandoutResponse(
            title=title,
            subtitle=subtitle,
            subject=subject,
            topic=topic,
            overview=str(
                parsed.get("overview")
                or f"这份讲义围绕“{topic}”梳理核心概念、常用方法和易错边界，适合打印后进行一轮集中复习。"
            ).strip(),
            sections=sections[:8],
            key_points=self._string_list(parsed.get("key_points"))[:10]
            or [f"理解“{topic}”的定义、适用条件和常见表示方式。"],
            formula_cards=self._string_list(parsed.get("formula_cards"))[:8],
            method_notes=self._string_list(parsed.get("method_notes"))[:8]
            or ["先确认概念和条件，再选择方法；最后用特殊值、单位或边界检查结论。"],
            common_traps=self._string_list(parsed.get("common_traps"))[:8]
            or ["不要只背结论，使用公式前先检查适用条件。"],
            recap_checklist=self._string_list(parsed.get("recap_checklist"))[:8]
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
    @page {{ size: A4; margin: 13mm 14mm; }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      background: #f0f4f1;
      color: #202722;
      font-family: "Noto Serif SC", "Songti SC", "SimSun", serif;
      line-height: 1.72;
    }}
    .sheet {{
      width: 210mm;
      min-height: 297mm;
      margin: 0 auto;
      padding: 17mm 17mm 18mm;
      background: #fffef9;
    }}
    header {{
      border-bottom: 2px solid #8aa386;
      padding-bottom: 13px;
      margin-bottom: 18px;
    }}
    h1 {{
      margin: 0;
      color: #254438;
      font-size: 27px;
      font-weight: 700;
      line-height: 1.3;
      letter-spacing: 0;
    }}
    .subtitle {{
      margin-top: 7px;
      color: #657467;
      font-size: 13px;
    }}
    .overview {{
      margin: 18px 0 20px;
      padding: 14px 16px;
      border: 1px solid #cbd9c6;
      background: #f5f8f0;
      color: #28362d;
      font-size: 13.5px;
      break-inside: avoid;
    }}
    .part {{
      margin: 19px 0 0;
      break-inside: auto;
    }}
    .part-title {{
      margin: 0 0 9px;
      color: #315c4c;
      font-size: 19px;
      font-weight: 700;
      line-height: 1.35;
    }}
    .body {{
      margin: 0 0 7px;
      font-size: 13.5px;
      color: #202722;
      white-space: pre-wrap;
    }}
    .panel-grid {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 11px;
      margin-top: 16px;
    }}
    .panel {{
      break-inside: avoid;
      border: 1px solid #cbd9c6;
      background: #fbfcf7;
      padding: 10px 12px;
      min-height: 34mm;
    }}
    .panel h2 {{
      margin: 0 0 7px;
      color: #315c4c;
      font-size: 15px;
      font-weight: 700;
    }}
    ul {{ margin: 6px 0 0 20px; padding: 0; }}
    li {{ margin: 3px 0; }}
    .checklist {{
      margin-top: 18px;
      border-top: 1px dashed #b7c8b2;
      padding-top: 12px;
      break-inside: avoid;
    }}
    .checklist h2 {{
      margin: 0 0 8px;
      color: #315c4c;
      font-size: 16px;
    }}
    .checklist li {{
      list-style: none;
      margin-left: -18px;
    }}
    .checklist li::before {{
      content: "□";
      margin-right: 7px;
      color: #315c4c;
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
    <section class="overview">{self._math_text_html(response.overview)}</section>
    {sections}
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

    def _sections(self, value: Any) -> list[LectureHandoutSection]:
        if not isinstance(value, list):
            return []
        sections: list[LectureHandoutSection] = []
        for item in value:
            if not isinstance(item, dict):
                continue
            title = str(item.get("title") or "").strip()
            body = str(item.get("body") or "").strip()
            bullets = self._string_list(item.get("bullets"))[:5]
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
