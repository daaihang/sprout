# Mory v3 Architecture Index

> 更新时间：2026-05-15

## 1. 文档目标

本组文档用于定义 `Mory v3` 的目标架构。

它统一：

- 记忆本体
- 客户端领域模型
- Composition 系统
- AI / Graph / Reflection 边界
- 后端接口
- 新工程实施顺序

文档不再承担历史比较、兼容设计或旧模型说明。

## 2. 文档结构

1. [01_memory_ontology.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/01_memory_ontology.md)
   统一记忆本体与层级定义

2. [02_client_domain_model.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/02_client_domain_model.md)
   客户端目标模型、SwiftData 结构与依赖边界

3. [03_composition_system.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/03_composition_system.md)
   Board、Composition 与空间化首页系统

4. [04_ai_graph_and_reflection.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/04_ai_graph_and_reflection.md)
   分析快照、图谱、阶段和反思系统

5. [05_backend_and_interfaces.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/05_backend_and_interfaces.md)
   后端职责、分析协议与接口边界

6. [06_migration_roadmap.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/06_migration_roadmap.md)
   新工程的实现顺序与 phase 路线图

7. [07_naming_glossary.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/07_naming_glossary.md)
   正式命名表与术语冻结

8. [10_record_shell_field_spec.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/10_record_shell_field_spec.md)
   `RecordShell` 字段规格与 capture 边界说明

## 3. 统一架构判断

`Mory v3` 的长期结构是：

`Capture -> Artifact -> Composition -> Semantic Graph -> Temporal Arc -> Reflection`

## 4. 实施原则

1. 先冻结对象边界，再写页面。
2. 先搭 5 层模型，再接 UI 壳子。
3. UI 只消费 feature state，不直接持有持久化真相。
4. AI 只在稳定对象之上工作，不承担基础对象建模。
