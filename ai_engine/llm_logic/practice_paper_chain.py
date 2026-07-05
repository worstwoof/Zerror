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

from .vivo_client import VivoAPIError, VivoLMClient


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
_JSON_LATEX_COMMAND_BACKSLASH_PATTERN = re.compile(
    r"(?<!\\)\\(?=(?:sqrt|frac|dfrac|tfrac|cdot|times|div|le|ge|leq|geq|neq|pm|mp|angle|triangle|parallel|perp|sin|cos|tan|log|ln|lim|sum|int|alpha|beta|gamma|lambda|mu|theta|pi|Delta|Omega|vec|bar|hat|overline)\b)"
)
_JSON_MATH_DELIMITER_BACKSLASH_PATTERN = re.compile(r"(?<!\\)\\(?=[()\[\]])")
_JSON_INVALID_BACKSLASH_PATTERN = re.compile(r'(?<!\\)\\(?!["\\/bfnrtu])')
_JSON_MISSING_COLON_FIELD_PATTERN = re.compile(
    r'"(title|subtitle|subject_focus|topic_focus|estimated_minutes|handout_overview|learning_targets|warmup_notes|concept_review|formula_cards|method_models|worked_examples|common_traps|questions|id|type|subject|topic|stem|options|answer|answer_index|solution_outline|solution_steps|diagram_svg|diagram_caption|reason_hint|difficulty|source_error_ids|answer_key)"\s+(?=[\[{"]|null|-?\d)'
)
_JSON_FIELD_QUOTE_SWALLOWED_VALUE_PATTERN = re.compile(
    r'"(title|subtitle|subject_focus|topic_focus|estimated_minutes|handout_overview|learning_targets|warmup_notes|concept_review|formula_cards|method_models|worked_examples|common_traps|questions|id|type|subject|topic|stem|options|answer|answer_index|solution_outline|solution_steps|diagram_svg|diagram_caption|reason_hint|difficulty|source_error_ids|answer_key)\s+([\[{]|null|-?\d)'
)


class PracticePaperService:
    def __init__(self, client: VivoLMClient) -> None:
        self.client = client

    def generate_practice_paper(self, request: PracticePaperRequest) -> PracticePaperResponse:
        if self._is_source_error_only_mode(request):
            return self._build_source_error_response(request)

        prompt = self._build_prompt(request)
        try:
            raw_output = self.client.chat_completion(
                prompt,
                max_tokens=self._practice_max_tokens(),
                timeout_seconds=self._practice_timeout_seconds(),
            )
        except VivoAPIError as exc:
            if not self._is_timeout_error(exc):
                raise
            logger.warning("practice paper primary generation timed out, retrying compact prompt: %s", exc)
            try:
                raw_output = self.client.chat_completion(
                    self._build_compact_prompt(request),
                    reasoning_effort="low",
                    max_tokens=self._practice_retry_max_tokens(),
                    timeout_seconds=self._practice_retry_timeout_seconds(),
                )
            except VivoAPIError as retry_exc:
                if not self._is_timeout_error(retry_exc):
                    raise
                logger.warning("practice paper compact retry timed out, using local fallback: %s", retry_exc)
                response = self._build_response(
                    request=request,
                    parsed={},
                    raw_output=f"local fallback after timeout: {retry_exc}",
                )
                logger.info(
                    "practice paper generated fallback questions=%s subjects=%s topics=%s",
                    len(response.questions),
                    len(response.subject_focus),
                    len(response.topic_focus),
                )
                return response
        parsed = self._parse_json(raw_output)
        output_source = "primary"
        if not self._has_valid_questions(parsed):
            logger.warning(
                "practice paper primary output was not usable, retrying compact prompt content_len=%s",
                len(raw_output),
            )
            try:
                retry_output = self.client.chat_completion(
                    self._build_compact_prompt(request),
                    reasoning_effort="low",
                    max_tokens=self._practice_retry_max_tokens(),
                    timeout_seconds=self._practice_retry_timeout_seconds(),
                )
                retry_parsed = self._parse_json(retry_output)
                if self._has_valid_questions(retry_parsed):
                    raw_output = retry_output
                    parsed = retry_parsed
                    output_source = "compact_retry"
                else:
                    logger.warning(
                        "practice paper compact output was not usable, falling back content_len=%s",
                        len(retry_output),
                    )
            except VivoAPIError as retry_exc:
                if not self._is_timeout_error(retry_exc):
                    raise
                logger.warning("practice paper compact retry after parse failure timed out: %s", retry_exc)
        response = self._build_response(
            request=request,
            parsed=parsed,
            raw_output=raw_output,
        )
        logger.info(
            "practice paper generated questions=%s subjects=%s topics=%s source=%s",
            len(response.questions),
            len(response.subject_focus),
            len(response.topic_focus),
            output_source if self._has_valid_questions(parsed) else "fallback",
        )
        return response

    def _practice_timeout_seconds(self) -> int:
        return min(max(30, self.client.settings.vivo_timeout_seconds), 165)

    def _practice_retry_timeout_seconds(self) -> int:
        return min(max(30, self.client.settings.vivo_timeout_seconds), 110)

    def _practice_max_tokens(self) -> int:
        return min(self.client.settings.vivo_max_tokens, 8192)

    def _practice_retry_max_tokens(self) -> int:
        return min(self.client.settings.vivo_max_tokens, 6144)

    def _is_timeout_error(self, exc: VivoAPIError) -> bool:
        message = str(exc).lower()
        return any(
            marker in message
            for marker in (
                "status=504",
                "gateway timeout",
                "gateway time-out",
                "read timed out",
                "timed out",
                "timeout",
            )
        )

    def _has_valid_questions(self, parsed: dict[str, Any]) -> bool:
        raw_questions = parsed.get("questions")
        if not isinstance(raw_questions, list):
            return False
        valid_count = 0
        for item in raw_questions:
            if not isinstance(item, dict):
                continue
            stem = str(item.get("stem") or "").strip()
            answer = str(item.get("answer") or "").strip()
            if not stem or not answer:
                continue
            if self._looks_like_prompt_leak(stem) or self._looks_like_prompt_leak(answer):
                continue
            valid_count += 1
        return valid_count > 0

    def _build_prompt(self, request: PracticePaperRequest) -> str:
        source_errors = self._source_errors_for_prompt(request)
        subjects = [
            item
            for item in request.selected_subjects
            if item.strip() and item.strip() not in {"全部", "全部学科"}
        ]
        subject_hint = "、".join(subjects) if subjects else "从错题档案中自动判断"
        topic_hint = "、".join(self._clean_filter_values(request.selected_topics)) or "从错题档案中自动判断"
        type_hint = "、".join(self._clean_filter_values(request.selected_type_tags)) or "从错题档案中自动判断"
        source_json = json.dumps(source_errors, ensure_ascii=False, indent=2)
        question_count = self._target_question_count(request)

        return f"""
CRITICAL JSON CONTRACT:
- Return exactly one JSON object. Do not return Markdown, code fences, comments, headings, analysis notes, or any text before or after the JSON.
- Do not write self-correction, uncertainty, hidden reasoning, draft notes, or phrases like "I wrote this wrong" inside any JSON value.
- Every string value must be complete, concise, and directly usable by a student or teacher.
- The raw response must be valid JSON before any repair. Do not use trailing commas. Do not put unescaped double quotes inside string values.
- In raw JSON text, every LaTeX backslash must be escaped as two backslashes. Write "\\\\(2\\\\sqrt{{6}}\\\\)" and "\\\\(x=\\\\frac{{13}}{{6}}\\\\)" in the JSON source. Do not write "\\(2\\sqrt{{6}}\\)" or "\\(x=\\frac{{13}}{{6}}\\)" with single backslashes in JSON source.
- For MathJax delimiters in JSON source, write "\\\\(" and "\\\\)" for inline math, and "\\\\[" and "\\\\]" for display math.
- If you are unsure about a calculation, choose a simpler valid question instead of writing uncertainty or correction notes.
只返回 JSON，不要 Markdown，不要代码围栏。
你是“错题都队”的教辅编辑和学科命题老师。请基于用户错题档案，生成一份可打印的蓝白教辅风格专题讲义。

组卷要求：
- 练习题题量：{question_count} 题。普通专题至少 3 道；如果错题集中是选择题、填空题、概念辨析、公式辨析等小知识点训练，至少生成 5 道选择/填空题。
- 选定学科：{subject_hint}。
- 选定知识点：{topic_hint}。
- 选定题型：{type_hint}。
- 策略：{request.strategy_label}。
- 生成模式：{request.generation_mode}。
- title 必须是居中大标题使用的“科目/章节/知识点名称”，优先写成“第 X 章 章节名称：知识点名称”或“学科 · 章节 · 知识点名称”，不要写泛泛的“专题讲义标题”。
- subtitle 只写一行补充说明，可以为空；不要重复 title。
- 讲义正文不要输出“知识点讲解/知识精讲/公式速查/易错提醒/内容提要”等前置讲解板块；只保留：标题、例题讲解与答案、习题。
- handout_overview、learning_targets、warmup_notes、concept_review、formula_cards、method_models、common_traps 可以返回空字符串或空数组，前端不会展示。
- worked_examples 是第一部分“例题讲解与答案”，生成 1 到 2 条；每条必须按“例题：...；解答思路：...；步骤/计算过程：...；答案：...”组织。
- questions 是第二部分“习题”，每道题只展示题目和作答区域；答案留在 JSON 的 answer/solution_steps 中，不在练习区直接展示。
- 题目必须围绕错题暴露出的知识点、错因和相近专题生成，不要复刻原题。
- 如果生成模式是“同类强化卷”，题目必须是同类新题，不要复刻原题。
- 如果生成模式是“混合提升卷”，至少一半题目围绕选定题型做变式迁移，保留 source_error_ids 指向对应错题。
- type 字段优先使用选定题型中的具体题型；topic 字段优先使用选定知识点。
- 难度应包含基础回收、变式巩固、综合迁移，适合学生打印后手写完成。
- 讲义不能只有习题，必须先给出例题，并给出例题讲解与答案。
- 题目要完整清晰；选择题必须提供 4 个选项和 0-based answer_index；非选择题 answer_index 返回 null。
- options 里只写选项内容，不要带 A.、B.、C.、D.、（A）、A、 等序号前缀。
- LaTeX 输出规范：所有数学公式、变量、方程、分式、根式、指数、坐标、角度、向量和带数学意义的数字都用 MathJax 可渲染格式包裹；行内公式用 \\( ... \\)，展示公式用 \\[ ... \\]。例如必须写成 \\(2\\sqrt{{6}}\\)、\\(x=\\frac{{13}}{{6}}\\)、\\(a^2=b^2+c^2-2bc\\cos A\\)，不要裸写 2\\sqrt{{6}} 或 x=\\frac{{13}}{{6}}。
- 答案 answer、solution_outline、solution_steps 以及讲义的公式卡片、例题讲解、易错提醒中也必须遵守上述 LaTeX 规范；普通解释文字用中文，数学对象进入公式环境。
- 答案解析要精炼：给出 1 到 2 个分步 solution_steps，每步 50 字以内；不要展开成完整答案页。
- 每道题先判断是否有“视觉结构”：图形位置关系、函数/圆锥曲线图像、运动或力的方向、电路连接、光路、化学流程、统计图表等。
- 如果存在视觉结构，可以在 diagram_svg 返回一个简洁 SVG 示意图；纯代数运算、纯概念辨析、无需图像辅助的题目返回空字符串。
- 为保证 JSON 可解析，diagram_svg 必须是单行 SVG 字符串，SVG 属性必须使用单引号，不要使用双引号，不要换行。例如 <svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 360 180'>...</svg>。
- 整份试卷最多 2 道题返回 diagram_svg；其他题即使可画图，也优先用 diagram_caption 描述关键关系。
- 圆锥曲线/椭圆/双曲线/抛物线、几何证明、函数图像题通常需要图；若判断需要图，至少标出坐标轴、中心/顶点、焦点、关键点、长短轴、准线、辅助线等核心元素。
- diagram_svg 必须是单个 <svg>...</svg>，不要包含 script、foreignObject、外链图片或事件属性。
- diagram_svg 的 viewBox 必须控制在 320x180 或 360x200 内，画成讲义小图，不要做成占满整页的大图。
- diagram_svg 里不要写完整公式、题目、解答、长句说明或大标题；只允许少量标签，如 x、y、O、A、B、F1、F2、P、v、F、mg、I。公式和说明放在 diagram_caption 或正文中。
- diagram_svg 中 text 元素的 font-size 不得超过 14；不要使用超大字号、transform 放大文字、MathJax、TeX、foreignObject。
- 示意图必须服务解题：标出已知点、关键线段/角度/坐标轴、运动方向、受力方向、电场/磁场方向、电流方向或光路方向等关键标记。
- 物理图不要只画物块/圆点；必须用箭头和文字标注 v、F、a、B、E、I、N、mg 等必要方向。磁场垂直纸面时用 ⊙/⊗ 或点/叉阵列表示，并写清“B 出纸面/入纸面”。
- 函数或几何图要标出坐标轴、关键点、辅助线、角度或长度关系；电路图要标出电源、开关、电流方向和关键表计/电阻。

错题档案：
{source_json}

输出 JSON 字段：
{{
  "title": "第 X 章 章节名称：知识点名称",
  "subtitle": "一行副标题",
  "subject_focus": ["学科"],
  "topic_focus": ["知识点"],
  "estimated_minutes": 25,
  "handout_overview": "",
  "learning_targets": [],
  "warmup_notes": [],
  "concept_review": [],
  "formula_cards": [],
  "method_models": [],
  "worked_examples": ["例题：具体例题；解答思路：关键入口；步骤/计算过程：分步推导；答案：最终答案"],
  "common_traps": [],
  "questions": [
    {{
      "id": "q1",
      "type": "单选题/填空题/解答题/应用题",
      "subject": "学科",
      "topic": "知识点",
      "stem": "具体题目",
      "options": ["A", "B", "C", "D"],
      "answer": "标准答案",
      "answer_index": 0,
      "solution_outline": "答案要点",
      "solution_steps": ["步骤1", "步骤2", "步骤3"],
      "diagram_svg": "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 360 180'>...</svg>",
      "diagram_caption": "示意图说明",
      "reason_hint": "这题主要回收的错因",
      "difficulty": "基础/中等/提高",
      "estimated_minutes": 3,
      "source_error_ids": ["错题 id"]
    }}
  ],
  "answer_key": []
}}
""".strip()

    def _build_compact_prompt(self, request: PracticePaperRequest) -> str:
        source_errors = self._source_errors_for_prompt(request)[:6]
        subjects = [
            item
            for item in request.selected_subjects
            if item.strip() and item.strip() not in {"全部", "全部学科"}
        ]
        subject_hint = "、".join(subjects) if subjects else "从错题档案中自动判断"
        topic_hint = "、".join(self._clean_filter_values(request.selected_topics)) or "自动判断"
        type_hint = "、".join(self._clean_filter_values(request.selected_type_tags)) or "自动判断"
        source_json = json.dumps(source_errors, ensure_ascii=False, indent=2)
        question_count = min(max(1, self._target_question_count(request)), 15)

        return f"""
CRITICAL JSON CONTRACT:
- Return exactly one valid JSON object and nothing else. No Markdown, code fences, comments, notes, or self-correction text.
- Do not include hidden reasoning, uncertainty, or draft phrases inside JSON values. If unsure, write a simpler valid question.
- Escape all LaTeX backslashes in raw JSON source. Use "\\\\(2\\\\sqrt{{6}}\\\\)" and "\\\\(x=\\\\frac{{13}}{{6}}\\\\)", never single-backslash LaTeX in JSON source.
- Use "\\\\(" "\\\\)" and "\\\\[" "\\\\]" as MathJax delimiters in raw JSON source.
只返回 JSON，不要 Markdown，不要代码围栏。
你是教辅命题老师。上一次完整讲义生成可能超时，请用轻量模式基于错题档案生成稳定可用的蓝白教辅风格专题讲义。

要求：
- 练习题题量：{question_count} 题，选定学科：{subject_hint}，选定知识点：{topic_hint}，选定题型：{type_hint}，策略：{request.strategy_label}，生成模式：{request.generation_mode}。
- title 写成“科目/章节/知识点名称”，优先使用“第 X 章 章节名称：知识点名称”。
- 讲义不要输出知识点讲解、知识精讲、公式速查、易错提醒、内容提要等前置讲解板块；只保留标题、例题讲解与答案、习题。
- handout_overview、concept_review、formula_cards、method_models、common_traps 返回空字符串或空数组即可。
- worked_examples 生成 1 到 2 条，每条按“例题：...；解答思路：...；步骤/计算过程：...；答案：...”输出，不要使用其他旧标签。
- 普通专题至少 3 道习题；如果错题集中是选择题、填空题、概念辨析、公式辨析等小知识点训练，至少生成 5 道选择/填空题。
- 大题/解答题/应用题要适合打印手写作答，前端会预留 8cm 答题空间。
- 优先覆盖错题暴露的知识点、错因和相近变式，不要复刻原题。
- 每题题目清晰，选择题提供 4 个 options 和 0-based answer_index；非选择题 answer_index 为 null。
- options 只写选项内容，不带 A.、B.、C.、D. 前缀。
- 所有数学公式、变量、分式、根式、坐标、角度和数学数字都用 MathJax：行内 \\( ... \\)，展示 \\[ ... \\]；例如 \\(2\\sqrt{{6}}\\)、\\(x=\\frac{{13}}{{6}}\\)。
- solution_steps 写 1 到 2 步，清楚说明关键公式、代入、计算和检验。
- diagram_svg 只在几何、圆锥曲线、函数图像、物理受力/运动、电路、光路等必须看图时返回小 SVG；否则返回空字符串。为保证 JSON 可解析，SVG 必须是一行字符串，属性用单引号，不用双引号，不要换行。
- diagram_svg 只画图形本身，不写完整公式、题目、解答或长句说明；text 标签只保留 x、y、O、A、B、F1、F2、P、v、F、mg、I 等短标签，字号不超过 14。
- 禁止把本提示词中的“具体题目”“标准答案”“步骤1”“选项1”等占位词当作真实内容输出；每一道题都必须是学生可以直接作答的具体题目。

错题档案：
{source_json}

输出 JSON 字段：
{{
  "title": "第 X 章 章节名称：知识点名称",
  "subtitle": "一行副标题",
  "subject_focus": ["学科"],
  "topic_focus": ["知识点"],
  "estimated_minutes": 20,
  "handout_overview": "",
  "learning_targets": [],
  "warmup_notes": [],
  "concept_review": [],
  "formula_cards": [],
  "method_models": [],
  "worked_examples": ["例题：具体例题；解答思路：关键入口；步骤/计算过程：分步推导；答案：最终答案"],
  "common_traps": [],
  "questions": [
    {{
      "id": "q1",
      "type": "单选题/填空题/解答题",
      "subject": "学科",
      "topic": "知识点",
      "stem": "具体题目",
      "options": ["选项1", "选项2", "选项3", "选项4"],
      "answer": "标准答案",
      "answer_index": 0,
      "solution_outline": "答案要点",
      "solution_steps": ["步骤1", "步骤2"],
      "diagram_svg": "",
      "diagram_caption": "",
      "reason_hint": "回收的错因",
      "difficulty": "基础/中等/提高",
      "estimated_minutes": 3,
      "source_error_ids": ["错题 id"]
    }}
  ],
  "answer_key": ["1. ..."]
}}
""".strip()

    def _source_errors_for_prompt(self, request: PracticePaperRequest) -> list[dict[str, Any]]:
        errors = self._filtered_errors(request)

        source = []
        for item in errors[:8]:
            source.append(
                {
                    "id": item.id,
                    "subject": item.subject,
                    "topic": item.topic,
                    "question": self._clip(item.question, 260),
                    "reason": self._clip(item.reason, 120),
                    "tags": item.tags[:6],
                    "question_format": item.question_format,
                    "type_tags": item.type_tags[:5],
                    "model_tags": item.model_tags[:5],
                    "difficulty": item.difficulty,
                    "classification_confidence": item.classification_confidence,
                    "my_answer": self._clip(item.my_answer, 160),
                    "ai_analysis": self._clip(item.ai_analysis, 180),
                }
            )
        return source

    def _filtered_errors(self, request: PracticePaperRequest) -> list[Any]:
        selected_subjects = set(self._clean_filter_values(request.selected_subjects))
        selected_subjects.discard("全部")
        selected_subjects.discard("全部学科")
        selected_topics = set(self._clean_filter_values(request.selected_topics))
        selected_type_tags = set(self._clean_filter_values(request.selected_type_tags))

        errors = list(request.errors)
        if selected_subjects:
            filtered = [item for item in errors if item.subject.strip() in selected_subjects]
            if filtered:
                errors = filtered
        if selected_topics:
            filtered = [item for item in errors if item.topic.strip() in selected_topics]
            if filtered:
                errors = filtered
        if selected_type_tags:
            filtered = [
                item
                for item in errors
                if selected_type_tags.intersection(self._source_error_type_labels(item))
            ]
            if filtered:
                errors = filtered
        return errors

    def _source_error_type_labels(self, item: Any) -> set[str]:
        labels = {
            str(label).strip()
            for label in [
                item.question_format,
                item.difficulty,
                *item.type_tags,
                *item.model_tags,
                *item.tags,
            ]
            if str(label).strip()
        }
        return labels

    def _clean_filter_values(self, values: list[str]) -> list[str]:
        cleaned = []
        for item in values:
            text = str(item).strip()
            if text and text not in cleaned:
                cleaned.append(text)
        return cleaned

    def _is_source_error_only_mode(self, request: PracticePaperRequest) -> bool:
        mode = request.generation_mode.strip() or request.strategy_label.strip()
        return any(marker in mode for marker in ("错题回炉", "只整理", "原错题", "自己的错题"))

    def _build_source_error_response(self, request: PracticePaperRequest) -> PracticePaperResponse:
        source_errors = self._filtered_errors(request) or list(request.errors)
        if not source_errors:
            return self._build_response(request=request, parsed={}, raw_output="local source-error fallback")

        target_count = max(1, min(request.question_count, len(source_errors)))
        selected = source_errors[:target_count]
        questions = [
            self._question_from_source_error(index, source)
            for index, source in enumerate(selected)
        ]
        subject_focus = self._most_common([item.subject for item in selected], limit=3)
        topic_focus = self._most_common([item.topic for item in selected], limit=5)
        answer_key = [
            f"{index + 1}. {question.answer}。{question.solution_outline}".strip()
            for index, question in enumerate(questions)
        ]
        response = PracticePaperResponse(
            title=self._default_title(request, topic_focus),
            subtitle=f"{request.strategy_label or '错题回炉卷'} · {len(questions)} 道原错题整理",
            subject_focus=subject_focus,
            topic_focus=topic_focus,
            strategy_label=request.strategy_label or request.generation_mode or "错题回炉卷",
            estimated_minutes=sum(q.estimated_minutes for q in questions) or len(questions) * 4,
            handout_overview="这份试卷只使用你筛选出的原错题，适合考前回炉、重做和复盘。",
            learning_targets=["重新完成原错题", "对照解析复盘错因", "确认同一题型的稳定入口"],
            warmup_notes=[],
            concept_review=[],
            formula_cards=[],
            method_models=[],
            worked_examples=[],
            common_traps=[],
            questions=questions,
            answer_key=answer_key,
            raw_model_output="local source-error-only paper",
        )
        return response.model_copy(
            update={"printable_html": self._build_printable_html(response)}
        )

    def _question_from_source_error(self, index: int, source: Any) -> PracticeQuestion:
        subject = source.subject or "综合"
        topic = source.topic or subject or "错题回收"
        question_type = source.type_tags[0] if source.type_tags else source.question_format or "错题回炉"
        answer = source.ai_analysis.strip() or source.my_answer.strip() or "请按原题解析重新完成，并在订正区写出正确思路。"
        reason = source.reason.strip() or "原错题回炉复盘"
        return PracticeQuestion(
            id=f"source-{source.id or index + 1}",
            type=question_type,
            subject=subject,
            topic=topic,
            stem=source.question.strip() or f"请重新完成「{topic}」中的第 {index + 1} 道错题。",
            options=[],
            answer=answer,
            answer_index=None,
            solution_outline=reason,
            solution_steps=[
                "先独立重做原题，不看答案，把关键条件和第一步入口写出来。",
                "再对照错因与解析，标出本次是否还卡在同一题型入口。",
            ],
            reason_hint=reason,
            difficulty=source.difficulty or "中等",
            estimated_minutes=5,
            source_error_ids=[source.id] if source.id else [],
        )

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
        filtered_errors = self._filtered_errors(request)

        if not subject_focus:
            subject_focus = self._most_common([item.subject for item in filtered_errors], limit=3)
        if not topic_focus:
            topic_focus = self._most_common([item.topic for item in filtered_errors], limit=5)

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
            worked_examples=self._clean_worked_examples(
                self._string_list(parsed.get("worked_examples"))
            )[:4],
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

        target_count = self._target_question_count(request)
        for index, item in enumerate(raw_questions[:target_count]):
            if not isinstance(item, dict):
                continue
            stem = str(item.get("stem") or "").strip()
            answer = str(item.get("answer") or "").strip()
            if not stem or not answer:
                continue
            if self._looks_like_prompt_leak(stem) or self._looks_like_prompt_leak(answer):
                continue
            answer_index = self._optional_int(item.get("answer_index"))
            options = [
                self._normalize_option(item)
                for item in self._string_list(item.get("options"))[:4]
            ]
            if options and all(self._looks_like_prompt_leak(option) for option in options):
                continue
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
            source_errors = self._filtered_errors(request) or request.errors or []
            small_item_practice = self._looks_like_small_item_practice(request)
            while len(questions) < target_count and source_errors:
                source = source_errors[len(questions) % len(source_errors)]
                questions.append(
                    self._fallback_small_item_question_from_source(
                        len(questions),
                        source,
                    )
                    if small_item_practice
                    else self._fallback_question_from_source(len(questions), source)
                )
            return questions
        return self._fallback_questions(request)

    def _target_question_count(self, request: PracticePaperRequest) -> int:
        requested = max(3, min(50, request.question_count))
        return max(requested, 5) if self._looks_like_small_item_practice(request) else requested

    def _looks_like_small_item_practice(self, request: PracticePaperRequest) -> bool:
        markers = ("选择", "单选", "多选", "填空", "判断", "概念", "辨析", "性质", "公式")
        errors = self._filtered_errors(request) or request.errors
        source_text = " ".join(
            " ".join(
                [
                    item.subject,
                    item.topic,
                    item.question,
                    item.reason,
                    " ".join(item.tags),
                    item.question_format,
                    " ".join(item.type_tags),
                    " ".join(item.model_tags),
                    item.ai_analysis,
                ]
            )
            for item in errors[:8]
        )
        return any(marker in source_text for marker in markers)

    def _fallback_questions(self, request: PracticePaperRequest) -> list[PracticeQuestion]:
        source_errors = self._filtered_errors(request) or request.errors or []
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
        small_item_practice = self._looks_like_small_item_practice(request)
        for index in range(self._target_question_count(request)):
            source = source_errors[index % len(source_errors)]
            questions.append(
                self._fallback_small_item_question_from_source(index, source)
                if small_item_practice
                else self._fallback_question_from_source(index, source)
            )
        return questions

    def _fallback_small_item_question_from_source(self, index: int, source: Any) -> PracticeQuestion:
        subject = source.subject or "综合"
        topic = source.topic or subject or "错题回收"
        source_question = self._clip(source.question or "", 150)
        source_reason = self._clip(source.reason or "", 90)
        if index % 2 == 0:
            return PracticeQuestion(
                id=f"q{index + 1}",
                type="单选题",
                subject=subject,
                topic=topic,
                stem=f"【{topic}辨析】下列哪一项最能避免原错题中的同类错误？\n原题摘要：{source_question}",
                options=[
                    "先检查定义域、范围、条件或公式适用前提，再判断结论",
                    "看到相似题型就直接套用原题答案",
                    "只比较选项长短，优先选择包含公式最多的一项",
                    "忽略题目限制，先把常见结论写上",
                ],
                answer="先检查定义域、范围、条件或公式适用前提，再判断结论",
                answer_index=0,
                solution_outline="小题训练的关键是先排除偷换条件和公式误用。",
                solution_steps=[
                    "先读限制条件，再对应公式或性质。",
                    "排除没有检查条件、直接套结论的选项。",
                ],
                reason_hint=source_reason or "概念或条件辨析不稳",
                source_error_ids=[source.id],
                estimated_minutes=2,
            )
        return PracticeQuestion(
            id=f"q{index + 1}",
            type="填空题",
            subject=subject,
            topic=topic,
            stem=f"【{topic}回收】做这类小题时，应先确认 ______ ，再代入公式或判断性质。",
            answer="定义域、取值范围、适用条件",
            solution_outline="空格强调先检查条件，再进行判断。",
            solution_steps=[
                "先找题目给出的范围、定义域或限制条件。",
                "再判断公式、性质或结论是否适用。",
            ],
            reason_hint=source_reason or "忽略条件导致判断错误",
            source_error_ids=[source.id],
            estimated_minutes=2,
        )

    def _fallback_question_from_source(self, index: int, source: Any) -> PracticeQuestion:
        subject = source.subject or "综合"
        topic = source.topic or subject or "错题回收"
        source_question = self._clip(source.question or "", 180)
        source_reason = self._clip(source.reason or "", 90)
        source_analysis = self._clip(source.ai_analysis or "", 180)
        template_index = index % 4

        if template_index == 0:
            return PracticeQuestion(
                id=f"q{index + 1}",
                type="简答题",
                subject=subject,
                topic=topic,
                stem=(
                    f"【{topic}基础回收】请写出解决这类题时必须先确认的 2 个条件，"
                    f"并说明每个条件会影响哪一步。参考原错题信息：{source_question}"
                ),
                answer="应先确认题设对象、适用公式或模型的前提条件，再说明这些条件如何决定建模、代入或分类讨论。",
                solution_outline="先列条件，再对应到公式、模型或步骤，最后给出检查点。",
                solution_steps=[
                    "从题目中划出已知对象、要求结论和限制条件。",
                    f"把这些条件对应到“{topic}”的定义、公式或常用模型。",
                    "说明若遗漏某个条件，会导致哪一步判断或计算出错。",
                ],
                reason_hint=source_reason or "基础条件识别不够稳定",
                source_error_ids=[source.id],
                estimated_minutes=4,
            )

        if template_index == 1:
            return PracticeQuestion(
                id=f"q{index + 1}",
                type="单选题",
                subject=subject,
                topic=topic,
                stem=(
                    f"【{topic}方法选择】遇到下面这类题时，最稳妥的第一步是什么？"
                    f"\n题目背景：{source_question}"
                ),
                options=[
                    "直接套最近记住的结论，先算出一个数值",
                    "先提取已知条件、目标结论和适用前提，再选择模型",
                    "只看选项差异，反推一个看起来合理的答案",
                    "跳过条件检查，把原错题答案迁移过来",
                ],
                answer="先提取已知条件、目标结论和适用前提，再选择模型",
                answer_index=1,
                solution_outline="这类题的关键是先完成条件识别，再决定公式或模型。",
                solution_steps=[
                    "原错题暴露的问题通常不是不会计算，而是条件和模型没有对齐。",
                    "先分离已知、所求、限制条件，能避免把不适用的结论硬套进去。",
                    "确定模型后再代入计算，最后回看题目范围或单位。",
                ],
                reason_hint=source_reason or "解题入口选择不稳",
                source_error_ids=[source.id],
                estimated_minutes=3,
            )

        if template_index == 2:
            return PracticeQuestion(
                id=f"q{index + 1}",
                type="填空题",
                subject=subject,
                topic=topic,
                stem=(
                    f"【{topic}错因修正】请补全这句话：做这类题时，不能只记结论，"
                    "还要先检查 ______ ，再进行代入或推导。"
                ),
                answer="公式、定理或模型的适用条件",
                solution_outline="空格处强调适用条件，这是从错题迁移到新题的第一道关口。",
                solution_steps=[
                    "先回看原错题中被忽略或误判的条件。",
                    "判断当前题是否满足同一个公式、定理或模型的前提。",
                    "满足后再代入；不满足时需要分类讨论或换模型。",
                ],
                reason_hint=source_reason or "忽略适用条件",
                source_error_ids=[source.id],
                estimated_minutes=2,
            )

        return PracticeQuestion(
            id=f"q{index + 1}",
            type="解答题",
            subject=subject,
            topic=topic,
            stem=(
                f"【{topic}迁移训练】根据原错题暴露的问题，写出一份三步解题流程："
                "第 1 步提取条件，第 2 步选择模型，第 3 步检验答案。"
                f"\n原错题摘要：{source_question}"
            ),
            answer="应包含条件提取、模型选择、代入推导和结果检验四个要点。",
            solution_outline=source_analysis or "用固定流程约束自己，减少同类题再次出错。",
            solution_steps=[
                "条件提取：写出题目给了什么、要求什么、有哪些限制。",
                f"模型选择：说明为什么使用“{topic}”相关公式、定义或方法。",
                "结果检验：检查符号、范围、单位、选项或结论是否与题意一致。",
            ],
            reason_hint=source_reason or "解题流程缺少检查环节",
            source_error_ids=[source.id],
            estimated_minutes=5,
        )

    def _build_printable_html(self, response: PracticePaperResponse) -> str:
        question_blocks = "\n".join(
            self._question_html(index, question)
            for index, question in enumerate(response.questions)
        )
        examples = self._example_blocks_html(
            response.worked_examples,
            response.questions,
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
    @page {{ size: A4; margin: 12mm 13mm; }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      background: #edf3f8;
      color: #222831;
      font-family: "Noto Serif SC", "Songti SC", "SimSun", serif;
      line-height: 1.68;
    }}
    .sheet {{
      width: 210mm;
      min-height: 297mm;
      margin: 0 auto;
      padding: 16mm 16mm 17mm;
      background: #ffffff;
    }}
    header {{
      text-align: center;
      margin-bottom: 20px;
    }}
    h1 {{
      margin: 0;
      color: #3f73aa;
      font-size: 26px;
      font-weight: 700;
      letter-spacing: 0;
      line-height: 1.35;
    }}
    .subtitle {{
      margin-top: 7px;
      color: #6a7f92;
      font-size: 13px;
    }}
    .summary {{
      position: relative;
      margin: 22px 0 22px;
      padding: 20px 26px 16px;
      border-top: 1.5px solid #8fb1cf;
      border-bottom: 1.5px solid #8fb1cf;
      background: #eaf3fb;
      color: #283745;
      font-size: 13.5px;
      text-align: left;
    }}
    .summary-label {{
      position: absolute;
      top: -15px;
      left: 50%;
      transform: translateX(-50%);
      padding: 4px 18px 5px;
      border-radius: 4px;
      background: #3f73aa;
      color: #ffffff;
      font-size: 14px;
      font-weight: 700;
    }}
    .summary p {{ margin: 0; text-indent: 2em; }}
    .part {{
      margin-top: 21px;
      break-inside: auto;
    }}
    .part-title {{
      margin: 0 0 13px;
      color: #3f73aa;
      font-size: 20px;
      font-weight: 700;
      line-height: 1.35;
    }}
    .subhead {{
      margin: 14px 0 7px;
      color: #4f86b9;
      font-size: 15px;
      font-weight: 700;
      line-height: 1.4;
    }}
    .teach-grid {{
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      margin-top: 6px;
    }}
    .teach-box {{
      break-inside: avoid;
      border: 1px solid #b9cde0;
      background: #fbfdff;
      padding: 9px 11px;
      margin-bottom: 9px;
    }}
    .teach-box h3 {{
      margin: 0 0 6px;
      font-size: 14px;
      color: #3f73aa;
    }}
    ul, ol {{ margin: 6px 0 0 20px; padding: 0; }}
    li {{ margin: 2px 0; }}
    .knowledge-table {{
      width: 100%;
      border-collapse: collapse;
      margin: 7px 0 10px;
      font-size: 13px;
      break-inside: avoid;
    }}
    .knowledge-table th,
    .knowledge-table td {{
      border: 1px solid #8fa9c2;
      padding: 7px 9px;
      vertical-align: top;
    }}
    .knowledge-table th {{
      width: 26%;
      color: #2f6698;
      background: #eaf3fb;
      text-align: center;
      font-weight: 700;
    }}
    .visual-grid {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 12px;
      margin: 9px 0 2px;
    }}
    .visual-card {{
      break-inside: avoid;
      border: 1px solid #b9cde0;
      background: #ffffff;
      padding: 6px;
      text-align: center;
      overflow: hidden;
      min-height: 52mm;
      display: flex;
      flex-direction: column;
      justify-content: center;
    }}
    .visual-card > svg {{
      display: block;
      width: 100%;
      max-width: 76mm;
      height: auto;
      max-height: 48mm;
      margin: 0 auto;
    }}
    .visual-card > svg text,
    .diagram > svg text {{
      font-size: 10px !important;
    }}
    .example-card {{
      break-inside: avoid;
      border-left: 4px solid #3f73aa;
      padding: 9px 11px;
      margin-bottom: 10px;
      background: #fbfdff;
    }}
    .example-title {{
      color: #2f6698;
      font-weight: 700;
      margin-bottom: 4px;
    }}
    .example-row {{
      margin: 4px 0;
    }}
    .example-label {{
      color: #2f6698;
      font-weight: 700;
    }}
    .question {{
      break-inside: avoid;
      padding: 11px 0 14px;
      border-bottom: 1px dashed #b9cde0;
    }}
    .q-head {{
      display: flex;
      gap: 8px;
      align-items: center;
      font-weight: 700;
      margin-bottom: 6px;
      color: #222831;
    }}
    .tag {{
      border: 1px solid #8fb1cf;
      color: #3f73aa;
      background: #f4f8fc;
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
      padding: 5px;
      border: 1px solid #b9cde0;
      background: #fbfdff;
      text-align: center;
      break-inside: avoid;
      overflow: hidden;
    }}
    .diagram > svg {{
      display: block;
      width: 100%;
      max-width: 72mm;
      max-height: 46mm;
      height: auto;
      margin: 0 auto;
    }}
    .caption {{
      margin-top: 4px;
      color: #66798b;
      font-size: 11px;
      text-align: center;
    }}
    .answer-space {{
      height: 12mm;
      border: 1px solid #d5e2ee;
      background: #ffffff;
      margin-top: 9px;
    }}
    .answer-space.short {{
      height: 0;
      border: 0;
      border-bottom: 1px solid #b9cde0;
      margin-top: 10px;
    }}
    .answer-space.large {{
      height: 80mm;
      background: #ffffff;
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
      color: #3f73aa;
    }}
    mjx-container {{
      font-size: 92% !important;
      overflow-wrap: normal;
    }}
    .stem mjx-container,
    .example-card mjx-container {{
      font-size: 92% !important;
    }}
    .options mjx-container,
    .caption mjx-container,
    .tag mjx-container {{
      font-size: 82% !important;
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
    <section class="part">
      <h2 class="part-title">1 例题讲解与答案</h2>
      {examples}
    </section>
    <section class="part">
      <h2 class="part-title">2 习题</h2>
      {question_blocks}
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
        answer_space_class = self._answer_space_class(question)
        answer_space = (
            f"<div class=\"{answer_space_class}\"></div>"
            if answer_space_class
            else ""
        )
        return f"""
<section class="question">
  <div class="q-head">
    <span>{index + 1}. {self._math_text_html(question.type)}</span>
    <span class="tag">{self._math_text_html(question.difficulty)}</span>
    <span class="tag">{self._math_text_html(question.topic or question.subject or "专题")}</span>
  </div>
  <div class="stem">{self._math_text_html(question.stem)}</div>
  {options}
  {answer_space}
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

    def _knowledge_table_html(
        self,
        *,
        concepts: list[str],
        formulas: list[str],
        methods: list[str],
        traps: list[str],
    ) -> str:
        rows = [
            ("知识点", self._compact_items_text(concepts)),
            ("公式/概念", self._compact_items_text(formulas)),
            ("做题步骤", self._compact_items_text(methods)),
            ("易错提醒", self._compact_items_text(traps)),
        ]
        row_html = "\n".join(
            f"<tr><th>{html.escape(label)}</th><td>{self._math_text_html(value)}</td></tr>"
            for label, value in rows
        )
        return f"<table class=\"knowledge-table\"><tbody>{row_html}</tbody></table>"

    def _compact_items_text(self, items: list[str]) -> str:
        cleaned = [str(item).strip() for item in items if str(item).strip()]
        if not cleaned:
            return "结合本讲义专题，先回看定义、条件和解题步骤，再进入练习。"
        return "；".join(cleaned[:2])

    def _example_blocks_html(
        self,
        examples: list[str],
        questions: list[PracticeQuestion],
    ) -> str:
        blocks = []
        example_candidates = self._clean_worked_examples(examples)
        if len(example_candidates) < 2:
            example_candidates.extend(
                self._worked_examples_from_questions(
                    questions,
                    limit=2 - len(example_candidates),
                )
            )
        for index, example in enumerate(example_candidates[:2]):
            content = str(example).strip()
            if not content:
                continue
            rows = self._example_rows_html(content)
            blocks.append(
                f"""
<section class="example-card">
  <div class="example-title">例题 {index + 1}</div>
  {rows}
</section>"""
            )
        if blocks:
            return "\n".join(blocks)
        return ""

    def _clean_worked_examples(self, examples: list[str]) -> list[str]:
        cleaned: list[str] = []
        for example in examples:
            content = str(example).strip()
            if not content:
                continue
            if self._looks_like_prompt_leak(content):
                continue
            cleaned.append(content)
        return cleaned

    def _worked_examples_from_questions(
        self,
        questions: list[PracticeQuestion],
        *,
        limit: int,
    ) -> list[str]:
        examples: list[str] = []
        for question in questions:
            if len(examples) >= limit:
                break
            stem = question.stem.strip()
            answer = question.answer.strip()
            if not stem or not answer:
                continue
            if self._looks_like_prompt_leak(stem) or self._looks_like_prompt_leak(answer):
                continue
            examples.append(self._question_to_worked_example(question))
        return examples

    def _question_to_worked_example(self, question: PracticeQuestion) -> str:
        stem = self._clip(question.stem, 260)
        answer = question.answer.strip()
        if question.options:
            option_labels = "ABCD"
            options = "；".join(
                f"{option_labels[index]}. {self._clip(option, 80)}"
                for index, option in enumerate(question.options[:4])
            )
            stem = f"{stem}\n{options}"
        outline = question.solution_outline.strip()
        if not outline:
            topic = question.topic.strip() or question.subject.strip() or "本题"
            outline = f"先抓住“{topic}”的适用条件，再按题目要求选择公式、性质或解题模型。"
        steps = [
            step
            for step in question.solution_steps
            if step.strip() and not self._looks_like_prompt_leak(step)
        ][:4]
        if not steps:
            steps = [
                "提取题干中的已知条件、限制范围和求解目标。",
                "把条件对应到相关定义、公式或性质，排除不满足前提的做法。",
                "代入计算或完成判断后，回到题意检查范围、符号和结论。",
            ]
        return (
            f"例题：{stem}；"
            f"解答思路：{outline}；"
            f"步骤/计算过程：{'；'.join(steps)}；"
            f"答案：{answer}"
        )

    def _example_rows_html(self, content: str) -> str:
        labels = ("例题", "解答思路", "步骤/计算过程", "答案")
        aliases = {"例题": ("例题", "题目", "题干")}
        pieces: dict[str, str] = {}
        for index, label in enumerate(labels):
            next_labels = labels[index + 1 :]
            current_label_patterns = aliases.get(label, (label,))
            if next_labels:
                next_label_patterns = []
                for next_label in next_labels:
                    next_label_patterns.extend(aliases.get(next_label, (next_label,)))
                pattern = r"(?:" + "|".join(
                    rf"{re.escape(current_label)}[：:]"
                    for current_label in current_label_patterns
                ) + r")\s*(.*?)(?=" + "|".join(
                    rf"{re.escape(next_label)}[：:]"
                    for next_label in next_label_patterns
                ) + r"|$)"
            else:
                pattern = r"(?:" + "|".join(
                    rf"{re.escape(current_label)}[：:]"
                    for current_label in current_label_patterns
                ) + r")\s*(.*)$"
            match = re.search(pattern, content, flags=re.DOTALL)
            if match:
                pieces[label] = match.group(1).strip(" ；;。\n")

        if not pieces:
            return f"<div class=\"example-row\">{self._math_text_html(content)}</div>"

        rows = []
        for label in labels:
            value = pieces.get(label, "")
            if not value:
                continue
            rows.append(
                f"<div class=\"example-row\"><span class=\"example-label\">{html.escape(label)}：</span>{self._math_text_html(value)}</div>"
            )
        return "\n".join(rows)

    def _diagram_gallery_html(self, questions: list[PracticeQuestion]) -> str:
        cards = []
        seen_diagram_keys: set[str] = set()
        for question in questions:
            diagram_key = self._stable_diagram_key(question)
            if not diagram_key or diagram_key in seen_diagram_keys:
                continue
            seen_diagram_keys.add(diagram_key)
            diagram_svg = self._stable_diagram_svg(question)
            if not diagram_svg:
                continue
            caption_text = self._stable_diagram_caption(question)
            caption = (
                f"<div class=\"caption\">{self._math_text_html(caption_text)}</div>"
                if caption_text.strip()
                else ""
            )
            cards.append(
                f"<div class=\"visual-card\">{diagram_svg}{caption}</div>"
            )
            if len(cards) >= 2:
                break
        if not cards:
            return ""
        return (
            "<h3 class=\"subhead\">1.4 图表/图像辅助</h3>"
            f"<div class=\"visual-grid\">{''.join(cards)}</div>"
        )

    def _answer_space_class(self, question: PracticeQuestion) -> str:
        text = f"{question.type} {question.stem}".lower()
        large_markers = (
            "解答",
            "应用",
            "证明",
            "计算",
            "综合",
            "大题",
            "过程",
            "推导",
        )
        if any(marker in text for marker in large_markers):
            return "answer-space large"
        return ""

    def _diagram_html(self, question: PracticeQuestion) -> str:
        diagram_svg = self._stable_diagram_svg(question)
        if not diagram_svg:
            return ""
        caption_text = self._stable_diagram_caption(question)
        caption = (
            f"<div class=\"caption\">{self._math_text_html(caption_text)}</div>"
            if caption_text.strip()
            else ""
        )
        return f"<div class=\"diagram\">{diagram_svg}{caption}</div>"

    def _stable_diagram_svg(self, question: PracticeQuestion) -> str:
        diagram_key = self._stable_diagram_key(question)
        if diagram_key == "trig":
            return self._trig_diagram_svg()
        if diagram_key == "ellipse":
            return self._ellipse_diagram_svg()
        return ""

    def _stable_diagram_caption(self, question: PracticeQuestion) -> str:
        diagram_key = self._stable_diagram_key(question)
        if diagram_key == "trig":
            return "正弦型函数在一个周期内的示意图，浅蓝区域表示单调递增区间。"
        if diagram_key == "ellipse":
            return "椭圆标准示意图：标出长轴、短轴、中心、焦点和动点，便于对应题目条件。"
        return question.diagram_caption.strip()

    def _stable_diagram_key(self, question: PracticeQuestion) -> str:
        text = f"{question.subject} {question.topic} {question.stem}".lower()
        if any(keyword in text for keyword in ("三角", "正弦", "sin", "周期", "单调区间")):
            return "trig"
        if any(keyword in text for keyword in ("椭圆", "圆锥曲线", "焦点", "离心率")):
            return "ellipse"
        return ""

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
        return self._stable_diagram_svg(question)

    def _fallback_diagram_caption(self, question: PracticeQuestion) -> str:
        return self._stable_diagram_caption(question) or "题目关键关系示意图。"

    def _trig_diagram_svg(self) -> str:
        return """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 180" role="img" aria-label="三角函数单调区间示意图">
  <defs>
    <clipPath id="plotArea"><rect x="34" y="20" width="292" height="118"/></clipPath>
  </defs>
  <rect x="0" y="0" width="360" height="180" fill="#ffffff"/>
  <line x1="34" y1="90" x2="330" y2="90" stroke="#30353b" stroke-width="1.4"/>
  <line x1="34" y1="142" x2="34" y2="22" stroke="#30353b" stroke-width="1.4"/>
  <g clip-path="url(#plotArea)">
    <rect x="34" y="38" width="74" height="52" fill="#d9edf5"/>
    <rect x="256" y="38" width="74" height="52" fill="#d9edf5"/>
    <path d="M34 90 C58 48 86 35 108 38 C145 43 160 75 182 90 C205 106 220 137 256 142 C280 145 306 126 330 90" fill="none" stroke="#2357ff" stroke-width="2.2"/>
  </g>
  <text x="324" y="106" font-size="11" fill="#586a7a">x</text>
  <text x="42" y="31" font-size="11" fill="#586a7a">y</text>
  <text x="104" y="106" font-size="10" fill="#586a7a">π/4</text>
  <text x="176" y="106" font-size="10" fill="#586a7a">π/2</text>
  <text x="252" y="106" font-size="10" fill="#586a7a">3π/4</text>
  <text x="316" y="106" font-size="10" fill="#586a7a">π</text>
</svg>
""".strip()

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

    def _normalize_option(self, option: str) -> str:
        cleaned = option.strip()
        cleaned = re.sub(
            r"^\s*(?:[\(\[（【]?\s*[A-Fa-f]\s*[\)\]）】]?[\.\、．:：]?\s+|[A-Fa-f][\.\、．:：]\s*)",
            "",
            cleaned,
        ).strip()
        return cleaned or option.strip()

    def _looks_like_prompt_leak(self, value: str) -> bool:
        text = re.sub(r"\s+", "", str(value or "")).strip().lower()
        if not text:
            return True
        placeholders = {
            "题干",
            "标准答案",
            "答案要点",
            "步骤1",
            "步骤2",
            "步骤3",
            "选项1",
            "选项2",
            "选项3",
            "选项4",
            "专题讲义标题",
            "一行副标题",
            "知识点",
            "学科",
            "错题id",
        }
        if text in {item.lower() for item in placeholders}:
            return True
        leak_markers = [
            "只返回json",
            "不要markdown",
            "输出json字段",
            "你是教辅命题老师",
            "你是“错题都队”",
            "要求：",
            "错题档案：",
            "设计一道同类例题",
            "抽取一个变式情境",
            "围绕本讲义知识点完成一道同类题",
            "写出最终结论",
            "写出最终答案",
            "具体例题",
            "关键入口",
            "分步推导并检查适用条件",
            "questions",
            "answer_index",
            "solution_steps",
            "diagram_svg",
        ]
        return any(marker.lower() in text for marker in leak_markers)

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
        svg = re.sub(r"\s+(?:width|height)\s*=\s*(['\"]).*?\1", "", svg, flags=re.IGNORECASE | re.DOTALL)

        def clean_text(match: re.Match[str]) -> str:
            open_tag, content, close_tag = match.groups()
            plain = re.sub(r"<[^>]+>", "", content).strip()
            font_match = re.search(r"font-size\s*=\s*(['\"])?([0-9.]+)", open_tag, re.IGNORECASE)
            font_size = float(font_match.group(2)) if font_match else 10.0
            has_large_scale = bool(
                re.search(r"transform\s*=\s*(['\"]).*?scale\(\s*(?:1\.[6-9]|[2-9])", open_tag, re.IGNORECASE)
            )
            bad_text = bool(
                re.search(
                    r"(\\|sin|cos|tan|frac|pi|函数|图像|周期|区间|公式|题干|解答|步骤|单调)",
                    plain,
                    re.IGNORECASE,
                )
            )
            if font_size > 16 or len(plain) > 18 or has_large_scale or bad_text:
                return ""
            return f"{open_tag}{content}{close_tag}"

        svg = re.sub(r"(<text\b[^>]*>)(.*?)(</text>)", clean_text, svg, flags=re.IGNORECASE | re.DOTALL)
        if "preserveAspectRatio" not in svg:
            svg = re.sub(r"<svg\b([^>]*)>", r"<svg\1 preserveAspectRatio='xMidYMid meet'>", svg, count=1)
        return svg.strip()

    def _parse_json(self, raw_output: str) -> dict[str, Any]:
        cleaned = raw_output.strip()
        candidates = []

        fence_match = re.search(
            r"```(?:json)?\s*(.*?)```",
            cleaned,
            re.DOTALL | re.IGNORECASE,
        )
        if fence_match:
            candidates.append(fence_match.group(1).strip())

        candidates.append(cleaned)

        object_match = re.search(r"\{.*\}", cleaned, re.DOTALL)
        if object_match:
            candidates.append(object_match.group(0).strip())

        seen = set()
        errors = []
        for candidate in candidates:
            if not candidate or candidate in seen:
                continue
            seen.add(candidate)

            repaired = self._repair_json_latex_escapes(candidate)
            for attempt, repaired_used in (
                (repaired, repaired != candidate),
                (candidate, False),
            ):
                parsed = self._loads_json_object(attempt)
                if parsed:
                    if repaired_used:
                        logger.info("practice paper json parsed after repair")
                    return parsed
                error = self._json_decode_error(attempt)
                if error:
                    errors.append(("repaired" if repaired_used else "raw", error))

        logger.warning(
            "practice paper json parse failed content_len=%s errors=%s",
            len(raw_output),
            errors[:3],
        )
        return {}

    def _loads_json_object(self, value: str) -> dict[str, Any]:
        try:
            parsed = json.loads(value)
        except json.JSONDecodeError:
            return {}
        return parsed if isinstance(parsed, dict) else {}

    def _repair_json_latex_escapes(self, value: str) -> str:
        repaired = _JSON_FIELD_QUOTE_SWALLOWED_VALUE_PATTERN.sub(r'"\1": \2', value)
        repaired = _JSON_MISSING_COLON_FIELD_PATTERN.sub(r'"\1": ', repaired)
        repaired = _JSON_MATH_DELIMITER_BACKSLASH_PATTERN.sub(r"\\\\", repaired)
        repaired = _JSON_LATEX_COMMAND_BACKSLASH_PATTERN.sub(r"\\\\", repaired)
        return _JSON_INVALID_BACKSLASH_PATTERN.sub(r"\\\\", repaired)

    def _json_decode_error(self, value: str) -> str:
        try:
            json.loads(value)
        except json.JSONDecodeError as exc:
            start = max(0, exc.pos - 60)
            end = min(len(value), exc.pos + 60)
            near = value[start:end].replace("\n", "\\n")
            return f"{exc.msg} at pos={exc.pos} near={near!r}"
        return ""

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
