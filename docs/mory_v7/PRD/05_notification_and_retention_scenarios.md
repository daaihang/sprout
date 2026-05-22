# 05. Notification And Retention Scenarios

## 1. Product Goal

Notifications should make Mory feel helpful, not noisy. v7 notifications must be generated from real memory value:

- unfinished reflection,
- meaningful daily question,
- cloud analysis ready,
- relationship/history revisit,
- open decision follow-up,
- first-week habit guidance.

## 2. Notification Types

| Type | Trigger | Channel | Example |
| --- | --- | --- | --- |
| Daily question | local or server candidate | local/APNs | “今天想补充一件和 Lily 有关的小事吗?” |
| Analysis ready | cloud result completed | APNs/local ready state | “刚才的记忆有一个可查看的连接” |
| Reflection ready | arc/reflection candidate accepted | local/APNs | “过去几周的搬家记录有了一个小结” |
| Open decision | unresolved decision detected | local/in-app | “这件事后来有结果了吗?” |
| Relationship revisit | important person with new pattern | local/in-app | “你最近和 Alex 的互动明显变多了” |
| Capture reminder | user-chosen schedule | local | “晚上回顾一下今天” |
| System context prompt | App Intent/share/journaling available | in-app first | “可以把这张票据加入 Mory” |

## 3. Cadence Rules

Initial v7 policy:

- max one proactive notification per day by default,
- daily question and reflection share the same quota,
- sensitive topics default to in-app only,
- quiet hours are respected,
- repeated dismiss lowers ranking,
- answered notifications raise similar high-quality prompts,
- “not now” creates cooldown, not rejection,
- “don't ask this” creates correction/negative signal.

## 4. Interaction Writeback

Every notification interaction writes an event:

```swift
enum NotificationInteractionKind: String, Codable, Sendable {
    case delivered
    case opened
    case answered
    case snoozed
    case dismissed
    case disabledCategory
    case markedBad
}
```

This event updates:

- notification ranking,
- question cooldown,
- privacy/sensitivity routing,
- context pack negative signals,
- eval metrics.

## 5. Local vs Remote Routing

| Case | Preferred route |
| --- | --- |
| locally prepared daily question | local notification |
| cloud analysis complete | APNs with safe preview |
| sensitive relationship question | in-app only or redacted local |
| user-chosen reminder | local notification |
| cross-device server state | APNs |
| background refresh failed | launch recovery, not repeated spam |

## 6. Retention Strategy

First week:

- focus on capture habit and obvious value,
- lightweight question only when evidence is strong,
- avoid deep psychological claims.

After enough history:

- relationship changes,
- emotional patterns,
- decisions and outcomes,
- recurring places/themes,
- weekly/monthly reflection.

User trust is higher priority than notification volume.

## 7. Success Criteria

- Notifications are explainable from their source evidence.
- User can answer, snooze, dismiss, or disable categories.
- Interaction events feed future ranking.
- Sensitive content is never exposed in unsafe previews.
- Daily question no longer requires opening Home first.
