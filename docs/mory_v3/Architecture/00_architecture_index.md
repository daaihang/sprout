# Mory v3 Architecture Index

> 文档版本：Architecture v3.0 draft  
> 更新时间：2026-05-13

## 1. 文档目标

这组文档用于替代“仅围绕前后端分层”的旧式架构说明。

Mory 当前真正需要冻结的，不是简单的：

- iOS 端怎么写
- Go 后端怎么调 AI

而是：

> 整个记忆系统的统一分层与对象边界。

因为当前项目最危险的问题已经不是“某个功能没做”，而是三套宇宙并存：

1. 数据宇宙：`Record / Person / Decision / MediaCard`
2. UI 宇宙：`Container / Card / StickerGrid / span override`
3. AI 宇宙：`tags / emotion / themes / reflection`

如果这三层继续并行演化而不统一，后续开发会越来越依赖 mapper 和硬转。

## 2. 文档结构

1. [01_memory_ontology.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/01_memory_ontology.md)  
   统一记忆本体与五层结构

2. [02_client_domain_model.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/02_client_domain_model.md)  
   客户端领域模型、SwiftData 目标结构、Record 降级方案

3. [03_composition_system.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/03_composition_system.md)  
   Home composition、container 持久化、渲染层与布局层分工

4. [04_ai_graph_and_reflection.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/04_ai_graph_and_reflection.md)  
   AI 分析协议、语义图谱、反思层职责与落库设计

5. [05_backend_and_interfaces.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/05_backend_and_interfaces.md)  
   Go 后端定位、接口边界、认证、分析与轻状态服务职责

6. [06_migration_roadmap.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/06_migration_roadmap.md)  
   从当前仓库到目标架构的演进路线、里程碑、迁移策略

7. [07_mac_prototype_v0.1.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/07_mac_prototype_v0.1.md)  
   Mac 原型版目标、范围、共享层抽离、验证任务与 2 周落地计划

8. [08_mac_prototype_v0.1_implementation_checklist.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/08_mac_prototype_v0.1_implementation_checklist.md)  
   Mac 原型执行清单、目录规划、代码拆分顺序、首批文件与验收标准

9. [09_mac_prototype_v0.1_validation_and_handoff.md](/Users/z14/Documents/sprout/docs/mory_v3/Architecture/09_mac_prototype_v0.1_validation_and_handoff.md)  
   Mac 原型验证结论、handoff 结果、graph 下一步与 iOS 回迁顺序

当前状态补充：

- Mac prototype 已完成 `Artifact -> Composition -> Graph -> Temporal Arc -> Reflection` 的 prototype 级闭环验证
- `TemporalArc` 已进入正式对象、显式 reflection 关联、merge/provenance 的验证阶段

## 3. 新架构的根判断

Mory 的长期结构应当是：

`Artifacts -> Compositions -> Semantic Graph -> Temporal Arcs -> Reflection`

而不是：

`Record -> Cards -> AI`

## 4. 实施原则

1. 不做一次性推翻重写
2. 先冻结对象边界，再改页面和接口
3. 先引入 `Artifact` 与 `Composition`，再上 `Graph` 与 `Arc`
4. AI 只承担高价值理解，不承担所有基础计算
5. 一切迁移设计都必须允许当前 App 继续运行
