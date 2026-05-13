# 10. Record Legacy Field Inventory

> 更新时间：2026-05-14
> 目的：为 `Record` 旧字段清理进入“待删除候选”阶段建立显式台账。

## 1. 当前判断

`Record` 已不再是主真相根。  
主录入链已经停止主动写入大部分旧展示字段。

当前剩余问题不是“是否要降级 Record”，而是：

1. 哪些旧字段仍被真实用户路径读取
2. 哪些只剩 fallback 价值
3. 哪些已经退化为 debug / calibration 依赖

## 2. 字段分类

### 2.1 `cardType`

状态：`fallback-only / debug-compatible`

当前用途：

- `Record.cardKind` setter 仍会写回 `cardType`
- `derivedCardKind` 在无法从真实内容推导时回退到 `cardType`
- debug / calibration sample 仍直接写 `record.cardType`

当前判断：

- 主 composer capture 已不再写
- standalone add-card 已不再写
- 真实用户路径读取已基本改为 content-first

删除前条件：

1. 移除 debug / calibration 对 `record.cardType` 的直接写入
2. 确认旧数据在 timeline / today-in-history / detail 中不再依赖它兜底

删除优先级：高

### 2.2 `cardUnits`

状态：`legacy-only`

当前用途：

- `Record.containerSpan`
- `legacyDashboardContainerSpan`

当前判断：

- 首页主 composition 路径默认 span 已不再依赖
- 新录入链已不再写

删除前条件：

1. `legacyDashboardContainerSpan` 只剩 debug 或存量 fallback 使用
2. 明确旧数据是否需要一次性迁移到 `CompositionItemState`

删除优先级：高

### 2.3 `cardWidthColumns`

状态：`legacy-only`

当前用途：

- `Record.containerSpan`
- `legacyDashboardContainerSpan`

当前判断：

- 与 `cardUnits` 同步处理

删除前条件：

1. 与 `cardUnits` 同步完成

删除优先级：高

### 2.4 `dashboardCardSpanOverridesData`

状态：`legacy-fallback`

当前用途：

- `legacyDashboardContainerSpan`
- `setDashboardContainerSpan`
- 旧 per-card span override 存量兼容

当前判断：

- 首页主路径已迁到 `CompositionItemState`
- 这是剩余 legacy layout 兼容最核心的一项

删除前条件：

1. 确认没有真实用户路径继续写入
2. 明确旧 span override 是否迁移或放弃

删除优先级：中高

## 3. 真实主路径现状

已完成：

- composer capture 不再写 legacy `cardType`
- standalone add-card 不再写 legacy `cardType`
- standalone add-card 不再写默认 `cardUnits/cardWidthColumns`
- timeline detail entry 改为 content-kind 驱动
- today-in-history subtitle 改为 content-kind 驱动

剩余：

- `RecordMapper` 仍保留 legacy span 分支
- debug / calibration 仍直接写旧字段

## 4. 下一阶段动作

### 4.1 结构动作

1. 把 debug / calibration 从 `record.cardType` 直写迁到兼容 helper
2. 评估 `legacyDashboardContainerSpan` 的真实调用面
3. 明确 `cardUnits/cardWidthColumns/dashboardCardSpanOverridesData` 是否进入迁移或直接废弃

### 4.2 UI 动作

在不返工架构的前提下，开始重做高频卡片内部版式：

1. `QuoteCard`
2. `PhotoCard`
3. `PhaseReflectionCard`

## 5. 完成标准

当以下条件成立时，可认为 `Record` 基本完成降级：

1. 主录入链不再写 legacy 展示字段
2. 主读取链不再依赖 legacy 展示字段
3. 旧字段只剩 debug / migration 用途
4. 可明确列出待删字段与删前条件
