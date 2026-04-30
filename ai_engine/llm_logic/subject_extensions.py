from __future__ import annotations

import html
import json
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
    parameters = _math_detect_parameters(cleaned_question)
    focus = knowledge_points[0] if knowledge_points else profile["fallback_focus"]
    title = profile["title"]

    visual_model = {
        "coordinate_system": profile["coordinate_system"],
        "layers": [
            {
                "id": "core_object",
                "type": profile["core_layer_type"],
                "label": focus,
                "source": expressions[0] if expressions else "根据题干中的核心关系式补全",
            },
            {
                "id": "constraints",
                "type": "annotation",
                "label": "题设条件",
                "source": "标出定义域、取值范围、已知点、边界条件或事件条件。",
            },
            {
                "id": "solution_path",
                "type": "guide",
                "label": "解题推进",
                "source": solution_steps[0] if solution_steps else profile["default_step"],
            },
        ],
        "controls": [
            {
                "name": name,
                "label": f"参数 {name}",
                "default": 1,
                "min": -5,
                "max": 5,
                "step": 0.5,
            }
            for name in parameters[:4]
        ],
        "annotations": profile["annotations"],
    }

    content = {
        "renderer": "generic_chart_spec",
        "version": 2,
        "scene": scene,
        "title": title,
        "question_excerpt": cleaned_question[:220],
        "knowledge_points": knowledge_points[:4],
        "expressions": expressions[:4],
        "visual_model": visual_model,
        "plot_suggestions": [
            {
                "label": "核心对象",
                "value": focus,
            },
            {
                "label": "推荐坐标/画法",
                "value": profile["drawing_hint"],
            },
            {
                "label": "关键观察",
                "value": profile["observation_hint"],
            },
            {
                "label": "可交互参数",
                "value": "、".join(parameters[:4]) if parameters else profile["parameter_hint"],
            },
        ],
        "student_tasks": profile["student_tasks"],
        "step_mapping": solution_steps[:3],
        "render_hints": profile["render_hints"],
        "misconception_checks": profile["misconception_checks"],
    }
    return RichArtifact(
        artifact_type="chart_spec",
        title=title,
        description="为数学题生成可接图表、几何草图或步骤可视化组件的结构化方案。",
        mime_type="application/json",
        content=json.dumps(content, ensure_ascii=False, indent=2),
    )


def _math_scene_type(cleaned_question: str, knowledge_points: List[str]) -> str:
    text = f"{cleaned_question} {' '.join(knowledge_points)}".lower()
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
            "title": "函数图像联动分析",
            "fallback_focus": "题目中的主函数或核心关系式",
            "coordinate_system": "cartesian_2d",
            "core_layer_type": "curve",
            "drawing_hint": "建立直角坐标系，标出定义域、截距、零点、极值点、单调区间和对称性。",
            "observation_hint": "先看图像的关键点和整体走势，再把代数变形对应到图像变化。",
            "parameter_hint": "可把系数、平移量或区间端点作为滑块。",
            "default_step": "先确定定义域和关键点，再分析单调性、极值或交点。",
            "student_tasks": [
                "先观察定义域、零点、对称性，再判断图像走势。",
                "把题目中的关键参数作为滑块，观察平移、伸缩和交点变化。",
            ],
            "render_hints": ["优先画坐标轴、网格、函数曲线和关键点标签。", "若有多个函数，使用不同颜色并标出交点。"],
            "annotations": ["定义域", "零点/交点", "极值点", "单调区间"],
            "misconception_checks": ["不要把图像交点误当作函数零点。", "检查端点能否取到以及区间开闭。"],
        },
        "geometry": {
            "title": "几何构型草图建议",
            "fallback_focus": "题目中的核心图形与约束关系",
            "coordinate_system": "plane_geometry",
            "core_layer_type": "shape",
            "drawing_hint": "先画骨架图，再叠加中点、垂线、角平分线、平行线或切线等辅助元素。",
            "observation_hint": "优先寻找不变量：角、边长比例、圆周角、相似关系或面积关系。",
            "parameter_hint": "可把角度、边长比例或动点位置作为滑块。",
            "default_step": "先固定已知点线面关系，再补辅助线并寻找相似、全等或圆关系。",
            "student_tasks": [
                "先固定关键点与约束，再逐步标出边、角或切线关系。",
                "把题目中的不变量写进图中，减少纯文字推理负担。",
            ],
            "render_hints": ["保持图形比例清晰，已知条件用标签标注。", "辅助线使用虚线，结论对象使用高亮。"],
            "annotations": ["已知边角", "辅助线", "相似/全等关系", "目标结论"],
            "misconception_checks": ["不要默认图形按比例精确。", "区分已知垂直、可证垂直和看起来垂直。"],
        },
        "conic": {
            "title": "圆锥曲线结构图",
            "fallback_focus": "圆锥曲线的标准方程、焦点和几何性质",
            "coordinate_system": "cartesian_2d",
            "core_layer_type": "conic",
            "drawing_hint": "在坐标系中画出曲线、焦点、准线、顶点、渐近线或动点轨迹。",
            "observation_hint": "把方程参数和几何量对应起来，重点观察焦点、离心率和轨迹约束。",
            "parameter_hint": "可把 a、b、c、e 或斜率作为滑块。",
            "default_step": "先化为标准形式，再定位焦点、顶点、准线或渐近线。",
            "student_tasks": ["先把方程化成标准形式。", "再把参数与焦点、离心率、渐近线或切线条件对应。"],
            "render_hints": ["曲线和焦点必须同屏展示。", "若有直线交点，标出弦中点、斜率或面积对象。"],
            "annotations": ["焦点", "顶点", "准线/渐近线", "动点轨迹"],
            "misconception_checks": ["检查 a、b、c 的大小关系。", "注意椭圆和双曲线焦点位置差异。"],
        },
        "calculus": {
            "title": "导数与积分过程图",
            "fallback_focus": "函数变化率、切线、面积或极值关系",
            "coordinate_system": "cartesian_2d",
            "core_layer_type": "curve",
            "drawing_hint": "画出函数曲线、切线/法线、单调区间、极值点和积分面积区域。",
            "observation_hint": "把导数符号对应到增减，把积分上下限对应到面积边界。",
            "parameter_hint": "可把切点、积分上下限或参数系数作为滑块。",
            "default_step": "先求导或确定积分区间，再把符号变化与图形区域对应。",
            "student_tasks": ["用导数符号表标出单调区间。", "把切线斜率或积分面积直接标在图上。"],
            "render_hints": ["导数为零的位置用竖线标记。", "积分区域用半透明色填充。"],
            "annotations": ["切点", "极值点", "导数符号", "积分区域"],
            "misconception_checks": ["导数为零不一定是极值。", "定积分有符号，面积问题需确认上下方关系。"],
        },
        "statistics": {
            "title": "统计分布可视化建议",
            "fallback_focus": "样本数据、统计量和分布形态",
            "coordinate_system": "statistical_chart",
            "core_layer_type": "bar_or_box_plot",
            "drawing_hint": "先列数据表，再映射到柱状图、折线图、散点图或箱线图。",
            "observation_hint": "对比集中趋势、离散程度和异常值，而不是只盯单个数值。",
            "parameter_hint": "可把分组、样本量或频率区间作为切换项。",
            "default_step": "先整理样本和频数，再计算均值、方差或概率。",
            "student_tasks": ["先整理样本空间或频数表。", "对比期望、方差或频率变化时，分系列展示。"],
            "render_hints": ["柱状图要标清类别和频数。", "箱线图要标出四分位和异常点。"],
            "annotations": ["均值", "方差", "频率", "异常值"],
            "misconception_checks": ["不要混淆频数和频率。", "样本方差和总体方差公式不同。"],
        },
        "probability": {
            "title": "概率事件结构图",
            "fallback_focus": "样本空间、事件关系和概率计算路径",
            "coordinate_system": "event_space",
            "core_layer_type": "tree_or_venn",
            "drawing_hint": "用树状图、韦恩图或表格拆分样本空间，并标出互斥、独立或条件概率关系。",
            "observation_hint": "先判断事件是否互斥、独立或有条件，再决定乘法、加法或补集策略。",
            "parameter_hint": "可把试验次数、成功概率或条件事件作为控件。",
            "default_step": "先列样本空间，再按事件关系写概率表达式。",
            "student_tasks": ["先把随机试验拆成阶段或分类。", "标出每条路径或每个区域对应的概率。"],
            "render_hints": ["树状图每条边显示条件概率。", "韦恩图要标出交、并、补区域。"],
            "annotations": ["样本空间", "互斥/独立", "条件概率", "补事件"],
            "misconception_checks": ["独立事件和互斥事件不是一回事。", "条件概率要更新样本空间。"],
        },
        "sequence": {
            "title": "数列递推与趋势图",
            "fallback_focus": "数列通项、递推关系和求和结构",
            "coordinate_system": "discrete_index",
            "core_layer_type": "discrete_points",
            "drawing_hint": "以 n 为横轴画离散点或阶梯图，并把递推箭头、差分或累加区域标出来。",
            "observation_hint": "观察相邻项关系、增长趋势和求和结构，再决定公式法、递推法或裂项法。",
            "parameter_hint": "可把 n、首项、公差、公比或递推参数作为滑块。",
            "default_step": "先写出前几项，再寻找差分、比值或递推不变量。",
            "student_tasks": ["列出前 3 到 5 项，观察差分或比值。", "把通项和前 n 项和分别标成两条序列。"],
            "render_hints": ["离散点不要连成连续函数。", "递推关系用箭头标出从 n 到 n+1 的变化。"],
            "annotations": ["首项", "公差/公比", "递推箭头", "前 n 项和"],
            "misconception_checks": ["不要把数列当连续函数处理。", "注意 n 的起始值。"],
        },
        "vector": {
            "title": "向量关系示意图",
            "fallback_focus": "向量坐标、夹角、投影或线性组合",
            "coordinate_system": "vector_plane",
            "core_layer_type": "vector",
            "drawing_hint": "画出向量起点、终点、合成平行四边形、投影线和夹角。",
            "observation_hint": "把代数坐标和几何方向对应起来，重点看夹角、投影和线性组合。",
            "parameter_hint": "可把向量分量、夹角或比例系数作为滑块。",
            "default_step": "先统一起点或坐标，再计算数量积、模长或投影。",
            "student_tasks": ["统一向量起点后再比较方向。", "把数量积与夹角/投影关系写在图旁。"],
            "render_hints": ["向量箭头要有方向和标签。", "投影线用虚线，合向量用强调色。"],
            "annotations": ["起点/终点", "夹角", "投影", "合向量"],
            "misconception_checks": ["向量平移不改变向量本身。", "数量积为 0 表示垂直而不是向量为 0。"],
        },
        "linear_algebra": {
            "title": "线性代数结构图",
            "fallback_focus": "矩阵、向量空间、特征值或线性变换",
            "coordinate_system": "matrix_transform",
            "core_layer_type": "matrix_map",
            "drawing_hint": "用矩阵表格、向量映射或特征方向示意图展示变换前后关系。",
            "observation_hint": "把矩阵运算看成空间变换，重点观察基向量、特征方向和维数变化。",
            "parameter_hint": "可把矩阵元素、特征值或变换系数作为控件。",
            "default_step": "先确定矩阵结构，再分析秩、行列式、逆矩阵或特征值。",
            "student_tasks": ["标出矩阵作用前后的基向量。", "把特征值对应的伸缩倍数写在特征方向旁。"],
            "render_hints": ["矩阵块和向量箭头并列展示。", "若涉及行变换，展示每一步矩阵变化。"],
            "annotations": ["基向量", "特征方向", "秩/维数", "行变换"],
            "misconception_checks": ["矩阵乘法顺序不能交换。", "可逆与行列式非零、满秩要对应检查。"],
        },
        "algebra": {
            "title": "代数关系拆解图",
            "fallback_focus": "方程、不等式或代数变形链",
            "coordinate_system": "symbolic_flow",
            "core_layer_type": "formula_flow",
            "drawing_hint": "把条件、变形、目标结论拆成流程节点，并标出等价变形和非等价推理。",
            "observation_hint": "先确认每一步变形是否等价，再关注定义域、符号和取值范围。",
            "parameter_hint": "可把未知量、参数范围或临界点作为控件。",
            "default_step": "先整理条件和目标，再逐步做等价变形或分类讨论。",
            "student_tasks": ["把条件、目标和关键变形写成节点。", "遇到不等式时单独标出符号变化和范围限制。"],
            "render_hints": ["等价变形用实线箭头，分类讨论用分支节点。", "定义域和限制条件放在固定提示区。"],
            "annotations": ["定义域", "等价变形", "分类讨论", "临界点"],
            "misconception_checks": ["开方、平方、约分可能引入或丢失解。", "不等式乘除负数要变号。"],
        },
    }
    return profiles.get(scene, profiles["algebra"])


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


def _math_detect_parameters(text: str) -> List[str]:
    reserved = {"x", "y", "n", "m"}
    params: List[str] = []
    for match in re.finditer(r"(?<![a-zA-Z])([a-zA-Z])(?=\s*(?:为|是|∈|>|<|=|,|，|、|[+\-*/^]))", text):
        name = match.group(1)
        if name.lower() not in reserved and name not in params:
            params.append(name)
    for name in ["a", "b", "c", "k", "p", "q", "t"]:
        if re.search(rf"(?<![a-zA-Z]){name}(?![a-zA-Z])", text, re.IGNORECASE) and name not in params:
            params.append(name)
    return params


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

    has_content = any(
        isinstance(parsed.get(key), list) and len(parsed.get(key) or []) > 0
        for key in ["plot_suggestions", "student_tasks", "step_mapping", "render_hints"]
    )
    visual_model = parsed.get("visual_model")
    if isinstance(visual_model, dict) and visual_model:
        has_content = True
    return has_content


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
