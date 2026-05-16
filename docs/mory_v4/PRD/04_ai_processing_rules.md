# 04. AI Processing Rules

## 1. AI 处理的统一原则

v3 已确立：AI 只负责意义生成，不负责基础结构。

v4 扩展 Artifact 类型后，AI 处理分为两层：

| 层 | 执行位置 | 目的 | 延迟要求 |
|----|---------|------|---------|
| **L1: Artifact 预处理** | 本地 (iOS) | 把非文字 Artifact 转化为文字 | < 5s |
| **L2: 语义分析** | 服务端 (Go) | 从文字中提取实体、主题、情绪、故事线 | < 15s（目标） |

L1 是 v4 新增的。L2 是 v3 已有的（ArchitecturePipelineExecutor）。

## 2. L1: Artifact 预处理规则

### 2.1 处理矩阵

| ArtifactKind | L1 处理 | 输出字段 | iOS 框架 | 耗时 |
|-------------|--------|---------|---------|------|
| `text` | 无需处理 | textContent = 原文 | — | 0s |
| `photo` | Vision 分类 + 描述 + OCR | title, summary, textContent | Vision, VisionKit | < 3s |
| `audio` | Speech 转写 | textContent = 转写文字 | Speech | < 10s/min |
| `weather` | WeatherKit 查询 | title, summary, metadata | WeatherKit | < 2s |
| `location` | 反向地理编码 | title, summary, metadata | CoreLocation | < 1s |
| `music` | MusicKit 查询 | title, summary, metadata | MusicKit | < 1s |
| `link` | LPMetadataProvider | title, summary, metadata | LinkPresentation | < 3s |

### 2.2 L1 处理的输出规范

每种 Artifact 的 L1 处理必须输出**至少一个可读的文字字段**，用于下游 L2 分析。

输出优先级：
1. `textContent` — AI 分析的主要输入
2. `summary` — 展示用，也参与分析
3. `title` — 展示用

如果 L1 处理失败（例如 Vision 无法识别图片），Artifact 仍然保存，但 `textContent` 为空，L2 分析时忽略该 Artifact。

## 3. L2: 语义分析规则

### 3.1 分析输入组装

v3 的 AnalyzeRequestBuilder 已定义输入格式。v4 扩展为：

```
分析输入 = {
  rawText: RecordShell.rawText,
  artifacts: [
    { kind: "photo", content: "一群朋友在海边烧烤，背景是日落" },
    { kind: "audio", content: "今天和小王聊了很久，他说他打算辞职" },
    { kind: "weather", content: "晴天 28°C 上海" },
    { kind: "location", content: "金山城市沙滩" },
    { kind: "music", content: "正在听 Hotel California - Eagles" }
  ],
  knownEntities: [...已有的人物/主题/地点实体]
}
```

### 3.2 分析输出不变

L2 输出仍然是 v3 定义的 `RecordAnalysisSnapshot`：

- summary
- themes
- emotionInterpretation
- salienceScore
- retrievalTerms
- entityMentions
- candidateEdges
- followUpCandidates
- reflectionHint

### 3.3 多模态上下文对分析的影响

AI 在分析时，天气/地点/音乐等上下文可以增强理解：

| 场景 | 无上下文 | 有上下文 |
|------|---------|---------|
| 用户写 "今天好累" | AI: "用户表达疲劳" | AI: "用户在30°C高温天从公司步行回家（地点从办公室到住所），且已连续第3天提到疲劳（故事线关联）" |
| 用户拍了一张照片 | AI: "照片内容不明" | AI: "海边日落照片，配合地点（金山沙滩）和天气（晴天28°C），可能是一次海边聚会" |

## 4. AI 内容把关规则（P1）

### 4.1 实体去重

当 AI 输出新的 entityMention 时，GraphUpdater 需要检查：

| 检查项 | 规则 | 示例 |
|-------|------|------|
| 别名匹配 | 归一化比较（去空格、大小写） | "小王" = "王小明" 需要用户确认 |
| 同义词 | AI 判断是否指同一人 | "我妈" = "妈妈" = "王阿姨" |
| 合并阈值 | 共现次数 ≥ 3 且 AI 置信度 > 0.8 | 自动合并 |

### 4.2 故事线误判检测

```
if arc.relatedMemories.count < 3 {
  arc.status = .candidate  // 不自动提升
}

if arc.themeCoherence < 0.5 {
  // 故事线主题连贯性不足，标记需要复审
  arc.needsReview = true
}
```

### 4.3 感悟质量过滤

```
if reflection.confidence < 0.4 {
  drop  // 不保存
}

if reflection.body.count < 20 {
  drop  // 内容太短，无信息量
}

if isDuplicateOfExisting(reflection) {
  drop  // 与已有感悟重复
}
```

## 5. AI 速度优化策略

当前 53s 的拆解：

```
Step 2: Analyze        ~25s（DeepSeek API 调用）
Step 8: Reflection     ~25s（DeepSeek API 调用）
其他步骤（本地）       ~3s
```

### 5.1 立即可做的优化

| 优化项 | 预期效果 | 工作量 |
|-------|---------|-------|
| 确认 AI_MODEL 是否为 deepseek-reasoner | 如果是，换成 deepseek-chat 可降到 ~20s | 1 小时 |
| Analyze 和 Reflection 并行 | 总时间 = max(25s, 25s) ≈ 25s | 0.5 天 |
| 减少 prompt 长度 | 每次调用降低 3-5s | 0.5 天 |
| streaming 反馈 | 不减时间，但用户感知更好 | 1 天 |

### 5.2 中期优化

| 优化项 | 预期效果 | 前提条件 |
|-------|---------|---------|
| 切换到更快的模型（Claude Haiku / GPT-4o-mini） | < 10s | 验证分析质量 |
| 本地 LLM 做轻量预分析 | < 3s 的粗分析 + 后台精分析 | iOS 18 Core ML |
| 缓存相似 prompt 的分析结果 | 重复场景秒回 | 需要相似度判断 |
