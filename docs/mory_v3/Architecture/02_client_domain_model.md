# 02. Client Domain Model

## 1. 目标

本文档定义 `Mory v3` 客户端的正式领域模型。

它不保留历史兼容语义，不承担页面临时拼装，也不为旧对象做映射。

## 2. 五层客户端模型

### 2.1 Capture Layer

对象：

- `RecordShell`
- `CaptureSource`
- `RecordArtifactLink`

`RecordShell` 字段：

- `id`
- `createdAt`
- `updatedAt`
- `captureSource`
- `rawText`
- `userMood`
- `userIntensity`
- `inputContext`
- `artifactIDs`

### 2.2 Content Truth Layer

对象：

- `Artifact`
- `ArtifactPayload`
- `ArtifactMediaRef`

`Artifact` 建议字段：

- `id`
- `recordID`
- `kind`
- `title`
- `summary`
- `textContent`
- `metadata`
- `binaryPayload`
- `previewPayload`
- `createdAt`
- `updatedAt`

`Artifact.kind` 的正式词表：

- `text`
- `photo`
- `audio`
- `music`
- `link`
- `location`
- `weather`
- `todo`
- `document`

边界规则：

- `ArtifactKind` 只表达内容载体类型，不表达图谱语义。
- `person mention`、`decision fragment`、`theme hint` 不是 `ArtifactKind`。
- 这些语义应进入 `RecordAnalysisSnapshot`、`EntityNode`、`EntityEdge` 与 `ArtifactEntityLink`。
- `todo` 是正式一级 kind，不再通过 `note` 或其他过渡命名表示。

### 2.3 Composition Layer

对象：

- `Board`
- `Composition`
- `CompositionItem`

`Board` 表示展示上下文，例如：

- home day board
- people board
- arc board
- search board

`CompositionItem` 建议字段：

- `id`
- `boardID`
- `boardKey`
- `compositionID`
- `compositionKey`
- `itemKey`
- `targetType`
- `targetID`
- `widthColumns`
- `heightUnits`
- `zIndex`
- `rotationDegrees`
- `scale`
- `isHidden`
- `updatedAt`

### 2.4 Entity Layer

对象：

- `EntityNode`
- `EntityEdge`
- `ArtifactEntityLink`

`EntityNode` 建议字段：

- `id`
- `kind`
- `displayName`
- `canonicalName`
- `aliases`
- `summary`
- `provenanceRecordIDs`
- `createdAt`
- `updatedAt`
- `confidence`

`ArtifactEntityLink` 建议字段：

- `id`
- `artifactID`
- `entityID`
- `confidence`
- `source`
- `sourceRecordID`
- `sourceAnalysisRecordID`
- `evidenceSummary`
- `createdAt`

### 2.5 Reflection Layer

对象：

- `RecordAnalysisSnapshot`
- `ReflectionSnapshot`
- `TemporalArc`

`RecordAnalysisSnapshot` 建议字段：

- `recordID`
- `summary`
- `themes`
- `emotionInterpretation`
- `salienceScore`
- `retrievalTerms`
- `entityMentions`
- `candidateEdges`
- `followUpCandidates`
- `reflectionHint`
- `createdAt`

## 3. SwiftData 结构原则

### 3.1 持久化层

SwiftData 负责：

- `RecordShell` store model
- `Artifact` store model
- `Board / Composition / CompositionItem`
- `RecordAnalysisSnapshot` store model
- `ReflectionSnapshot` store model
- `EntityNode / EntityEdge / ArtifactEntityLink`
- `TemporalArc` store model

### 3.2 非职责

SwiftData 不负责：

- 页面投影逻辑
- 运行时动画状态
- 卡片类型扩张

## 4. 客户端依赖方向

目标依赖方向：

- `App -> Features`
- `Features -> Domain + UseCase`
- `UseCase -> Repository`
- `Repository -> Persistence`
- `Persistence -> Domain`

UI 不直接操作底层持久化模型。

## 5. 设计原则

1. `RecordShell` 只是 capture 边界。
2. `Artifact` 是内容真相层。
3. `Composition` 是空间组织层。
4. `Entity Graph` 是长期关系层。
5. `TemporalArc` 与 `Reflection` 是高层理解层。
