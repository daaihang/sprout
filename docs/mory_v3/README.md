# Mory v3 Documentation Set

> 更新时间：2026-05-13  
> 适用范围：`sprout/` iOS App、`server/` Go Backend、产品规划、信息架构、AI 分析链路、商业化与演进路线

本目录是面向 `Mory / Sprout` 下一阶段重构与发布准备的新版文档集合。

目标不是继续维护一份“大而全但彼此冲突”的单文件，而是把文档拆成：

- `PRD/`：产品定义、用户价值、功能边界、AI 产品策略、商业化与发布
- `Architecture/`：统一记忆本体、客户端数据模型、Composition 系统、AI / Graph 层、后端接口、迁移路线

这套文档基于三个输入统一整理：

1. 当前仓库真实代码状态
2. 已有 `v2.0` 技术架构文档与核心抽象文档
3. 对当前项目三套世界观断裂问题的系统性评估

## 阅读顺序

如果你是产品 owner：

1. [PRD/00_prd_index.md](/Users/z14/Documents/sprout/docs/mory_v3/PRD/00_prd_index.md)
2. [PRD/01_product_vision.md](/Users/z14/Documents/sprout/docs/mory_v3/PRD/01_product_vision.md)
3. [PRD/03_information_architecture.md](/Users/z14/Documents/sprout/docs/mory_v3/PRD/03_information_architecture.md)
4. [PRD/05_ai_product_strategy.md](/Users/z14/Documents/sprout/docs/mory_v3/PRD/05_ai_product_strategy.md)

如果你是架构/工程负责人：

1. [Architecture/00_architecture_index.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/00_architecture_index.md)
2. [Architecture/01_memory_ontology.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/01_memory_ontology.md)
3. [Architecture/02_client_domain_model.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/02_client_domain_model.md)
4. [Architecture/03_composition_system.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/03_composition_system.md)
5. [Architecture/06_migration_roadmap.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/06_migration_roadmap.md)
6. [Architecture/07_mac_prototype_v0.1.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/07_mac_prototype_v0.1.md)
7. [Architecture/08_mac_prototype_v0.1_implementation_checklist.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/08_mac_prototype_v0.1_implementation_checklist.md)
8. [Architecture/09_mac_prototype_v0.1_validation_and_handoff.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/09_mac_prototype_v0.1_validation_and_handoff.md)

## 核心结论

Mory 的下一阶段不应继续被定义为：

`Record -> Cards -> AI`

而应被定义为：

`Artifacts -> Compositions -> Semantic Graph -> Temporal Arcs -> Reflection`

这不是一句口号，而是整个产品、数据模型、UI 系统、AI 协议和迁移路线的统一设计中心。
