# 10. RecordShell Field Specification

> 更新时间：2026-05-15

## 1. 文档目标

本文档定义 `Mory v3` 中 `RecordShell` 的正式字段边界。

`RecordShell` 是 capture shell，不承担内容事实、空间布局、长期关系或高层反思。

## 2. 正式字段

`RecordShell` 应保留：

- `id`
- `createdAt`
- `updatedAt`
- `captureSource`
- `rawText`
- `userMood`
- `userIntensity`
- `inputContext`
- `artifactIDs`

## 3. 字段职责

### 3.1 时间边界

- `createdAt`
- `updatedAt`

用于表达 capture event 的时间点与更新时间。

### 3.2 输入来源

- `captureSource`

用于表达 composer、voice、photo、import 等来源。

### 3.3 原始上下文

- `rawText`
- `inputContext`
- `userMood`
- `userIntensity`

用于保存用户显式输入与当下上下文。

### 3.4 内容引用

- `artifactIDs`

用于连接正式内容真相层。

## 4. 明确不属于 RecordShell 的职责

这些内容不应回挂到 `RecordShell`：

- 卡片类型
- 卡片尺寸
- 首页布局状态
- 人物关系
- 阶段对象
- 反思正文
- 任何 renderer 专属字段

## 5. 设计原则

1. `RecordShell` 只负责 capture 边界。
2. `Artifact` 承担内容事实。
3. `Composition` 承担空间组织。
4. `Entity Graph` 承担关系结构。
5. `TemporalArc` 与 `Reflection` 承担高层理解。
