# Mory v3 Documentation Set

> 更新时间：2026-05-15  
> 适用范围：`mory/` 新工程、产品定义、客户端架构、AI 分析、图谱、阶段与反思系统

本目录是 `Mory v3` 的目标态规范文档。

它只描述新项目要实现的对象边界、交互结构、接口约束和实施顺序，不承担以下职责：

- 不记录旧工程残留
- 不设计兼容层
- 不描述双写或临时 fallback
- 不把历史模型当成正式方案的一部分

## 阅读顺序

如果你是产品负责人：

1. [PRD/00_prd_index.md](/Users/z14/Documents/sprout/docs/mory_v3/PRD/00_prd_index.md)
2. [PRD/01_product_vision.md](/Users/z14/Documents/sprout/docs/mory_v3/PRD/01_product_vision.md)
3. [PRD/03_information_architecture.md](/Users/z14/Documents/sprout/docs/mory_v3/PRD/03_information_architecture.md)
4. [PRD/04_core_flows_and_requirements.md](/Users/z14/Documents/sprout/docs/mory_v3/PRD/04_core_flows_and_requirements.md)
5. [PRD/05_ai_product_strategy.md](/Users/z14/Documents/sprout/docs/mory_v3/PRD/05_ai_product_strategy.md)

如果你是架构/工程负责人：

1. [Architecture/00_architecture_index.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/00_architecture_index.md)
2. [Architecture/01_memory_ontology.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/01_memory_ontology.md)
3. [Architecture/02_client_domain_model.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/02_client_domain_model.md)
4. [Architecture/03_composition_system.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/03_composition_system.md)
5. [Architecture/04_ai_graph_and_reflection.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/04_ai_graph_and_reflection.md)
6. [Architecture/05_backend_and_interfaces.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/05_backend_and_interfaces.md)
7. [Architecture/06_migration_roadmap.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/06_migration_roadmap.md)
8. [Architecture/07_naming_glossary.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/07_naming_glossary.md)

## 核心判断

`Mory v3` 的统一结构是：

`Capture -> Artifact -> Composition -> Entity Graph -> Temporal Arc -> Reflection`

这条链路同时定义：

- 数据真相层
- 首页与详情的 UI 组织层
- AI 的输入和输出边界
- 人物、阶段、检索和反思能力

## 文档原则

1. 只描述目标态，不描述旧架构。
2. 只定义正式对象，不保留临时层。
3. 只写可长期存在的边界，不写过渡性命名。
4. 产品、UI、数据和 AI 必须使用同一组对象语言。
