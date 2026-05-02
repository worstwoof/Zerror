from __future__ import annotations

import html
import json
import math
import re
from typing import Iterable, List, Optional

from backend.app.schemas.card_schema import RichArtifact


def filter_subject_extension_artifacts(
    *,
    subject: str,
    cleaned_question: str,
    artifacts: Iterable[RichArtifact],
) -> List[RichArtifact]:
    profile = _resolve_subject_profile(subject, cleaned_question)
    if profile is None:
        return list(artifacts)

    filtered: List[RichArtifact] = []
    for artifact in artifacts:
        if artifact.artifact_type != profile.default_artifact_type:
            continue
        if not _is_artifact_content_valid(
            artifact,
            subject=subject,
            cleaned_question=cleaned_question,
        ):
            continue
        if artifact.artifact_type == "chart_spec":
            artifact = _with_chart_spec_legacy_display_fields(
                artifact,
                cleaned_question=cleaned_question,
            )
        filtered.append(artifact)
    return filtered


def build_subject_extension_artifacts(
    *,
    subject: str,
    cleaned_question: str,
    knowledge_points: Iterable[str],
    solution_steps: Iterable[str],
    existing_artifacts: Iterable[RichArtifact],
) -> List[RichArtifact]:
    profile = _resolve_subject_profile(subject, cleaned_question)
    if profile is None:
        return []

    existing_types = {artifact.artifact_type for artifact in existing_artifacts}
    if profile.default_artifact_type in existing_types:
        return []

    artifact = profile.builder(
        cleaned_question=cleaned_question,
        knowledge_points=list(knowledge_points),
        solution_steps=list(solution_steps),
    )
    return [artifact]


class _SubjectProfile:
    def __init__(self, default_artifact_type: str, builder) -> None:
        self.default_artifact_type = default_artifact_type
        self.builder = builder


def _resolve_subject_profile(subject: str, cleaned_question: str) -> Optional[_SubjectProfile]:
    normalized = f"{subject} {cleaned_question}".lower()

    if any(
        keyword in normalized
        for keyword in [
            "数学",
            "线性代数",
            "高数",
            "概率",
            "统计",
            "函数",
            "导数",
            "积分",
            "几何",
            "解析几何",
            "数列",
            "向量",
            "矩阵",
            "特征值",
            "二次函数",
            "抛物线",
            "椭圆",
            "双曲线",
        ]
    ):
        return _SubjectProfile("chart_spec", _build_math_chart_spec)
    if any(keyword in normalized for keyword in ["物理", "力学", "电路", "电学", "光学", "运动", "速度", "加速度"]):
        return _SubjectProfile("interactive_html", _build_physics_html)
    if any(keyword in normalized for keyword in ["化学", "离子", "氧化还原", "平衡", "有机", "实验", "反应"]):
        return _SubjectProfile("study_card", _build_chemistry_study_card)
    if any(keyword in normalized for keyword in ["编程", "计算机", "算法", "java", "python", "c++", "数据结构", "代码"]):
        return _SubjectProfile("code_snippet", _build_programming_snippet)
    if any(keyword in normalized for keyword in ["生物", "细胞", "遗传", "光合作用", "呼吸作用", "有丝分裂", "减数分裂", "生态"]):
        return _SubjectProfile("timeline", _build_biology_timeline)
    return None


def _build_math_chart_spec(
    *,
    cleaned_question: str,
    knowledge_points: List[str],
    solution_steps: List[str],
) -> RichArtifact:
    scene = _math_scene_type(cleaned_question, knowledge_points)
    profile = _math_scene_profile(scene)
    expressions = _math_extract_expressions(cleaned_question)
    title = profile["title"]
    solution_path = _math_solution_path(profile, solution_steps)
    formula_transformations = _math_formula_transformations(
        scene,
        profile=profile,
        expressions=expressions,
        solution_steps=solution_steps,
        cleaned_question=cleaned_question,
    )
    coordinate_graph = _math_coordinate_graph_spec(
        scene,
        cleaned_question=cleaned_question,
        knowledge_points=knowledge_points,
        solution_steps=solution_steps,
    )

    content = {
        "renderer": "generic_chart_spec",
        "version": 3,
        "scene": scene,
        "topic_type": scene,
        "title": title,
        "question_excerpt": _math_latexize_display_text(cleaned_question[:220]),
        "knowledge_points": knowledge_points[:4],
        "expressions": [_math_inline_formula(expression) for expression in expressions[:4]],
        "core_idea": profile["core_idea"],
        "formula_transformations": formula_transformations,
        "solution_path": solution_path,
        "mistake_traps": profile["mistake_traps"],
        "review_checklist": profile["review_checklist"],
        "visual_hint": profile["visual_hint"],
        # Compatibility for older mobile clients that only render these fields.
        "plot_suggestions": _math_legacy_display_sections(
            profile=profile,
            formula_transformations=formula_transformations,
            solution_path=solution_path,
        ),
        "student_tasks": profile["review_checklist"],
        "step_mapping": [
            f"{_math_latexize_display_text(str(item['action']))}：{_math_latexize_display_text(str(item['reason']))}"
            for item in solution_path[:4]
            if item.get("action") and item.get("reason")
        ],
    }
    if coordinate_graph:
        content["coordinate_graph"] = coordinate_graph
    return RichArtifact(
        artifact_type="chart_spec",
        title=title,
        description="把数学错题整理成可直接复盘的关键思路、变形路径和自查清单。",
        mime_type="application/json",
        content=json.dumps(content, ensure_ascii=False, indent=2),
    )


def _math_scene_type(cleaned_question: str, knowledge_points: List[str]) -> str:
    text = f"{cleaned_question} {' '.join(knowledge_points)}".lower()
    if any(keyword in text for keyword in ["解析几何", "抛物线", "椭圆", "双曲线", "焦点", "准线", "离心率", "圆锥曲线"]):
        return "conic"
    if any(keyword in text for keyword in ["导数", "求导", "切线", "积分", "定积分", "极限", "分部", "换元", "\\int"]):
        return "calculus"
    if any(keyword in text for keyword in ["函数", "二次函数", "一次函数", "指数", "对数", "三角函数", "图像", "零点", "最小值", "最大值"]):
        return "function"
    scene_keywords = [
        ("linear_algebra", ["线性代数", "矩阵", "行列式", "特征值", "特征向量", "秩", "向量空间", "线性变换"]),
        ("statistics", ["统计", "样本", "频率", "均值", "方差", "标准差", "直方图", "箱线图"]),
        ("probability", ["概率", "随机变量", "分布", "期望", "方差", "排列", "组合", "事件", "独立"]),
        ("sequence", ["数列", "递推", "通项", "等差", "等比", "前n项", "求和", "极限"]),
        ("vector", ["向量", "数量积", "点积", "叉积", "投影", "夹角", "坐标表示"]),
        ("conic", ["解析几何", "抛物线", "椭圆", "双曲线", "焦点", "准线", "离心率", "圆锥曲线"]),
        ("geometry", ["几何", "三角形", "圆", "四边形", "相似", "全等", "切线", "垂直", "平行", "角平分线"]),
        ("calculus", ["导数", "积分", "极限", "单调", "极值", "面积", "变化率"]),
        ("function", ["函数", "二次函数", "一次函数", "指数", "对数", "三角函数", "图像", "零点"]),
    ]
    for scene, keywords in scene_keywords:
        if any(keyword in text for keyword in keywords):
            return scene
    if re.search(r"(f\s*\(|y\s*=|x\^|x²|\\frac|\\sqrt|sin|cos|tan)", text):
        return "function"
    return "algebra"


def _math_scene_profile(scene: str) -> dict:
    profiles = {
        "function": {
            "title": "函数题复盘卡",
            "core_idea": "函数题的核心是把代数条件和图像特征互相翻译，先抓定义域、零点、单调性、极值和对称性，再回到题目目标。",
            "formula_focus": "把题目中的函数式、方程或不等式整理成能判断零点、交点、单调性或最值的形式。",
            "default_transformations": [
                "整理函数表达式，先确认定义域和参数限制。",
                "把方程或不等式转化为零点、交点、单调性或最值问题。",
                "结合端点、极值点和区间开闭检查结论是否完整。",
            ],
            "solution_path": [
                {"action": "先定范围", "reason": "定义域和区间端点会决定后续变形是否等价。"},
                {"action": "找关键点", "reason": "零点、极值点和交点通常就是分类讨论的分界。"},
                {"action": "用图像校验代数结论", "reason": "图像能快速发现漏掉的端点、重根或无解区间。"},
            ],
            "mistake_traps": ["忽略定义域或端点能否取到。", "把交点、零点、极值点混为一谈。", "参数讨论时漏掉临界值。"],
            "review_checklist": ["定义域是否先写清楚。", "每次平方、开方、约分是否保持等价。", "端点、重根和无解情形是否检查。"],
            "visual_hint": "若题目涉及零点、交点、最值或参数范围，可画一张简洁函数草图，只标定义域、关键点和区间变化。",
        },
        "geometry": {
            "title": "几何题复盘卡",
            "core_idea": "几何题要先把已知关系落到图上，再寻找不变量和辅助线，让相似、全等、圆、平行或面积关系自然出现。",
            "formula_focus": "把边角关系、比例关系、圆关系或面积关系整理成可直接使用的条件。",
            "default_transformations": [
                "标出已知边、角、平行、垂直、切线或中点关系。",
                "寻找能连接已知与目标的辅助线或关键圆。",
                "用相似、全等、圆周角或面积关系推进结论。",
            ],
            "solution_path": [
                {"action": "重画结构图", "reason": "把条件显性化，避免靠视觉猜结论。"},
                {"action": "锁定目标关系", "reason": "知道要证明边、角、比例还是面积，才能选择辅助线。"},
                {"action": "寻找不变量", "reason": "相似、圆周角、平行线比例和面积不变量常是突破口。"},
            ],
            "mistake_traps": ["默认图形按比例精确。", "把看起来垂直或相等当成已知。", "辅助线画了但没有服务目标结论。"],
            "review_checklist": ["每个图上标记是否都有题设或推理依据。", "辅助线是否连接了已知和目标。", "结论是否回到题目要求而不是停在中间关系。"],
            "visual_hint": "建议画一张干净骨架图：已知条件实线标注，辅助线用虚线，目标关系用高亮标出。",
        },
        "conic": {
            "title": "圆锥曲线复盘卡",
            "core_idea": "圆锥曲线题要把方程参数和几何意义绑定起来，重点盯标准形式、焦点、离心率、准线、渐近线、弦和切线条件。",
            "formula_focus": "先化标准方程，再把 $a,b,c,e$、焦点、准线、渐近线或直线斜率对应起来。",
            "default_transformations": [
                "把方程化成标准形式，确认曲线类型和焦点方向。",
                "写出核心参数关系，例如椭圆 $a^2=b^2+c^2$ 或双曲线 $c^2=a^2+b^2$。",
                "把直线、弦、切线或动点条件转成代数方程。",
            ],
            "solution_path": [
                {"action": "先判曲线和方向", "reason": "焦点位置、参数关系和渐近线公式都依赖曲线类型。"},
                {"action": "列参数关系", "reason": "圆锥曲线计算常在 $a,b,c,e$ 之间转换。"},
                {"action": "把几何条件代数化", "reason": "弦长、中点、切线和面积最终都要落到方程上。"},
            ],
            "mistake_traps": ["椭圆和双曲线的 $a,b,c$ 关系混用。", "焦点在 x 轴还是 y 轴判断错误。", "联立直线后漏掉判别式或根与系数关系。"],
            "review_checklist": ["曲线类型、焦点方向和标准形式是否确认。", "$a,b,c,e$ 关系是否写对。", "直线联立后的判别式、韦达关系是否用完整。"],
            "visual_hint": "若涉及焦点、准线、弦或切线，可画坐标草图标出曲线方向、焦点和直线位置。",
        },
        "calculus": {
            "title": "导数积分复盘卡",
            "core_idea": "导数积分题要先识别结构：对称区间看奇偶性，三角式看恒等变形，乘积型积分优先考虑分部积分或换元。",
            "formula_focus": "重点整理奇偶性、三角恒等变形、换元、分部积分和上下限变化。",
            "default_transformations": [
                "先观察积分区间是否对称，判断被积函数的奇偶性。",
                "遇到三角函数先做恒等变形，例如半角、平方降幂或和差化积。",
                "乘积型或含 $e^x$、$x$ 的积分，优先考虑分部积分或换元。",
            ],
            "solution_path": [
                {"action": "先看区间和结构", "reason": "对称性、周期性和上下限往往能直接简化计算。"},
                {"action": "再做恒等变形", "reason": "三角式、根式或指数乘积通常需要先整理成可积形式。"},
                {"action": "选择积分工具", "reason": "换元处理复合结构，分部积分处理乘积结构。"},
                {"action": "代回上下限并检查符号", "reason": "定积分最容易在上下限和符号处出错。"},
            ],
            "mistake_traps": ["对称区间内没有先判断奇偶性。", "三角半角或平方降幂公式写错。", "分部积分忘记边界项或符号。", "换元后没有同步更改上下限。"],
            "review_checklist": ["是否先检查对称区间、奇偶性或周期性。", "三角恒等变形是否逐步写清。", "分部积分的 $u,dv$ 选择是否让问题变简单。", "上下限、边界项和符号是否最后复核。"],
            "visual_hint": "定积分题通常不需要复杂图像；若涉及面积或奇偶性，可只画区间对称关系和函数奇偶示意。",
        },
        "statistics": {
            "title": "统计题复盘卡",
            "core_idea": "统计题先整理数据口径，再区分频数、频率、均值、方差、标准差和异常值，最后回到题目要比较的量。",
            "formula_focus": "把样本、频数、频率、均值和方差公式分清楚，避免口径混乱。",
            "default_transformations": ["先列清数据表或频数表。", "按题目要求计算集中趋势或离散程度。", "对比结论要说明数据口径和比较对象。"],
            "solution_path": [
                {"action": "整理数据口径", "reason": "频数、频率和样本量不清会导致后面全错。"},
                {"action": "选择统计量", "reason": "均值看水平，方差/标准差看波动，不能混用。"},
                {"action": "解释结果", "reason": "统计题通常要求把数字翻译成实际结论。"},
            ],
            "mistake_traps": ["频数和频率混淆。", "样本方差和总体方差公式混用。", "只算数字但没有回答实际含义。"],
            "review_checklist": ["样本总数是否核对。", "频数、频率、均值、方差是否各自口径一致。", "最后结论是否回应题目问题。"],
            "visual_hint": "数据比较题可用简单表格、柱状图或箱线图辅助观察集中趋势和波动。",
        },
        "probability": {
            "title": "概率题复盘卡",
            "core_idea": "概率题先拆样本空间和事件关系，再判断互斥、独立、条件概率或补事件，最后选择加法、乘法或分类讨论。",
            "formula_focus": "把事件、条件、交并补关系和路径概率写清楚。",
            "default_transformations": ["列出样本空间或分阶段试验。", "判断事件关系：互斥、独立、条件或补事件。", "用加法公式、乘法公式或全概率思路计算。"],
            "solution_path": [
                {"action": "先拆事件", "reason": "事件边界不清会导致重复计数或漏算。"},
                {"action": "判断关系", "reason": "互斥、独立和条件概率对应不同公式。"},
                {"action": "按路径或区域计算", "reason": "树状图或韦恩图能防止重复和遗漏。"},
            ],
            "mistake_traps": ["把互斥事件当独立事件。", "条件概率没有更新样本空间。", "分类讨论有重叠或遗漏。"],
            "review_checklist": ["样本空间是否完整。", "事件是否有交叉或条件限制。", "每一类概率相加前是否互斥。"],
            "visual_hint": "分阶段试验建议画树状图；集合关系复杂时建议画韦恩图。",
        },
        "sequence": {
            "title": "数列题复盘卡",
            "core_idea": "数列题要从前几项、相邻项关系、递推结构和求和方式入手，判断是等差等比、差分、裂项还是构造新数列。",
            "formula_focus": "整理通项、递推式、差分、比值和前 n 项和之间的关系。",
            "default_transformations": ["先写出前几项观察规律。", "比较差分、比值或递推不变量。", "根据结构选择公式法、递推法、错位相减或裂项相消。"],
            "solution_path": [
                {"action": "列前几项", "reason": "规律和起始下标通常先从具体项暴露出来。"},
                {"action": "找相邻关系", "reason": "差分、比值和递推式决定方法。"},
                {"action": "选择求和策略", "reason": "等差等比、错位相减、裂项相消适用场景不同。"},
            ],
            "mistake_traps": ["把数列当连续函数处理。", "忽略 n 的起始值。", "求和时上下限错位。"],
            "review_checklist": ["前几项是否和通项一致。", "递推式的起始条件是否使用。", "求和上下限和项数是否核对。"],
            "visual_hint": "一般不需要连续图像；可用表格列出 n、a_n、S_n 或相邻项差分。",
        },
        "vector": {
            "title": "向量题复盘卡",
            "core_idea": "向量题要把坐标运算和几何意义对应起来，重点关注起点统一、线性组合、数量积、模长、夹角和投影。",
            "formula_focus": "整理向量坐标、数量积、模长、夹角或投影公式。",
            "default_transformations": ["统一向量起点或坐标表示。", "把几何条件转成数量积、模长或线性组合。", "用坐标运算验证方向、夹角和长度。"],
            "solution_path": [
                {"action": "统一表示", "reason": "不同起点的向量要先平移或坐标化。"},
                {"action": "转成运算", "reason": "垂直、夹角、投影和共线都有对应代数条件。"},
                {"action": "回到几何意义", "reason": "计算结果要解释为方向、长度或位置关系。"},
            ],
            "mistake_traps": ["向量平移后忘记方向不变。", "数量积为 0 的含义误解。", "夹角公式漏掉模长或符号。"],
            "review_checklist": ["向量起点或坐标是否统一。", "数量积、模长、夹角公式是否完整。", "最后结论是否解释几何关系。"],
            "visual_hint": "若涉及夹角、投影或合向量，可画箭头图标出方向、投影线和合成关系。",
        },
        "linear_algebra": {
            "title": "线性代数复盘卡",
            "core_idea": "线性代数题要明确矩阵运算对象和结构，关注乘法顺序、秩、行列式、可逆性、特征值和线性变换含义。",
            "formula_focus": "整理矩阵运算、特征值映射、行列式、秩或逆矩阵关系。",
            "default_transformations": ["先确认矩阵维度和运算顺序。", "根据题意选择秩、行列式、逆矩阵或特征值工具。", "把结果和可逆、线性无关或特征方向联系起来。"],
            "solution_path": [
                {"action": "检查维度和顺序", "reason": "矩阵乘法通常不能交换，维度错会导致整题失效。"},
                {"action": "锁定结构性质", "reason": "秩、行列式、可逆性和特征值各自服务不同问题。"},
                {"action": "使用对应定理", "reason": "例如 $A^k$ 的特征值来自特征值的 k 次方。"},
            ],
            "mistake_traps": ["矩阵乘法顺序写反。", "把特征值和特征向量的变化规律混淆。", "可逆、满秩、行列式非零没有对应检查。"],
            "review_checklist": ["矩阵维度和乘法顺序是否核对。", "使用的定理是否满足前提。", "特征值、行列式、秩的结论是否对应题目问法。"],
            "visual_hint": "如果题目涉及线性变换，可用矩阵作用前后关系或特征方向示意帮助理解；纯计算题可不画图。",
        },
        "algebra": {
            "title": "代数题复盘卡",
            "core_idea": "代数题的重点是保证每一步变形合法，先整理条件和目标，再处理定义域、符号、临界点和分类讨论。",
            "formula_focus": "把方程、不等式、参数范围或代数变形链整理清楚。",
            "default_transformations": ["先写清条件、目标和定义域。", "逐步做等价变形，并标记非等价操作。", "遇到参数、不等式或绝对值时分类讨论。"],
            "solution_path": [
                {"action": "先写限制", "reason": "定义域、分母不为零和根号条件会影响解集。"},
                {"action": "做等价变形", "reason": "变形是否等价决定有没有增根或漏解。"},
                {"action": "分类并回代", "reason": "参数题和不等式题必须检查每类条件。"},
            ],
            "mistake_traps": ["平方、开方、约分导致增根或漏解。", "不等式乘除负数忘记变号。", "分类讨论没有覆盖所有临界点。"],
            "review_checklist": ["定义域和限制条件是否先写。", "非等价变形后是否回代检验。", "分类讨论是否不重不漏。"],
            "visual_hint": "",
        },
    }
    return profiles.get(scene, profiles["algebra"])


def _math_formula_transformations(
    scene: str,
    *,
    profile: dict,
    expressions: List[str],
    solution_steps: List[str],
    cleaned_question: str,
) -> List[dict]:
    transformations: List[dict] = []
    if expressions:
        for index, expression in enumerate(expressions[:3], start=1):
            transformations.append(
                {
                    "label": f"关键式 {index}",
                    "detail": _math_inline_formula(expression),
                }
            )

    lowered = cleaned_question.lower()
    if scene == "calculus":
        if any(token in lowered for token in ["对称", "-\\frac", "-π", "-pi", "奇", "偶"]):
            transformations.append(
                {
                    "label": "对称区间",
                    "detail": "先判断被积函数奇偶性：奇函数在对称区间上积分为 0，偶函数可转化为两倍半区间积分。",
                }
            )
        if any(token in lowered for token in ["sin", "cos", "tan", "三角"]):
            transformations.append(
                {
                    "label": "三角恒等变形",
                    "detail": "优先检查半角、平方降幂、诱导公式和和差关系，把被积函数化成更容易积分的形式。",
                }
            )
        if any(token in lowered for token in ["分部", "e^", "e^x"]):
            transformations.append(
                {
                    "label": "分部积分",
                    "detail": "乘积型积分先选择能简化的 $u$ 和容易积分的 $dv$，别忘记边界项。",
                }
            )

    for step in solution_steps[:2]:
        if step and all(step != item["detail"] for item in transformations):
            transformations.append({"label": "解题步骤提示", "detail": step})

    if not transformations:
        transformations = [
            {"label": "关键整理", "detail": profile["formula_focus"]},
            *({"label": f"推荐变形 {i}", "detail": item} for i, item in enumerate(profile["default_transformations"][:2], start=1)),
        ]
    return transformations[:5]


def _math_coordinate_graph_spec(
    scene: str,
    *,
    cleaned_question: str,
    knowledge_points: List[str],
    solution_steps: List[str],
) -> Optional[dict]:
    text = f"{cleaned_question} {' '.join(knowledge_points)} {' '.join(solution_steps)}".lower()
    if scene == "function":
        graph = _math_function_coordinate_graph(text)
    elif scene == "calculus" and _math_is_derivative_graph_question(text):
        graph = _math_derivative_coordinate_graph()
    elif scene == "conic":
        graph = _math_conic_coordinate_graph(text)
    else:
        return None

    detected_points = _math_extract_coordinate_points(cleaned_question)
    if detected_points:
        labels = {str(point.get("label") or "") for point in graph.get("points", [])}
        for point in detected_points[:5]:
            if point["label"] not in labels:
                graph.setdefault("points", []).append(point)
    return graph


def _math_is_derivative_graph_question(text: str) -> bool:
    derivative_markers = [
        "导数",
        "单调",
        "极值",
        "最值",
        "切线",
        "斜率",
        "凹凸",
        "拐点",
        "f'",
        "y'",
        "\\prime",
    ]
    integral_markers = ["积分", "\\int", "定积分", "原函数"]
    return any(marker in text for marker in derivative_markers) and not (
        any(marker in text for marker in integral_markers)
        and not any(marker in text for marker in ["导数", "切线", "单调", "极值"])
    )


def _math_function_coordinate_graph(text: str) -> dict:
    is_quadratic = any(marker in text for marker in ["二次", "抛物线", "x^2", "x²"])
    if is_quadratic:
        curves = [
            {
                "label": "函数图像 y=f(x)",
                "points": _math_plot_points(lambda x: 0.3 * (x - 1) * (x - 1) - 1.2, [-3, -2, -1, 0, 1, 2, 3, 4, 5]),
            }
        ]
        points = [
            {"label": "顶点 V(1,-1.2)", "x": 1, "y": -1.2},
            {"label": "零点附近 A(-1,0)", "x": -1, "y": 0},
            {"label": "零点附近 B(3,0)", "x": 3, "y": 0},
        ]
        lines = [
            {"label": "对称轴 x=1", "from": [1, -2.5], "to": [1, 3.2], "style": "dashed"},
            {"label": "x 轴", "from": [-3.5, 0], "to": [5.2, 0], "style": "axis"},
        ]
        focus = ["先看定义域、零点、顶点和单调区间，再回到题目条件判断交点或最值。"]
    else:
        curves = [
            {
                "label": "函数图像 y=f(x)",
                "points": _math_plot_points(lambda x: 0.18 * x * x * x - 0.9 * x + 0.2, [-3, -2.4, -1.8, -1.2, -0.6, 0, 0.6, 1.2, 1.8, 2.4, 3]),
            }
        ]
        points = [
            {"label": "零点/交点候选", "x": 0.22, "y": 0},
            {"label": "极值点候选", "x": -1.29, "y": 0.97},
            {"label": "极值点候选", "x": 1.29, "y": -0.57},
        ]
        lines = [
            {"label": "y=0 辅助线", "from": [-3.2, 0], "to": [3.2, 0], "style": "dashed"},
            {"label": "x=0 参考线", "from": [0, -2.2], "to": [0, 2.2], "style": "axis"},
        ]
        focus = ["把方程解、交点、端点和单调变化放到同一张图上核对，避免只靠代数变形漏情况。"]

    return {
        "title": "二维坐标辅助图",
        "is_schematic": True,
        "x_range": [-3.5, 5.5] if is_quadratic else [-3.4, 3.4],
        "y_range": [-2.5, 4.0] if is_quadratic else [-2.2, 2.2],
        "curves": curves,
        "lines": lines,
        "points": points,
        "student_focus": focus,
    }


def _math_derivative_coordinate_graph() -> dict:
    return {
        "title": "导数与切线辅助图",
        "is_schematic": True,
        "x_range": [-3.4, 3.4],
        "y_range": [-2.4, 2.4],
        "curves": [
            {
                "label": "原函数 y=f(x)",
                "points": _math_plot_points(lambda x: 0.18 * x * x * x - 0.9 * x + 0.2, [-3, -2.4, -1.8, -1.2, -0.6, 0, 0.6, 1.2, 1.8, 2.4, 3]),
            }
        ],
        "lines": [
            {"label": "切线示意", "from": [-1.2, 0.05], "to": [3.0, -1.38], "style": "solid"},
            {"label": "x=x0", "from": [1.0, -2.0], "to": [1.0, 2.0], "style": "dashed"},
        ],
        "points": [
            {"label": "切点 P(x0,f(x0))", "x": 1.0, "y": -0.52},
            {"label": "f'(x)=0", "x": -1.29, "y": 0.97},
            {"label": "f'(x)=0", "x": 1.29, "y": -0.57},
        ],
        "student_focus": [
            "导数题优先把切点、切线斜率、极值点和单调区间标在图上，检查代数结论是否符合图像趋势。"
        ],
    }


def _math_conic_coordinate_graph(text: str) -> dict:
    if any(marker in text for marker in ["抛物线", "准线"]):
        return {
            "title": "抛物线辅助图",
            "is_schematic": True,
            "x_range": [-2.0, 5.0],
            "y_range": [-4.0, 4.0],
            "curves": [
                {
                    "label": "抛物线 $y^2=4px$ 示意",
                    "points": [[x * x, 2 * x] for x in [-2, -1.5, -1, -0.5, 0, 0.5, 1, 1.5, 2]],
                }
            ],
            "lines": [
                {"label": "准线 x=-p", "from": [-1, -3.6], "to": [-1, 3.6], "style": "dashed"},
                {"label": "对称轴", "from": [-1.6, 0], "to": [4.5, 0], "style": "axis"},
            ],
            "points": [
                {"label": "焦点 F(p,0)", "x": 1, "y": 0},
                {"label": "顶点 O(0,0)", "x": 0, "y": 0},
            ],
            "student_focus": ["把焦点、准线、对称轴和动点位置画出来，再把距离关系翻译成方程。"],
        }
    if "双曲线" in text:
        return {
            "title": "双曲线辅助图",
            "is_schematic": True,
            "x_range": [-5.0, 5.0],
            "y_range": [-4.0, 4.0],
            "curves": [
                {"label": "右支", "points": _math_plot_points(lambda x: math.sqrt(max(0.0, x * x / 4 - 1)), [2, 2.4, 2.8, 3.2, 3.8, 4.5])},
                {"label": "右支", "points": _math_plot_points(lambda x: -math.sqrt(max(0.0, x * x / 4 - 1)), [2, 2.4, 2.8, 3.2, 3.8, 4.5])},
                {"label": "左支", "points": _math_plot_points(lambda x: math.sqrt(max(0.0, x * x / 4 - 1)), [-4.5, -3.8, -3.2, -2.8, -2.4, -2])},
                {"label": "左支", "points": _math_plot_points(lambda x: -math.sqrt(max(0.0, x * x / 4 - 1)), [-4.5, -3.8, -3.2, -2.8, -2.4, -2])},
            ],
            "lines": [
                {"label": "渐近线", "from": [-5, -2.5], "to": [5, 2.5], "style": "dashed"},
                {"label": "渐近线", "from": [-5, 2.5], "to": [5, -2.5], "style": "dashed"},
            ],
            "points": [
                {"label": "焦点 F1", "x": -2.8, "y": 0},
                {"label": "焦点 F2", "x": 2.8, "y": 0},
                {"label": "顶点", "x": -2, "y": 0},
                {"label": "顶点", "x": 2, "y": 0},
            ],
            "student_focus": ["先确认实轴方向、焦点和渐近线，再处理直线联立、弦长或切线条件。"],
        }
    return {
        "title": "椭圆辅助图",
        "is_schematic": True,
        "x_range": [-4.0, 4.0],
        "y_range": [-3.0, 3.0],
        "curves": [
            {
                "label": "椭圆示意",
                "points": [
                    [round(3 * math.cos(t), 2), round(2 * math.sin(t), 2)]
                    for t in [i * math.pi / 14 for i in range(29)]
                ],
            }
        ],
        "lines": [
            {"label": "长轴", "from": [-3.4, 0], "to": [3.4, 0], "style": "axis"},
            {"label": "短轴", "from": [0, -2.4], "to": [0, 2.4], "style": "axis"},
            {"label": "辅助直线/弦", "from": [-2.6, -1.2], "to": [2.5, 1.5], "style": "dashed"},
        ],
        "points": [
            {"label": "焦点 F1", "x": -2.24, "y": 0},
            {"label": "焦点 F2", "x": 2.24, "y": 0},
            {"label": "端点", "x": -3, "y": 0},
            {"label": "端点", "x": 3, "y": 0},
        ],
        "student_focus": ["把标准方程、焦点、长短轴和题目中的直线/动点放到同一坐标图中，检查 $a,b,c,e$ 的对应关系。"],
    }


def _math_plot_points(fn, xs: List[float]) -> List[List[float]]:
    return [[round(float(x), 2), round(float(fn(float(x))), 2)] for x in xs]


def _math_extract_coordinate_points(text: str) -> List[dict]:
    points: List[dict] = []
    pattern = re.compile(r"([A-ZＡ-Ｚ]?)\s*[（(]\s*(-?\d+(?:\.\d+)?)\s*[,，]\s*(-?\d+(?:\.\d+)?)\s*[）)]")
    for index, match in enumerate(pattern.finditer(text), start=1):
        label = match.group(1) or f"P{index}"
        points.append(
            {
                "label": f"{label}({match.group(2)},{match.group(3)})",
                "x": float(match.group(2)),
                "y": float(match.group(3)),
            }
        )
    return points


def _math_solution_path(profile: dict, solution_steps: List[str]) -> List[dict]:
    if solution_steps:
        profile_path = profile["solution_path"]
        path = [
            {
                "action": step,
                "reason": profile_path[index - 1]["reason"]
                if index - 1 < len(profile_path)
                else "这一步用于把题目条件继续转化为可计算、可验证的数学关系。",
            }
            for index, step in enumerate(solution_steps[:4], start=1)
            if step.strip()
        ]
        if path:
            return path
    return profile["solution_path"][:4]


def _math_legacy_display_sections(
    *,
    profile: dict,
    formula_transformations: List[dict],
    solution_path: List[dict],
) -> List[dict]:
    sections = [
        {
            "label": "核心思路",
            "value": profile["core_idea"],
        }
    ]
    if formula_transformations:
        sections.append(
            {
                "label": "关键变形",
                "value": "；".join(
                    f"{item['label']}：{_math_latexize_display_text(str(item['detail']))}"
                    for item in formula_transformations[:5]
                    if item.get("label")
                    and item.get("detail")
                    and not _math_is_formula_only(str(item["detail"]))
                ),
            }
        )
    if solution_path:
        sections.append(
            {
                "label": "解题路线",
                "value": "；".join(
                    f"{_math_latexize_display_text(str(item['action']))}：{_math_latexize_display_text(str(item['reason']))}"
                    for item in solution_path[:3]
                    if item.get("action") and item.get("reason")
                ),
            }
        )
    if profile["mistake_traps"]:
        sections.append(
            {
                "label": "易错提醒",
                "value": "；".join(profile["mistake_traps"][:3]),
            }
        )
    return [section for section in sections if section.get("value")]


def _math_inline_formula(expression: str) -> str:
    cleaned = _math_clean_latex_fragment(expression)
    if not cleaned:
        return ""
    return f"${cleaned}$"


def _math_clean_latex_fragment(value: str) -> str:
    cleaned = value.strip().strip("；;，,。")
    cleaned = cleaned.strip("$").strip()
    return cleaned.strip().strip("；;，,。")


def _math_latexize_display_text(value: str) -> str:
    text = value.strip()
    if not text:
        return ""
    text = text.replace(r"\(", "$").replace(r"\)", "$")
    text = text.replace(r"\[", "$").replace(r"\]", "$")
    text = re.sub(
        r"\$\$\s*([^$]+?)\s*\$\$",
        lambda match: _math_inline_formula(match.group(1)),
        text,
    )
    text = re.sub(
        r"\$\s*([^$]+?)\s*\${2,}",
        lambda match: _math_inline_formula(match.group(1)),
        text,
    )
    parts = text.split("$")
    for index in range(0, len(parts), 2):
        parts[index] = re.sub(
            r"((?:\\int|\\frac|\\sqrt|\\sum|\\lim|\\sin|\\cos|\\tan)[^；;。]*?)(?=；|;|。|，|,|$)",
            lambda match: _math_inline_formula(match.group(1)),
            parts[index],
        )
    return "$".join(parts)


def _math_is_formula_only(value: str) -> bool:
    cleaned = value.strip()
    return cleaned.startswith("$") and cleaned.endswith("$") and cleaned.count("$") == 2


def _math_extract_expressions(text: str) -> List[str]:
    candidates: List[str] = []
    patterns = [
        r"\$\$([^$]{2,120})\$\$",
        r"\$([^$]{2,120})\$",
        r"((?:f|g|h)\s*\([^)]*\)\s*=\s*[^，。；;\n]{1,100})",
        r"(y\s*=\s*[^，。；;\n]{1,100})",
        r"([a-zA-Z]\s*=\s*[^，。；;\n]{1,80})",
        r"([0-9a-zA-Z\\^_+\-*/=(){}\[\].\s]{2,100}=\s*[0-9a-zA-Z\\^_+\-*/(){}\[\].\s]{1,80})",
        r"([0-9a-zA-Z\\^_+\-*/=(){}\[\].\s]+(?:\\frac|\\sqrt|sin|cos|tan)[^，。；;\n]{0,80})",
    ]
    for pattern in patterns:
        for match in re.finditer(pattern, text, re.IGNORECASE):
            value = match.group(1).strip()
            if 2 <= len(value) <= 140 and value not in candidates:
                candidates.append(value)
    return candidates


def _build_physics_html(
    *,
    cleaned_question: str,
    knowledge_points: List[str],
    solution_steps: List[str],
) -> RichArtifact:
    scene_type = _physics_scene_type(cleaned_question)

    if scene_type == "circuit":
        html_title = "电路过程演示"
        body = _physics_circuit_html(cleaned_question, knowledge_points)
    elif scene_type == "optics":
        html_title = "光路变化演示"
        body = _physics_optics_html(cleaned_question, knowledge_points)
    elif scene_type == "board_block":
        html_title = "木板-物块运动演示"
        body = _physics_board_block_html(cleaned_question, knowledge_points)
    elif scene_type == "incline":
        html_title = "斜面运动演示"
        body = _physics_incline_html(cleaned_question, knowledge_points)
    elif scene_type == "projectile":
        html_title = "平抛与斜抛演示"
        body = _physics_projectile_html(cleaned_question, knowledge_points)
    elif scene_type == "collision":
        html_title = "碰撞过程演示"
        body = _physics_collision_html(cleaned_question, knowledge_points)
    else:
        html_title = "受力与运动演示"
        body = _physics_mechanics_html(cleaned_question, knowledge_points, solution_steps)

    return RichArtifact(
        artifact_type="interactive_html",
        title=html_title,
        description="可直接接入 WebView 的物理过程演示页面骨架。",
        mime_type="text/html",
        content=body,
    )


def _physics_board_block_html(cleaned_question: str, knowledge_points: List[str]) -> str:
    board_length = _extract_number(cleaned_question, [r"l\s*=\s*([0-9]+(?:\.[0-9]+)?)", r"长为\s*([0-9]+(?:\.[0-9]+)?)"], "1.0")
    board_mass = _extract_number(cleaned_question, [r"M\s*=\s*([0-9]+(?:\.[0-9]+)?)", r"质量为\s*([0-9]+(?:\.[0-9]+)?)"], "1.0")
    block_mass = _extract_number(cleaned_question, [r"m\s*=\s*([0-9]+(?:\.[0-9]+)?)"], "0.5")
    friction = _extract_number(cleaned_question, [r"μ\s*=\s*([0-9]+(?:\.[0-9]+)?)", r"mu\s*=\s*([0-9]+(?:\.[0-9]+)?)"], "0.20")
    tags = " / ".join(html.escape(item) for item in knowledge_points[:3]) or "相对运动 / 摩擦力 / 连接体"

    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>木板-物块运动演示</title>
  <style>
    :root {{
      color-scheme: dark;
    }}
    * {{
      box-sizing: border-box;
    }}
    body {{
      margin: 0;
      font-family: "Noto Sans SC", "Microsoft YaHei", sans-serif;
      background: radial-gradient(circle at top, #24342f, #101716 68%);
      color: #eef3ea;
      padding: 14px;
    }}
    .shell {{
      display: grid;
      gap: 12px;
    }}
    .card {{
      border-radius: 20px;
      padding: 14px;
      background: rgba(255,255,255,0.08);
      border: 1px solid rgba(255,255,255,0.10);
      backdrop-filter: blur(10px);
    }}
    .title {{
      font-size: 18px;
      font-weight: 700;
      margin-bottom: 6px;
    }}
    .subtitle {{
      color: #d4ded5;
      font-size: 12px;
      line-height: 1.5;
    }}
    .chips {{
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-top: 10px;
    }}
    .chip {{
      border-radius: 999px;
      padding: 6px 10px;
      background: rgba(255,214,160,0.10);
      font-size: 12px;
      color: #f8f3ea;
    }}
    .stage {{
      position: relative;
      height: 280px;
      overflow: hidden;
      border-radius: 20px;
      background:
        linear-gradient(180deg, rgba(255,255,255,0.05), rgba(255,255,255,0.01)),
        radial-gradient(circle at 30% 20%, rgba(255,214,160,0.08), transparent 36%);
    }}
    .ground {{
      position: absolute;
      left: 0;
      right: 0;
      bottom: 48px;
      height: 6px;
      background: rgba(255,214,160,0.62);
    }}
    .board {{
      position: absolute;
      left: 52px;
      bottom: 54px;
      width: 250px;
      height: 26px;
      border-radius: 16px;
      background: linear-gradient(135deg, #9f8157, #d8bb8c);
      box-shadow: 0 12px 30px rgba(0,0,0,0.24);
      transform: translateX(var(--board-x, 0px));
    }}
    .block {{
      position: absolute;
      left: 106px;
      bottom: 80px;
      width: 70px;
      height: 48px;
      border-radius: 16px;
      background: linear-gradient(135deg, #b8d18d, #7ea170);
      box-shadow: 0 12px 24px rgba(0,0,0,0.24);
      transform: translateX(var(--block-x, 0px));
    }}
    .arrow {{
      position: absolute;
      height: 3px;
      background: #ffb17d;
      transform-origin: left center;
      opacity: 0.95;
    }}
    .arrow::after {{
      content: "";
      position: absolute;
      right: -8px;
      top: -4px;
      border-left: 10px solid #ffb17d;
      border-top: 5px solid transparent;
      border-bottom: 5px solid transparent;
    }}
    .arrow.reverse {{
      transform: rotate(180deg);
    }}
    .force-board {{
      left: 212px;
      bottom: 128px;
      width: 92px;
    }}
    .friction-block {{
      left: 96px;
      bottom: 146px;
      width: 54px;
    }}
    .friction-board {{
      left: 194px;
      bottom: 102px;
      width: 54px;
    }}
    .label {{
      position: absolute;
      font-size: 12px;
      color: #f8f3ea;
    }}
    .label-board {{
      left: 134px;
      bottom: 38px;
    }}
    .label-block {{
      left: 122px;
      bottom: 134px;
    }}
    .label-f {{
      left: 308px;
      bottom: 122px;
    }}
    .label-fb {{
      left: 82px;
      bottom: 140px;
    }}
    .label-fw {{
      left: 250px;
      bottom: 96px;
    }}
    .legend {{
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 8px;
      margin-top: 10px;
    }}
    .legend-item {{
      border-radius: 14px;
      background: rgba(255,255,255,0.04);
      padding: 10px;
      font-size: 12px;
      color: #d9e1d4;
    }}
    .legend strong {{
      display: block;
      color: #fff4de;
      margin-bottom: 4px;
    }}
    .controls {{
      display: grid;
      gap: 10px;
    }}
    .buttons {{
      display: flex;
      gap: 10px;
    }}
    button {{
      flex: 1;
      border: 0;
      border-radius: 14px;
      padding: 12px 14px;
      font-size: 14px;
      font-weight: 700;
      cursor: pointer;
    }}
    .primary {{
      background: #ffd6a0;
      color: #171712;
    }}
    .secondary {{
      background: rgba(255,255,255,0.08);
      color: #eef3ea;
      border: 1px solid rgba(255,255,255,0.10);
    }}
    .slider-row {{
      display: grid;
      gap: 6px;
    }}
    .slider-label {{
      display: flex;
      justify-content: space-between;
      font-size: 12px;
      color: #d9e1d4;
    }}
    input[type="range"] {{
      width: 100%;
      accent-color: #ffd6a0;
    }}
    .stats {{
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 8px;
    }}
    .stat {{
      border-radius: 14px;
      background: rgba(255,255,255,0.04);
      padding: 10px;
    }}
    .stat-key {{
      font-size: 11px;
      color: #c9d2c8;
      margin-bottom: 4px;
    }}
    .stat-value {{
      font-size: 18px;
      font-weight: 700;
      color: #fff4de;
    }}
  </style>
</head>
<body data-scene="board_block">
  <div class="shell">
    <section class="card">
      <div class="title">木板-物块相对运动</div>
      <div class="subtitle">围绕板块运动场景展示木板与物块的相对位移、受力方向和速度变化，不重复整段题干。</div>
      <div class="chips">
        <span class="chip">木板长度 {html.escape(board_length)} m</span>
        <span class="chip">木板质量 {html.escape(board_mass)} kg</span>
        <span class="chip">物块质量 {html.escape(block_mass)} kg</span>
        <span class="chip">摩擦系数 {html.escape(friction)}</span>
      </div>
      <div class="chips">
        <span class="chip">{html.escape(tags)}</span>
      </div>
    </section>

    <section class="card stage" id="stage">
      <div class="ground"></div>
      <div class="board" id="board"></div>
      <div class="block" id="block"></div>
      <div class="arrow force-board" id="forceArrow"></div>
      <div class="arrow friction-block reverse" id="frictionOnBlock"></div>
      <div class="arrow friction-board" id="frictionOnBoard"></div>
      <div class="label label-board">木板 M</div>
      <div class="label label-block">物块 m</div>
      <div class="label label-f">外力</div>
      <div class="label label-fb">f</div>
      <div class="label label-fw">f</div>
    </section>

    <section class="card">
      <div class="stats">
        <div class="stat">
          <div class="stat-key">木板速度</div>
          <div class="stat-value" id="boardSpeed">0.0</div>
        </div>
        <div class="stat">
          <div class="stat-key">物块速度</div>
          <div class="stat-value" id="blockSpeed">0.0</div>
        </div>
        <div class="stat">
          <div class="stat-key">相对位移</div>
          <div class="stat-value" id="relativeOffset">0.00</div>
        </div>
      </div>
      <div class="legend">
        <div class="legend-item"><strong>当前状态</strong><span id="stateText">静止，点击开始观察相对运动。</span></div>
        <div class="legend-item"><strong>观察重点</strong>物块是否相对木板滑动，摩擦力方向如何随相对趋势确定。</div>
      </div>
    </section>

    <section class="card controls">
      <div class="buttons">
        <button class="primary" id="toggleBtn">开始演示</button>
        <button class="secondary" id="resetBtn">重置</button>
      </div>
      <label class="slider-row">
        <div class="slider-label"><span>外力强度</span><span id="forceValue">1.2 N</span></div>
        <input id="forceSlider" type="range" min="0.6" max="6.0" step="0.1" value="1.2" />
      </label>
      <label class="slider-row">
        <div class="slider-label"><span>摩擦系数</span><span id="muValue">{html.escape(friction)}</span></div>
        <input id="muSlider" type="range" min="0.05" max="0.8" step="0.01" value="{html.escape(friction)}" />
      </label>
      <label class="slider-row">
        <div class="slider-label"><span>视角模式</span><span id="modeValue">地面参考系</span></div>
        <input id="modeSlider" type="range" min="0" max="1" step="1" value="0" />
      </label>
    </section>
  </div>

  <script>
    const stage = document.getElementById('stage');
    const board = document.getElementById('board');
    const block = document.getElementById('block');
    const boardSpeedEl = document.getElementById('boardSpeed');
    const blockSpeedEl = document.getElementById('blockSpeed');
    const relativeOffsetEl = document.getElementById('relativeOffset');
    const stateTextEl = document.getElementById('stateText');
    const toggleBtn = document.getElementById('toggleBtn');
    const resetBtn = document.getElementById('resetBtn');
    const forceSlider = document.getElementById('forceSlider');
    const muSlider = document.getElementById('muSlider');
    const modeSlider = document.getElementById('modeSlider');
    const forceValue = document.getElementById('forceValue');
    const muValue = document.getElementById('muValue');
    const modeValue = document.getElementById('modeValue');
    const frictionOnBlock = document.getElementById('frictionOnBlock');
    const frictionOnBoard = document.getElementById('frictionOnBoard');

    const boardMass = {float(board_mass)};
    const blockMass = {float(block_mass)};
    let running = false;
    let rafId = null;
    let lastTime = 0;
    let t = 0;
    let boardX = 0;
    let relativeX = 0;
    let boardSpeed = 0;
    let blockSpeed = 0;

    function clamp(value, min, max) {{
      return Math.max(min, Math.min(max, value));
    }}

    function format(num, digits = 2) {{
      return Number(num).toFixed(digits);
    }}

    function syncLabels() {{
      forceValue.textContent = `${{format(forceSlider.value, 1)}} N`;
      muValue.textContent = format(muSlider.value, 2);
      modeValue.textContent = Number(modeSlider.value) === 0 ? '地面参考系' : '木板参考系';
    }}

    function computeState(dt) {{
      const force = Number(forceSlider.value);
      const mu = Number(muSlider.value);
      const g = 10;
      const maxStatic = mu * blockMass * g;
      const sharedAcc = force / (boardMass + blockMass);
      const needFriction = blockMass * sharedAcc;
      const slipping = needFriction > maxStatic;

      if (slipping) {{
        const boardAcc = Math.max((force - mu * blockMass * g) / boardMass, 0.15);
        const blockAcc = mu * g * 0.45;
        boardSpeed += boardAcc * dt;
        blockSpeed += blockAcc * dt;
        boardX += boardAcc * dt * 46;
        relativeX -= Math.max(boardSpeed - blockSpeed, 0) * dt * 34;
        stateTextEl.textContent = '发生相对滑动：木板向前更快，物块相对木板向后滑。';
      }} else {{
        boardSpeed += sharedAcc * dt;
        blockSpeed = boardSpeed;
        boardX += sharedAcc * dt * 42;
        relativeX *= 0.88;
        stateTextEl.textContent = '保持相对静止：物块与木板共同加速。';
      }}

      boardX = clamp(boardX, 0, 150);
      relativeX = clamp(relativeX, -90, 20);

      const boardDisplayX = Number(modeSlider.value) === 0 ? boardX : 0;
      const blockDisplayX = Number(modeSlider.value) === 0 ? boardX + relativeX : relativeX;

      board.style.setProperty('--board-x', `${{boardDisplayX}}px`);
      block.style.setProperty('--block-x', `${{blockDisplayX}}px`);

      const frictionReversed = relativeX < -8;
      frictionOnBlock.classList.toggle('reverse', frictionReversed);
      frictionOnBoard.classList.toggle('reverse', !frictionReversed);

      boardSpeedEl.textContent = format(boardSpeed, 1);
      blockSpeedEl.textContent = format(blockSpeed, 1);
      relativeOffsetEl.textContent = format(Math.abs(relativeX) / 42, 2);
    }}

    function step(timestamp) {{
      if (!running) return;
      if (!lastTime) lastTime = timestamp;
      const dt = Math.min((timestamp - lastTime) / 1000, 0.032);
      lastTime = timestamp;
      t += dt;
      computeState(dt);
      rafId = requestAnimationFrame(step);
    }}

    function start() {{
      if (running) return;
      running = true;
      toggleBtn.textContent = '暂停演示';
      rafId = requestAnimationFrame(step);
    }}

    function stop() {{
      running = false;
      toggleBtn.textContent = '开始演示';
      if (rafId) cancelAnimationFrame(rafId);
      rafId = null;
      lastTime = 0;
    }}

    function reset() {{
      stop();
      t = 0;
      boardX = 0;
      relativeX = 0;
      boardSpeed = 0;
      blockSpeed = 0;
      stateTextEl.textContent = '静止，点击开始观察相对运动。';
      board.style.setProperty('--board-x', '0px');
      block.style.setProperty('--block-x', '0px');
      boardSpeedEl.textContent = '0.0';
      blockSpeedEl.textContent = '0.0';
      relativeOffsetEl.textContent = '0.00';
      frictionOnBlock.classList.add('reverse');
      frictionOnBoard.classList.remove('reverse');
      syncLabels();
    }}

    toggleBtn.addEventListener('click', () => {{
      if (running) {{
        stop();
      }} else {{
        start();
      }}
    }});

    resetBtn.addEventListener('click', reset);
    forceSlider.addEventListener('input', syncLabels);
    muSlider.addEventListener('input', syncLabels);
    modeSlider.addEventListener('input', () => {{
      syncLabels();
      computeState(0);
    }});

    syncLabels();
    reset();
  </script>
</body>
</html>"""


def _physics_incline_html(cleaned_question: str, knowledge_points: List[str]) -> str:
    angle = _extract_number(
        cleaned_question,
        [r"([0-9]+(?:\.[0-9]+)?)\s*[°º]", r"θ\s*=\s*([0-9]+(?:\.[0-9]+)?)", r"倾角\s*为?\s*([0-9]+(?:\.[0-9]+)?)"],
        "30",
    )
    friction = _extract_number(
        cleaned_question,
        [r"μ\s*=\s*([0-9]+(?:\.[0-9]+)?)", r"mu\s*=\s*([0-9]+(?:\.[0-9]+)?)"],
        "0.20",
    )
    mass = _extract_number(
        cleaned_question,
        [r"m\s*=\s*([0-9]+(?:\.[0-9]+)?)", r"质量为\s*([0-9]+(?:\.[0-9]+)?)"],
        "1.0",
    )
    tags = " / ".join(html.escape(item) for item in knowledge_points[:3]) or "斜面受力 / 临界条件 / 加速度"

    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>斜面运动演示</title>
  <style>
    :root {{
      color-scheme: dark;
    }}
    * {{
      box-sizing: border-box;
    }}
    body {{
      margin: 0;
      font-family: "Noto Sans SC", "Microsoft YaHei", sans-serif;
      background: radial-gradient(circle at top, #22343b, #0f171b 70%);
      color: #eef4ef;
      padding: 14px;
    }}
    .shell {{
      display: grid;
      gap: 12px;
    }}
    .card {{
      border-radius: 20px;
      padding: 14px;
      background: rgba(255,255,255,0.08);
      border: 1px solid rgba(255,255,255,0.10);
    }}
    .title {{
      font-size: 18px;
      font-weight: 700;
      margin-bottom: 6px;
    }}
    .subtitle {{
      font-size: 12px;
      color: #d7e1dc;
      line-height: 1.5;
    }}
    .chips {{
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-top: 10px;
    }}
    .chip {{
      border-radius: 999px;
      padding: 6px 10px;
      background: rgba(255,214,160,0.10);
      font-size: 12px;
      color: #fff2de;
    }}
    .stage {{
      position: relative;
      height: 300px;
      overflow: hidden;
      border-radius: 22px;
      background:
        linear-gradient(180deg, rgba(255,255,255,0.04), rgba(255,255,255,0.01)),
        radial-gradient(circle at 70% 10%, rgba(255,214,160,0.08), transparent 34%);
    }}
    .ground {{
      position: absolute;
      left: -10px;
      right: -10px;
      bottom: 30px;
      height: 8px;
      background: rgba(255,255,255,0.08);
    }}
    .ramp {{
      position: absolute;
      left: 52px;
      bottom: 36px;
      width: 240px;
      height: 14px;
      border-radius: 12px;
      background: linear-gradient(135deg, #9c825c, #ddc197);
      transform-origin: left center;
      transform: rotate(calc(var(--angle) * -1deg));
      box-shadow: 0 18px 24px rgba(0,0,0,0.22);
    }}
    .block {{
      position: absolute;
      left: 112px;
      bottom: 146px;
      width: 56px;
      height: 42px;
      border-radius: 14px;
      background: linear-gradient(135deg, #b8d18d, #7ea170);
      box-shadow: 0 12px 24px rgba(0,0,0,0.24);
      transform: translate(var(--dx), var(--dy)) rotate(calc(var(--angle) * -1deg));
    }}
    .arrow {{
      position: absolute;
      height: 3px;
      background: #ffb17d;
      transform-origin: left center;
      border-radius: 4px;
    }}
    .arrow::after {{
      content: "";
      position: absolute;
      right: -8px;
      top: -4px;
      border-left: 10px solid #ffb17d;
      border-top: 5px solid transparent;
      border-bottom: 5px solid transparent;
    }}
    .gravity {{
      left: 142px;
      bottom: 140px;
      width: 78px;
      transform: rotate(90deg);
    }}
    .normal {{
      left: 145px;
      bottom: 168px;
      width: 58px;
    }}
    .friction {{
      left: 132px;
      bottom: 132px;
      width: 54px;
    }}
    .label {{
      position: absolute;
      font-size: 12px;
      color: #f6f2e8;
    }}
    .lg {{ left: 176px; bottom: 200px; }}
    .ln {{ left: 92px; bottom: 175px; }}
    .lf {{ left: 86px; bottom: 112px; }}
    .controls {{
      display: grid;
      gap: 10px;
    }}
    .buttons {{
      display: flex;
      gap: 10px;
    }}
    button {{
      flex: 1;
      border: 0;
      border-radius: 14px;
      padding: 12px 14px;
      font-size: 14px;
      font-weight: 700;
      cursor: pointer;
    }}
    .primary {{
      background: #ffd6a0;
      color: #171712;
    }}
    .secondary {{
      background: rgba(255,255,255,0.08);
      color: #eef3ea;
      border: 1px solid rgba(255,255,255,0.10);
    }}
    .slider-row {{
      display: grid;
      gap: 6px;
    }}
    .slider-label {{
      display: flex;
      justify-content: space-between;
      font-size: 12px;
      color: #d9e1d4;
    }}
    input[type="range"] {{
      width: 100%;
      accent-color: #ffd6a0;
    }}
    .stats {{
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 8px;
    }}
    .stat {{
      border-radius: 14px;
      background: rgba(255,255,255,0.04);
      padding: 10px;
    }}
    .stat-key {{
      font-size: 11px;
      color: #c9d2c8;
      margin-bottom: 4px;
    }}
    .stat-value {{
      font-size: 18px;
      font-weight: 700;
      color: #fff4de;
    }}
  </style>
</head>
<body data-scene="incline">
  <div class="shell">
    <section class="card">
      <div class="title">斜面受力与下滑</div>
      <div class="subtitle">聚焦斜面上的受力分解、是否下滑，以及沿斜面方向的运动变化，不重复整段题干。</div>
      <div class="chips">
        <span class="chip">倾角 {html.escape(angle)}°</span>
        <span class="chip">质量 {html.escape(mass)} kg</span>
        <span class="chip">摩擦系数 {html.escape(friction)}</span>
        <span class="chip">{html.escape(tags)}</span>
      </div>
    </section>

    <section class="card stage">
      <div class="ground"></div>
      <div class="ramp"></div>
      <div class="block" id="block"></div>
      <div class="arrow gravity"></div>
      <div class="arrow normal" id="normalArrow"></div>
      <div class="arrow friction" id="frictionArrow"></div>
      <div class="label lg">mg</div>
      <div class="label ln">N</div>
      <div class="label lf">f</div>
    </section>

    <section class="card">
      <div class="stats">
        <div class="stat">
          <div class="stat-key">沿斜面加速度</div>
          <div class="stat-value" id="accValue">0.0</div>
        </div>
        <div class="stat">
          <div class="stat-key">沿斜面速度</div>
          <div class="stat-value" id="speedValue">0.0</div>
        </div>
        <div class="stat">
          <div class="stat-key">运动状态</div>
          <div class="stat-value" id="stateShort">静止</div>
        </div>
      </div>
    </section>

    <section class="card controls">
      <div class="buttons">
        <button class="primary" id="toggleBtn">开始演示</button>
        <button class="secondary" id="resetBtn">重置</button>
      </div>
      <label class="slider-row">
        <div class="slider-label"><span>斜面角度</span><span id="angleValue">{html.escape(angle)}°</span></div>
        <input id="angleSlider" type="range" min="10" max="60" step="1" value="{html.escape(angle)}" />
      </label>
      <label class="slider-row">
        <div class="slider-label"><span>摩擦系数</span><span id="muValue">{html.escape(friction)}</span></div>
        <input id="muSlider" type="range" min="0.00" max="0.80" step="0.01" value="{html.escape(friction)}" />
      </label>
    </section>
  </div>

  <script>
    const root = document.documentElement;
    const block = document.getElementById('block');
    const frictionArrow = document.getElementById('frictionArrow');
    const normalArrow = document.getElementById('normalArrow');
    const accValue = document.getElementById('accValue');
    const speedValue = document.getElementById('speedValue');
    const stateShort = document.getElementById('stateShort');
    const toggleBtn = document.getElementById('toggleBtn');
    const resetBtn = document.getElementById('resetBtn');
    const angleSlider = document.getElementById('angleSlider');
    const muSlider = document.getElementById('muSlider');
    const angleValue = document.getElementById('angleValue');
    const muValue = document.getElementById('muValue');

    let running = false;
    let rafId = null;
    let lastTime = 0;
    let progress = 0;
    let speed = 0;

    function fmt(num, digits = 2) {{
      return Number(num).toFixed(digits);
    }}

    function syncScene() {{
      const angleDeg = Number(angleSlider.value);
      root.style.setProperty('--angle', angleDeg);
      root.style.setProperty('--dx', '0px');
      root.style.setProperty('--dy', '0px');
      angleValue.textContent = `${{angleDeg}}°`;
      muValue.textContent = fmt(muSlider.value, 2);
      normalArrow.style.transform = `rotate(${{-angleDeg - 90}}deg)`;
      frictionArrow.style.transform = `rotate(${{-angleDeg + 180}}deg)`;
    }}

    function compute(dt) {{
      const g = 10;
      const angle = Number(angleSlider.value) * Math.PI / 180;
      const mu = Number(muSlider.value);
      const along = g * Math.sin(angle);
      const friction = mu * g * Math.cos(angle);
      const acc = Math.max(along - friction, 0);

      if (acc > 0.01) {{
        speed += acc * dt;
        progress = Math.min(progress + speed * dt * 24, 160);
        stateShort.textContent = '下滑';
      }} else {{
        speed = 0;
        progress *= 0.92;
        stateShort.textContent = '临界/静止';
      }}

      const dx = progress;
      const dy = Math.tan(angle) * progress * 0.46;
      block.style.transform = `translate(${{dx}}px, ${{dy}}px) rotate(${{-Number(angleSlider.value)}}deg)`;
      accValue.textContent = fmt(acc, 1);
      speedValue.textContent = fmt(speed, 1);
    }}

    function step(timestamp) {{
      if (!running) return;
      if (!lastTime) lastTime = timestamp;
      const dt = Math.min((timestamp - lastTime) / 1000, 0.032);
      lastTime = timestamp;
      compute(dt);
      rafId = requestAnimationFrame(step);
    }}

    function start() {{
      if (running) return;
      running = true;
      toggleBtn.textContent = '暂停演示';
      rafId = requestAnimationFrame(step);
    }}

    function stop() {{
      running = false;
      toggleBtn.textContent = '开始演示';
      if (rafId) cancelAnimationFrame(rafId);
      rafId = null;
      lastTime = 0;
    }}

    function reset() {{
      stop();
      progress = 0;
      speed = 0;
      block.style.transform = `translate(0px, 0px) rotate(${{-Number(angleSlider.value)}}deg)`;
      compute(0);
    }}

    toggleBtn.addEventListener('click', () => {{
      if (running) stop();
      else start();
    }});
    resetBtn.addEventListener('click', reset);
    angleSlider.addEventListener('input', () => {{
      syncScene();
      reset();
    }});
    muSlider.addEventListener('input', () => {{
      syncScene();
      reset();
    }});

    syncScene();
    reset();
  </script>
</body>
</html>"""


def _physics_mechanics_html(
    cleaned_question: str,
    knowledge_points: List[str],
    solution_steps: List[str],
) -> str:
    title = html.escape(cleaned_question[:80] or "物理过程演示")
    tags = " / ".join(html.escape(item) for item in knowledge_points[:3]) or "受力分析 / 运动过程"
    bullets = "".join(
        f"<li>{html.escape(step)}</li>"
        for step in (solution_steps[:3] or ["先识别研究对象，再画受力图。", "结合牛顿定律或功能关系分析变化。"])
    )
    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>物理过程演示</title>
  <style>
    body {{
      margin: 0;
      font-family: "Noto Sans SC", "Microsoft YaHei", sans-serif;
      background: linear-gradient(160deg, #101819, #1b2f2c 55%, #33544d);
      color: #eef3ea;
      padding: 18px;
    }}
    .panel {{
      background: rgba(255, 255, 255, 0.08);
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 20px;
      padding: 16px;
      backdrop-filter: blur(10px);
    }}
    .stage {{
      position: relative;
      height: 220px;
      margin: 16px 0;
      border-radius: 18px;
      overflow: hidden;
      background: linear-gradient(180deg, rgba(255,255,255,0.06), rgba(255,255,255,0.02));
    }}
    .ground {{
      position: absolute;
      left: 0;
      right: 0;
      bottom: 42px;
      height: 6px;
      background: rgba(255, 214, 160, 0.7);
    }}
    .block {{
      position: absolute;
      bottom: 48px;
      left: 24px;
      width: 72px;
      height: 48px;
      border-radius: 14px;
      background: linear-gradient(135deg, #ffd6a0, #acbd86);
      animation: slide 3s ease-in-out infinite alternate;
      box-shadow: 0 14px 30px rgba(0,0,0,0.28);
    }}
    .arrow {{
      position: absolute;
      height: 3px;
      background: #ffb17d;
      transform-origin: left center;
    }}
    .arrow::after {{
      content: "";
      position: absolute;
      right: -8px;
      top: -4px;
      border-left: 10px solid #ffb17d;
      border-top: 5px solid transparent;
      border-bottom: 5px solid transparent;
    }}
    .force {{ left: 108px; bottom: 116px; width: 92px; }}
    .normal {{ left: 68px; bottom: 130px; width: 70px; transform: rotate(-90deg); }}
    .gravity {{ left: 68px; bottom: 84px; width: 70px; transform: rotate(90deg); }}
    .label {{
      position: absolute;
      font-size: 13px;
      color: #f8f3ea;
      letter-spacing: 0.3px;
    }}
    .label.force {{ left: 188px; bottom: 122px; }}
    .label.normal {{ left: 86px; bottom: 156px; }}
    .label.gravity {{ left: 86px; bottom: 56px; }}
    ul {{ margin: 10px 0 0; padding-left: 18px; line-height: 1.6; }}
    .meta {{ color: #d9e1d4; font-size: 13px; }}
    @keyframes slide {{
      from {{ transform: translateX(0); }}
      to {{ transform: translateX(180px); }}
    }}
  </style>
</head>
<body data-scene="mechanics">
  <div class="panel">
    <h2 style="margin: 0 0 6px;">{title}</h2>
    <div class="meta">建议聚焦：{tags}</div>
    <div class="stage">
      <div class="ground"></div>
      <div class="block"></div>
      <div class="arrow force"></div>
      <div class="arrow normal"></div>
      <div class="arrow gravity"></div>
      <div class="label force">F</div>
      <div class="label normal">N</div>
      <div class="label gravity">mg</div>
    </div>
    <div class="panel" style="padding: 12px; background: rgba(0,0,0,0.12);">
      <strong>复盘引导</strong>
      <ul>{bullets}</ul>
    </div>
  </div>
</body>
</html>"""


def _physics_projectile_html(cleaned_question: str, knowledge_points: List[str]) -> str:
    speed = _extract_number(
        cleaned_question,
        [r"v0\s*=\s*([0-9]+(?:\.[0-9]+)?)", r"初速度\s*为?\s*([0-9]+(?:\.[0-9]+)?)"],
        "12",
    )
    angle = _extract_number(
        cleaned_question,
        [r"([0-9]+(?:\.[0-9]+)?)\s*[°º]", r"抛射角\s*为?\s*([0-9]+(?:\.[0-9]+)?)", r"θ\s*=\s*([0-9]+(?:\.[0-9]+)?)"],
        "45",
    )
    tags = " / ".join(html.escape(item) for item in knowledge_points[:3]) or "运动合成 / 水平速度 / 竖直位移"

    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>平抛与斜抛演示</title>
  <style>
    :root {{
      color-scheme: dark;
    }}
    * {{
      box-sizing: border-box;
    }}
    body {{
      margin: 0;
      font-family: "Noto Sans SC", "Microsoft YaHei", sans-serif;
      background: linear-gradient(180deg, #102033, #152c2d 58%, #1a241f);
      color: #eff4ea;
      padding: 14px;
    }}
    .shell {{
      display: grid;
      gap: 12px;
    }}
    .card {{
      border-radius: 20px;
      padding: 14px;
      background: rgba(255,255,255,0.08);
      border: 1px solid rgba(255,255,255,0.10);
    }}
    .title {{
      font-size: 18px;
      font-weight: 700;
      margin-bottom: 6px;
    }}
    .subtitle {{
      font-size: 12px;
      color: #d7e1dc;
      line-height: 1.5;
    }}
    .chips {{
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-top: 10px;
    }}
    .chip {{
      border-radius: 999px;
      padding: 6px 10px;
      background: rgba(255,214,160,0.10);
      font-size: 12px;
      color: #fff2de;
    }}
    canvas {{
      display: block;
      width: 100%;
      height: 280px;
      border-radius: 20px;
      background: linear-gradient(180deg, rgba(146,201,255,0.10), rgba(255,255,255,0.02));
    }}
    .controls {{
      display: grid;
      gap: 10px;
    }}
    .buttons {{
      display: flex;
      gap: 10px;
    }}
    button {{
      flex: 1;
      border: 0;
      border-radius: 14px;
      padding: 12px 14px;
      font-size: 14px;
      font-weight: 700;
      cursor: pointer;
    }}
    .primary {{
      background: #ffd6a0;
      color: #171712;
    }}
    .secondary {{
      background: rgba(255,255,255,0.08);
      color: #eef3ea;
      border: 1px solid rgba(255,255,255,0.10);
    }}
    .slider-row {{
      display: grid;
      gap: 6px;
    }}
    .slider-label {{
      display: flex;
      justify-content: space-between;
      font-size: 12px;
      color: #d9e1d4;
    }}
    input[type="range"] {{
      width: 100%;
      accent-color: #ffd6a0;
    }}
    .stats {{
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 8px;
      margin-top: 10px;
    }}
    .stat {{
      border-radius: 14px;
      background: rgba(255,255,255,0.04);
      padding: 10px;
    }}
    .stat-key {{
      font-size: 11px;
      color: #c9d2c8;
      margin-bottom: 4px;
    }}
    .stat-value {{
      font-size: 18px;
      font-weight: 700;
      color: #fff4de;
    }}
  </style>
</head>
<body data-scene="projectile">
  <div class="shell">
    <section class="card">
      <div class="title">抛体轨迹演示</div>
      <div class="subtitle">观察水平与竖直两个方向的运动如何叠加成完整轨迹，画面聚焦轨迹和落点。</div>
      <div class="chips">
        <span class="chip">初速度 {html.escape(speed)} m/s</span>
        <span class="chip">角度 {html.escape(angle)}°</span>
        <span class="chip">{html.escape(tags)}</span>
      </div>
    </section>

    <section class="card">
      <canvas id="stage" width="360" height="280" aria-label="抛体运动演示"></canvas>
      <div class="stats">
        <div class="stat">
          <div class="stat-key">水平位移</div>
          <div class="stat-value" id="xValue">0.0</div>
        </div>
        <div class="stat">
          <div class="stat-key">竖直高度</div>
          <div class="stat-value" id="yValue">0.0</div>
        </div>
        <div class="stat">
          <div class="stat-key">飞行时间</div>
          <div class="stat-value" id="tValue">0.0</div>
        </div>
      </div>
    </section>

    <section class="card controls">
      <div class="buttons">
        <button class="primary" id="toggleBtn">开始演示</button>
        <button class="secondary" id="resetBtn">重置</button>
      </div>
      <label class="slider-row">
        <div class="slider-label"><span>初速度</span><span id="speedLabel">{html.escape(speed)} m/s</span></div>
        <input id="speedSlider" type="range" min="6" max="30" step="1" value="{html.escape(speed)}" />
      </label>
      <label class="slider-row">
        <div class="slider-label"><span>抛射角</span><span id="angleLabel">{html.escape(angle)}°</span></div>
        <input id="angleSlider" type="range" min="5" max="80" step="1" value="{html.escape(angle)}" />
      </label>
    </section>
  </div>

  <script>
    const canvas = document.getElementById('stage');
    const ctx = canvas.getContext('2d');
    const toggleBtn = document.getElementById('toggleBtn');
    const resetBtn = document.getElementById('resetBtn');
    const speedSlider = document.getElementById('speedSlider');
    const angleSlider = document.getElementById('angleSlider');
    const speedLabel = document.getElementById('speedLabel');
    const angleLabel = document.getElementById('angleLabel');
    const xValue = document.getElementById('xValue');
    const yValue = document.getElementById('yValue');
    const tValue = document.getElementById('tValue');

    let running = false;
    let rafId = null;
    let lastTime = 0;
    let time = 0;
    let history = [];

    function fmt(num, digits = 1) {{
      return Number(num).toFixed(digits);
    }}

    function syncLabels() {{
      speedLabel.textContent = `${{speedSlider.value}} m/s`;
      angleLabel.textContent = `${{angleSlider.value}}°`;
    }}

    function stateAt(t) {{
      const g = 10;
      const v0 = Number(speedSlider.value);
      const angle = Number(angleSlider.value) * Math.PI / 180;
      const vx = v0 * Math.cos(angle);
      const vy = v0 * Math.sin(angle);
      return {{
        x: vx * t,
        y: vy * t - 0.5 * g * t * t,
      }};
    }}

    function draw() {{
      const w = canvas.width;
      const h = canvas.height;
      ctx.clearRect(0, 0, w, h);

      ctx.fillStyle = 'rgba(255,255,255,0.04)';
      ctx.fillRect(0, 0, w, h);
      ctx.strokeStyle = 'rgba(255,255,255,0.18)';
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(28, h - 28);
      ctx.lineTo(w - 16, h - 28);
      ctx.moveTo(28, h - 28);
      ctx.lineTo(28, 18);
      ctx.stroke();

      ctx.strokeStyle = '#ffd6a0';
      ctx.lineWidth = 3;
      ctx.beginPath();
      history.forEach((point, index) => {{
        const px = 28 + point.x * 8;
        const py = h - 28 - point.y * 8;
        if (index === 0) ctx.moveTo(px, py);
        else ctx.lineTo(px, py);
      }});
      ctx.stroke();

      if (history.length) {{
        const last = history[history.length - 1];
        const px = 28 + last.x * 8;
        const py = h - 28 - last.y * 8;
        ctx.fillStyle = '#b8d18d';
        ctx.beginPath();
        ctx.arc(px, py, 7, 0, Math.PI * 2);
        ctx.fill();
      }}
    }}

    function step(timestamp) {{
      if (!running) return;
      if (!lastTime) lastTime = timestamp;
      const dt = Math.min((timestamp - lastTime) / 1000, 0.032);
      lastTime = timestamp;
      time += dt;
      const state = stateAt(time);

      if (state.y < 0) {{
        running = false;
        toggleBtn.textContent = '重新演示';
      }} else {{
        history.push(state);
        xValue.textContent = fmt(state.x);
        yValue.textContent = fmt(state.y);
        tValue.textContent = fmt(time);
        draw();
        rafId = requestAnimationFrame(step);
      }}
    }}

    function start() {{
      if (running) return;
      running = true;
      toggleBtn.textContent = '暂停演示';
      rafId = requestAnimationFrame(step);
    }}

    function stop() {{
      running = false;
      if (rafId) cancelAnimationFrame(rafId);
      rafId = null;
      lastTime = 0;
      toggleBtn.textContent = history.length ? '继续演示' : '开始演示';
    }}

    function reset() {{
      stop();
      time = 0;
      history = [{{ x: 0, y: 0 }}];
      xValue.textContent = '0.0';
      yValue.textContent = '0.0';
      tValue.textContent = '0.0';
      draw();
      toggleBtn.textContent = '开始演示';
    }}

    toggleBtn.addEventListener('click', () => {{
      if (running) stop();
      else {{
        if (!history.length || toggleBtn.textContent === '重新演示') {{
          reset();
        }}
        start();
      }}
    }});
    resetBtn.addEventListener('click', reset);
    speedSlider.addEventListener('input', () => {{
      syncLabels();
      reset();
    }});
    angleSlider.addEventListener('input', () => {{
      syncLabels();
      reset();
    }});

    syncLabels();
    reset();
  </script>
</body>
</html>"""


def _physics_collision_html(cleaned_question: str, knowledge_points: List[str]) -> str:
    mass1 = _extract_number(cleaned_question, [r"m1\s*=\s*([0-9]+(?:\.[0-9]+)?)", r"质量为\s*([0-9]+(?:\.[0-9]+)?)"], "1.0")
    mass2 = _extract_number(cleaned_question, [r"m2\s*=\s*([0-9]+(?:\.[0-9]+)?)"], "1.0")
    speed1 = _extract_number(cleaned_question, [r"v1\s*=\s*([0-9]+(?:\.[0-9]+)?)", r"速度为\s*([0-9]+(?:\.[0-9]+)?)"], "6")
    tags = " / ".join(html.escape(item) for item in knowledge_points[:3]) or "动量守恒 / 碰撞类型 / 速度变化"

    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>碰撞过程演示</title>
  <style>
    :root {{
      color-scheme: dark;
    }}
    * {{
      box-sizing: border-box;
    }}
    body {{
      margin: 0;
      font-family: "Noto Sans SC", "Microsoft YaHei", sans-serif;
      background: linear-gradient(180deg, #131a2b, #18222b 58%, #171d1c);
      color: #eef4ea;
      padding: 14px;
    }}
    .shell {{
      display: grid;
      gap: 12px;
    }}
    .card {{
      border-radius: 20px;
      padding: 14px;
      background: rgba(255,255,255,0.08);
      border: 1px solid rgba(255,255,255,0.10);
    }}
    .title {{
      font-size: 18px;
      font-weight: 700;
      margin-bottom: 6px;
    }}
    .subtitle {{
      font-size: 12px;
      color: #d7e1dc;
      line-height: 1.5;
    }}
    .chips {{
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
      margin-top: 10px;
    }}
    .chip {{
      border-radius: 999px;
      padding: 6px 10px;
      background: rgba(255,214,160,0.10);
      font-size: 12px;
      color: #fff2de;
    }}
    .stage {{
      position: relative;
      height: 250px;
      overflow: hidden;
      border-radius: 20px;
      background: linear-gradient(180deg, rgba(255,255,255,0.05), rgba(255,255,255,0.01));
    }}
    .track {{
      position: absolute;
      left: 0;
      right: 0;
      bottom: 46px;
      height: 6px;
      background: rgba(255,214,160,0.62);
    }}
    .cart {{
      position: absolute;
      bottom: 52px;
      width: 78px;
      height: 44px;
      border-radius: 14px;
      box-shadow: 0 12px 24px rgba(0,0,0,0.24);
      transform: translateX(var(--x, 0px));
    }}
    .cart.a {{
      left: 18px;
      background: linear-gradient(135deg, #ffd6a0, #d69e70);
    }}
    .cart.b {{
      left: 238px;
      background: linear-gradient(135deg, #b8d18d, #7ea170);
    }}
    .wheel {{
      position: absolute;
      bottom: -8px;
      width: 12px;
      height: 12px;
      border-radius: 50%;
      background: #eef3ea;
    }}
    .w1 {{ left: 12px; }}
    .w2 {{ right: 12px; }}
    .spark {{
      position: absolute;
      left: 192px;
      bottom: 98px;
      width: 24px;
      height: 24px;
      border-radius: 50%;
      background: radial-gradient(circle, rgba(255,214,160,0.95), rgba(255,214,160,0));
      opacity: 0;
      transform: scale(0.4);
    }}
    .spark.active {{
      animation: pop 0.35s ease-out 1;
    }}
    @keyframes pop {{
      0% {{ opacity: 0; transform: scale(0.3); }}
      40% {{ opacity: 1; transform: scale(1.0); }}
      100% {{ opacity: 0; transform: scale(1.5); }}
    }}
    .controls {{
      display: grid;
      gap: 10px;
    }}
    .buttons {{
      display: flex;
      gap: 10px;
    }}
    button {{
      flex: 1;
      border: 0;
      border-radius: 14px;
      padding: 12px 14px;
      font-size: 14px;
      font-weight: 700;
      cursor: pointer;
    }}
    .primary {{
      background: #ffd6a0;
      color: #171712;
    }}
    .secondary {{
      background: rgba(255,255,255,0.08);
      color: #eef3ea;
      border: 1px solid rgba(255,255,255,0.10);
    }}
    .slider-row {{
      display: grid;
      gap: 6px;
    }}
    .slider-label {{
      display: flex;
      justify-content: space-between;
      font-size: 12px;
      color: #d9e1d4;
    }}
    input[type="range"] {{
      width: 100%;
      accent-color: #ffd6a0;
    }}
    .stats {{
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
      gap: 8px;
      margin-top: 10px;
    }}
    .stat {{
      border-radius: 14px;
      background: rgba(255,255,255,0.04);
      padding: 10px;
    }}
    .stat-key {{
      font-size: 11px;
      color: #c9d2c8;
      margin-bottom: 4px;
    }}
    .stat-value {{
      font-size: 18px;
      font-weight: 700;
      color: #fff4de;
    }}
  </style>
</head>
<body data-scene="collision">
  <div class="shell">
    <section class="card">
      <div class="title">小车碰撞过程</div>
      <div class="subtitle">聚焦碰撞前后速度变化与碰撞类型，不把整道题塞进 WebView。</div>
      <div class="chips">
        <span class="chip">m1 = {html.escape(mass1)} kg</span>
        <span class="chip">m2 = {html.escape(mass2)} kg</span>
        <span class="chip">v1 = {html.escape(speed1)} m/s</span>
        <span class="chip">{html.escape(tags)}</span>
      </div>
    </section>

    <section class="card stage">
      <div class="track"></div>
      <div class="cart a" id="cartA">
        <div class="wheel w1"></div>
        <div class="wheel w2"></div>
      </div>
      <div class="cart b" id="cartB">
        <div class="wheel w1"></div>
        <div class="wheel w2"></div>
      </div>
      <div class="spark" id="spark"></div>
    </section>

    <section class="card">
      <div class="stats">
        <div class="stat">
          <div class="stat-key">碰撞类型</div>
          <div class="stat-value" id="typeValue">弹性</div>
        </div>
        <div class="stat">
          <div class="stat-key">A车速度</div>
          <div class="stat-value" id="v1Value">{html.escape(speed1)}</div>
        </div>
        <div class="stat">
          <div class="stat-key">B车速度</div>
          <div class="stat-value" id="v2Value">0.0</div>
        </div>
      </div>
    </section>

    <section class="card controls">
      <div class="buttons">
        <button class="primary" id="toggleBtn">开始演示</button>
        <button class="secondary" id="resetBtn">重置</button>
      </div>
      <label class="slider-row">
        <div class="slider-label"><span>A车初速度</span><span id="speedLabel">{html.escape(speed1)} m/s</span></div>
        <input id="speedSlider" type="range" min="2" max="14" step="1" value="{html.escape(speed1)}" />
      </label>
      <label class="slider-row">
        <div class="slider-label"><span>恢复系数</span><span id="eLabel">1.0</span></div>
        <input id="eSlider" type="range" min="0" max="1" step="0.1" value="1" />
      </label>
    </section>
  </div>

  <script>
    const cartA = document.getElementById('cartA');
    const cartB = document.getElementById('cartB');
    const spark = document.getElementById('spark');
    const toggleBtn = document.getElementById('toggleBtn');
    const resetBtn = document.getElementById('resetBtn');
    const speedSlider = document.getElementById('speedSlider');
    const eSlider = document.getElementById('eSlider');
    const speedLabel = document.getElementById('speedLabel');
    const eLabel = document.getElementById('eLabel');
    const typeValue = document.getElementById('typeValue');
    const v1Value = document.getElementById('v1Value');
    const v2Value = document.getElementById('v2Value');

    const m1 = {float(mass1)};
    const m2 = {float(mass2)};
    let running = false;
    let rafId = null;
    let lastTime = 0;
    let x1 = 0;
    let x2 = 0;
    let v1 = Number(speedSlider.value);
    let v2 = 0;
    let collided = false;

    function fmt(num, digits = 1) {{
      return Number(num).toFixed(digits);
    }}

    function syncLabels() {{
      speedLabel.textContent = `${{speedSlider.value}} m/s`;
      eLabel.textContent = fmt(eSlider.value, 1);
      typeValue.textContent = Number(eSlider.value) >= 0.9 ? '弹性' : (Number(eSlider.value) <= 0.2 ? '近非弹性' : '一般碰撞');
    }}

    function render() {{
      cartA.style.setProperty('--x', `${{x1}}px`);
      cartB.style.setProperty('--x', `${{x2}}px`);
      v1Value.textContent = fmt(v1);
      v2Value.textContent = fmt(v2);
    }}

    function step(timestamp) {{
      if (!running) return;
      if (!lastTime) lastTime = timestamp;
      const dt = Math.min((timestamp - lastTime) / 1000, 0.032);
      lastTime = timestamp;

      x1 += v1 * dt * 18;
      x2 += v2 * dt * 18;

      const distance = 220 + x2 - x1;
      if (!collided && distance <= 78) {{
        collided = true;
        spark.classList.remove('active');
        void spark.offsetWidth;
        spark.classList.add('active');
        const e = Number(eSlider.value);
        const nextV1 = ((m1 - e * m2) * v1 + (1 + e) * m2 * v2) / (m1 + m2);
        const nextV2 = ((m2 - e * m1) * v2 + (1 + e) * m1 * v1) / (m1 + m2);
        v1 = nextV1;
        v2 = nextV2;
      }}

      render();
      if (x1 < 190 && x2 < 190) {{
        rafId = requestAnimationFrame(step);
      }} else {{
        running = false;
        toggleBtn.textContent = '重新演示';
      }}
    }}

    function start() {{
      if (running) return;
      running = true;
      toggleBtn.textContent = '暂停演示';
      rafId = requestAnimationFrame(step);
    }}

    function stop() {{
      running = false;
      if (rafId) cancelAnimationFrame(rafId);
      rafId = null;
      lastTime = 0;
      toggleBtn.textContent = collided ? '继续演示' : '开始演示';
    }}

    function reset() {{
      stop();
      x1 = 0;
      x2 = 0;
      v1 = Number(speedSlider.value);
      v2 = 0;
      collided = false;
      spark.classList.remove('active');
      render();
      toggleBtn.textContent = '开始演示';
    }}

    toggleBtn.addEventListener('click', () => {{
      if (running) stop();
      else {{
        if (toggleBtn.textContent === '重新演示') {{
          reset();
        }}
        start();
      }}
    }});
    resetBtn.addEventListener('click', reset);
    speedSlider.addEventListener('input', () => {{
      syncLabels();
      reset();
    }});
    eSlider.addEventListener('input', () => {{
      syncLabels();
      reset();
    }});

    syncLabels();
    reset();
  </script>
</body>
</html>"""


def _physics_circuit_html(cleaned_question: str, knowledge_points: List[str]) -> str:
    title = html.escape(cleaned_question[:80] or "电路过程演示")
    tags = " / ".join(html.escape(item) for item in knowledge_points[:3]) or "串并联 / 欧姆定律"
    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <style>
    body {{
      margin: 0;
      font-family: "Noto Sans SC", "Microsoft YaHei", sans-serif;
      background: radial-gradient(circle at top, #2b413c, #111715 70%);
      color: #f4efe6;
      padding: 18px;
    }}
    .card {{
      border-radius: 22px;
      padding: 18px;
      background: rgba(255,255,255,0.08);
      border: 1px solid rgba(255,255,255,0.1);
    }}
    svg {{ width: 100%; height: 220px; display: block; }}
    .caption {{ color: #d7d3ca; font-size: 13px; line-height: 1.7; }}
    .charge {{
      fill: #ffd6a0;
      animation: move 3s linear infinite;
    }}
    @keyframes move {{
      from {{ offset-distance: 0%; }}
      to {{ offset-distance: 100%; }}
    }}
  </style>
</head>
<body data-scene="circuit">
  <div class="card">
    <h2 style="margin: 0 0 6px;">{title}</h2>
    <div class="caption">建议聚焦：{tags}</div>
    <svg viewBox="0 0 480 220" aria-label="电路演示图">
      <rect x="40" y="30" width="400" height="160" rx="20" fill="rgba(255,255,255,0.03)" />
      <path d="M90 70 H360 V150 H90 Z" fill="none" stroke="#edd8b0" stroke-width="6" stroke-linejoin="round"/>
      <line x1="90" y1="110" x2="70" y2="110" stroke="#edd8b0" stroke-width="6" />
      <line x1="70" y1="95" x2="70" y2="125" stroke="#edd8b0" stroke-width="6" />
      <line x1="58" y1="100" x2="58" y2="120" stroke="#edd8b0" stroke-width="3" />
      <circle cx="360" cy="110" r="24" fill="rgba(255,214,160,0.18)" stroke="#ffd6a0" stroke-width="5" />
      <circle class="charge" cx="110" cy="70" r="6">
        <animateMotion dur="2.4s" repeatCount="indefinite" path="M0 0 H250 V80 H-250 V-80" />
      </circle>
      <text x="46" y="86" fill="#f8f3ea" font-size="14">电源</text>
      <text x="336" y="116" fill="#f8f3ea" font-size="14">灯泡</text>
      <text x="178" y="56" fill="#d7d3ca" font-size="13">I</text>
    </svg>
    <div class="caption">可继续扩展成开关控制、电阻变化、串并联对比等交互演示。</div>
  </div>
</body>
</html>"""


def _physics_optics_html(cleaned_question: str, knowledge_points: List[str]) -> str:
    title = html.escape(cleaned_question[:80] or "光路变化演示")
    tags = " / ".join(html.escape(item) for item in knowledge_points[:3]) or "透镜 / 折射 / 成像"
    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <style>
    body {{
      margin: 0;
      font-family: "Noto Sans SC", "Microsoft YaHei", sans-serif;
      background: linear-gradient(180deg, #111b20, #1d3038);
      color: #f7f1e6;
      padding: 18px;
    }}
    .card {{
      border-radius: 22px;
      padding: 18px;
      background: rgba(255,255,255,0.08);
      border: 1px solid rgba(255,255,255,0.1);
    }}
    svg {{ width: 100%; height: 220px; display: block; }}
    .ray {{
      stroke: #ffd6a0;
      stroke-width: 4;
      stroke-linecap: round;
      stroke-dasharray: 12 12;
      animation: dash 2.5s linear infinite;
    }}
    @keyframes dash {{
      to {{ stroke-dashoffset: -48; }}
    }}
  </style>
</head>
<body data-scene="optics">
  <div class="card">
    <h2 style="margin: 0 0 6px;">{title}</h2>
    <div style="color:#d7d3ca; font-size:13px;">建议聚焦：{tags}</div>
    <svg viewBox="0 0 480 220" aria-label="光路演示图">
      <line x1="240" y1="24" x2="240" y2="196" stroke="#9cc1cf" stroke-width="6" />
      <line x1="40" y1="110" x2="440" y2="110" stroke="rgba(255,255,255,0.2)" stroke-width="2" />
      <path class="ray" d="M70 70 L240 100 L380 62" fill="none" />
      <path class="ray" d="M70 150 L240 120 L380 160" fill="none" />
      <text x="252" y="42" fill="#f8f3ea" font-size="14">透镜/界面</text>
      <text x="26" y="105" fill="#f8f3ea" font-size="13">入射光</text>
      <text x="386" y="58" fill="#f8f3ea" font-size="13">像点</text>
    </svg>
    <div style="color:#d7d3ca; font-size:13px; line-height:1.7;">可继续接入焦距、物距、像距的滑块，做成成像规律演示。</div>
  </div>
</body>
</html>"""


def _build_chemistry_study_card(
    *,
    cleaned_question: str,
    knowledge_points: List[str],
    solution_steps: List[str],
) -> RichArtifact:
    topic = _first_keyword_match(
        cleaned_question,
        {
            "氧化还原": ["氧化", "还原", "化合价", "电子转移"],
            "离子反应": ["离子", "沉淀", "电解质", "共存"],
            "化学平衡": ["平衡", "勒夏特列", "转化率", "平衡常数"],
            "有机推断": ["有机", "官能团", "酯", "醇", "烯"],
        },
        default="实验与反应条件",
    )
    content = {
        "theme": topic,
        "question_excerpt": cleaned_question[:220],
        "cards": [
            {
                "front": "先判断什么",
                "back": knowledge_points[0] if knowledge_points else "先识别反应类型、限制条件和守恒关系。",
            },
            {
                "front": "高频失误",
                "back": "忽略反应条件、漏写状态符号、电子守恒或离子共存判断不完整。",
            },
            {
                "front": "复盘清单",
                "back": "配平、条件、现象、守恒、结论五项逐一检查。",
            },
            {
                "front": "步骤提示",
                "back": "；".join(solution_steps[:2]) if solution_steps else "先列已知条件，再按守恒或平衡关系推进。",
            },
        ],
    }
    return RichArtifact(
        artifact_type="study_card",
        title=f"{topic}复习卡片",
        description="将化学题拆成可快速翻看的知识卡片，适合移动端碎片化复习。",
        mime_type="application/json",
        content=json.dumps(content, ensure_ascii=False, indent=2),
    )


def _build_programming_snippet(
    *,
    cleaned_question: str,
    knowledge_points: List[str],
    solution_steps: List[str],
) -> RichArtifact:
    language = "text"
    lowered = cleaned_question.lower()
    if "java" in lowered:
        language = "java"
    elif "python" in lowered:
        language = "python"
    elif "c++" in lowered or "cpp" in lowered:
        language = "cpp"

    focus = knowledge_points[0] if knowledge_points else "算法/代码逻辑"
    snippet = {
        "language": language,
        "focus": focus,
        "question_excerpt": cleaned_question[:220],
        "template": _programming_template(language, focus),
        "trace_steps": solution_steps[:3] or [
            "先明确输入输出与约束。",
            "再确定核心数据结构或状态定义。",
            "最后补边界条件与复杂度检查。",
        ],
        "debug_checklist": [
            "变量初始化是否正确。",
            "循环边界和递归出口是否覆盖完整。",
            "样例输入输出是否与题意一致。",
        ],
    }
    return RichArtifact(
        artifact_type="code_snippet",
        title=f"{focus}代码骨架",
        description="为编程题提供可继续填充的代码/调试骨架。",
        mime_type="application/json",
        content=json.dumps(snippet, ensure_ascii=False, indent=2),
    )


def _programming_template(language: str, focus: str) -> str:
    if language == "java":
        return (
            "public class Solution {\n"
            "    public static void solve() {\n"
            f"        // 核心关注：{focus}\n"
            "        // 1. 读取输入\n"
            "        // 2. 维护状态\n"
            "        // 3. 输出答案\n"
            "    }\n"
            "}\n"
        )
    if language == "python":
        return (
            "def solve():\n"
            f"    # 核心关注：{focus}\n"
            "    # 1. 读取输入\n"
            "    # 2. 更新状态\n"
            "    # 3. 输出答案\n"
            "\n"
            "if __name__ == '__main__':\n"
            "    solve()\n"
        )
    if language == "cpp":
        return (
            "#include <bits/stdc++.h>\n"
            "using namespace std;\n\n"
            "int main() {\n"
            f"    // 核心关注：{focus}\n"
            "    // 1. 读入\n"
            "    // 2. 状态转移/搜索/模拟\n"
            "    // 3. 输出\n"
            "    return 0;\n"
            "}\n"
        )
    return (
        f"核心关注：{focus}\n"
        "步骤：输入 -> 状态维护 -> 输出\n"
        "调试：先样例，再边界，再复杂度。\n"
    )


def _build_biology_timeline(
    *,
    cleaned_question: str,
    knowledge_points: List[str],
    solution_steps: List[str],
) -> RichArtifact:
    topic = _first_keyword_match(
        cleaned_question,
        {
            "光合作用": ["光合作用", "叶绿体", "光反应", "暗反应"],
            "细胞呼吸": ["呼吸作用", "线粒体", "有氧", "无氧"],
            "有丝分裂": ["有丝分裂", "纺锤体", "染色体"],
            "减数分裂": ["减数分裂", "联会", "四分体"],
            "基因表达": ["转录", "翻译", "rna", "蛋白质"],
        },
        default="生物过程复盘",
    )
    timeline = {
        "theme": topic,
        "question_excerpt": cleaned_question[:220],
        "stages": [
            {
                "stage": "起点",
                "focus": knowledge_points[0] if knowledge_points else "先识别研究对象与发生场所。",
            },
            {
                "stage": "过程推进",
                "focus": solution_steps[0] if solution_steps else "沿着物质变化或结构变化逐步推进。",
            },
            {
                "stage": "关键分叉",
                "focus": solution_steps[1] if len(solution_steps) > 1 else "区分条件变化带来的不同路径或结果。",
            },
            {
                "stage": "结果回收",
                "focus": "把结构、功能和条件重新对应到题目问法。",
            },
        ],
    }
    return RichArtifact(
        artifact_type="timeline",
        title=f"{topic}过程时间线",
        description="把生物过程题拆解为时序步骤，便于后续接动画或时间线组件。",
        mime_type="application/json",
        content=json.dumps(timeline, ensure_ascii=False, indent=2),
    )


def _first_keyword_match(text: str, mapping: dict[str, List[str]], default: str) -> str:
    lowered = text.lower()
    for label, keywords in mapping.items():
        if any(keyword.lower() in lowered for keyword in keywords):
            return label
    return default


def _is_artifact_content_valid(
    artifact: RichArtifact,
    *,
    subject: str,
    cleaned_question: str,
) -> bool:
    content = artifact.content.strip()
    if not content:
        return False

    if artifact.artifact_type == "interactive_html":
        lowered = content.lower()
        if not ("<html" in lowered and "</html>" in lowered and "<body" in lowered):
            return False
        if "物理" in subject or _looks_like_physics_question(cleaned_question):
            return _physics_html_matches_question(cleaned_question, content)
        return True

    if artifact.mime_type == "application/json":
        try:
            parsed = json.loads(content)
        except json.JSONDecodeError:
            return False
        if not isinstance(parsed, dict):
            return False
        if artifact.artifact_type == "chart_spec":
            return _is_chart_spec_valid(parsed)
        return True

    return True


def _is_chart_spec_valid(parsed: dict) -> bool:
    scene = str(parsed.get("scene") or "").strip()
    renderer = str(parsed.get("renderer") or "").strip()
    if not scene:
        return False
    if renderer and renderer != "generic_chart_spec":
        return False

    if str(parsed.get("core_idea") or "").strip():
        return True
    has_content = any(
        isinstance(parsed.get(key), list) and len(parsed.get(key) or []) > 0
        for key in [
            "formula_transformations",
            "solution_path",
            "mistake_traps",
            "review_checklist",
            "plot_suggestions",
            "student_tasks",
            "step_mapping",
            "render_hints",
            "coordinate_graph",
        ]
    )
    visual_model = parsed.get("visual_model")
    if isinstance(visual_model, dict) and visual_model:
        has_content = True
    coordinate_graph = parsed.get("coordinate_graph")
    if isinstance(coordinate_graph, dict) and coordinate_graph:
        has_content = True
    return has_content


def _with_chart_spec_legacy_display_fields(
    artifact: RichArtifact,
    *,
    cleaned_question: str = "",
) -> RichArtifact:
    if artifact.mime_type != "application/json":
        return artifact
    try:
        parsed = json.loads(artifact.content)
    except json.JSONDecodeError:
        return artifact
    if not isinstance(parsed, dict):
        return artifact
    scene = str(parsed.get("scene") or parsed.get("topic_type") or "").strip()
    if not isinstance(parsed.get("coordinate_graph"), dict):
        knowledge_values = parsed.get("knowledge_points")
        if not isinstance(knowledge_values, list):
            knowledge_values = []
        solution_values = parsed.get("solution_path")
        solution_texts: List[str] = []
        if isinstance(solution_values, list):
            for item in solution_values:
                if isinstance(item, dict):
                    action = str(item.get("action") or "").strip()
                    if action:
                        solution_texts.append(action)
                elif str(item).strip():
                    solution_texts.append(str(item))
        graph = _math_coordinate_graph_spec(
            scene,
            cleaned_question=cleaned_question,
            knowledge_points=[str(item) for item in knowledge_values],
            solution_steps=solution_texts,
        )
        if graph:
            parsed["coordinate_graph"] = graph

    if parsed.get("plot_suggestions"):
        return RichArtifact(
            artifact_type=artifact.artifact_type,
            title=artifact.title,
            description=artifact.description,
            mime_type=artifact.mime_type,
            content=json.dumps(parsed, ensure_ascii=False, indent=2),
        )

    core_idea = str(parsed.get("core_idea") or "").strip()
    transformations = parsed.get("formula_transformations")
    solution_path = parsed.get("solution_path")
    mistake_traps = parsed.get("mistake_traps")
    review_checklist = parsed.get("review_checklist")

    legacy_sections: List[dict] = []
    if core_idea:
        legacy_sections.append({"label": "核心思路", "value": core_idea})
    if isinstance(transformations, list):
        value = "；".join(
            f"{item.get('label', '关键变形')}：{_math_latexize_display_text(str(item.get('detail', '')))}"
            for item in transformations[:5]
            if isinstance(item, dict)
            and str(item.get("detail") or "").strip()
            and not _math_is_formula_only(str(item.get("detail") or ""))
        )
        if value:
            legacy_sections.append({"label": "关键变形", "value": value})
    if isinstance(solution_path, list):
        value = "；".join(
            f"{_math_latexize_display_text(str(item.get('action', '解题步骤')))}：{_math_latexize_display_text(str(item.get('reason', '')))}"
            for item in solution_path[:3]
            if isinstance(item, dict) and str(item.get("reason") or "").strip()
        )
        if value:
            legacy_sections.append({"label": "解题路线", "value": value})
            parsed["step_mapping"] = [
                f"{_math_latexize_display_text(str(item.get('action', '解题步骤')))}：{_math_latexize_display_text(str(item.get('reason', '')))}"
                for item in solution_path[:4]
                if isinstance(item, dict) and str(item.get("reason") or "").strip()
            ]
    if isinstance(mistake_traps, list) and mistake_traps:
        legacy_sections.append(
            {
                "label": "易错提醒",
                "value": "；".join(str(item) for item in mistake_traps[:3] if str(item).strip()),
            }
        )
    if isinstance(review_checklist, list) and review_checklist:
        parsed["student_tasks"] = [str(item) for item in review_checklist if str(item).strip()]

    if not legacy_sections:
        return artifact
    parsed["plot_suggestions"] = legacy_sections
    return RichArtifact(
        artifact_type=artifact.artifact_type,
        title=artifact.title,
        description=artifact.description,
        mime_type=artifact.mime_type,
        content=json.dumps(parsed, ensure_ascii=False, indent=2),
    )


def _looks_like_physics_question(cleaned_question: str) -> bool:
    lowered = cleaned_question.lower()
    physics_keywords = [
        "物块",
        "木板",
        "板块",
        "小车",
        "斜面",
        "摩擦",
        "加速度",
        "速度",
        "位移",
        "受力",
        "牛顿",
        "电路",
        "电流",
        "电压",
        "透镜",
        "折射",
        "反射",
        "成像",
    ]
    return any(keyword in lowered for keyword in physics_keywords)


def _physics_html_matches_question(cleaned_question: str, html_content: str) -> bool:
    question_type = _physics_scene_type(cleaned_question)
    marker_match = re.search(r'data-scene=["\']([a-z_]+)["\']', html_content, re.IGNORECASE)
    html_type = marker_match.group(1).lower() if marker_match else _physics_scene_type(html_content)

    if question_type == "unknown":
        return True
    if html_type == "unknown":
        return False
    if question_type == "mechanics":
        return html_type in {"mechanics", "board_block", "incline", "projectile", "collision"}
    return question_type == html_type


def _physics_scene_type(text: str) -> str:
    lowered = text.lower()

    optics_keywords = [
        "光路",
        "透镜",
        "凸透镜",
        "凹透镜",
        "折射",
        "反射",
        "像距",
        "物距",
        "焦距",
        "成像",
        "平面镜",
        "入射光",
    ]
    circuit_keywords = [
        "电路",
        "电流",
        "电压",
        "电阻",
        "欧姆",
        "串联",
        "并联",
        "灯泡",
        "电源",
        "开关",
    ]
    board_block_keywords = [
        "木板",
        "板块",
        "物块",
        "滑块",
        "滑板",
        "摩擦",
        "传送带",
        "连接体",
    ]
    incline_keywords = [
        "斜面",
        "斜坡",
        "倾角",
        "沿斜面",
    ]
    projectile_keywords = [
        "平抛",
        "斜抛",
        "抛体",
        "抛出",
        "射程",
        "落点",
        "飞行时间",
    ]
    collision_keywords = [
        "碰撞",
        "相碰",
        "对心碰撞",
        "弹性碰撞",
        "非弹性碰撞",
        "小球",
    ]
    electromagnetism_keywords = [
        "电场",
        "磁场",
        "电磁场",
        "带电粒子",
        "粒子",
        "洛伦兹力",
        "安培力",
        "电磁感应",
        "感应电流",
        "感应电动势",
        "磁通量",
        "导体棒",
        "线圈",
        "偏转",
        "轨迹",
        "右手定则",
        "左手定则",
        "匀强磁场",
    ]
    mechanics_keywords = [
        "受力",
        "牛顿",
        "加速度",
        "速度",
        "位移",
        "弹簧",
        "振子",
    ]

    if any(keyword in lowered for keyword in optics_keywords):
        return "optics"
    if any(keyword in lowered for keyword in circuit_keywords):
        return "circuit"
    if any(keyword in lowered for keyword in electromagnetism_keywords):
        return "electromagnetism"
    if any(keyword in lowered for keyword in incline_keywords):
        return "incline"
    if any(keyword in lowered for keyword in projectile_keywords):
        return "projectile"
    if any(keyword in lowered for keyword in collision_keywords):
        return "collision"
    if any(keyword in lowered for keyword in board_block_keywords):
        return "board_block"
    if any(keyword in lowered for keyword in mechanics_keywords):
        return "mechanics"
    return "unknown"


def _extract_number(text: str, patterns: List[str], default: str) -> str:
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            return match.group(1)
    return default
