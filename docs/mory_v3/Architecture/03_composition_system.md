# 03. Composition System

## 1. 当前 UI 架构的优点与问题

当前首页已经不是传统日记时间轴，而是 container-first 的卡片系统。  
这是项目已经做对的部分。

优点：

- `RecordMapper` 已经在做内容到展示的投影
- `StickerGridLayout` 已经在做空间排布
- `CardContainer` 已经引入旋转、缩放、zIndex 等空间线索

问题：

- Container 还不是持久化领域对象
- 布局状态仍依赖 `Record` 上的尺寸覆盖字段
- 空间关系没有进入 AI 和语义层

所以现在要做的不是抛弃首页，而是把它从“视觉技巧”升级为“Composition system”。

## 2. Composition 的职责

Composition 层负责回答：

- 哪些内容在同一个空间中被摆在一起
- 每个对象多大、在哪里、位于哪一层
- 哪些内容互相覆盖、相邻或聚类
- 用户如何在板面上组织记忆

这层不是纯前端细节。  
它是记忆系统结构的一部分。

## 3. 为什么空间关系本身有意义

在记忆产品里，以下信息都是有价值的：

- 用户总把某个人相关内容放在一起
- 某张图总被放在正中央
- 某些 artifact 经常成组出现
- 某类内容经常被压到边缘

这些并非装饰，而是潜在语义。

如果空间层不持久化，AI 和 graph 永远看不到这些线索。

## 4. 建议的数据结构

### 4.1 Board

Board 是一个展示上下文容器，例如：

- 某一天首页
- 某个人物页
- 某个阶段页

### 4.2 Composition

Composition 是某个 board 下的一组排布单元。

### 4.3 CompositionItem

CompositionItem 代表一个被摆放出来的对象。

建议字段：

- target type
- target id
- width/height units
- x/y hint
- zIndex
- rotation
- scale
- style

## 5. 布局算法与持久化的边界

### 5.1 应持久化的内容

- item span
- zIndex
- rotation
- scale
- 用户显式调整结果
- 稳定排序

### 5.2 不必持久化的内容

- 一次渲染中的临时动画态
- 每帧计算的像素值
- 纯响应式导出的最终 frame

换句话说：

持久化的是“布局意图与结果”，不是“每次渲染的屏幕坐标”。

## 6. 渲染层建议

现阶段不建议删除所有现有卡片组件。  
正确做法是加一层：

`ArtifactRenderer`

职责：

- 根据 artifact kind 和 composition context 选择合适的视觉呈现
- 复用现有 `PhotoCard / MusicCard / WeatherCard / PeopleCard ...`
- 逐步让这些卡片从“业务真相对象”降级为“渲染器实现”

## 7. RecordMapper 的重构方向

当前 `RecordMapper.allCards(record:)` 是过渡期非常关键的中间层，但长期会成为瓶颈。

它现在承担了：

- 读取 record
- 判断显示哪些卡
- 构造具体 card data
- 决定 span
- 决定 record section

长期建议拆成：

1. `RecordAggregateBuilder`
2. `CompositionProjector`
3. `ArtifactRenderer`

这能把：

- 聚合构建
- 组合投影
- 视觉渲染

分成三个稳定步骤。

## 8. 首页组合来源建议

### 8.1 短期

首页仍然可由“按天查询 records -> 投影成 composition items”得到。

### 8.2 中期

首页应支持独立的 `DayBoard` / `HomeBoard` 持久化对象。

### 8.3 长期

首页不一定只展示单日 record，而是展示“当前相关的记忆空间”，包括：

- 今日记录
- 主动回顾
- 相关人物
- 阶段入口

## 9. Composition 与 AI 的关系

AI 不需要直接读每个像素，但应该能看到结构化的 composition 信息，例如：

- 哪些 artifacts 同组出现
- 哪个 item 处于视觉主位
- 哪些对象长期相邻

这能支持：

- spatial reasoning
- prominence inference
- grouping hints

## 10. 设计约束

为了避免再次失控，Composition 层应遵守：

1. View 组件不是持久化真相
2. 布局字段不再继续挂到 `Record`
3. 卡片类型不是领域模型根
4. 渲染层可多样，但 Composition 数据结构要稳定
