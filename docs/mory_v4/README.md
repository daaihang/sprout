# Mory v4 Documentation Set

> 更新时间：2026-05-16
> 适用范围：多模态输入、上下文自动采集、AI 处理链、认证持久化、数据同步、主页卡片连接

本目录是 `Mory v4` 的目标态规范文档。

v3 建立了统一的五层记忆本体和端到端链路。v4 在此基础上解决三个问题：

1. 输入太窄——只有文字，用户无法把真实生活带进来
2. 上下文太少——系统不知道用户在哪、什么天气、听什么歌
3. 基础设施缺失——登录不持久、数据不同步、AI 太慢

## v3 已完成的能力

- 五层本体：Artifact → Composition → Graph → Arc → Reflection
- 端到端链路：Capture → AI Analyze → Graph Update → Arc Promote → Reflection Generate
- 七个 Tab：Home / Memories / Timeline / People / Arcs / Search / Reflections
- 基础 Capture：文字 + 照片选择 + 录音（未过 AI）
- Apple 登录（未持久化）
- 全量本地化（en + zh-Hans 222 条）
- Debug 诊断系统

## v4 要解决的能力

1. 多模态输入：图片解析、录音转文字、音乐采集、链接提取
2. 上下文自动采集：天气、地点、当前活动
3. AI 处理链：每种 Artifact 的 AI 处理规则
4. 基础设施：认证持久化、AI 速度优化
5. 主页卡片与数据连接
6. AI 内容把关

## 阅读顺序

如果你是产品负责人：

1. [PRD/00_v4_prd_index.md](PRD/00_v4_prd_index.md)
2. [PRD/01_v4_scope_and_goals.md](PRD/01_v4_scope_and_goals.md)
3. [PRD/02_artifact_input_matrix.md](PRD/02_artifact_input_matrix.md)
4. [PRD/03_capture_flows.md](PRD/03_capture_flows.md)
5. [PRD/04_ai_processing_rules.md](PRD/04_ai_processing_rules.md)
6. [PRD/05_context_auto_collection.md](PRD/05_context_auto_collection.md)
7. [PRD/06_home_board_connection.md](PRD/06_home_board_connection.md)

如果你是架构/工程负责人：

1. [Architecture/00_v4_architecture_index.md](Architecture/00_v4_architecture_index.md)
2. [Architecture/01_artifact_kind_expansion.md](Architecture/01_artifact_kind_expansion.md)
3. [Architecture/02_capture_pipeline.md](Architecture/02_capture_pipeline.md)
4. [Architecture/03_ai_artifact_processors.md](Architecture/03_ai_artifact_processors.md)
5. [Architecture/04_auto_context_services.md](Architecture/04_auto_context_services.md)
6. [Architecture/05_auth_persistence.md](Architecture/05_auth_persistence.md)
7. [Architecture/06_ai_speed_optimization.md](Architecture/06_ai_speed_optimization.md)
8. [Architecture/07_build_roadmap.md](Architecture/07_build_roadmap.md)

## 核心判断

v4 不改变 v3 的五层本体。它只做一件事：

> 把 Artifact 从 "只有文字" 扩展到 "图片、录音、音乐、地点、天气、链接"，并让每种 Artifact 都有对应的 AI 处理规则和自动采集能力。

新输入进来后，后续的 Composition → Graph → Arc → Reflection 链路不需要改动。
