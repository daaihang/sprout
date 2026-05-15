# 03. Composition System

## 1. Composition 的职责

`Composition` 负责把记忆材料组织进一个可持续存在的空间结构。

它回答：

- 哪些对象被放在一起
- 每个对象多大
- 每个对象位于哪一层
- 哪些对象相邻、覆盖或聚类
- 用户如何通过空间关系组织记忆

## 2. 核心对象

### 2.1 Board

`Board` 是展示上下文，例如：

- day board
- people board
- arc board
- search board

### 2.2 Composition

`Composition` 是某个 board 下的一组空间排布单元。

### 2.3 CompositionItem

`CompositionItem` 是实际被摆放出来的对象引用。

`targetType` 可以是：

- artifact
- record
- arc
- reflection
- system

## 3. 持久化边界

应持久化：

- `span`
- `zIndex`
- `rotation`
- `scale`
- `hidden`
- 用户显式调整结果
- 稳定排序与 item identity

不应持久化：

- 像素级 frame
- 每帧动画状态
- 瞬时 hover / drag 中间态

## 4. 首页结构

首页的正式结构是：

`DayBoard -> Composition -> CompositionItem -> Renderer`

其中：

- `DayBoard` 提供当天上下文
- `Composition` 提供空间组织
- `CompositionItem` 提供目标引用与视觉状态
- `Renderer` 负责选择具体卡片外观

### 4.1 Home Composition 最小稳定规则

当前首页正式最小规则是：

- 首页 board 先接 `record` 项，保证 capture 后立即可见
- 当存在高强度 `arc` 时，首页可插入少量阶段项
- 当存在 `saved` 或高置信 `suggested` reflection 时，首页可插入少量 reflection 项
- system item 只保留为未来 recall / prompt 插槽，不反向定义领域真相

这意味着首页不再只是最近记录列表，而是一个最小可持续的 mixed-object composition。

### 4.2 当前允许持久化的 layout 字段

当前允许用户与系统共同稳定维护的字段是：

- `widthColumns`
- `heightUnits`
- `zIndex`
- `rotationDegrees`
- `scale`
- `isHidden`

当前不做的事：

- 不持久化像素级拖拽坐标
- 不提前引入复杂自由布局编辑器
- 不把 layout 状态挂回 `RecordShell`

### 4.3 后续扩展顺序

- 先把 home board 的 mixed-object composition 稳定下来
- 再评估 people / arc / search 是否需要独立 board
- 最后再补用户显式调整与持久化布局编辑能力
## 5. Renderer 约束

`Renderer` 的职责是根据目标对象和上下文选择视觉表达。

它可以复用：

- `PhotoCard`
- `MusicCard`
- `TodayInHistoryCard`
- 其他纯展示卡片组件

但这些卡片组件不再是领域模型。

## 6. 与 AI 的关系

AI 不需要读每个像素，但应能读到结构化 composition 信号，例如：

- 哪些 artifacts 同组出现
- 哪些对象位于主位
- 哪些对象长期相邻
- 哪些系统卡长期被隐藏

## 7. 设计原则

1. Composition 是数据层，不是 view-only 技巧。
2. 布局字段不能回挂到 `RecordShell`。
3. 卡片外观可变化，Composition 结构必须稳定。
