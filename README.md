<div align="center">
  <img src="https://img.shields.io/badge/AIGC-Education-423B63?style=for-the-badge&logo=openai&logoColor=white&labelColor=1B305D" alt="Zerror Logo" />

  <h1 style="font-family: 'Orbitron', sans-serif;">🌱 知芽 Zerror </h1>

  <p>
    <strong>不在错误中焦虑，让知识在灵感中发芽 | 面向中学学习场景的 AIGC 智能错题成长应用</strong>
  </p>

  <p>
    <img src="https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white" />
    <img src="https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white" />
    <img src="https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white" />
    <img src="https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white" />
    <br/>
    <img src="https://img.shields.io/badge/PostgreSQL-4169E1?style=flat-square&logo=postgresql&logoColor=white" />
    <img src="https://img.shields.io/badge/Tencent_COS-00A4FF?style=flat-square&logo=tencentqq&logoColor=white" />
    <img src="https://img.shields.io/badge/Manim-Blackboard_Video-2C7A7B?style=flat-square" />
    <img src="https://img.shields.io/badge/GeoGebra-Interactive_Graph-EF8A17?style=flat-square" />
    <img src="https://img.shields.io/badge/vivo-OCR_&_LLM-6E56CF?style=flat-square&logo=magic&logoColor=white" />
  </p>

  <p><em>🏆 vivo × 南开大学 AIGC 创新大赛“错题都队”参赛作品</em></p>
</div>

------

# 📖 项目简介

传统错题本更多承担“记录错误”的功能，却很少真正帮助用户**理解错误、消化错误、转化错误**。对于许多中学生来说，错题积累得越多，焦虑感反而越强，复习过程也容易陷入机械重复、缺少反馈和动力的泥潭。

**知芽 Zerror** 以“**AI 错题重构**”为核心思路，尝试将错题整理从静态记录升级为动态成长系统。项目围绕“**识别 - 诊断 - 重构 - 可视化 - 训练 - 复习**”的闭环展开，通过图片识别、AI 深度解析、学科拓展产物、动态讲解视频与云端同步，让每一次错误都不只是被记录下来，而是被进一步理解、利用和延展。

**🚀 当前版本更新进展：**
当前版本已经在原有前端界面、后端服务、数据库存储、对象存储上传、蓝心大模型 OCR / 文本与图像分析链路基础上，继续打通了**双阶段图片解析后台任务、数学 GeoGebra 交互图、Manim 黑板风格讲解视频、ManimCat 数学渲染侧车、物理场景动画模板与前端可视化预览页**。它不只是“能识别、能解析”的错题工具，而是开始具备“能讲清、能演示、能等待、能重试”的真实学习产品形态。

**当前已打通的核心链路：**

- 用户注册、登录、会话管理与基础账号体系
- 错题图片上传、蓝心大模型 OCR 提取、文本清洗与题干保底保存
- 图片解析后台任务：先返回 OCR / 基础卡片，再异步生成高质量详解
- 文本分析、图片分析、数学图形、物理动画与多学科扩展产物生成
- GeoGebra 交互图、Manim / ManimCat 讲解视频与前端 WebView / 视频预览
- 错题状态、用户资料、设备信息与学习快照的云端同步
- 腾讯云 PostgreSQL + 腾讯云 COS + Docker 容器化部署

------

## 📸 项目一览

> 💡 *注：以下为产品界面演示，展示了知芽从收录、解析到可视化讲解的学习闭环。*

|                          收录与解析                          |                         可视化与沉淀                         |
| :----------------------------------------------------------: | :----------------------------------------------------------: |
| ![首页/数据看板](./img/placeholder5.png)<br>📊 **数据看板**：首页聚合复习入口、错题档案与弱项提醒 | ![衍生题训练营](./img/placeholder2.png)<br>🔄 **举一反三**：AI 提取底层逻辑并生成训练内容 |
| ![错题拍照/预览](./img/placeholder1.png)<br>📸 **智能收录**：拍照 / 图片导入、OCR 识别与后台排队解析 | ![动态视图](./img/placeholder6.png)<br>🎬 **可视化讲解**：GeoGebra 交互图与 Manim 黑板视频辅助理解 |
| ![AI解析页](./img/placeholder3.png)<br>🧠 **深度解析**：知识点标签、错因定位、步骤拆解与 LaTeX 公式渲染 | ![错题档案](./img/placeholder4.png)<br>💎 **错题积累**：错题转化为复盘卡片、图形草图和学习产物 |

------

## ✨ 核心功能亮点

### 1. 📸 智能错题收录

- **多渠道导入**：支持拍照上传、图片导入与手动录入，适配移动端真实拍题场景。
- **OCR 减负**：深度结合 **蓝心大模型 OCR** 提取题面文本，并进行基础清洗与规范化处理，照比传统记录方式为学生减负。
- **题目不丢保底**：图片解析链路即使遇到上游模型超时，也会优先保留 OCR 题干和基础错题卡，避免一次拍题因为等待过长而失效。

### 2. 🧠 知芽 AI 深度解析

- **结构化诊断**：围绕题目生成知识点、步骤拆解、错因定位、复习建议与相似题。
- **双链路解析**：既支持纯文本分析，也打通了“图片上传 → OCR → AI 解析”的完整视觉链路。
- **高质量二阶段生成**：新增后台解析任务，第一阶段返回可展示的 OCR / 基础结果，第二阶段使用质量模型补全完整推导、公式、错因与复习建议。
- **陪伴式反馈**：强调“说人话”的解析表达，让 AI 更像学习伙伴，有效降低用户对错题的抗拒与焦虑心理。

### 3. 📐 数学图形与复盘卡

- **数学结构化卡片**：围绕函数、几何、圆锥曲线、导数、概率统计、数列、向量、线性代数等题型生成 `chart_spec` 复盘内容。
- **坐标辅助图**：函数、导数与圆锥曲线类题可生成 `coordinate_graph`，呈现曲线、辅助线、关键点和学生操作建议。
- **GeoGebra 交互图**：后端将结构化场景转为安全 GeoGebra 命令，前端用 WebView 展示动点、切线、圆锥曲线、多情形参数等交互内容。
- **Manim 数学视频**：数学题可进入 Manim / ManimCat 渲染队列，生成黑板风格讲解视频，适合展示题干高亮、图形变化与逐步推导。

### 4. 🎬 物理动画与场景讲解

- **Manim 物理讲解**：针对力学、木板-物块、电磁场、光学、波动、斜面、抛体、碰撞等场景生成结构化动画视频任务。
- **黑板式推导流程**：视频不只展示运动，还会把“研究对象、受力方向、运动关系、列式推导”拆成清晰步骤，减少学生看动画但不懂公式的断层。
- **HTML 交互兜底**：部分物理题仍可生成可嵌入 WebView 的 HTML 演示页，覆盖受力运动、电路、光路等轻量场景。
- **失败不影响详解**：动画是增强内容，渲染失败会返回友好提示和 diagnostics，不影响题目解析卡片本身完成。

### 5. ☁️ 云端同步与账号体系

- **完整账号系统**：支持注册、登录、登出、会话校验与基础用户信息管理。
- **状态快照同步**：错题记录、收藏状态、掌握程度、设备信息与学习快照可同步到云端数据库。
- **对象存储支持**：媒体文件（图片、头像等）直连**腾讯云 COS**，便于多端共享与持久保存。

### 6. 🧩 多学科扩展产物

- **数学**：复盘卡、坐标辅助图、GeoGebra 场景、Manim 视频。
- **物理**：Manim 动画、HTML 过程演示、受力和运动关系可视化。
- **化学**：反应条件、实验步骤、平衡移动等知识卡片。
- **编程**：代码骨架、执行轨迹、调试清单与输入输出样例。
- **生物**：过程时间线，适合承接代谢、遗传、生态循环等阶段化内容。

### 7. 🌱 复习闭环与成长体验

- **从错题走向训练**：不仅提示“错了”，更引导“为什么错、以后如何避免”，继续引导至复习和练习。
- **页面联动更完整**：首页、拍题页、解析页、学科拓展页、错题档案页和数据页已形成较完整的使用路径。
- **公式阅读更自然**：前端补充 LaTeX 文本组件，对裸公式、分式、根号、上下标等内容做渲染适配，让理科题解析更像可读讲义。

------

## 💡 设计解读与创新评估

### 一、理念贯穿性

项目的核心理念是：**“不在错误中焦虑，让知识在灵感中发芽。”**

- **命名哲思**：“知芽”象征知识萌发；“Zerror” 不仅寄托了 “zero error（零失误）” 的期许，更承载着将 error 重新理解为成长入口的深刻意义。
- **情绪价值**：摒弃传统学习工具中过度强调“扣分、订正”的压迫感，转而提供充满呼吸感、层次感和生命感的暗绿色调卡片式轻松视觉体验。
- **等待体验**：针对 AI 生成慢、视频渲染慢的真实问题，使用后台任务、进度轮询、部分成功和重试机制，把“卡住”变成“先给你可用内容，后面继续补全”。

### 二、核心创新点

1. **升维“错题本”概念**：从“静态存储工具”升级为“理解错误、生成反馈、继续训练、动态演示”的 AI 成长系统。
2. **情绪与认知双管齐下**：既关注精准的知识诊断，也通过友好的交互文案抚平面对错误时的挫败感。
3. **多模态解释闭环**：OCR、文本解析、图像分析、GeoGebra 交互图、Manim 视频和学科卡片形成连续链路。
4. **工程化可落地**：后台任务、渲染队列、静态媒体服务、Docker 镜像、CJK 字体和 LaTeX 依赖，让演示能力更接近真实部署环境。

### 三、市场前景

错题整理是中学生群体的高频长期痛点刚需。**知芽 Zerror** 目前已经具备从前端体验到后端服务、从文字解析到动态讲解、从本地状态到云端同步的完整雏形，兼具效率工具的实用性与养成类产品的粘性。这意味着它不只是一个“概念型比赛作品”，更具备转化为真实学习产品的潜力。

------

## 🛠️ 技术架构与技术栈

项目采用 **客户端 + 后端服务 + AI 引擎 + 渲染管线** 的分层架构，保障复杂的业务模型、耗时 AI 生成任务和视频渲染任务不阻塞前端交互。

### 当前版本已落地的技术栈

- **📱 客户端 (Frontend)**: Flutter, Dart, Material Design, WebView, video_player, LaTeX 渲染组件
- **⚙️ 服务端 (Backend)**: FastAPI, Python, Pydantic, SQLAlchemy, 后台线程任务
- **🗄️ 数据与存储 (Infrastructure)**: PostgreSQL, Tencent COS (腾讯云对象存储), Docker / Docker Compose, 静态媒体服务
- **🤖 AI 引擎**:
  - 蓝心大模型 OCR
  - 蓝心大模型文本模型 / 图像模型调用封装
  - 高质量文本解析二阶段生成
  - Prompt Engineering 与学科拓展产物生成
- **🎞️ 可视化渲染**:
  - GeoGebra 结构化交互图
  - Manim 本地视频渲染
  - ManimCat 数学视频侧车服务
  - manim-physics 物理组件快照
  - FFmpeg、LaTeX、Noto CJK 字体与 Docker 镜像支持

### 当前已实现的核心后端接口

- `GET /api/v1/health`：健康检查
- `POST /api/v1/auth/register` & `POST /api/v1/auth/login`：注册与登录
- `GET /api/v1/auth/me` & `POST /api/v1/auth/logout`：会话查询与登出
- `GET / PUT /api/v1/app-state/{sync_user_id}`：应用状态双向同步
- `POST /api/v1/files/upload`：媒体文件上传至 COS
- `POST /api/v1/ocr/extract`：OCR 提取与清洗
- `POST /api/v1/analysis/text`：文本错题解析
- `POST /api/v1/analysis/image`：图片 OCR + 解析兼容链路
- `POST /api/v1/analysis/image/jobs`：创建双阶段图片解析后台任务
- `GET /api/v1/analysis/image/jobs/{job_id}`：轮询图片解析任务状态
- `POST /api/v1/analysis/image/jobs/{job_id}/retry`：基于已有 OCR 结果重试高质量详解
- `POST /api/v1/analysis/physics-animation`：创建数学 / 物理 Manim 视频增强内容
- `POST /api/v1/render/geogebra`：将结构化场景转为 GeoGebra 交互图 payload
- `POST /api/v1/render/manim`：创建 Manim 视频渲染任务
- `GET /api/v1/render/manim/{job_id}`：查询 Manim 渲染进度和视频地址

### 双阶段任务设计

- 第一阶段：完成 OCR，返回题干、基础错题卡和 `partial_result`，保证拍题内容先落地。
- 第二阶段：后台调用高质量模型补全完整答案、公式推导、错因分析、复习计划和学科拓展。
- 失败策略：如果第二阶段失败，任务保留 `partial_success`，前端可展示基础结果并提供“重新生成详解”。
- 视频策略：Manim 渲染任务独立于解析结果，视频失败不阻断错题详解。

------

## 📁 项目结构

```text
Zerror/
├── docs/                            # 接口契约、部署说明、设计记录
├── frontend/                        # Flutter 客户端工程
│   ├── android/                     # Android 原生平台能力接入与应用图标
│   ├── assets/                      # 图片、背景、品牌资源等静态素材
│   └── lib/
│       ├── core/                    # 全局状态、常量、LaTeX 渲染、会话管理
│       ├── data/                    # AI API 客户端、后台任务与渲染任务数据结构
│       └── screen/
│           ├── base/                # 首页、档案、计划、用户资料等基础页面
│           └── capture/             # 拍题、编辑、AI 解析、GeoGebra / Manim 预览页
├── backend/                         # FastAPI 后端服务
│   ├── app/
│   │   ├── api/v1/                  # auth / app-state / files / upload / render 路由
│   │   ├── core/                    # 环境变量、核心配置、鉴权、对象存储
│   │   ├── db/                      # ORM 模型与数据库连接
│   │   ├── rendering/               # GeoGebra 与 Manim 渲染器
│   │   ├── schemas/                 # Pydantic 数据结构验证
│   │   └── services/                # 解析任务、渲染任务、ManimCat 客户端等业务逻辑
│   └── Dockerfile                   # 后端容器化构建脚本，内置 Manim / LaTeX / CJK 字体依赖
├── ai_engine/                       # AI 能力引擎模块
│   └── llm_logic/                   # OCR 清洗、vivo 诊断链、学科扩展、数学 / 物理场景生成
├── scripts/                         # 分析质量与渲染诊断测试脚本
├── third_party/
│   ├── manim-physics/               # 物理动画组件快照
│   └── manimcat/                    # 数学 Manim 视频侧车服务源码快照
├── static/media/manim/              # 后端运行时生成的 Manim 视频与任务状态
├── docker-compose.yml               # 后端服务本地/云端容器编排
└── .env.example                     # 环境变量模板，含 vivo、COS、ManimCat 配置
```

------

## 🔧 运行与配置提示

### 后端关键环境变量

- `DATABASE_URL`：PostgreSQL 或本地 SQLite 连接串
- `TENCENT_COS_SECRET_ID` / `TENCENT_COS_SECRET_KEY` / `TENCENT_COS_REGION` / `TENCENT_COS_BUCKET`：对象存储配置
- `VIVO_API_KEY` / `VIVO_APP_ID`：蓝心大模型接口凭证
- `VIVO_TEXT_MODEL` / `VIVO_VISION_MODEL` / `VIVO_QUALITY_TEXT_MODEL`：文本、视觉和高质量解析模型配置
- `VIVO_ANIMATION_MODEL`：动画场景生成模型配置
- `MANIMCAT_BASE_URL` / `MANIMCAT_API_KEY`：ManimCat 数学视频侧车服务
- `MANIMCAT_JOB_TIMEOUT_SECONDS` / `MANIMCAT_POLL_INTERVAL_SECONDS`：数学视频任务等待与轮询配置

### 渲染依赖

后端 Docker 镜像已加入 Manim 视频所需的 `ffmpeg`、LaTeX、`dvisvgm`、Cairo、Pango、Noto CJK 字体等依赖，并使用腾讯云 apt / PyPI 镜像加速构建。数学视频可走 ManimCat 侧车服务，物理视频可走本地 Manim 渲染管线。

------

## 👥 开发团队

本项目围绕需求分析、界面实现、AI 链路打通、可视化渲染与服务端部署协同推进：

|     姓名     | 负责模块           | 核心贡献                                                     |
| :----------: | :----------------- | :----------------------------------------------------------- |
| **[黄子豪]** | 🎨 **客户端与 UI**  | Flutter 页面实现、视觉氛围设计、核心交互流程、AI 解析页与可视化预览体验开发、Manim 渲染部署 |
| **[蔡子涵]** | 🔌 **AI 链路集成**  | vivo OCR / 文本 / 图像能力接入，端到端 AI 数据流封装、后台任务与返回结构设计 |
| **[张天译]** | 📝 **文档与表达**   | 项目理念整理、方案说明文案、项目策划、展示 README 与产品表达打磨 |
| **[金宇辰]** | ⚙️ **服务端与部署** | FastAPI 架构设计、数据库建模、应用状态同步、腾讯云数据库 / COS / Docker |
| **[林子媛]** | 🤖 **Prompt 调优**  | AI 解析风格、错因分析逻辑、学科扩展提示词、数学 / 物理可视化输出稳定性调试 |

------

<div align="center">
  <p><strong>知芽 Zerror</strong> —— 让每一次错误，都成为知识发芽的起点。</p>
</div>
