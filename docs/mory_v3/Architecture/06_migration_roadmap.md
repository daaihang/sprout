# 06. Build Roadmap

## 1. 路线目标

本路线图用于定义 `Mory v3` 新工程的正式实现顺序。

它只描述目标态实现，不描述历史兼容策略。

## 2. 总体原则

1. 先冻结对象边界，再写页面。
2. 先落 5 层模型，再接 UI 壳。
3. 不保留旧模型。
4. 不保留兼容层。
5. 不双写。

## 3. Phase 0: 文档冻结

输出物：

- PRD
- 架构文档
- 命名表
- 实施顺序

验收标准：

- 团队能用同一组对象语言描述产品、UI、数据和 AI

## 4. Phase 1: Capture + Artifact

目标：

- 建立正式 capture 边界
- 建立内容真相层

动作：

- 定义 `RecordShell`
- 定义 `Artifact`
- 打通 composer / photo / audio / location 等 capture 到 artifact 的主写入链

验收标准：

- 新 capture 全部写入 `RecordShell + Artifact`

## 5. Phase 2: Composition

目标：

- 建立首页与 board 的正式空间结构

动作：

- 定义 `Board / Composition / CompositionItem`
- 建立 day board
- 建立首页 renderer
- 建立可持续的 layout state

验收标准：

- 首页完全由 composition 驱动

## 6. Phase 3: Analysis Snapshot

目标：

- 让分析结果有稳定落点

动作：

- 定义 `RecordAnalysisSnapshot`
- 打通 `/api/analysis/records`
- capture 后异步保存 analysis

验收标准：

- 单条记忆分析可持久化并被首页、详情、搜索消费

## 7. Phase 4: Entity Graph

目标：

- 建立长期关系层

动作：

- 定义 `EntityNode / EntityEdge / ArtifactEntityLink`
- 先做 `person / place / theme / decision`
- 建立增量 graph 更新

验收标准：

- 人物页与主题检索不再依赖时间流反查

## 8. Phase 5: Temporal Arc

目标：

- 建立阶段层

动作：

- 定义 `TemporalArc`
- 建立候选、接受、归档与合并治理
- 建立阶段详情与阶段列表

验收标准：

- 用户可以稳定查看阶段对象及其关联材料

## 9. Phase 6: Reflection

目标：

- 建立高价值意义层

动作：

- 定义 `ReflectionSnapshot`
- 建立 record reflection 与 arc reflection
- 建立保存、归档、回放和入口治理

验收标准：

- `ReflectionSnapshot` 成为正式可管理对象
- 客户端已具备保存、忽略、归档、详情查看、从 arc / memory 进入 reflection 的正式链路
- 服务端 reflection API 至少完成协议冻结，不再与文档冲突

## 10. Phase 7: App Shell And Feature Integration

目标：

- 用新 UI 壳子接通新结构

动作：

- Home
- Memories timeline
- Memory detail
- Search
- People
- Arcs
- Reflections

验收标准：

- `Home / Memories / Search / People / Arcs / Reflections / Debug` 全部只消费新 memory stack
- 不再存在 Prototype / Shared 旧工程主路径
- 首页、详情、搜索、对象页之间的对象跳转规则一致

## 11. Phase 8: Governance And Polish

目标：

- 建立可持续演进能力

动作：

- dedupe
- merge provenance
- search ranking
- export / import
- diagnostics

验收标准：

- entity dedupe / alias / provenance / edge weight 规则有正式定义并落到代码
- composition、search ranking、debug diagnostics 具备稳定回归门槛
- 数据、UI、AI 和治理规则形成稳定闭环
