# Mory v4 Architecture Index

> 更新时间：2026-05-17

## 1. 文档目标

本组文档定义 v4 的架构增量。

v4 不重写 v3 架构，它在现有五层模型之上增加：

- Artifact 预处理层（本地 AI）
- 保存前上下文候选采集服务
- 认证持久化
- AI 速度优化
- AnalyzeRequestBuilder 扩展

## 2. 架构原则

1. 新增的 Artifact 类型不改变 ontology。`ArtifactKind` 已预定义 9 种类型。
2. 所有非文字 Artifact 必须在本地转化为文字后再参与 L2 分析。
3. 自动上下文以保存前候选形式进入 Artifact，不是 RecordShell 字段。
4. 本地 AI（Vision/Speech）不发送用户数据到服务端。

## 3. 文档结构

1. [01_artifact_kind_expansion.md](01_artifact_kind_expansion.md) — ArtifactKind 扩展与 CaptureArtifactDraft 改造
2. [02_capture_pipeline.md](02_capture_pipeline.md) — 统一 Capture 管道设计
3. [03_ai_artifact_processors.md](03_ai_artifact_processors.md) — 每种 Artifact 的本地 AI 处理器
4. [04_auto_context_services.md](04_auto_context_services.md) — 天气/地点/音乐自动采集服务
5. [05_auth_persistence.md](05_auth_persistence.md) — Apple 登录持久化方案
6. [06_ai_speed_optimization.md](06_ai_speed_optimization.md) — 服务端 AI 速度优化
7. [07_build_roadmap.md](07_build_roadmap.md) — 实施路线图与验收标准
8. [../STATUS_2026-05-17.md](../STATUS_2026-05-17.md) — 当前进度、文档修正和真机验证清单

## 4. 新增文件预览

v4 实施完成后，新增文件预估：

```
mory/
  Infrastructure/
    Context/
      WeatherContextService.swift      (新建)
      LocationContextService.swift     (新建)
      MusicContextService.swift        (新建)
      ContextPermissionManager.swift   (新建)
    AI/
      PhotoArtifactProcessor.swift     (新建)
      AudioTranscriptionService.swift  (新建)
      LinkMetadataExtractor.swift      (新建)
    Analysis/
      AnalyzeRequestBuilder.swift      (修改：扩展 artifact 输入)
      ArchitecturePipelineExecutor.swift (修改：Analyze 后安全并行优化，待实施)
    Auth/
      AppleAuthService.swift           (修改：持久化)
      KeychainCredentialStore.swift    (修改：token 刷新)
  Domain/
    Content/
      Artifact.swift                   (不变)
    MemoryFeatureModels.swift          (修改：MemorySummary 扩展)
  Features/
    Capture/
      CaptureComposerView.swift        (修改：保存前上下文候选 + 多模态)
    Home/
      HomeScreen.swift                 (修改：Board 卡片渲染)
```
