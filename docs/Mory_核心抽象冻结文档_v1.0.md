# Mory 核心抽象冻结文档 v1.0

> 基于当前代码现状与目标产品方向整理  
> 更新时间：2026-05-13  
> 目的：冻结底层世界观，避免后续 UI、AI、数据模型继续分叉

## 1. 文档目的

现在 Mory 最大的问题已经不是“怎么接 AI”，而是：

- 数据模型已经在长大
- UI 已经进入空间系统
- AI 已经开始承担语义组织
- 产品目标正在从日记 App 变成记忆空间系统

如果这个阶段不先冻结核心抽象，后面继续加功能只会让：

- `Record`
- `Card`
- `AI Output`
- `People / Place / Decision`

越来越互相缠绕。

这份文档的目标只有一个：

> 明确 Mory 接下来应该长期稳定的底层抽象，而不是继续围绕临时业务对象扩张。

## 2. 核心判断

当前代码已经暴露出一个明显事实：

- UI 层正在向 `Container / Layout / Composition` 演进
- 数据层和 AI 层仍然以 `Record` 为中心

这会造成三层世界观不一致：

1. UI 觉得内容是空间组合
2. 数据模型觉得内容是日记记录
3. AI 觉得内容是文本请求

这三套中心如果不统一，后面会越来越痛苦。

因此需要冻结新的总世界观：

> Mory 不是“Record 驱动的日记系统”，而是“Artifact Graph 驱动的记忆空间系统”。

只是当前工程还不能一步推翻到纯 graph，所以需要一个分层过渡模型。

## 3. 新的五层抽象

建议冻结 5 个底层抽象，而不是继续把 `Record` 当唯一根。

### 3.1 Artifact

`Artifact` 是记忆系统中的最小语义碎片。

它不是 UI 卡片，也不是完整记录，而是“人生中的一个可引用对象”。

典型 Artifact：

- 一段文本
- 一张照片
- 一段音频
- 一首歌
- 一个地点
- 一次情绪表达
- 一组 todo
- 一次人物提及
- 一个 decision 片段

它的核心特点：

- 可被多个上层对象引用
- 可独立拥有 metadata
- 不依赖某个特定 UI 形态存在

一句话：

> Artifact 是内容真相层，不是展示层。

### 3.2 Container

`Container` 是空间组合单元。

它负责的是：

- 元素如何被放在一起
- 哪些内容彼此相邻
- 哪些对象在一个视觉上下文中出现
- 用户如何在空间里组织记忆

`Container` 不应该是业务真相源，它是：

- board 上的组合壳
- 某种叙事视图
- 某个时刻的摆放结果

一句话：

> Container 是空间组织层，不是语义根对象。

### 3.3 Record

`Record` 不应再被定义为宇宙中心。  
它更适合被重新定义为：

> 一次捕获事件，或一个时间点上的记忆聚合壳。

也就是说，`Record` 的职责是：

- 表示这次写入/记录行为发生了
- 把多个 artifacts 在某个时间点聚合起来
- 保存创建时间、更新时间、输入入口、上下文快照

`Record` 不应该长期拥有一切。  
它应该逐步从：

- `Record owns artifacts`

转向：

- `Record references artifacts`

一句话：

> Record 是时间点聚合，不是内容宇宙中心。

### 3.4 Graph

`Graph` 是长期关系层。

它表达的是稳定对象与稳定关系，而不是一次记录。

建议的长期节点类型：

- `PersonNode`
- `PlaceNode`
- `ThemeNode`
- `DecisionNode`
- `MoodNode`
- `MediaNode`
- `ArtifactNode`

建议的关系类型：

- `MENTIONED_WITH`
- `CAPTURED_AT`
- `RELATED_TO`
- `PART_OF`
- `REPEATED_DURING`
- `INFLUENCED_BY`
- `NEAR_IN_TIME`
- `NEAR_IN_SPACE`

这层的作用是：

- 避免 AI 每次都从零总结人生
- 支撑长期检索与回顾
- 支撑人物关系、地点关系、阶段关系
- 让 AI 更新 graph delta，而不是反复读全量内容

一句话：

> Graph 是长期语义记忆层。

### 3.5 Temporal Layer

`Temporal Layer` 是时间阶段层。

它表达的不是单条记录，而是更高一级的时间结构：

- `Moment`
- `Period`
- `Arc`
- `Chapter`

典型例子：

- “准备离职的春天”
- “和某个人关系变近的那段时间”
- “搬家前后的一个月”
- “连续焦虑的那几周”

这层存在的意义是：

- 把离散记录变成阶段体验
- 支撑 chapter 级回顾
- 支撑更强的 AI reflection
- 让系统能表达“长期变化”，而不是只有点状事件

一句话：

> Temporal Layer 是人生阶段表达层。

## 4. 五层关系

这五层的关系建议定义为：

```text
Artifact: 最小语义碎片
Container: 空间组合
Record: 时间点聚合
Graph: 长期关系网络
Temporal Layer: 阶段结构
```

它们的职责边界：

- `Artifact`：内容是什么
- `Container`：内容怎样被摆放在空间里
- `Record`：这次记录行为发生在什么时候
- `Graph`：这些对象长期如何关联
- `Temporal Layer`：这些对象属于哪段人生阶段

## 5. 对当前架构的修正

### 5.1 当前最大风险：Record 中心化过强

当前代码中 `Record` 仍然是主聚合根。  
这在今天还可行，但继续发展会越来越别扭。

未来一定会出现这些情况：

- 一张照片关联多个主题
- 一个人横跨很多 container
- 一段情绪贯穿多个时间点
- 一个 decision 跨越数月
- 一个地点不断重复出现

这时如果仍坚持“所有东西都归属于某条 record”，系统会越来越扭曲。

所以正确修正不是立刻删除 `Record`，而是：

- 降低它的统治地位
- 让它从“根”变成“壳”

### 5.2 当前第二风险：Container 和 AI 脱节

UI 已经明显进入空间系统，但 AI 输入还停留在：

- `record.content`
- `persons`

这是不够的。

未来 AI 需要理解的不只是文本，还包括：

- 哪些元素被放在一起
- 哪些对象总是接近
- 哪些内容被用户固定摆在特定区域
- 哪些 artifacts 形成视觉 cluster

所以未来 AI 的一部分输入必须升级为：

- `Board Snapshot`
- `Container Snapshot`
- `Spatial Relationship Summary`

### 5.3 当前第三风险：Card 类型过早业务化

如果继续围绕：

- `MusicCard`
- `WeatherCard`
- `MovieCard`
- `TodoCard`

无限扩张，最终会得到爆炸式类型树。

更稳定的方向是：

- 小核心 artifact 类型
- 大 metadata
- renderer 决定显示形式

也就是：

- 数据层不要先业务化死
- UI 层负责具体呈现策略

## 6. 新的架构原则

### 6.1 原则一：真相层和展示层分离

长期真相层应属于：

- `Artifact`
- `Graph`
- `Temporal Layer`

展示层应属于：

- `Container`
- renderer
- layout system

`Record` 处于中间层，主要作为输入与时间锚点。

### 6.2 原则二：能 deterministic 的，不要先交给 LLM

必须明确区分：

- `Intelligence`
- `Reflection`

`Intelligence` 应尽量本地确定性完成，例如：

- 人物 mention 统计
- recurring places
- 时间聚类
- 音乐频率
- 情绪变化趋势
- revisit 候选

`Reflection` 才交给 AI，例如：

- 这段关系为什么对你重要
- 这次记录的深层矛盾是什么
- 这段阶段的主题是什么

一句话：

> 基础 intelligence 本地化，昂贵 reflection AI 化。

### 6.3 原则三：AI 输出优先写 Graph Delta，不是重写人生

未来 AI 最理想的职责不是反复 summarize 全库，而是：

- 读取当前记录快照
- 结合少量上下文
- 输出 graph delta

例如：

- 新的人物关系边
- 新的主题节点
- 新的地点关联
- 新的阶段候选

这样成本和可维护性都会好很多。

### 6.4 原则四：空间语义必须成为一等输入

未来 AI 输入不能只有文本与 metadata。  
还应逐步加入：

- container layout
- element positions
- artifact grouping
- stable co-occurrence
- board clusters

因为记忆天然带空间性。

## 7. 冻结后的对象定义

### 7.1 Artifact 的定义

建议未来统一为：

```text
Artifact
- id
- type
- subtype
- source
- createdAt
- canonicalText
- mediaRefs
- entityRefs
- tags
- metadata
```

说明：

- `type` 是最小核心分类
- `subtype` 是细分
- `canonicalText` 是可供搜索与 AI 使用的文本化表达
- `metadata` 用于弹性扩展

### 7.2 Container 的定义

```text
Container
- id
- boardID
- title
- layoutState
- artifactRefs
- visualStyle
- createdAt
- updatedAt
```

说明：

- container 引用 artifacts
- 不直接拥有长期语义真相

### 7.3 Record 的定义

```text
Record
- id
- captureType
- createdAt
- updatedAt
- artifactRefs
- containerRefs
- inputContext
- analysisRefs
```

说明：

- record 是一次记录会话
- 不是最终语义归宿

### 7.4 Graph 的定义

```text
Node
- id
- nodeType
- canonicalName
- metadata

Edge
- id
- fromNodeID
- toNodeID
- edgeType
- weight
- evidenceRefs
- createdAt
- updatedAt
```

说明：

- `evidenceRefs` 指向 record / artifact / analysis snapshot
- graph 不是纯 AI 产物，也可由 deterministic engine 维护

### 7.5 Temporal Layer 的定义

```text
TemporalUnit
- id
- type: moment | period | arc | chapter
- title
- summary
- startAt
- endAt
- relatedRecordRefs
- relatedArtifactRefs
- relatedNodeRefs
```

## 8. AI 架构如何对齐这五层

### 8.1 现在的问题

当前 AI 文档里虽然已经比旧版本先进很多，但仍然以：

- `Record Aggregate`

为核心输入。

这比纯文本强，但还不够。

### 8.2 未来正确输入

未来 AI 输入应逐步分为三类：

#### A. Record Snapshot

表示这次记录行为。

#### B. Container / Spatial Snapshot

表示它在空间中如何被组织。

#### C. Graph / Temporal Context

表示它与长期对象和阶段的关系。

建议输入结构最终演化为：

```json
{
  "record_snapshot": {},
  "artifact_snapshot": {},
  "container_snapshot": {},
  "graph_context": {},
  "temporal_context": {}
}
```

### 8.3 未来正确输出

AI 输出不应只是：

- tags
- insight

而应包含：

- analysis snapshot
- graph delta
- temporal candidates
- spatial interpretation

例如：

- 某人和某主题关系增强
- 某地点变成 recurring place
- 某组记录开始形成 chapter
- 某个 container 代表一种稳定叙事模式

## 9. 本地 deterministic 系统应先落地什么

当前最该优先本地化的不是更强 LLM，而是基础 intelligence engine。

建议优先做：

### 9.1 Person Intelligence

- mention count
- last mentioned at
- recurring co-mentions
- contact frequency windows

### 9.2 Place Intelligence

- recurring places
- time-of-day patterns
- place-person co-occurrence

### 9.3 Temporal Intelligence

- weekly clusters
- mood streaks
- recurring late-night entries
- high-density periods

### 9.4 Artifact Intelligence

- repeated song references
- repeated media themes
- repeated photo contexts

### 9.5 Revisit Intelligence

- recently important but forgotten
- unfinished decision clusters
- emotionally dense periods

这部分尽量不要先依赖 LLM。

## 10. 迁移路线

### 10.1 第一阶段：冻结术语

立刻统一术语：

- `Artifact`
- `Container`
- `Record`
- `Graph`
- `Temporal Layer`

后续文档、代码命名、AI 文档、产品讨论都用同一套词。

### 10.2 第二阶段：让 Record 降级

不要立刻删除 `Record`，但开始做两件事：

- 从“拥有一切”改成“引用一切”
- 把新能力尽量挂到 artifact / graph 层

### 10.3 第三阶段：从 Card 类型转向 Artifact Renderer

逐步把：

- 业务对象

和：

- 渲染对象

拆开。

方向是：

- data model 更通用
- renderer 更具体

### 10.4 第四阶段：新增 Graph 层

不要一开始追求复杂图数据库。  
先做本地可持久化 graph node/edge 即可。

先覆盖：

- person
- place
- theme
- decision

### 10.5 第五阶段：新增 Temporal Layer

先做最小版本：

- `Period`
- `Chapter`

先让系统能表达：

- 一段时间
- 一个阶段

不用一开始就做完整人生叙事引擎。

### 10.6 第六阶段：让 AI 改成更新 delta

最终方向：

- AI 不再反复读全库总结
- AI 只基于当前快照输出：
  - analysis snapshot
  - graph delta
  - temporal candidates

## 11. 这份冻结文档的最终结论

### 11.1 对当前系统的一句话判断

Mory 已经不适合继续按“日记记录系统”的世界观演进了。

它真正正在长成的是：

> 一个以 Artifact 为真相层、以 Container 为空间层、以 Graph 为长期记忆层、以 Temporal Layer 为人生阶段层的记忆空间系统。

### 11.2 接下来最重要的事情

现在最重要的不是继续加功能，而是冻结这五层抽象。

只要这五层稳定：

- AI
- UI
- 搜索
- 回顾
- 人物
- 决策
- 章节

都会自然长出来。

### 11.3 最危险的事情

当前最危险的不是 AI 成本，也不是模型选择，而是：

> 过早把业务对象固化成长期根抽象。

尤其是：

- `Record` 永远当中心
- `Card` 类型持续爆炸
- AI 继续只围绕文本工作

这三件事如果不纠正，后面重构成本会非常高。

---

## 附录 A：当前代码的对应关系

当前代码里可视为过渡态的对应物：

- `Record`：[`sprout/sprout/Models/Record.swift`](/Users/z14/Documents/sprout/sprout/sprout/Models/Record.swift:1)
- `Person`：[`sprout/sprout/Models/Person.swift`](/Users/z14/Documents/sprout/sprout/sprout/Models/Person.swift:1)
- `MediaCard`：[`sprout/sprout/Models/MediaCard.swift`](/Users/z14/Documents/sprout/sprout/sprout/Models/MediaCard.swift:1)
- `Activity`：[`sprout/sprout/Models/Activity.swift`](/Users/z14/Documents/sprout/sprout/sprout/Models/Activity.swift:1)
- `Decision`：[`sprout/sprout/Models/Decision.swift`](/Users/z14/Documents/sprout/sprout/sprout/Models/Decision.swift:1)
- `Record -> 多卡片映射`：[`sprout/sprout/Services/RecordMapper.swift`](/Users/z14/Documents/sprout/sprout/sprout/Services/RecordMapper.swift:1)
- `首页空间组合入口`：[`sprout/sprout/ContentView.swift`](/Users/z14/Documents/sprout/sprout/sprout/ContentView.swift:1)

## 附录 B：后续文档建议

建议后面再补三份文档：

- `Mory_Artifact模型设计文档.md`
- `Mory_Graph层设计文档.md`
- `Mory_TemporalLayer设计文档.md`
