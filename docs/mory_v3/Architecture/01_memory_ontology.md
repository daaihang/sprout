# 01. Memory Ontology

## 1. 为什么必须先冻结 ontology

任何中长期软件，一旦底层对象体系不统一，就会进入以下循环：

- 新功能需要额外对象
- 旧对象无法表达新语义
- 临时加 mapper
- UI、数据、AI 互相翻译
- 最终没人再说得清“什么才是真相层”

Mory 当前已经处在这个临界点。

代码现状表明：

- `Record` 被当成内容主根
- `DashboardCardInfo` 和 `CardContainer` 在承担 UI 投影和布局逻辑
- AI 协议仍然把记录看成文本请求

这三层没有统一本体。

因此必须先冻结统一 ontology。

## 2. 五层统一记忆本体

### 2.1 Layer 1: Artifact

定义：

> Artifact 是记忆系统中最小的可引用内容对象。

Artifact 的基本特征：

- 可以被多个上层对象引用
- 可以拥有独立 metadata
- 不依赖某种固定 UI 形态存在
- 不以某次 record 的唯一归属为前提

示例：

- 一段文字片段
- 一张照片
- 一段音频转录
- 一首歌引用
- 一个地点快照
- 一次天气快照
- 一个链接
- 一个待办集合
- 一次人物提及
- 一个决策片段

Artifact 要解决的是“内容真相层”问题。

### 2.2 Layer 2: Composition

定义：

> Composition 是将 artifacts 组织到某个视觉或叙事空间中的持久化对象。

Composition 负责：

- artifact 如何被放在一起
- 相对空间关系
- 尺寸、层级、顺序、旋转等视觉组织结果
- board 上的叙事上下文

Composition 不是纯 View。  
它必须进入持久层，因为空间组织本身就是记忆意义的一部分。

### 2.3 Layer 3: Semantic Graph

定义：

> Semantic Graph 是稳定对象与稳定关系的长期记忆网络。

Graph 节点可包括：

- PersonNode
- PlaceNode
- ThemeNode
- DecisionNode
- MoodNode
- ProjectNode
- ArtifactNode

Graph 边可包括：

- MENTIONED_WITH
- OCCURRED_AT
- RELATED_TO
- PART_OF
- REPEATED_IN
- INFLUENCED_BY
- NEAR_IN_TIME
- NEAR_IN_SPACE

Graph 的职责是长期关系表达，而不是一次记录的临时视图。

### 2.4 Layer 4: Temporal Arc

定义：

> Temporal Arc 是将离散材料组织成阶段性人生结构的时间层。

典型对象：

- LifePeriod
- LifeArc
- Chapter
- Season

Temporal Arc 负责回答：

- 这些材料属于哪段时期
- 某段状态何时开始、何时减弱
- 某个主题在一段时间里如何变化

### 2.5 Layer 5: Reflection

定义：

> Reflection 是在前四层基础上生成的高价值意义层输出。

Reflection 是：

- 结构化理解的语言化表达
- 模式的解释
- 关系的解释
- 阶段的解释

Reflection 不是原始数据，不是布局，不是事实字段。

## 3. Record 在新 ontology 中的位置

`Record` 仍然保留，但职责必须改变。

新的定义：

> Record 是一次 capture event，或者一个时间点上的临时聚合壳。

它适合保留的职责：

- createdAt / updatedAt
- 输入源
- capture 场景
- 用户手填上下文
- 引用哪些 artifacts
- 触发分析和排序的边界

它不适合继续承担的职责：

- 一切内容的唯一所有者
- UI 组合状态的持久化根
- 长期语义关系中心

## 4. 层间关系

建议层间关系如下：

- `Record -> [ArtifactRef]`
- `Composition -> [CompositionItem] -> ArtifactRef / RecordRef`
- `Artifact -> [EntityLink]`
- `EntityNode <-> EntityEdge`
- `TemporalArc -> [ArtifactRef | RecordRef | EntityRef]`
- `Reflection -> source refs`

## 5. 为什么不是直接上 graph database

当前阶段没有必要把“统一 ontology”误解为“必须引入图数据库”。

原因：

- 当前项目仍是本地优先
- iOS 端主数据层仍以 SwiftData 为现实基础
- 关系复杂度还没到必须引入独立 graph storage
- 真正的问题是对象边界，而不是存储技术名称

所以第一原则是：

先用清晰对象建模统一 ontology，后续再决定是否需要专门的 graph storage。

## 6. Ontology 对产品和工程的影响

### 6.1 对产品的影响

- 首页不再只是 cards grid，而是 compositions board
- 人物页、阶段页、搜索页获得真正的中层支撑
- 新内容类型不再需要复制整套产品结构

### 6.2 对工程的影响

- 减少 mapper 爆炸
- 降低 UI 对数据真相的绑架
- 降低 AI 每次重读全量人生的成本

### 6.3 对 AI 的影响

- 输入协议可围绕稳定对象组织
- 输出可以落在 artifact / entity / reflection，而不漂浮

## 7. Ontology 冻结原则

从现在开始，新增需求若要进入实现，必须回答：

1. 这个新对象属于哪一层？
2. 它是事实对象、空间对象、关系对象、阶段对象还是反思对象？
3. 如果它只是某种渲染方式，为什么要进入领域模型？

答不出来，就不应立即编码。
