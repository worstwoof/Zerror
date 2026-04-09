# 🌿 错题都队 (Cuoti DouDui) 

> **产品 Slogan：不在错误中焦虑，在灵感中生长。**
> 
> 🏆 **vivo × 南开大学 AIGC 创新大赛参赛作品**

![Flutter](https://img.shields.io/badge/Frontend-Flutter-02569B?logo=flutter&logoColor=white)
![Android](https://img.shields.io/badge/OS-OriginOS_Widget-3DDC84?logo=android&logoColor=white)
![FastAPI](https://img.shields.io/badge/Backend-FastAPI-009688?logo=fastapi&logoColor=white)
![AI](https://img.shields.io/badge/AI_Engine-LLM_%2B_Stable_Diffusion-FF6F00?logo=openai&logoColor=white)

## 💡 痛点与破局 (Why We Built This)

传统的错题本是“冷冰冰的扣分记录”，加重了年轻人的学习焦虑。
**「错题都队」** 利用 AIGC（大语言模型 + 视觉生成模型），将每一次的做题失误，重构为招募进专属数字战队的“知识精灵”。我们打通了从「视觉识别 -> 认知诊断 -> 视觉重构 -> 兴趣演练」的完整多模态闭环。

---


## 🏗️ 全栈工程目录说明 (Monorepo Architecture)

本项目采用严格的前后端分离与 AI 引擎解耦架构，确保高并发下的 AIGC 响应稳定性。

```text
cuoti-doudui-repo/
│
├── .github/                      # 🤖 DevOps 与自动化流水线
│   └── workflows/                # CI/CD 脚本 (代码格式检查、一键打包 APK)
│
├── docs/                         # 📚 团队核心契约文档库
│   ├── api_contracts.md          # ⚠️ 前后端联调的 JSON 接口协议规范 (核心桥梁)
│   ├── db_schema.md              # 数据库 ER 图与表结构设计
│   └── ai_prompts_log.md         # AIGC 炼丹记录 (记录高质量的生图/文本提示词参数)
│
├── frontend/                     # 📱 客户端源码 (Flutter + OriginOS 原生层)
│   ├── android/                  # 纯血 Android 原生工程
│   │   └── app/src/main/java/com/cuotidoudui/
│   │       ├── originos_widget/  # 🌟 vivo 专属：OriginOS 桌面原子组件原生 Kotlin 代码
│   │       └── intent/           # 🌟 vivo 专属：Jovi 语音意图识别接入层
│   ├── assets/                   # 静态资源管理
│   │   └── images/               # 存放应用 Logo、多状态启动页与暗调微质感背景图 (auth_bg 等)
│   └── lib/                      # Flutter UI 与跨平台业务逻辑
│       ├── core/                 # 核心基座：主题配置、全局常量、原生通信通道 (MethodChannel)
│       ├── data/                 # 数据驱动层：API 请求封装 (Dio)、本地缓存与数据模型
│       └── screen/               # 核心视图层 (UI 渲染与状态分发)
│           ├── base/             # 👑 核心主干业务模块集合
│           │   # 包含：
│           │   # 1. 基础导航与档案：home_screen (主页), profile_screen (个人中心)
│           │   # 2. 身份与安全：login_screen, register_screen (鉴权链路)
│           │   # 3. 游戏化特训系统：weakness_practice (闯关地图), level_*, final_exam (沉浸式模考)
│           │   # 4. 智能引擎接口：smart_review (艾宾浩斯记忆闪卡), manual_entry (沉浸式 LaTeX 录入)
│           │   # 5. 数据面板：data_dashboard_screen (学情可视化)
│           ├── capture/          # 📸 错题捕捉与 OCR 录入流 (包含：error_preview, error_edit)
│           ├── detail/           # 🗂️ 档案室详情展示视图
│           └── training/         # ⚔️ 专属训练模式相关扩展视图
│
├── backend/                      # ⚙️ 后端高并发服务 (FastAPI)
│   ├── app/
│   │   ├── api/v1/               # RESTful API 路由层 (auth, upload, flashcards)
│   │   ├── core/                 # 环境配置读取与跨域设置
│   │   ├── db/                   # PostgreSQL 数据库 ORM 模型与 SQLAlchemy Session
│   │   ├── schemas/              # Pydantic 数据验证 (严格校验前后端数据格式)
│   │   └── worker/               # 🌟 Celery 异步任务队列 (防止 AIGC 长耗时阻塞主线程)
│   ├── Dockerfile                # 后端服务容器化打包脚本
│   └── requirements.txt          # 后端 Python 依赖清单
│
├── ai_engine/                    # 🧠 AIGC 魔法引擎 (完全独立的 Python 处理包)
│   ├── llm_logic/                # 🧠 左脑：大语言模型处理模块
│   │   ├── prompts_config.yaml   # 核心系统提示词统一配置文件
│   │   ├── ocr_parser.py         # 调用 OCR 并进行脏数据清洗与公式重构
│   │   ├── diagnostic_chain.py   # LangChain 逻辑链：题型识别 -> 错因诊断 -> 解法提取
│   │   ├── expand_chain.py       # 衍生题生成器：将底层逻辑注入用户兴趣语境
│   │   └── emotion_generator.py  # 情绪价值驱动：生成专属治愈寄语的小脚本
│   │
│   ├── vision_synthesis/         # 👁️ 右脑：视觉多模态生成模块
│   │   ├── sd_api_client.py      # Stable Diffusion API 调用封装与参数控制
│   │   ├── prompt_builder.py     # 动态组装生图 Prompt (结合学科风格与用户审美)
│   │   └── card_renderer.py      # 🌟 核心排版器：用 Pillow 将题目、解析与精灵图合成精美闪卡
│   │
│   └── requirements.txt          # AI 专属依赖 (LangChain, Pillow, Requests 等)
│
├── scripts/                      # 🛠️ 效率自动化工具箱
│   ├── run_all.sh                # 本地一键启动后端全家桶 (FastAPI + Celery)
│   └── test_ai_mock.py           # ⚠️ AI 工程师生命线：不依赖前后端，单脚本跑通 AIGC 全链路测试
│
├── docker-compose.yml            # 🐳 容器编排配置 (一键拉起 PostgreSQL 和 Redis 基础组件)
└── .env.example                  # 环境变量配置模板 (用于存放数据库密码、大模型 API Key)
```

---

"我们不制造标准答案，我们只负责让灵感发芽。" —— Cuoti DouDui Team

