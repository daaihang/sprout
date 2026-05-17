# Mory v4 PRD Index

> 更新时间：2026-05-17

## 1. 文档目标

本套 PRD 定义 v4 的产品边界。

v4 的核心命题是：

> 让用户能用真实的生活材料——而不仅仅是文字——记录记忆，并让系统自动补全上下文。

## 2. 文档结构

1. [01_v4_scope_and_goals.md](01_v4_scope_and_goals.md) — 版本目标与验收标准
2. [02_artifact_input_matrix.md](02_artifact_input_matrix.md) — Artifact 类型全量矩阵
3. [03_capture_flows.md](03_capture_flows.md) — 每种输入的用户交互流程
4. [04_ai_processing_rules.md](04_ai_processing_rules.md) — 每种 Artifact 的 AI 处理规则
5. [05_context_auto_collection.md](05_context_auto_collection.md) — 自动采集的上下文策略
6. [06_home_board_connection.md](06_home_board_connection.md) — 主页卡片与真实数据的连接
7. [../STATUS_2026-05-17.md](../STATUS_2026-05-17.md) — 当前进度、文档修正和真机验证清单

## 3. v4 不改变的东西

- 五层本体不变
- Tab 结构不变
- Graph / Arc / Reflection 的生成逻辑不变
- 命名术语不变
- 后端 AI 分析协议不变（扩展，不重写）

## 4. v4 新增的东西

- 6 种 Artifact 获得完整的采集 → AI 处理 → 展示链路
- 3 种保存前上下文候选（天气、地点、音乐）
- 认证持久化
- AI 速度优化
- 主页卡片接入真实数据
