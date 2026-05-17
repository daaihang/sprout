# 06. Home Board Connection

## 1. 问题

v3 首页有 Board / Composition 系统，但当前 Today Board 是空的或只有静态内容。

用户打开 app 看到的是空白，而不是有意义的记忆回顾。

## 2. 目标

v4 的 Today Board 必须：

1. 展示今天/最近的真实记忆
2. 展示进行中的故事线
3. 展示最新的感悟
4. 随着用户积累内容，卡片越来越丰富

## 3. Board 组成规则

Today Board 的卡片由 HomeBoardStoreBuilder 自动生成。规则：

### 3.1 卡片类型与优先级

| 优先级 | 卡片类型 | 数据来源 | 展示条件 |
|-------|---------|---------|---------|
| 1 | 最新记忆 | 最近 3 条 MemorySummary | 始终展示 |
| 2 | 进行中的故事线 | status = .accepted 的 TemporalArc | 有 accepted arc 时展示 |
| 3 | 最新感悟 | status = .suggested 的 ReflectionSnapshot | 有新感悟时展示 |
| 4 | 今天回顾 | 去年/上月同日的记忆 | 有历史数据时展示 |
| 5 | 关系提醒 | 最近 30 天未出现的高频人物 | 有足够人物数据时展示 |

### 3.2 卡片数量限制

- 首页最多展示 8 张卡片
- 如果材料不足，展示空态引导

### 3.3 卡片刷新时机

| 触发 | 动作 |
|------|------|
| App 进入前台 | 如果距上次刷新 > 5 分钟，重新生成 |
| 新记忆保存后 | 立即重新生成 |
| 分析完成后 | 立即重新生成（可能产生新 arc/reflection） |
| 手动下拉刷新 | 立即重新生成 |

## 4. 卡片渲染规则

### 4.1 记忆卡片

```
┌────────────────────────────┐
│ 📝 今天和小王聊了很久       │
│ 10:30 · 星巴克 南京西路     │
│ 多云 22°C · Queen 正在播放  │
│ #职场 #友情                │
└────────────────────────────┘
```

底部的天气、地点、音乐来自 v4 新增的上下文 Artifact。

### 4.2 故事线卡片

```
┌────────────────────────────┐
│ 📖 跑步习惯养成             │
│ 第 23 天 · 7 条记忆         │
│ 进行中                     │
└────────────────────────────┘
```

### 4.3 感悟卡片

```
┌────────────────────────────┐
│ ✨ 你最近在重新思考职业方向   │
│ 基于最近 5 条记忆的模式      │
│ 查看 · 保存 · 忽略          │
└────────────────────────────┘
```

## 5. 实现路径

### 5.1 HomeBoardStoreBuilder 改造

当前 `HomeBoardStoreBuilder` 存在但产出为空。v4 需要：

1. 查询最近记忆（已有 `fetchRecentMemories`）
2. 查询 accepted arcs（已有 `fetchTemporalArcs` / graph context summaries）
3. 查询 suggested reflections（已有 `fetchReflections`）
4. 按优先级组装 CompositionItem
5. 写入 Board + Composition

> 2026-05-17 实现状态：当前代码中 `TemporalArcStatus` 没有 `.active`，产品 UI 使用 `.accepted` 表示可展示故事线。后续如果需要区分 “candidate / active / accepted”，需要先补状态迁移规则，再更新 Home 筛选。

### 5.2 卡片上下文展示

记忆卡片需要展示关联的 weather/location/music Artifact 的摘要。
这需要 MemorySummary 查询时 JOIN 关联 Artifact。

当前 `MemorySummary` 只有 `primaryArtifact`。v4 需要扩展为：

```swift
struct MemorySummary {
    let record: RecordShell
    let primaryArtifact: Artifact?
    let contextArtifacts: [Artifact]  // weather + location + music
    let artifactCount: Int
    let pipelineStatus: MemoryPipelineStatusSnapshot?
}
```

## 6. 空态设计

用户记忆数 < 3 时，Today Board 展示引导卡片：

```
┌────────────────────────────┐
│ 👋 欢迎使用 Mory            │
│ 记录你的第一条记忆，         │
│ 故事线和感悟会逐渐浮现。     │
│ [开始记录]                  │
└────────────────────────────┘
```
