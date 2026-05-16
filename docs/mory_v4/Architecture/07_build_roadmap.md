# 07. Build Roadmap

## 1. 路线目标

本路线图定义 v4 的实施顺序、每个阶段的交付物和验收标准。

## 2. 总体原则

1. 每个 Phase 独立可交付，不存在跨 Phase 依赖。
2. 先做基础设施（认证、速度），再做功能（多模态）。
3. 每个 Phase 完成后可以发版。
4. 本地 AI 处理优先于服务端处理。

## 3. Phase 0: 基础修复（1 天）

### 目标

解决 v3 遗留的基础设施问题。

### 动作

| # | 任务 | 文件 | 工作量 |
|---|------|------|-------|
| 0-1 | 认证持久化 | AppleAuthService, KeychainCredentialStore, MoryApp | 0.5 天 |
| 0-2 | AI 思考模式配置 | server/internal/ai/openai.go | 0.5 小时 |
| 0-3 | v3 本地化 commit（如果未提交） | 所有本地化文件 | 0.5 小时 |

### 验收标准

- [ ] 冷启动不需要重新登录
- [ ] AI 请求使用 `thinking: { type: "disabled" }` 禁用思考模式
- [ ] 所有 v3 改动已提交

---

## 4. Phase 1: AI 速度优化（1.5 天）

### 目标

端到端分析时间从 ~53s 降到 < 15s。

### 动作

| # | 任务 | 文件 | 工作量 |
|---|------|------|-------|
| 1-1 | Analyze 和 Reflection 并行化 | ArchitecturePipelineExecutor | 0.5 天 |
| 1-2 | Prompt 长度精简 | AnalyzeRequestBuilder, server ai/ | 0.5 天 |
| 1-3 | 分析完成通知机制 | NotificationCenter 替代轮询 | 0.5 天 |

### 验收标准

- [ ] 端到端分析 < 15s（DeepSeek Chat 模型）
- [ ] MemoryDetailView 收到分析完成通知后自动刷新
- [ ] Debug 页显示分析耗时

---

## 5. Phase 2: 图片 AI 解析（2 天）

### 目标

照片选取后自动生成描述，纳入正常解析流程。

### 动作

| # | 任务 | 文件 | 工作量 |
|---|------|------|-------|
| 2-1 | PhotoArtifactProcessor 实现 | Infrastructure/AI/PhotoArtifactProcessor.swift (新建) | 1 天 |
| 2-2 | CaptureComposerView 集成 | Features/Capture/CaptureComposerView.swift | 0.5 天 |
| 2-3 | AnalyzeRequestBuilder 扩展 | Infrastructure/Analysis/AnalyzeRequestBuilder.swift | 0.5 天 |

### 新建文件

```
mory/Infrastructure/AI/PhotoArtifactProcessor.swift
```

### 验收标准

- [ ] 选取照片后 < 3s 生成描述
- [ ] 照片描述出现在 Artifact.textContent 中
- [ ] 照片描述参与 AI 分析（出现在 AnalysisSnapshot.summary 中）
- [ ] OCR 文字正确提取
- [ ] 缩略图正确生成并展示

---

## 6. Phase 3: 录音转文字（2 天）

### 目标

录音后自动转写为文字，作为 rawText 参与解析。

### 动作

| # | 任务 | 文件 | 工作量 |
|---|------|------|-------|
| 3-1 | AudioTranscriptionService 实现 | Infrastructure/AI/AudioTranscriptionService.swift (新建) | 1 天 |
| 3-2 | CaptureComposerView 集成 | Features/Capture/CaptureComposerView.swift | 0.5 天 |
| 3-3 | 转写结果编辑 UI | Features/Capture/CaptureComposerView.swift | 0.5 天 |

### 新建文件

```
mory/Infrastructure/AI/AudioTranscriptionService.swift
```

### 验收标准

- [ ] 录音结束后 < 10s/分钟 完成转写
- [ ] 转写文字出现在 textContent 中
- [ ] 用户可以在保存前编辑转写文字
- [ ] 支持中文和英文
- [ ] rawText 自动填充为转写文字（如果用户没有手动输入）

---

## 7. Phase 4: 上下文自动采集（3 天）

### 目标

每次 capture 自动附加天气、地点、音乐。

### 动作

| # | 任务 | 文件 | 工作量 |
|---|------|------|-------|
| 4-1 | LocationContextService | Infrastructure/Context/LocationContextService.swift (新建) | 0.5 天 |
| 4-2 | WeatherContextService | Infrastructure/Context/WeatherContextService.swift (新建) | 0.5 天 |
| 4-3 | MusicContextService | Infrastructure/Context/MusicContextService.swift (新建) | 0.5 天 |
| 4-4 | ContextAutoCollector | Infrastructure/Context/ContextAutoCollector.swift (新建) | 0.5 天 |
| 4-5 | ContextPermissionManager | Infrastructure/Context/ContextPermissionManager.swift (新建) | 0.5 天 |
| 4-6 | CaptureArtifactDraft 扩展 | Domain/MemoryFeatureModels.swift | 0.25 天 |
| 4-7 | MemoryCaptureArtifactBuilder 扩展 | Infrastructure/Analysis/MemoryCaptureArtifactBuilder.swift | 0.25 天 |

### 新建文件

```
mory/Infrastructure/Context/LocationContextService.swift
mory/Infrastructure/Context/WeatherContextService.swift
mory/Infrastructure/Context/MusicContextService.swift
mory/Infrastructure/Context/ContextAutoCollector.swift
mory/Infrastructure/Context/ContextPermissionManager.swift
```

### Info.plist 变更

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Mory 需要你的位置来记录天气和地点信息</string>
<key>NSAppleMusicUsageDescription</key>
<string>Mory 可以记录你正在听的音乐</string>
```

### Capability 变更

- Apple Developer Portal: 启用 WeatherKit
- Xcode: 添加 WeatherKit capability
- Xcode: 添加 MusicKit capability（如果尚未添加）

### 验收标准

- [ ] 授权位置后，每次保存自动附加 location Artifact
- [ ] 授权位置后，每次保存自动附加 weather Artifact
- [ ] 授权 MusicKit 后，播放音乐时保存自动附加 music Artifact
- [ ] 未授权时静默跳过，不影响保存
- [ ] 上下文采集超时 3s 自动放弃
- [ ] MemoryDetailView 正确展示天气/地点/音乐 Artifact
- [ ] 天气/地点/音乐参与 AI 分析（出现在 prompt 中）

---

## 8. Phase 5: 链接 URL 预览（1 天）

### 目标

粘贴链接后自动提取元数据。

### 动作

| # | 任务 | 文件 | 工作量 |
|---|------|------|-------|
| 5-1 | LinkMetadataExtractor | Infrastructure/AI/LinkMetadataExtractor.swift (新建) | 0.5 天 |
| 5-2 | CaptureComposerView 集成 | Features/Capture/CaptureComposerView.swift | 0.5 天 |

### 验收标准

- [ ] 粘贴 URL 后 < 5s 显示标题和预览图
- [ ] link Artifact 的 title/summary 来自页面元数据

---

## 9. Phase 6: 主页卡片连接（2 天）

### 目标

Today Board 展示真实数据。

### 动作

| # | 任务 | 文件 | 工作量 |
|---|------|------|-------|
| 6-1 | HomeBoardStoreBuilder 改造 | Infrastructure/Analysis/HomeBoardStoreBuilder.swift | 1 天 |
| 6-2 | MemorySummary 扩展 contextArtifacts | Domain/MemoryFeatureModels.swift | 0.25 天 |
| 6-3 | 卡片渲染 UI | Features/Home/HomeScreen.swift | 0.5 天 |
| 6-4 | 空态引导 | Features/Home/HomeScreen.swift | 0.25 天 |

### 验收标准

- [ ] 首页展示最近 3 条记忆卡片
- [ ] 记忆卡片展示天气/地点/音乐上下文
- [ ] 有 active arc 时展示故事线卡片
- [ ] 有 suggested reflection 时展示感悟卡片
- [ ] 记忆 < 3 条时展示引导卡片

---

## 10. Phase 7: AI 内容把关（1.5 天）

### 目标

提升 AI 输出质量。

### 动作

| # | 任务 | 文件 | 工作量 |
|---|------|------|-------|
| 7-1 | 实体去重检查 | Infrastructure/Analysis/GraphUpdater.swift | 0.5 天 |
| 7-2 | 感悟质量过滤 | Infrastructure/Analysis/TemporalArcPromoter.swift | 0.5 天 |
| 7-3 | 故事线连贯性检查 | Infrastructure/Analysis/TemporalArcCandidateBuilder.swift | 0.5 天 |

### 验收标准

- [ ] 同一个人不会在图谱中出现多个节点
- [ ] 低质量感悟（< 20 字、置信度 < 0.4）被过滤
- [ ] 不相关记忆不会被聚到同一条故事线

---

## 11. 时间总览

| Phase | 内容 | 工作量 | 累计 |
|-------|------|-------|------|
| Phase 0 | 基础修复 | 1 天 | 1 天 |
| Phase 1 | AI 速度优化 | 1.5 天 | 2.5 天 |
| Phase 2 | 图片 AI 解析 | 2 天 | 4.5 天 |
| Phase 3 | 录音转文字 | 2 天 | 6.5 天 |
| Phase 4 | 上下文自动采集 | 3 天 | 9.5 天 |
| Phase 5 | 链接 URL 预览 | 1 天 | 10.5 天 |
| Phase 6 | 主页卡片连接 | 2 天 | 12.5 天 |
| Phase 7 | AI 内容把关 | 1.5 天 | 14 天 |
| **总计** | | **14 天** | |

## 12. 发版节点

| 节点 | 包含 Phase | 版本号建议 |
|------|-----------|-----------|
| Alpha 1 | 0 + 1 | v4.0-alpha.1 |
| Alpha 2 | 0 + 1 + 2 + 3 | v4.0-alpha.2 |
| Beta 1 | 0 ~ 4 | v4.0-beta.1 |
| Beta 2 | 0 ~ 6 | v4.0-beta.2 |
| Release | 0 ~ 7 | v4.0 |

## 13. 风险

| 风险 | 影响 | 缓解 |
|------|------|------|
| WeatherKit capability 审批延迟 | Phase 4 延迟 | 提前在 Developer Portal 申请 |
| Vision 图片描述质量不足 | 照片解析效果差 | 评估是否需要服务端 AI 补充 |
| Speech 转写中文准确率不够 | 录音功能可用性差 | 允许用户手动编辑转写结果 |
| DeepSeek 并行调用限流 | AI 速度优化打折 | 检查 API rate limit |
| MusicKit 在模拟器不可用 | 开发测试困难 | 所有 music 相关需真机测试 |
