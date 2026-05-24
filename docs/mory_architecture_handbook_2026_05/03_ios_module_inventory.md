# 03. iOS Module Inventory

本文按目录梳理 iOS 侧模块。每个模块包含职责、输入输出、主要工作流、关键文件、当前问题和解决方案。

## 1. App

职责：

- App 生命周期和 dependency composition。
- Auth state 与 local data session 创建。
- Sentry、AppDelegate、URL/deep link、background coordinator 装配。
- Root tab/shell 和 pending external capture URL 传递。

输入：

- 用户登录状态。
- Deep link URL。
- App lifecycle events。
- Remote notification / BGTask registration。

输出：

- `MoryRootView`。
- owner-scoped `MoryLocalDataSession`。
- environment values：repository、auth、cloud intelligence、remote push。

关键文件：

- `MoryApp.swift`
- `MoryRootView.swift`
- `MoryAppDependencies.swift`
- `MoryAppDelegate.swift`
- `MoryLocalDataSession.swift`

问题：

- App composition root 合理，但接入的 runtime concern 已很多。
- `MoryRootView` 同时处理 tab shell、composer seed、external capture URL、auth/local state 变化。

解决方案：

- 保留 `MoryApp` 作为唯一 composition root。
- 抽出 `ExternalCaptureDeepLinkCoordinator` 和 `RootComposerCoordinator`，让 root view 只绑定状态。

## 2. Domain

职责：

- 稳定业务模型、snapshot、enum、mutation draft、repository ports。
- 不依赖 SwiftUI、SwiftData、UIKit。

输入：

- 来自 Capture、Analysis、Persistence mapper、Server response 的业务数据。

输出：

- `RecordShell`、`Artifact`、`RecordAnalysisSnapshot`。
- `MemoryCaptureDraft`、`CaptureArtifactDraft`。
- `SelfProfile`、`AnalysisContextPack`、`GraphDelta`、`AffectSnapshot`、`PersonProfile`。
- repository protocol。

关键文件：

- `Domain/Memory/MemoryFeatureModels.swift`
- `Domain/Intelligence/AnalysisContextModels.swift`
- `Domain/Intelligence/AffectModels.swift`
- `Domain/Intelligence/IntelligenceModels.swift`
- `Domain/Intelligence/PersonProfileModels.swift`
- `Domain/Graph/Graph.swift`
- `Domain/Content/Artifact.swift`

问题：

- `MemoryFeatureModels.swift` 放入太多跨域 presentation 和 repository 类型。
- `MoryMemoryRepositorying` 过大，使 Domain 层变成全系统总线。

解决方案：

- 保持 Domain 无 framework 依赖。
- 拆分 Domain 文件：
  - `CaptureDomainModels`
  - `MemoryPresentationModels`
  - `SearchDomainModels`
  - `GraphPresentationModels`
  - `RepositoryPorts`

## 3. Infrastructure / Analysis

职责：

- 构建 Analyze request。
- 执行 v7 production pipeline。
- graph update、place resolution、temporal arc candidate、quality policy、artifact processing。

输入：

- `RecordShell`
- `Artifact`
- `AnalysisContextPack`
- Cloud v7 response
- SwiftData 查询结果

输出：

- `RecordAnalysisSnapshot`
- graph nodes/edges/links
- proposals
- arcs/reflections
- debug trace

关键文件：

- `ArchitecturePipelineExecutor.swift`
- `AnalyzeV7Models.swift`
- `AnalyzeResponseMapper.swift`
- `AnalysisContextPackBuilder.swift`
- `GraphUpdater.swift`
- `PlaceProfileResolver.swift`
- `TemporalArcCandidateBuilder.swift`
- `ContentQualityPolicies.swift`

问题：

- Pipeline 和 SwiftData 绑定。
- `AnalyzeV7Models.swift` 同时容纳 request、response、mapper、capabilities，文件较大。

解决方案：

- Pipeline 改为依赖 query/persist ports。
- Analyze v7 拆成 request、response、mapper、quality/capabilities 文件。

## 4. Infrastructure / Context

职责：

- 地点、天气、音乐、Journaling、External Capture、Platform diagnostics。
- 将系统上下文转换成 `CaptureArtifactDraft` 或 `MemoryCaptureDraft`。

输入：

- CoreLocation、WeatherKit、MusicKit、JournalingSuggestions、App Group payload。

输出：

- `CaptureArtifactDraft`
- `JournalingSuggestionDraft`
- `MemoryCaptureDraft`
- diagnostics snapshot

关键文件：

- `ContextAutoCollector.swift`
- `AppleJournalingSuggestionAdapter.swift`
- `JournalingSuggestionContextService.swift`
- `ExternalCaptureDraftFactory.swift`
- `ExternalCaptureInboxCodec.swift`
- `ExternalCaptureInboxStore.swift`
- `PlatformCaptureDiagnostics.swift`
- `MusicContextService.swift`

问题：

- Journaling adapter 和 ExternalCapture factory 是关键 mapping 点，容易被 UI 绕过。
- App Group inbox 和 handoff store 的产品语义需要持续保持“composer-first，inbox recovery-only”。

解决方案：

- 所有外部上下文必须经过 `MemoryCaptureDraft`。
- 不新增 `JournalingMemory` 或 parallel save path。
- External Capture conversion 集中在 factory，不在 UI 里拼 artifact。

## 5. Infrastructure / Intelligence

职责：

- Entity resolution、GraphDelta apply、clarification question、job worker、background coordinator、cloud intelligence client。

输入：

- repository ports
- cloud proposals
- correction events
- background jobs

输出：

- updated profile/graph state
- intelligence jobs
- questions
- background executions

关键文件：

- `EntityResolutionService.swift`
- `GraphDeltaApplier.swift`
- `ClarificationQuestionBuilder.swift`
- `IntelligenceJobWorker.swift`
- `BackgroundTaskCoordinator.swift`
- `CloudIntelligenceClient.swift`

问题：

- 多个 service 仍直接接大 `MoryMemoryRepositorying`。
- Job worker 中 GraphDelta apply、profile refresh、notification 等职责容易继续膨胀。

解决方案：

- service 依赖最小 repository ports。
- 将 job kind 的执行器拆成独立 handler。

## 6. Infrastructure / Notifications

职责：

- notification intent preparation。
- local notification scheduling。
- remote push registration/sync/writeback。
- notification delivery routing。

输入：

- notification preferences
- intelligence signals
- APNs token
- push delivery server responses

输出：

- local notifications
- remote push registration
- delivery writeback
- debug snapshots

关键文件：

- `NotificationIntentPreparationService.swift`
- `NotificationDeliveryRouter.swift`
- `LocalNotificationScheduler.swift`
- `RemotePushSyncService.swift`
- `NotificationSettingsService.swift`
- `NotificationInteractionService.swift`

问题：

- Router tests 曾受 SwiftData lifecycle 影响。
- Notification delivery policy 和 product retention strategy 未来会继续复杂。

解决方案：

- notification tests 使用 mock repository。
- policy、preparation、delivery、writeback 分层保持独立。

## 7. Infrastructure / Networking

职责：

- API client。
- Auth refresh aware requests。
- Analyze v7、reflection、question、chapter、photo semantic、notification、push、eval endpoints。
- Cloud debug error storage。

关键文件：

- `MoryAPIClient.swift`
- `MoryAPIConfiguration.swift`
- `BackgroundURLSessionInfrastructure.swift`

问题：

- `MoryAPIClient.swift` 超过 1000 行，已经是多 API surface 聚合。

解决方案：

- 按 endpoint family 拆 client extension：
  - `MoryAPIClient+Auth`
  - `MoryAPIClient+Analyze`
  - `MoryAPIClient+Notifications`
  - `MoryAPIClient+Push`
  - `MoryAPIClient+Eval`

## 8. Persistence

职责：

- SwiftData schema。
- Store models。
- Domain <-> Store mappers。
- Repository implementation。
- owner-scoped local data session。

关键文件：

- `MoryPersistenceStack.swift`
- `MoryLocalDataSession.swift`
- `Persistence/Models/*Stores.swift`
- `Persistence/Mappers/MoryDomainMappers+*.swift`
- `MoryMemoryRepository.swift`
- `MoryMemoryRepository+*.swift`

问题：

- 文件拆分已经改善，但 `MoryMemoryRepository` 类型本身仍大。
- extension 拆分解决可读性，不解决接口和事务边界。

解决方案：

- 拆协议和 use case service。
- repository 内 helper 按 owner 下沉。

## 9. Features

职责：

- 用户可见 SwiftUI 页面。
- 调用 repository/use case。
- 不直接实现 durable business rules。

主要模块：

- Capture：composer、cards、audio/photo/link/location/mood/Journaling。
- Home：today board、cards、grid。
- Memories/MemoryDetail：列表、详情、编辑。
- People/Entities：人物、实体、profile、merge/split。
- Insights：GraphDelta review、insights presentation。
- Settings：preferences、platform diagnostics、data controls、notification settings。
- Search/Timeline/Arcs/Reflections/Auth。

问题：

- Capture card view 和 composer view 仍大。
- Settings 已拆 section，方向正确。
- 部分 feature 直接接大 repository protocol。

解决方案：

- 按 feature 注入小 ports。
- Capture card 继续按 type 拆 view。

## 10. Debug

职责：

- 架构可视化、payload inspection、manual apply、diagnostics、quality tuning。

问题：

- Debug 大文件较多。
- Debug report builder 和 UI 在同一文件内。

解决方案：

- 继续拆 view/action/report formatter。
- Debug mutation 只调用正式 repository action。

## 11. AppIntents

职责：

- 系统快捷入口。
- 将外部 capture request 写入 shared handoff/inbox。

问题：

- 真机 phrase 可用性和系统发现仍需设备验证。

解决方案：

- 与 Platform Capture Diagnostics 的手动 checklist 绑定。

## 12. ExternalCaptureShared

职责：

- Share Extension 和 App 共享 payload 模型。
- Attachment references。
- JournalingEvidenceBundle。
- Inbox item model。

问题：

- 文件较大并包含 IO。

解决方案：

- 纯合同化并分文件。

## 13. Share Extension

职责：

- 接收系统 Share payload。
- 提取文本、URL、图片。
- 生成 `ExternalCaptureRequest`。
- 写入 App Group。
- 请求打开 Mory composer。

问题：

- `ShareViewController` 单文件承担 extraction、UI、handoff。

解决方案：

- 拆 extraction、confirmation state、handoff writer。
