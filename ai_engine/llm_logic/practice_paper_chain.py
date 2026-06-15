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
- 答案解析要像教辅答案栏一样完整，但必须精炼：给出 2 到 3 个分步 solution_steps，每步 60 字以内；不要只写一句答案。
- concept_review、formula_cards、method_models、worked_examples、common_traps 每个数组最多 3 条，每条 80 字以内。
- 每道题先判断是否有“视觉结构”：图形位置关系、函数/圆锥曲线图像、运动或力的方向、电路连接、光路、化学流程、统计图表等。
- 如果存在视觉结构，可以在 diagram_svg 返回一个简洁 SVG 示意图；纯代数运算、纯概念辨析、无需图像辅助的题目返回空字符串。
- 为保证 JSON 可解析，diagram_svg 必须是单行 SVG 字符串，SVG 属性必须使用单引号，不要使用双引号，不要换行。例如 <svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 360 180'>...</svg>。
- 整份试卷最多 3 道题返回 diagram_svg；其他题即使可画图，也优先用 diagram_caption 描述关键关系。
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
        source_json = json.dumps(source_errors, ensure_ascii=False, indent=2)
        question_count = min(max(1, request.question_count), 15)

        return f"""
只返回 JSON，不要 Markdown，不要代码围栏。
你是教辅命题老师。上一次完整讲义生成可能超时，请用轻量模式基于错题档案生成稳定可用的专题练习。

要求：
- 题量：{question_count} 题，选定学科：{subject_hint}，策略：{request.strategy_label}。
- 优先覆盖错题暴露的知识点、错因和相近变式，不要复刻原题。
- 每题题干清晰，选择题提供 4 个 options 和 0-based answer_index；非选择题 answer_index 为 null。
- options 只写选项内容，不带 A.、B.、C.、D. 前缀。
- 所有数学公式、变量、分式、根式、坐标、角度和数学数字都用 MathJax：行内 \\( ... \\)，展示 \\[ ... \\]；例如 \\(2\\sqrt{{6}}\\)、\\(x=\\frac{{13}}{{6}}\\)。
- solution_steps 写 2 到 4 步，清楚说明关键公式、代入、计算和检验。
- diagram_svg 只在几何、圆锥曲线、函数图像、物理受力/运动、电路、光路等必须看图时返回小 SVG；否则返回空字符串。为保证 JSON 可解析，SVG 必须是一行字符串，属性用单引号，不用双引号，不要换行。
- 精讲内容保持短小：concept_review、formula_cards、method_models、worked_examples、common_traps 每项 2 到 4 条。
- 禁止把本提示词中的“题干”“标准答案”“步骤1”“选项1”等占位词当作真实内容输出；每一道题都必须是学生可以直接作答的具体题目。

错题档案：
{source_json}

输出 JSON 字段：
{{
  "title": "专题讲义标题",
  "subtitle": "一行副标题",
  "subject_focus": ["学科"],
  "topic_focus": ["知识点"],
  "estimated_minutes": 20,
  "handout_overview": "80字以内",
  "learning_targets": ["目标1", "目标2"],
  "warmup_notes": ["提醒1", "提醒2"],
  "concept_review": ["概念1", "概念2"],
  "formula_cards": ["公式1", "公式2"],
  "method_models": ["模型1", "模型2"],
  "worked_examples": ["例题讲解1"],
  "common_traps": ["易错点1", "易错点2"],
  "questions": [
    {{
      "id": "q1",
      "type": "单选题/填空题/解答题",
      "subject": "学科",
      "topic": "知识点",
      "stem": "题干",
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
        for item in errors[:8]:
            source.append(
                {
                    "id": item.id,
                    "subject": item.subject,
                    "topic": item.topic,
                    "question": self._clip(item.question, 260),
                    "reason": self._clip(item.reason, 120),
                    "tags": item.tags[:6],
                    "my_answer": self._clip(item.my_answer, 160),
                    "ai_analysis": self._clip(item.ai_analysis, 180),
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
            questions.append(self._fallback_question_from_source(index, source))
        return questions

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
                    "从题干中划出已知对象、要求结论和限制条件。",
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
                "条件提取：写出题干给了什么、要求什么、有哪些限制。",
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
            start = max(0, exc.pos - 80)
            end = min(len(value), exc.pos + 80)
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
