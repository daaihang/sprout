# Notifications And Background Feature Inventory

## User Entry

- Notification settings.
- Permission settings.
- Local notification delivery.
- Remote push registration and diagnostics.
- Daily question and intelligence recovery services.

## Expected User Experience

Mory should remind users only when there is useful context: daily question, reflection ready, analysis finished, recurring theme, stage forming, revisit, or user-configured reminders. Users should know why a notification arrived.

## Current Components

| Component | Purpose | Status |
| --- | --- | --- |
| `LocalNotificationScheduler` | Schedule local notifications | `usable` |
| `NotificationIntentPreparationService` | Prepare notification intents | `wired` |
| `RemotePushSyncService` | Register/sync APNs token and preferences | `wired` |
| `NotificationDeliveryRouter` | Route delivery/interactions | `wired` |
| `BackgroundTaskCoordinator` | Register/run BGTask handlers | `wired` |
| Server push endpoints | Register/enqueue/writeback | `wired` |
| APNs worker | Deliver queued remote pushes | `wired` |

## Data Chain

```mermaid
flowchart LR
    A["Memory / question / reflection / pipeline status"] --> B["NotificationIntentPreparationService"]
    B --> C["NotificationIntentStore"]
    C --> D["LocalNotificationScheduler"]
    C --> E["RemotePushSyncService"]
    E --> F["Server /api/push/register + enqueue"]
    F --> G["APNs worker"]
    G --> H["Device notification"]
    H --> I["Notification interaction writeback"]
```

## AI Intervention Points

- Suggesting notification intent may call `/api/intelligence/suggest-notification-intent`.
- Daily question generation calls `/api/intelligence/suggest-questions`.
- Chapter suggestion can call `/api/intelligence/suggest-chapters`.
- Notification scheduling itself is policy logic, not AI.

## Failure And Retry

- Local notifications depend on user permission and scheduler state.
- Remote pushes depend on APNs token registration, server queue, worker, and writeback.
- Debug Remote Push Diagnostics can inspect parts of the chain.
- Real-device timing and BGTask scheduling remain validation gaps.

## Billing Cut Point

Basic reminders should be free. AI-generated timing, deep context reminders, and long-term reflection notifications can be Pro-gated by server-side quota and entitlement.

## Current Status

`wired`

## Gaps And Next Step

1. Document user-facing notification reasons and cadence.
2. Add a product notification history/explanation surface.
3. Complete real-device APNs and BGTask validation matrix.
