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

    if any(keyword in normalized for keyword in ["数学", "线性代数", "高数", "概率", "函数", "导数", "积分", "几何"]):
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
    scene = "function"
    title = "函数图像联动分析"
    hints = [
        "先观察定义域、零点、对称性，再决定图像走势。",
        "把题目中的关键参数作为滑块，观察图像变化趋势。",
    ]
    keywords = cleaned_question.lower()
    if any(token in keywords for token in ["几何", "三角形", "圆", "抛物线", "椭圆", "双曲线"]):
        scene = "geometry"
        title = "几何构型草图建议"
        hints = [
            "先固定关键点与约束，再逐步标出边、角或切线关系。",
            "优先把题目中的不变量写进图中，便于后续推理。",
        ]
    elif any(token in keywords for token in ["概率", "统计", "分布", "样本"]):
        scene = "statistics"
        title = "统计分布可视化建议"
        hints = [
            "先整理样本空间与随机变量，再决定柱状图或折线图。",
            "对比期望、方差或频率变化时，建议分系列展示。",
        ]

    content = {
        "renderer": "generic_chart_spec",
        "scene": scene,
        "title": title,
        "question_excerpt": cleaned_question[:220],
        "knowledge_points": knowledge_points[:4],
        "plot_suggestions": [
            {
                "label": "核心对象",
                "value": knowledge_points[0] if knowledge_points else "题目中的主函数或核心几何对象",
            },
            {
                "label": "推荐坐标/画法",
                "value": {
                    "function": "建立直角坐标系，标出截距、极值点和单调区间。",
                    "geometry": "先画骨架图，再叠加中点、垂线、角平分线等辅助元素。",
                    "statistics": "先列数据表，再映射到柱状图、折线图或箱线图。",
                }[scene],
            },
        ],
        "student_tasks": hints,
        "step_mapping": solution_steps[:3],
    }
    return RichArtifact(
        artifact_type="chart_spec",
        title=title,
        description="为数学题生成一个可继续接图表渲染器的结构化图像方案。",
        mime_type="application/json",
        content=json.dumps(content, ensure_ascii=False, indent=2),
    )


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
        return isinstance(parsed, dict)

    return True


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
