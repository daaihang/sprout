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

- `derivedCardKind` 在无法从真实内容推导时回退到 `cardType`
- 少量兼容 helper 仍会在没有内容信号时回退到 `cardType`

当前判断：

- 主 composer capture 已不再写
- standalone add-card 已不再写
- 真实用户路径读取已基本改为 content-first

删除前条件：

1. 确认旧数据在 detail / search / board fallback 中不再依赖它兜底
2. 核对 `RecordMapper` 与 `CompositionProjector` 的剩余兼容分支
3. 评估 SwiftData schema 删除 `cardType` 的迁移策略

删除优先级：高

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
- analyze 主链已切到 `/api/analysis/records`
- analyze preview 主链已切到 `/api/analysis/preview`

剩余：

- `derivedCardKind` 仍保留对 `cardType` 的最后 fallback
- `Record.cardType` 字段本身仍留在 SwiftData 模型中

## 4. 下一阶段动作

### 4.1 结构动作

1. 继续收缩 `cardType` 的兼容 fallback 范围
2. 继续减少 `RecordMapper` / detail fallback 对 `derivedCardKind` 的依赖
3. 评估 `cardType` 是否进入彻底删除阶段
4. 核对移除旧字段后的 SwiftData schema 迁移策略

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
4. `Record` 仅保留真正还在使用的 capture 相关字段
