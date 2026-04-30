# API JSON 契约文档

## MVP 目标

当前版本优先打通三条链路：

1. 图片 OCR：拍照后提取题干文本。
2. 文本解析：将题目文本交给 vivo 蓝心生成结构化错题解析。
3. 图片直出：上传图片后后端先做 OCR，再继续调用解析链路，返回完整结果。

## 接口列表

### `GET /api/v1/health`

用于服务健康检查。

示例响应：

```json
{
  "status": "ok",
  "service": "Cuoti DouDui Backend",
  "version": "0.1.0"
}
```

### `POST /api/v1/ocr/extract`

`multipart/form-data`

字段：

- `image`: 题目截图或拍照文件

示例响应：

```json
{
  "raw_text": "设矩阵 A 的特征值为 λ1, λ2, λ3，且 A 可逆。求证：A 的伴随矩阵 A* 的特征值。",
  "normalized_text": "设矩阵 A 的特征值为 λ1, λ2, λ3，且 A 可逆。\n求证：A 的伴随矩阵 A* 的特征值。",
  "blocks": []
}
```

### `POST /api/v1/analysis/text`

`application/json`

请求体：

```json
{
  "question_text": "设矩阵 A 的特征值为 λ1, λ2, λ3，且 A 可逆。求证：A 的伴随矩阵 A* 的特征值。",
  "subject": "线性代数",
  "user_answer": "",
  "wrong_reason_hint": "概念模糊",
  "enable_subject_extensions": true
}
```

示例响应：

```json
{
  "question_text": "设矩阵 A 的特征值为 λ1, λ2, λ3，且 A 可逆。求证：A 的伴随矩阵 A* 的特征值。",
  "cleaned_question": "设矩阵 A 的特征值为 λ1, λ2, λ3，且 A 可逆。求证：A 的伴随矩阵 A* 的特征值。",
  "subject": "线性代数",
  "knowledge_points": ["伴随矩阵", "特征值", "逆矩阵"],
  "solution_summary": "先利用 A* = |A|A^-1，再将 A^-1 的特征值性质代入。",
  "solution_steps": [
    "由 A 可逆可得 A* = |A|A^-1。",
    "若 A 的特征值为 λ，则 A^-1 的特征值为 1/λ。",
    "因此 A* 的特征值为 |A|/λ。"
  ],
  "mistake_diagnosis": "核心概念之间的联动记忆不牢，没能把伴随矩阵和逆矩阵关系联想到一起。",
  "review_plan": {
    "next_review_in_days": 1,
    "focus": "重点回顾伴随矩阵和逆矩阵的关系",
    "schedule": [1, 3, 7, 15]
  },
  "similar_questions": [
    {
      "prompt": "若 A 的特征值为 2 和 3，求 2A^-1 的特征值。",
      "answer_outline": "先求 A^-1 的特征值，再整体乘 2。"
    }
  ],
  "rich_artifacts": [],
  "source": "text",
  "raw_model_output": "{...}"
}
```

### `POST /api/v1/analysis/image`

`multipart/form-data`

字段：

- `image`: 题目截图或拍照文件
- `subject`: 学科名，可选
- `user_answer`: 学生答案，可选
- `wrong_reason_hint`: 用户自述错因，可选
- `enable_subject_extensions`: 是否允许生成扩展展示内容，可选

返回结构与 `analysis/text` 相同，但会多一个 `ocr` 字段：

```json
{
  "source": "image",
  "ocr": {
    "raw_text": "识别原文",
    "normalized_text": "清洗后的文本",
    "blocks": []
  }
}
```

## `rich_artifacts` 扩展约定

为了支持不同学科的高表现力展示内容，`rich_artifacts` 统一设计为数组，便于后续按学科扩展：

```json
[
  {
    "artifact_type": "interactive_html",
    "title": "牛顿第二定律动画演示",
    "description": "可直接用 WebView 展示的小型交互页面",
    "mime_type": "text/html",
    "content": "<html>...</html>"
  }
]
```

当前建议支持的扩展方向：

- `interactive_html`: 物理受力分析、运动过程、光路、电路变化
- `chart_spec`: 数学函数图像、统计图、几何构型
- `code_snippet`: 编程题执行轨迹、关键代码模板、输入输出样例
- `timeline`: 生物过程流转、历史事件推演、实验步骤动画
- `study_card`: 化学反应条件卡片、语文修辞辨析卡片、英语语法对照卡

### 当前已落地的首批学科扩展

为了便于 MVP 演示，当前后端已经支持一组“按学科兜底生成”的扩展内容：

- 数学：默认补充 `chart_spec`，返回结构化图表/几何草图建议。当前会按题型细分为 `function`、`geometry`、`conic`、`calculus`、`statistics`、`probability`、`sequence`、`vector`、`linear_algebra`、`algebra` 等场景，并补充公式、可视化图层、交互参数、标注和易错检查，适合后续对接 ECharts、Canvas 或自定义坐标系渲染。
- 物理：默认补充 `interactive_html`，返回可嵌入 WebView 的小型 HTML 演示页，当前覆盖受力运动、电路、光路三类模板。
- 化学：默认补充 `study_card`，返回 JSON 卡片集合，适合做翻卡式复习界面。
- 编程：默认补充 `code_snippet`，返回 JSON 结构的代码骨架、调试清单与执行步骤。
- 生物：默认补充 `timeline`，返回 JSON 时间线结构，适合后续接过程动画或阶段组件。

说明：

- 如果大模型本身已经返回了该学科对应的扩展类型，后端不会重复追加同类型 artifact。
- 如果大模型没有返回扩展内容，但 `enable_subject_extensions=true`，后端会自动补一个默认 artifact，保证演示链路稳定。

### 学科扩展示例

数学 `chart_spec` 示例：

```json
{
  "artifact_type": "chart_spec",
  "title": "函数图像联动分析",
  "description": "为数学题生成一个可继续接图表渲染器的结构化图像方案。",
  "mime_type": "application/json",
  "content": "{ \"renderer\": \"generic_chart_spec\", \"version\": 2, \"scene\": \"function\", \"expressions\": [...], \"visual_model\": {...}, ... }"
}
```

物理 `interactive_html` 示例：

```json
{
  "artifact_type": "interactive_html",
  "title": "受力与运动演示",
  "description": "可直接接入 WebView 的物理过程演示页面骨架。",
  "mime_type": "text/html",
  "content": "<!DOCTYPE html><html>...</html>"
}
```

化学 `study_card` 示例：

```json
{
  "artifact_type": "study_card",
  "title": "化学平衡复习卡片",
  "description": "将化学题拆成可快速翻看的知识卡片。",
  "mime_type": "application/json",
  "content": "{ \"cards\": [{\"front\": \"先判断什么\", \"back\": \"...\"}] }"
}
```

## 前端对接建议

现有 Flutter 页面可以按最小改动接入：

1. 预览页的“提取文字”按钮先调用 `POST /api/v1/ocr/extract`。
2. 文本确认页允许用户编辑 `normalized_text`。
3. 点击“生成我的错题档案”时调用 `POST /api/v1/analysis/text`。
4. 如果后续想减少一次请求，也可以直接在拍照后调用 `POST /api/v1/analysis/image`。
