# 10. Record Legacy Field Inventory

> 更新时间：2026-05-14
> 目的：记录 `Record` 旧字段清理状态，并明确剩余 fallback 层的收缩方向。

## 1. 当前判断

`Record` 已不再是主真相根。  
主录入链已经停止主动写入大部分旧展示字段。

当前剩余问题不是“是否要降级 Record”，而是：

1. 哪些旧字段仍被真实用户路径读取
2. 哪些只剩 fallback 价值
3. 哪些已经退化为 debug / calibration 依赖

## 2. 字段分类

### 2.1 `cardType`

状态：`removed from model`

当前用途：

- 无

当前判断：

- 主 composer capture 已不再写
- standalone add-card 已不再写
- `derivedCardKind` 已改为 `contentFirstCardKind ?? .text`
- `Record.cardType` 已从 SwiftData 模型物理移除

完成情况：

1. 旧数据在 detail / search / board fallback 中不再依赖 `cardType` 兜底
2. `CompositionProjector` 已直接生成 artifact-backed composition items
3. `RecordMapper` 已从首页投影链移除

### 2.2 `cardUnits`

状态：`removed from model`

当前判断：

- 已不再参与主读写链
- 已从 `Record` 模型物理移除

### 2.3 `cardWidthColumns`

状态：`removed from model`

当前判断：

- 已不再参与主读写链
- 已从 `Record` 模型物理移除

### 2.4 `dashboardCardSpanOverridesData`

状态：`removed from model`

当前判断：

- 主读取链已不再消费该字段
- 已从 `Record` 模型物理移除
- 旧 per-card span 现在统一由 `CompositionItemState` 负责

## 3. 真实主路径现状

已完成：

- composer capture 不再写 legacy `cardType`
- standalone add-card 不再写 legacy `cardType`
- standalone add-card 不再写默认 `cardUnits/cardWidthColumns`
- `Record.cardUnits/cardWidthColumns` 已从模型移除
- `RecordMapper` 主读取链不再读取 `dashboardCardSpanOverridesData`
- `Record.dashboardCardSpanOverridesData` 已从模型移除
- timeline detail entry 改为 content-kind 驱动
- today-in-history subtitle 改为 content-kind 驱动
- `Record.cardKind` 不再提供把新语义回写进 `cardType` 的 setter
- `derivedCardKind` 不再读取 `cardType`
- `Record.cardType` 已从模型移除
- `CompositionProjector` 直接渲染 artifacts，不再调用 `RecordMapper`
- photo / audio artifacts 与 `MediaCard` 共享 id，`MediaCard` 只作为二进制 payload backing
- analyze 主链已切到 `/api/analysis/records`
- analyze preview 主链已切到 `/api/analysis/preview`
- `RecordDetailView` 已切到 artifact evidence-first，`text/photo/audio/link/todo/music/map/weather/people` 优先从 `memoryView.artifacts` 和 analysis evidence 读取
- `MediaCard` 当前仅保留 photo/audio 的 payload backing；music/link/todo 的新写入路径已不再创建 `MediaCard`

剩余：

- `MediaCard` 仍作为 photo/audio payload backing store 存在
- 旧 timeline / preview 路径仍有部分 kind 推断依赖 `Record` 旧关系字段，后续要继续改为 artifact-backed 识别

## 4. 下一阶段动作

### 4.1 结构动作

1. 继续把 `RecordDetail` 的 section 数据源改为 artifact evidence-first
2. 梳理 `MediaCard` payload 字段，避免重新承载内容真相
3. 核对移除旧字段后的 SwiftData schema 迁移风险
4. 开始设计 Graph / Arc 一级体验与 Reflection API 的接口边界

### 4.2 UI 动作

在不返工架构的前提下，开始重做高频卡片内部版式：

1. `AudioCard`
2. `BookCard / FilmCard`
3. `RecordDetail` 中 artifact evidence 的可解释展示

## 5. 完成标准

当以下条件成立时，可认为 `Record` 基本完成降级：

1. 主录入链不再写 legacy 展示字段
2. 主读取链不再依赖 legacy 展示字段
3. 旧字段只剩 debug / migration 用途
4. `Record` 仅保留真正还在使用的 capture 相关字段
