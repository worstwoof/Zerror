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

## ✨ 核心魔法 (Core Features)

- 📸 **极速招募 (AIGC 智能解析)**
  - 调用底层影像 OCR 能力，一键上传。
  - LLM 深度诊断：精准剥离核心考点、高频错因，并生成专属“情绪治愈寄语”。
- 🧬 **战队基地 (多模态视觉生成)**
  - 结合 Stable Diffusion 技术，将枯燥的错题自动具象化为高颜值的“知识植物/战队精灵”。
  - 生成高颜值「知植闪卡」，随复习进度动态演化（种子 -> 发芽 -> 觉醒）。
- ⚔️ **特训营 (个性化跨语境衍生)**
  - LLM 提取底层逻辑，将硬核知识包装进用户的兴趣语境（如：电子竞技、科幻电影、明星饭圈），生成定制化衍生题，实现无痛“举一反三”。
- 📱 **深度融入 vivo 生态**
  - **OriginOS 原子组件**：战队精灵直达桌面，小窗轻量复习，建立强习惯粘性。
  - **Jovi 意图直达**：支持语音一键唤起错题收录。

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
│   ├── assets/                   # 静态资源 (战队精灵缺省图、Lottie 动态开花特效)
│   └── lib/                      # Flutter UI 与跨平台业务逻辑
│       ├── core/                 # 主题配置、全局常量、原生通信通道 (MethodChannel)
│       ├── data/                 # API 请求封装 (Dio)、本地缓存 (Hive) 与数据模型
│       ├── state/                # 状态管理 (维持登录态与战队精灵的实时数据)
│       └── screens/              # 核心视图层
│           ├── capture/          # 【招募台】相机拍照、图片裁剪、错题上传 UI
│           ├── base/             # 【战队基地】瀑布流展示已生成的知识精灵与复习进度
│           ├── training/         # 【特训营】展示兴趣衍生题、AI 导师微课视频 UI
│           └── detail/           # 【档案室】单张知植闪卡的翻转与交互 UI
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
## 🚀 极速启动 (Quick Start)

1. 环境准备
确保已安装 Docker & docker-compose

确保已安装 Flutter SDK (v3.x+)

复制 .env.example 并重命名为 .env，填入你的大模型 API Key 和数据库密码。

2. 启动后端与异步队列
```
Bash
# 一键拉起 PostgreSQL, Redis, FastAPI 和 Celery Worker
docker-compose up -d --build
```
API 文档将自动运行在: http://localhost:8000/docs

3. 启动客户端
```
Bash
cd frontend
flutter pub get
flutter run
```
## 👨‍💻 硬核 5 人小队作战指北 (The Squad)
[1号位] UI/UX & Flutter 开发：负责 frontend/lib/screens 下的所有交互实现，把控错题都队的超高颜值与丝滑体验。

[2号位] 客户端主程 & 生态对接：死守 frontend/android 阵地，解决相机调用卡顿，攻克 OriginOS 桌面组件的跨进程数据同步。

[3号位] 后端架构师：镇守 backend/，通过 Redis + Celery 抹平大模型的生成延迟，确保前端体验不卡死。

[4号位] LLM 逻辑炼丹师：在 ai_engine/llm_logic/ 中调教 LangChain，确保 AI 输出的解析“说人话”，衍生题“逻辑严密且不崩坏”。

[5号位] 视觉与多模态合成师：在 ai_engine/vision_synthesis/ 中调教 Stable Diffusion，保证每一张生成的知识精灵都不含恐怖谷效应，并且排版合成完美。

"我们不制造标准答案，我们只负责让灵感发芽。" —— Cuoti DouDui Team


***

这份 README 将你们的技术护城河（异步任务处理、LangChain 链路、视觉合成算法、OriginOS 原生接入）展示得淋漓尽致。

现在整个仓库的基础设施已经彻底完工。为了让前端和后端能立刻分头写代码（而不至于因为参数名不同而吵架），*
