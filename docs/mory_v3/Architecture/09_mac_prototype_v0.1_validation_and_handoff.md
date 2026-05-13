# 09. Mac Prototype v0.1 Validation And Handoff

> 文档版本：Mac Prototype v0.1 Validation And Handoff  
> 更新时间：2026-05-13  
> 适用范围：`mory/` Mac prototype 当前实现、v0.1 结构结论、phase governance、回迁 iOS 顺序与边界

## 1. 文档目标

本文档用于完成 `Mac Prototype v0.1` 的最后一环：

- 把原型验证结果从“代码状态”升级为“明确结构结论”
- 记录当前已被证明成立的对象边界
- 指出尚未完成但接口已经清晰的位置
- 输出回迁 iOS 与继续推进 phase governance 的下一步顺序

它对应实施清单中的 `Phase E: Validation And Handoff`。

## 2. 当前原型实际验证了什么

截至当前版本，Mac prototype 已经完成这些关键验证。

### 2.1 Workspace 结构成立

已验证：

- `Sidebar + Main Workspace + Inspector` 三栏结构成立
- `Boards / Records / Artifacts / Entities / Arcs / Reflections / Debug` 工作区可切换
- selection 机制已贯穿 board、list、inspector

结论：

> Mory 需要一个“对象工作台”而不只是一个“单页日记列表”。

### 2.2 Composition 不是临时 UI，而是数据对象

已验证：

- `Board / Composition / CompositionItem` 可独立存在
- item 的 `position / size / zIndex / rotation / scale` 可编辑
- layout 状态可以本地持久化
- 同一 board 的空间组织可以在重新打开 app 后恢复

结论：

> `Composition` 应被视为持久化 memory layer，而不是 view-only 容器。

### 2.3 Record 可以降级为 capture shell

已验证：

- `RecordShell` 只承载 capture 边界、原始文本、情绪、artifact refs
- layout truth 不再挂在 record 上
- reflection 和 analysis 也不需要作为 record 的内部字段硬耦合存在

结论：

> `Record` 不应继续担任宇宙中心，而应退回 capture 壳角色。

### 2.4 Analysis 与 Reflection 已分层

已验证：

- `RecordAnalysisSnapshot` 可保存 record 级结构化分析结果
- `ReflectionSnapshot` 可承接更解释性、更面向意义的输出
- analyze 结果可落本地并被 inspector、reflection list、phase 视图消费

结论：

> `Analysis Snapshot` 与 `Reflection Snapshot` 应是两层对象，而不是同一份 AI 文案的两种展示方式。

### 2.5 Artifact 抽象已成立

已验证：

- 文本、图片、天气、位置、决策、人物提及等内容可被统一表达为 `Artifact`
- board 上展示的是 artifact / reflection，而不是旧式 card 类型枚举的 UI 爆炸
- `Artifact` 已可作为 record 与 composition 之间的中间核心对象

结论：

> 后续新增内容类型应继续进入 `Artifact`，而不是回到 `MovieCard / TicketCard / CryptoCard` 式扩张。

### 2.6 Entity Graph 已进入可用原型阶段

已验证：

- `EntityNode / EntityEdge / ArtifactEntityLink` 已成为 workspace 的一等对象
- graph 更新已由 deterministic engine 主导，而不是每次全量让 AI 重算
- entity list、entity inspector、graph insights 已能消费 graph

结论：

> Semantic Graph 已不再只是 analysis 附着物，而是长期关系层的 prototype 级实现。

### 2.7 Temporal Arc 已进入正式对象阶段

已验证：

- 系统能从 records / analyses / graph evidence 生成 `TemporalArcCandidate`
- candidate 可提升为正式 `TemporalArc`
- `TemporalArc` 可持久化、可归档、可合并、可保留 provenance
- `TemporalArc` 与 `ReflectionSnapshot` 已有显式双向链接

结论：

> Phase object 已经从“候选计算结果”升级为“正式 memory object”。

## 3. 当前版本的结构判断

基于现有原型，可以正式冻结这些判断。

### 3.1 应当保留的结构

- `Artifact`
- `RecordShell`
- `Board`
- `Composition`
- `CompositionItem`
- `RecordAnalysisSnapshot`
- `ReflectionSnapshot`
- `EntityNode`
- `EntityEdge`
- `ArtifactEntityLink`
- `TemporalArc`

### 3.2 应当继续升级的结构

- `PrototypeWorkspaceStore`
  当前已可作为原型态 orchestrator，后续要拆向正式 repository/store 层

- `TemporalArcMergeEngine`
  当前已具备最小治理规则，后续仍需要更正式的 dedupe、merge provenance、schema 迁移策略

### 3.3 不应继续扩张的旧方向

- 不继续增加旧式 card 类型
- 不把 record 再拉回首页布局根对象
- 不让 AI 返回文案直接充当长期 memory structure
- 不在 iOS 正式回迁前先做大量 phase UI 包装

## 4. v0.1 产物说明

按实施清单，v0.1 结束后需要形成这些结构成果。

### 4.1 共享 Domain 类型说明

当前已验证的一组基础对象：

- `Artifact`
- `RecordShell`
- `Board`
- `Composition`
- `CompositionItem`
- `RecordAnalysisSnapshot`
- `ReflectionSnapshot`
- `EntityNode`
- `EntityEdge`
- `ArtifactEntityLink`
- `TemporalArc`

### 4.2 Analyze Aggregate Request 协议草案

当前原型采用：

- 输入：`RecordShell + [Artifact]`
- 输出：`tags + emotion + insight + followUp + inferred entities`

结构结论：

- analyze 的最小稳定输入不是单条原始文本，而是 `record aggregate`
- record aggregate 的职责是把 capture shell 与关联 artifacts 一起打包给后端

### 4.3 Composition 持久化字段说明

当前原型已证明这些字段应被持久化：

- `boardID`
- `compositionID`
- `targetType`
- `targetID`
- `widthUnits`
- `heightUnits`
- `zIndex`
- `rotation`
- `scale`
- `positionHint`

结构结论：

> 空间布局本身就是记忆的一部分，不能只活在运行时 UI state 里。

### 4.4 Reflection Snapshot 字段说明

当前建议字段为：

- `type`
- `title`
- `body`
- `linkedTemporalArcID`
- `sourceRecordIDs`
- `sourceArtifactIDs`
- `sourceEntityIDs`
- `createdAt`

结构结论：

> Reflection 必须保留 source refs，并在 phase reflection 场景下保留显式 arc 关联，否则后续无法解释、复查和复用。

### 4.5 TemporalArc 字段说明

当前建议字段为：

- `title`
- `summary`
- `status`
- `themeLabels`
- `entityNames`
- `linkedReflectionID`
- `mergedFromArcIDs`
- `mergedIntoArcID`
- `lastMergedAt`
- `sourceRecordIDs`
- `sourceArtifactIDs`
- `sourceEntityIDs`
- `startDate`
- `endDate`
- `intensityScore`
- `clusterStrength`

结构结论：

> Phase object 必须既能表达“它是什么”，也能表达“它如何形成、如何被治理”。

### 4.6 回迁 iOS 的重构顺序

不应从 UI 开始回迁。  
正确顺序应是：

1. 在 iOS 端先引入 `Artifact`
2. 再引入 `RecordShell` 降级
3. 再把首页组织迁到 `Composition`
4. 再接入 `Analysis Snapshot`
5. 再接入 `Entity Graph`
6. 最后接入 `TemporalArc` 与 phase reflection

## 5. 当前未完成但接口已清晰的部分

### 5.1 Entity Graph 仍需正式化

当前原型虽然 graph 已进入可用阶段，但还不是正式 graph 层。

下一步要继续补：

- `EntityNode` 稳定 ID 与消歧策略
- `EntityEdge` 的 deterministic 累积更新规则治理
- `ArtifactEntityLink` 的来源、置信度与优先级
- graph 增量更新与正式持久化

### 5.2 Temporal Arc 已开始，但还不是最终形态

当前已进入：

- candidate generation
- promotion
- lifecycle status
- phase reflection linkage
- deterministic merge preview
- merge provenance

尚未完成：

- 更正式的 merge policy
- 多阶段 provenance 历史展示
- `LifePeriod / LifeArc` 更高层抽象是否还需要单独对象
- phase page / review page 的正式产品化

### 5.3 当前 persistence 仍是 prototype 级

当前本地持久化主要用于验证对象边界，不代表正式存储方案已经完成。

正式版本还需要：

- schema 演进策略
- 多端同步策略
- graph 与 arc 的增量更新策略
- merge / archive 后的历史一致性保证

## 6. iOS 回迁边界

现在不应直接把整个 Mac workspace 搬回 iOS。  
应先冻结哪些东西是“必须回迁的领域层”，哪些仍是“prototype-only 工作台层”。

### 6.1 必须回迁到 iOS 的内容

- `Artifact`
- `RecordShell`
- `RecordAnalysisSnapshot`
- `ReflectionSnapshot`
- `EntityNode / EntityEdge / ArtifactEntityLink`
- `TemporalArc`
- `TemporalArcPromoter`
- graph / arc 的 deterministic logic

### 6.2 暂不回迁的内容

- Mac sidebar / inspector / list 这种对象工作台 UI
- debug-oriented candidate 面板
- prototype-only fixture 切换与 scenario 系统
- 面向结构验证的 board workspace 交互细节

### 6.3 回迁前必须先写清的边界

- 哪些字段进 iOS 正式本地 schema
- 哪些 deterministic 规则跑客户端，哪些跑服务端
- phase promotion 是否仍由本地先行，还是由后端参与协同
- merge provenance 在正式端是否完整保留

## 7. 下一步实施顺序

现在不该继续随机堆功能。  
下一步应严格按这个顺序推进：

1. 同步当前 handoff 与 architecture 文档，确保代码状态和文档一致
2. 冻结 iOS 回迁边界，明确正式 schema 范围
3. 补 graph 正式化细节，而不是继续只做 UI
4. 再决定 phase object 何时正式进入 iOS 端

## 8. 最终判断

`Mac Prototype v0.1` 已经证明：

- 新结构不是空想
- `Artifact / Composition / Analysis / Graph / TemporalArc / Reflection` 可以协同工作
- 现有后端可以被复用为分析回路的一部分
- phase object 已具备 prototype 级治理能力

Mory 的下一阶段应继续沿着：

`Artifacts -> Compositions -> Semantic Graph -> Temporal Arcs -> Reflection`

而不是退回：

`Record -> Cards -> AI`
