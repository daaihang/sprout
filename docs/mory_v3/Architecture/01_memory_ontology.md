# 01. Memory Ontology

## 1. Ontology 的作用

`Mory v3` 必须先冻结统一 ontology，再写 UI、持久化和 AI。

否则会出现三个问题：

- 内容对象和展示对象混淆
- AI 输出没有稳定落点
- 页面不断为对象边界兜底

## 2. 五层统一记忆本体

### 2.1 Layer 1: Artifact

定义：

> Artifact 是系统中最小的可引用记忆材料。

`ArtifactKind` 的正式一级词表冻结为：

- `text`
- `photo`
- `audio`
- `music`
- `link`
- `location`
- `weather`
- `todo`
- `document`

当前 Phase 1 composer 正式写入链只覆盖：

- `text`
- `photo`
- `audio`
- `location`
- `link`
- `todo`

`music / weather / document` 仍属于正式 `ArtifactKind`，但当前主要保留给导入、外部集成或后续 capture 入口。

以下语义不再视为一级 `ArtifactKind`：

- 人物提及
- 决策片段
- 情绪信号

它们应作为：

- `RecordShell` 的显式上下文字段
- `RecordAnalysisSnapshot` 的分析结果
- `EntityNode / ArtifactEntityLink` 的语义落点

### 2.2 Layer 2: Composition

定义：

> Composition 是将 artifacts 组织进某个视觉或叙事空间中的持久化对象。

它表达：

- 大小
- 层级
- 相邻关系
- 叙事上下文

### 2.3 Layer 3: Semantic Graph

定义：

> Semantic Graph 是稳定对象与稳定关系的长期记忆网络。

节点可包括：

- Person
- Place
- Theme
- Decision

边可包括：

- related to
- mentioned with
- repeated in
- decided at

### 2.4 Layer 4: Temporal Arc

定义：

> Temporal Arc 是将离散材料组织为阶段性结构的时间层。

它表达：

- 开始与结束
- 高密度时段
- 主题演化
- 关系变化期

### 2.5 Layer 5: Reflection

定义：

> Reflection 是在前四层基础上生成的高价值意义层输出。

它负责：

- 解释模式
- 解释阶段
- 解释关系
- 组织高层回顾

## 3. RecordShell 的位置

`RecordShell` 是 capture event，而不是宇宙中心。

它只保留：

- 时间
- 输入来源
- 原始文本
- 用户显式上下文
- 对 artifacts 的引用

## 4. 层间关系

建议层间关系：

- `RecordShell -> [ArtifactRef]`
- `Composition -> [CompositionItem] -> ArtifactRef / RecordRef / ReflectionRef / ArcRef`
- `Artifact -> [EntityLink]`
- `EntityNode <-> EntityEdge`
- `TemporalArc -> [RecordRef | ArtifactRef | EntityRef]`
- `Reflection -> source refs`

## 5. 冻结原则

新需求进入实现前必须回答：

1. 它属于哪一层。
2. 它是事实对象、空间对象、关系对象、阶段对象还是反思对象。
3. 它是否只是渲染方式，而不该进入领域模型。
