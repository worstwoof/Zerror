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

### `POST /api/v1/analysis/image/jobs`

推荐给移动端批量拍题使用的双阶段接口。它会立即创建后台任务并返回 `job_id`，避免手机端长时间等待同一个 HTTP 连接。

`multipart/form-data` 字段与 `analysis/image` 相同。

返回：

```json
{
  "job_id": "24位任务ID",
  "status": "pending",
  "progress": 0,
  "message": "已加入后台解析队列。",
  "error": "",
  "created_at": 1778170000.0,
  "updated_at": 1778170000.0,
  "ocr": null,
  "partial_result": null,
  "result": null
}
```

状态约定：

- `pending`: 待解析
- `processing`: OCR 或高质量详解生成中
- `partial_success`: 已有 OCR/基础结果，高质量详解仍在生成或可重试
- `completed`: 高质量详解完成
- `failed`: 任务失败且没有可用结果
- `need_retry`: 需要用户稍后重试

### `GET /api/v1/analysis/image/jobs/{job_id}`

查询后台解析任务。前端建议每 2-4 秒轮询一次；拿到 `partial_result` 时即可先展示“已识别题目，正在生成高质量详解”，拿到 `result` 后替换为完整详解。

### `POST /api/v1/analysis/image/jobs/{job_id}/retry`

当任务已有 OCR 结果但高质量详解失败时，重新生成详解。该接口只重跑第二阶段，不要求用户重新上传图片。

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
- `chart_spec`: 数学错题复盘卡，包含题型定位、核心思路、关键变形、解题路线、二维坐标辅助图、易错提醒和复盘清单
- `code_snippet`: 编程题执行轨迹、关键代码模板、输入输出样例
- `timeline`: 生物过程流转、历史事件推演、实验步骤动画
- `study_card`: 化学反应条件卡片、语文修辞辨析卡片、英语语法对照卡

### 当前已落地的首批学科扩展

为了便于 MVP 演示，当前后端已经支持一组“按学科兜底生成”的扩展内容：

- 数学：默认补充 `chart_spec`，返回面向学生复盘的结构化卡片。当前会按题型细分为 `function`、`geometry`、`conic`、`calculus`、`statistics`、`probability`、`sequence`、`vector`、`linear_algebra`、`algebra` 等场景，并补充核心思路、关键公式/变形、解题路线、易错提醒和复盘清单；函数、导数和圆锥曲线类题可额外返回 `coordinate_graph`，用于展示曲线、辅助线、关键点和坐标标注；不再生成可交互参数等渲染器配置。
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
  "title": "导数积分复盘卡",
  "description": "把数学错题整理成可直接复盘的关键思路、变形路径和自查清单。",
  "mime_type": "application/json",
  "content": "{ \"renderer\": \"generic_chart_spec\", \"version\": 3, \"scene\": \"function\", \"topic_type\": \"function\", \"core_idea\": \"...\", \"formula_transformations\": [...], \"solution_path\": [...], \"coordinate_graph\": { \"title\": \"二维坐标辅助图\", \"x_range\": [-4, 4], \"y_range\": [-3, 3], \"curves\": [{ \"label\": \"函数图像 y=f(x)\", \"points\": [[-2, 1], [0, 0], [2, 1]] }], \"lines\": [{ \"label\": \"对称轴\", \"from\": [0, -3], \"to\": [0, 3], \"style\": \"dashed\" }], \"points\": [{ \"label\": \"A(0,0)\", \"x\": 0, \"y\": 0 }], \"student_focus\": [\"把交点、端点和单调区间放到图上核对。\"] }, \"mistake_traps\": [...], \"review_checklist\": [...], \"visual_hint\": \"...\" }"
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
