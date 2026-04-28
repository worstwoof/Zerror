
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
    <img src="https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white" />
    <img src="https://img.shields.io/badge/vivo-OCR_&_LLM-6E56CF?style=flat-square&logo=magic&logoColor=white" />
  </p>

  <p><em>🏆 vivo × 南开大学 AIGC 创新大赛“错题都队”参赛作品</em></p>
</div>

---

# 📖 项目简介 

传统错题本更多承担“记录错误”的功能，却很少真正帮助用户**理解错误、消化错误、转化错误**。对于许多中学生来说，错题积累得越多，焦虑感反而越强，复习过程也容易陷入机械重复、缺少反馈和动力的泥潭。

**知芽 Zerror** 以“**AI 错题重构**”为核心思路，尝试将错题整理从静态记录升级为动态成长系统。项目围绕“**识别 - 诊断 - 重构 - 训练 - 复习**”的闭环展开，通过图片识别、AI 解析、学习产物生成与云端同步，让每一次错误都不只是被记录下来，而是被进一步理解、利用和延展。

**🚀 当前版本更新进展：**
当前版本已经从早期的界面原型，推进到了具备**前端界面、后端服务、数据库存储、对象存储上传、蓝心大模型 OCR / 文本与图像分析链路**的已部署可运行形态。它不只是概念展示，而是朝着真实学习应用场景继续落地。

**当前已打通的核心链路：**
- 用户注册、登录、会话管理与基础账号体系
- 错题图片上传、蓝心大模型 OCR 提取与文本清洗
- 文本分析、图片分析与多模态学科扩展产物生成
- 错题状态、用户资料、设备信息与学习快照的云端同步
- 腾讯云 PostgreSQL + 腾讯云 COS + Docker 容器化部署

---

## 📸 项目一览

> 💡 *注：以下为产品界面演示，展示了知芽核心的学习闭环。*

| 收录与解析 | 衍生与沉淀|
| :---: | :---: |
| ![首页/数据看板](./img/placeholder5.png)<br>📊 **数据看板**：首页聚合复习入口与弱项提醒 | ![衍生题训练营](./img/placeholder2.png)<br>🔄 **举一反三**：AI 提取底层逻辑并生成训练内容 |
| ![错题拍照/预览](./img/placeholder1.png)<br>📸 **智能收录**：拍照 / 图片导入与 OCR 识别 | ![动态视图](./img/placeholder6.png)<br>☁️ **可视化讲解**：账号、资料与学习状态跨端同步保存 |
| ![AI解析页](./img/placeholder3.png)<br>🧠 **深度解析**：知识点标签、错因定位与步骤拆解 | ![错题档案](./img/placeholder4.png)<br>💎 **错题积累**：错题转化为“知植闪卡”等学习产物 |


---

## ✨ 核心功能亮点

### 1. 📸 智能错题收录
- **多渠道导入**：支持拍照上传、图片导入与手动录入。
- **OCR 减负**：深度结合 **蓝心大模型 OCR** 提取题面文本，并进行基础清洗与规范化处理，照比传统记录方式为学生减负。
- **复杂内容处理**：为数学公式、理科题干、图片题等复杂学习内容保留了完善的扩展空间。

### 2. 🧠 知芽 AI 深度解析
- **结构化诊断**：围绕题目生成知识点、步骤拆解、错因定位与复习建议。
- **双链路解析**：既支持纯文本分析，也打通了“图片上传 → OCR → AI 解析”的完整视觉链路。
- **陪伴式反馈**：强调“说人话”的解析表达，让 AI 更像学习伙伴，有效降低用户对错题的抗拒与焦虑心理。

### 3. 🎞️ 多模态产物与衍生训练
- **逻辑迁移与扩展**：在原题基础上提取底层逻辑，生成相似题或变式题，帮助攻克薄弱点。
- **按学科定制产物**：当前版本已围绕数学、物理等方向实现扩展能力；针对部分物理题，更支持生成可嵌入 WebView 的交互式 HTML 动画演示。

### 4. ☁️ 云端同步与账号体系
- **完整账号系统**：支持注册、登录、会话校验与基础用户信息管理。
- **状态快照同步**：错题记录、收藏状态、掌握程度可实时同步到云端数据库。
- **对象存储支持**：媒体文件（图片、头像等）直连**腾讯云 COS**，便于多端共享与持久保存。

### 5. 🌱 复习闭环与成长体验
- **从错题走向训练**：不仅提示“错了”，更引导“为什么错、以后如何避免”，继续引导至复习和练习。
- **页面联动更完整**：首页、解析页、训练页、档案页和数据页已形成较完整的使用路径，告别死板列表，打造“养成系”学习体验。

---

## 💡 设计解读与创新评估 

### 一、 理念贯穿性
项目的核心理念是：**“不在错误中焦虑，让知识在灵感中发芽。”**
- **命名哲思**：“知芽”象征知识萌发；“Zerror” 不仅寄托了 “zero error（零失误）” 的期许，更承载着将 error 重新理解为成长入口的深刻意义。
- **情绪价值**：摒弃传统学习工具中过度强调“扣分、订正”的压迫感，转而提供充满呼吸感、层次感和生命感的暗绿色调卡片式轻松视觉体验。

### 二、 核心创新点
1. **升维“错题本”概念**：从“静态存储工具”升级为“理解错误、生成反馈、继续训练”的动态 AI 成长系统。
2. **情绪与认知双管齐下**：既关注精准的知识诊断，也通过友好的交互文案抚平面对错误时的挫败感。
3. **前后端与 AI 真实联动**：从本地 UI 原型进化为拥有云端数据库、文件上传与 AI 分析主链路的真实工程。

### 三、 市场前景
错题整理是中学生群体的高频长期痛点刚需。**知芽 Zerror** 目前已经具备从前端体验到后端服务的完整雏形，兼具效率工具的实用性与养成类产品的粘性。这意味着它不只是一个“概念型比赛作品”，更具备极强的落地价值与转化为真实学习产品的潜力。

---

## 🛠️ 技术架构与技术栈 

项目采用 **客户端 + 后端服务 + AI 引擎** 的三层解耦架构，保障复杂的业务模型和耗时生成任务不阻塞前端交互。

### 当前版本已落地的技术栈
* **📱 客户端 (Frontend)**: Flutter, Dart, Material Design
* **⚙️ 服务端 (Backend)**: FastAPI, Python, Pydantic, SQLAlchemy
* **🗄️ 数据与存储 (Infrastructure)**: PostgreSQL, Tencent COS (腾讯云对象存储), Docker / Docker Compose
* **🤖 AI 引擎 (AI Engine)**: 
  * 蓝心大模型 OCR
  * 蓝心大模型 文本模型 / 图像模型调用封装
  * Prompt Engineering
  * 学科扩展学习产物生成（含物理动画生成等）

### 当前已实现的核心后端接口
- `GET /api/v1/health`：健康检查
- `POST /api/v1/auth/register` & `login`：注册与登录
- `GET / PUT /api/v1/app-state/{sync_user_id}`：应用状态双向同步
- `POST /api/v1/files/upload`：媒体文件上传至 COS
- `POST /api/v1/ocr/extract`：OCR 提取与清洗
- `POST /api/v1/analysis/text` & `image`：多模态错题分析
- `POST /api/v1/analysis/physics-animation`：物理动画产物生成

---

## 📁 项目结构 (Project Structure)

```text
Zerror/
├── .github/workflows/               # CI/CD 自动化流水线
├── docs/                            # 接口契约、部署说明、设计记录
├── frontend/                        # Flutter 客户端工程
│   ├── android/                     # Android 原生平台能力接入
│   ├── assets/                      # 图片、背景、品牌资源等静态素材
│   └── lib/
│       ├── core/                    # 全局状态、主题、原生通道、会话管理
│       ├── data/                    # 接口客户端、数据模型与数据封装
│       └── screen/                  # 核心业务视图 (base, capture 等)
├── backend/                         # FastAPI 后端服务
│   ├── app/
│   │   ├── api/v1/                  # auth / app-state / files / upload 等路由
│   │   ├── core/                    # 核心配置、鉴权、对象存储
│   │   ├── db/                      # ORM 模型与数据库连接
│   │   ├── schemas/                 # Pydantic 数据结构验证
│   │   └── services/                # 应用状态同步等核心业务逻辑
│   └── Dockerfile                   # 后端容器化构建脚本
├── ai_engine/                       # AI 能力引擎模块
│   ├── llm_logic/                   # OCR 清洗、vivo 诊断链、衍生题与学科扩展
│   └── vision_synthesis/            # 视觉合成方向预留
├── docker-compose.yml               # 后端服务本地/云端容器编排
└── .env.example                     # 环境变量模板
```

---

## 👥 开发团队 

本项目围绕需求分析、界面实现、AI 链路打通与服务端部署协同推进：

| 姓名 | 负责模块 | 核心贡献 |
| :---: | :--- | :--- |
| **[黄子豪]** | 🎨 **客户端与 UI** | Flutter 页面实现、视觉氛围设计、核心交互流程与主要学习页面开发 |
| **[蔡子涵]** | 🔌 **AI 链路集成** | vivo OCR / 文本 / 图像能力接入，端到端 AI 数据流封装与返回结构设计 |
| **[张天译]** | 📝 **文档与表达** | 项目理念整理、方案说明文案、项目策划与展示 README 撰写 |
| **[金宇辰]** | ⚙️ **服务端与部署** | FastAPI 架构设计、数据库建模、应用状态同步、腾讯云数据库与 COS 部署 |
| **[林子媛]** | 🤖 **Prompt 调优** | AI 解析风格、错因分析逻辑、学科扩展提示词与输出稳定性调试 |
---

<div align="center">
  <p><strong>知芽 Zerror</strong> —— 让每一次错误，都成为知识发芽的起点。</p>
</div>
```
