# Mory v7 Architecture Index

## 1. Purpose

v7 focuses on one concrete target:

> make Mory analysis truly personal, long-horizon, and proactively useful without breaking local-first boundaries.

Compared with v6, v7 is not a UI-first rewrite. It is an intelligence architecture upgrade:

- richer analysis context assembly,
- stronger entity identity lifecycle,
- structured mood representation,
- reliable background orchestration,
- notification triggers beyond "open app first".

## 2. Baseline (Code Truth)

Current baseline entry points:

- iOS app shell and launch recovery: `/Users/z14/Documents/sprout/mory/mory/App/MoryRootView.swift`
- Home-triggered daily question prep: `/Users/z14/Documents/sprout/mory/mory/Features/Home/HomeScreen.swift`
- Record analyze request builder: `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Analysis/Pipeline/AnalyzeRequestBuilder.swift`
- Pipeline orchestrator: `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Analysis/Pipeline/ArchitecturePipelineExecutor.swift`
- Intelligence recovery and worker: `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Intelligence/AppIntelligenceRecoveryService.swift`, `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Intelligence/IntelligenceJobWorker.swift`
- Notification intent policy and scheduling: `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Notifications/NotificationIntentPreparationService.swift`, `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Notifications/LocalNotificationScheduler.swift`
- APNs registration/sync: `/Users/z14/Documents/sprout/mory/mory/Infrastructure/Notifications/RemotePushSyncService.swift`
- Go push queue/worker and API: `/Users/z14/Documents/sprout/server/internal/http/handlers.go`, `/Users/z14/Documents/sprout/server/internal/notification/push_delivery_worker.go`

## 3. Document Set

| Document | Role |
| --- | --- |
| [01 Personalization Background Notification System](01_personalization_background_notification_system.md) | v7核心文档：现状、缺口、分期实施与验收。 |

## 4. v7 Delivery Principle

v7 implementation order:

1. business architecture first,
2. debug and observability second,
3. stable background + AI loop third,
4. polished UI last.

