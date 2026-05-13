# 02. Client Domain Model

## 1. 当前客户端模型问题

当前 `sprout` iOS 端已经有一套可运行的 `SwiftData` 模型，但职责混杂明显：

- `Record` 同时承担内容、布局、天气、位置、卡片尺寸、排序
- `MediaCard` 是内容对象，但被收缩为 `Record` 的附属品
- `Person` 与 `Decision` 是独立对象，但没有被提升到统一 graph 关系层

这意味着客户端模型正处在“可用但不可长期扩展”的阶段。

## 2. 当前模型现状摘要

当前主要模型包括：

- `Record`
- `MediaCard`
- `Person`
- `Decision`
- `Activity`
- `DailyQuestion`
- `DashboardSystemCardConfig`

其中 `Record` 仍是主聚合根。

## 3. 目标客户端分层

客户端领域模型建议拆成以下几组：

### 3.1 Capture Layer

- `Record`
- `RecordInputSource`
- `RecordArtifactLink`

### 3.2 Content Truth Layer

- `Artifact`
- `ArtifactPayload`
- `ArtifactMediaRef`

### 3.3 Composition Layer

- `Board`
- `Composition`
- `CompositionItem`

### 3.4 Entity Layer

- `EntityNode`
- `EntityAlias`
- `EntityEdge`
- `ArtifactEntityLink`

### 3.5 Reflection Layer

- `RecordAnalysisSnapshot`
- `ReflectionSnapshot`
- `ArcReflectionSnapshot`

## 4. Artifact 模型建议

### 4.1 核心字段

建议 `Artifact` 至少包括：

```text
Artifact
  id
  createdAt
  updatedAt
  kind
  subtype
  source
  status
  textContent
  title
  summary
  timeStart
  timeEnd
  latitude
  longitude
  placeLabel
  metadataJSON
```

### 4.2 kind 建议

- `text`
- `photo`
- `audio`
- `music`
- `link`
- `weather`
- `location`
- `todo`
- `person_mention`
- `decision_note`
- `quote`

### 4.3 设计原则

- `kind` 用于决定基础渲染和处理路径
- `subtype` 用于细分，不要把所有变体都提升成一级对象
- 高度动态信息放到 `metadataJSON`
- 稳定且高频访问的字段显式建模

## 5. Record 模型重定义

### 5.1 保留字段

Record 应保留：

- `id`
- `createdAt`
- `updatedAt`
- `captureSource`
- `rawText`
- `userMood`
- `userIntensity`
- `inputContext`

### 5.2 弱化字段

以下字段应逐步从 `Record` 脱离：

- `cardType`
- `cardUnits`
- `cardWidthColumns`
- `dashboardCardSpanOverridesData`

### 5.3 关系调整

从：

- `Record owns MediaCard`

调整为：

- `Record references Artifacts`

## 6. Composition 客户端模型建议

### 6.1 Board

Board 是某种展示上下文：

- home day board
- people board
- arc board
- search result board

### 6.2 Composition

Composition 是一个持久化空间组合对象。

建议字段：

```text
Composition
  id
  boardID
  createdAt
  updatedAt
  title
  layoutStyle
  sortOrder
```

### 6.3 CompositionItem

CompositionItem 负责指向具体渲染对象。

建议字段：

```text
CompositionItem
  id
  compositionID
  targetType
  artifactID?
  recordID?
  x
  y
  widthUnits
  heightUnits
  zIndex
  rotation
  scale
  styleJSON
```

## 7. Entity 模型建议

### 7.1 EntityNode

建议字段：

```text
EntityNode
  id
  kind
  displayName
  canonicalName
  summary
  createdAt
  updatedAt
  confidence
```

### 7.2 EntityEdge

```text
EntityEdge
  id
  fromEntityID
  toEntityID
  relationType
  weight
  firstSeenAt
  lastSeenAt
  evidenceCount
```

### 7.3 ArtifactEntityLink

用于把 artifact 与 entity 连接起来，避免所有关系都只能走 `Record`。

## 8. Reflection 客户端模型建议

### 8.1 RecordAnalysisSnapshot

面向单条 record / capture 的结构化分析。

建议包括：

- themes
- emotionInterpretation
- salience
- retrievalTerms
- detectedEntities
- followUpCandidates

### 8.2 ReflectionSnapshot

面向多对象或阶段的解释性输出。

建议包括：

- reflectionType
- sourceRefs
- title
- body
- evidenceSummary
- confidence
- status

## 9. 迁移策略

客户端模型不能一次性大换血，建议分阶段：

1. 新增 `Artifact`，保留 `MediaCard`
2. 新写入链路双写
3. 新增 `Composition`，让首页渐进切换
4. 新增 `RecordAnalysisSnapshot`
5. 最后再清理 `Record` 中布局遗留字段

## 10. SwiftData 现实约束

因为当前 App 主存储是 `SwiftData`，所以模型设计要注意：

- 迁移可控
- 查询成本可控
- 不要在第一阶段引入过深关系爆炸
- 对复杂字段使用可演进的 JSON payload

目标不是一开始建最“纯”的模型，而是建一套既可落地又不继续恶化结构的模型。
