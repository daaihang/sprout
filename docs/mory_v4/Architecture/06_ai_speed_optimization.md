# 06. AI Speed Optimization

## 1. 现状分析

v3 端到端分析耗时 ~53 秒。拆解：

```
ArchitecturePipelineExecutor.execute()
  Step 1: fetchRecord              ~0.1s (本地)
  Step 2: analyze()                ~25s  (DeepSeek API)  ← 瓶颈 1
  Step 3: saveAnalysis             ~0.1s (本地)
  Step 4: updateGraph              ~0.5s (本地)
  Step 5: buildArtifacts           ~0.1s (本地)
  Step 6: buildArcCandidates       ~0.5s (本地)
  Step 7: promote()                ~0.5s (本地)
  Step 8: generateReflection()     ~25s  (DeepSeek API)  ← 瓶颈 2
  Step 9: saveReflection           ~0.1s (本地)
  总计                             ~53s
```

两次 API 调用占 95% 时间，且是串行的。

## 2. 优化方案

### 2.1 Phase A: 保持模型 + 禁用思考模式（0.5 小时）

DeepSeek v4-pro 模型支持 `thinking` 参数控制思考模式：
- `thinking.type = "enabled"` — 启用思考模式（默认），每次 25-30s
- `thinking.type = "disabled"` — 禁用思考模式，每次 8-12s

通过在请求中添加 `thinking: { type: "disabled" }`，可以在保持模型能力的同时大幅降低延迟：

```go
// server/internal/ai/openai.go
request := openAIChatRequest{
    Messages: messages,
    Thinking: &thinkingConfig{Type: "disabled"},  // 禁用思考模式
}
```

预期效果：53s → ~25s（Analyze + Reflection 串行）

> 注意：Phase B（并行化）会进一步降低到 ~15s，建议先完成 Phase A 验证延迟改善。

### 2.2 Phase B: Analyze 和 Reflection 并行（0.5 天）

当前 Step 2（Analyze）和 Step 8（Reflection）是串行的。但 Reflection 的输入不完全依赖 Analyze 的输出。

改造 ArchitecturePipelineExecutor：

```swift
// 并行方案

// 阶段 1: 获取数据 (本地)
let record = fetchRecord()
let artifacts = fetchArtifacts()
let knownEntities = fetchEntities()

// 阶段 2: 并行 AI 调用
async let analysisResult = analysisService.analyze(record, artifacts, knownEntities)
async let reflectionResult = analysisService.generateReflection(record, artifacts, ...)

let analysis = try await analysisResult
let reflection = try await reflectionResult

// 阶段 3: 本地处理 (串行，依赖 analysis)
saveAnalysis(analysis)
updateGraph(analysis)
buildArcCandidates(analysis)
promote()
saveReflection(reflection)
```

预期效果：25s → max(12s, 12s) ≈ 12s

**注意：** 并行化意味着 Reflection 在生成时不知道 Analyze 的完整结果（实体、主题等）。这是可接受的退化：

- Reflection 的主要输入是 rawText + artifacts，不是 analysis
- 后续 v5 可以做二次 reflection（用 analysis 结果增强）

### 2.3 Phase C: 减少 Prompt 长度（0.5 天）

审查 AnalyzeRequestBuilder 和 ReflectionRequestBuilder 的 prompt：

| 优化项 | 方法 |
|-------|------|
| system prompt 长度 | 精简到 < 500 字 |
| 已知实体列表 | 只传最近 20 个，不传全量 |
| artifact 内容 | 截断到前 500 字 |
| few-shot 示例 | 移除或缩减 |

预期效果：每次调用降低 2-3s

### 2.4 Phase D: Streaming 反馈（1 天）

不减少总时间，但改善感知体验：

```
用户保存 → "已保存到本地" (立即)
         → "正在解析..." (0.5s)
         → "发现 3 个主题" (流式更新)
         → "识别到 2 个人物" (流式更新)
         → "解析完成" (最终)
```

实现方式：

- 服务端 API 改为 SSE（Server-Sent Events）
- 客户端用 `URLSession` stream 接收
- 每收到一个中间结果，更新 pipelineStatus

### 2.5 Phase E: 切换模型（需要评估）

| 模型 | 分析质量 | 速度 | 成本 |
|------|---------|------|------|
| DeepSeek Chat | 当前基线 | ~12s | 低 |
| Claude 3.5 Haiku | 需验证 | ~3s | 中 |
| GPT-4o-mini | 需验证 | ~5s | 中 |
| 本地 Core ML | 需验证 | ~2s | 零 |

建议 v4 先做 Phase A + B + C，达到 < 15s 目标。Phase D 和 E 作为增强。

## 3. 客户端感知优化

### 3.1 乐观更新

保存时立即显示记忆卡片，pipelineStatus = .running。分析完成后异步更新。

### 3.2 进度展示

```swift
// MemoryDetailView 中
if pipelineStatus.stage == .running {
    ProgressView()
    Text("pipeline.status.running")  // "解析中"
}
```

### 3.3 自动刷新

MemoryDetailView 已有 4 秒自动轮询。v4 不改变此行为，但考虑改为 notification-based：

```
ArchitecturePipelineExecutor 完成后
  → 发送 NotificationCenter.post(.memoryAnalysisCompleted)
  → MemoryDetailView 收到后刷新
  → 首页 Board 收到后重新生成
```

## 4. 服务端优化（需要服务端配合）

| 优化项 | 工作量 | 效果 |
|-------|-------|------|
| 开启 API 响应缓存 | 0.5 天 | 相似内容秒回 |
| 减少重试次数（当前 3 次） | 配置修改 | 失败时更快返回 |
| 连接池复用 | 0.5 天 | 减少连接建立时间 |
| 批量分析接口 | 1 天 | 一次请求分析多条记忆 |

## 5. 量化目标

| 指标 | v3 基线 | Phase A | Phase A+B | Phase A+B+C | 最终目标 |
|------|--------|---------|-----------|-------------|---------|
| Analyze 单次 | ~25s | ~12s | ~12s | ~10s | < 10s |
| Reflection 单次 | ~25s | ~12s | ~12s | ~10s | < 10s |
| 端到端（串行） | ~53s | ~27s | — | — | — |
| 端到端（并行） | — | — | ~15s | ~12s | < 15s |
| 用户感知等待 | 53s | 27s | 15s | 12s | < 5s (streaming) |
