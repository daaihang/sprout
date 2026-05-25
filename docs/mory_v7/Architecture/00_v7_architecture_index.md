# Mory v7 Architecture Index

## 1. Purpose

v7 的目标不是把 v6 的卡片或首页做得更复杂，而是把 Mory 从“单条记录分析器”升级成：

> identity-aware, retrieval-grounded, correction-driven long-term memory system.

也就是：每次新记忆都能围绕“我是谁、这些人是谁、过去发生过什么、用户纠正过什么、哪些证据可信”进行有约束的长期分析。

## 2. Current Code Truth

当前 v6 已经有 Capture、Graph、Profile、Question、Search、Notification 的雏形，但它们还没有形成闭环。

| Area | Current entry points | v7 gap |
| --- | --- | --- |
| Analyze | `AnalyzeRequestBuilder.swift`, `ArchitecturePipelineExecutor.swift`, `server/internal/ai/types.go` | 只带当前记忆、附件、最多 20 个轻量 known entities，没有历史 context pack |
| Profile | `IntelligenceModels.swift`, `EntityEnrichmentService.swift`, `GraphDeltaApplier.swift` | `EntityProfile` 没有作为 Analyze 输入，人物画像不够厚 |
| Questions | `ClarificationQuestionBuilder.swift`, `DailyQuestionSuggestionService.swift`, `ClarificationQuestionCard.swift` | 问题类型定义比运行写回更完整，freeform/纠错闭环不足 |
| Search | `SpotlightSearchableItemBuilder.swift`, `MoryMemoryRepository.semanticSearch` | 面向用户搜索，不是分析前召回器 |
| Arc/Reflection | `ArchitecturePipelineExecutor.swift`, `MoryAPIClient.swift` | Arc/Reflection 多为后处理，Reflection 请求只有 linked id 而非 evidence |
| Notifications | `NotificationOrchestrator.swift`, `AppIntelligenceRecoveryService.swift`, `NotificationDeliveryRouter.swift`, `LocalNotificationScheduler.swift` | 通知已收敛为 trigger -> dedupe -> policy -> routing 单入口；系统通知仅保留 dailyQuestion/analysisReady/reflectionReady/debugTest |
| Remote push | `RemotePushSyncService.swift`, `push_delivery_worker.go` | APNs 基础存在，但主动 intent 生产没有成为生产路径 |
| Context capture | `ContextAutoCollector.swift`, `LocationContextService.swift`, `MusicContextService.swift`, `WeatherContextService.swift` | location/weather/music 有基础；Journaling picker adapter、App Intent shell、Share Extension confirmation flow、external capture V2 inbox 已整合；真机能力验证仍属于 release hardening |

## 3. Architecture Map

| Document | Role |
| --- | --- |
| [01 Identity And Self Profile](01_identity_and_self_profile.md) | 定义 `SelfProfile`、第一人称解析、用户本人档案和本地优先边界 |
| [02 Entity Resolution And Correction](02_entity_resolution_and_correction.md) | 定义人物/地点/主题/决策的消歧、合并、拆分、纠错事件和 tombstone |
| [03 Person Profile And Portrait](03_person_profile_and_portrait.md) | 定义 `PersonProfile`/`EntityProfileV2`、人物画像字段、证据和刷新策略 |
| [04 Analysis Context Pack](04_analysis_context_pack.md) | 定义 Analyze 前的历史召回、rank、budget、privacy gate 和 payload schema |
| [05 Structured Mood And Affect](05_structured_mood_and_affect.md) | 定义 VAD/PAD、PANAS chips、tone hints、appraisal、Affect correction |
| [06 Background AI Notification Orchestration](06_background_ai_notification_orchestration.md) | 定义 BGTask、background URLSession、APNs、本地通知、App Intents 的组合架构 |
| [07 Cloud Contracts v7](07_cloud_contracts_v7.md) | 定义 `/api/analyze/v7`、context-aware reflection、proposal-first AI 输出 |
| [08 Graph Delta v2 And Mutations](08_graph_delta_v2_and_mutations.md) | 定义通用 graph mutation、merge/split rewrite、undo 和事务边界 |
| [09 Jobs Recomputation And Invalidations](09_jobs_recomputation_and_invalidations.md) | 定义编辑、删除、回答问题、merge/split 后的重算和失效策略 |
| [10 Eval Observability And Debug](10_eval_observability_and_debug.md) | 定义长期智能 eval、debug surfaces、context pack viewer 和 profile diff viewer |
| [11 Phase Implementation Backlog](11_phase_implementation_backlog.md) | 把 v7 拆成可落地 Phase、验收标准和测试清单 |
| [12 Current v6 Gap Matrix](12_current_v6_gap_matrix.md) | 把当前代码/文档差口映射到 v7 模块 |
| [13 Data Model Catalog](13_data_model_catalog.md) | 汇总 v7 新增/扩展领域模型、持久化归属和迁移关系 |
| [14 Privacy Security And Local First](14_privacy_security_and_local_first.md) | 定义本地优先、云端最小化、敏感数据、通知预览和审计边界 |
| [15 iOS Capability Matrix](15_ios_capability_matrix.md) | 汇总 BGTask、URLSession、APNs、通知、App Intents、Journaling、ML 等 iOS 能力 |
| [16 Context Pack Examples](16_context_pack_examples.md) | 用具体场景说明 context pack 如何召回、排序、裁剪和解释 |
| [17 Identity Correction Examples](17_identity_correction_examples.md) | 用“我/舍友/同名人/关系变化”等案例定义纠错行为 |
| [18 Repository And UI Boundaries](18_repository_and_ui_boundaries.md) | 定义架构层、业务层、UI AI 分工和不可跨越边界 |
| [19 Testing Acceptance Matrix](19_testing_acceptance_matrix.md) | 把 v7 Phase、模块、测试类型和验收条件映射到矩阵 |
| [Personalization Background Notification System](01_personalization_background_notification_system.md) | 早期综合审计文档，保留为 current-state/gap overview |

## 4. v7 System Flow

```text
Capture Draft
  -> Context Sources
      -> location/weather/music/photo/OCR/voice/JournalingSuggestion/AppIntent
  -> AffectSnapshot + ContextEvidence
  -> AnalysisContextPackBuilder
      -> SelfProfile
      -> related PersonProfile / PlaceProfile / ThemeProfile
      -> semantic search related memories
      -> related arcs/reflections
      -> user corrections and negative signals
      -> privacy gate + token budget
  -> /api/analyze/v7
      -> analysis summary
      -> profile update proposals
      -> merge/split candidates
      -> reflection/arc candidates
      -> question candidates
  -> GraphDeltaV2 policy
      -> auto-apply safe facts
      -> queue uncertain proposals
      -> ask user corrections
  -> Jobs/Recompute
      -> profile portrait refresh
      -> arc/reflection invalidation
      -> search index update
      -> notification intent candidates
```

## 5. Non-Goals

- v7 does not upload the user's full local database to cloud.
- v7 does not make AI output trusted facts by default.
- v7 does not rely on unlimited iOS background execution.
- v7 does not block business architecture work on final UI polish.
- v7 does not treat mood as a single label.

## 6. Delivery Principle

Implementation order:

1. business architecture and data contracts,
2. debug/test/eval surfaces,
3. background + notification reliability,
4. UI integration,
5. polish.
