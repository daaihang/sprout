# 05. Notifications And Daily Questions

## 1. Purpose

Notifications and daily questions make Mory useful when the user has not actively opened the app.

They must be helpful, controlled, and explainable.

## 2. Notification Types

Current system notification types are intentionally narrow:

| Type | Example | Default |
| --- | --- | --- |
| analysisReady | "Your memories are ready to review." | Enabled if notifications allowed |
| dailyQuestion | "A question is ready for today's reflection." | Smart, conservative |
| reflectionReady | "A reflection is ready to review." | Conservative |
| debugTest | "A debug notification is ready." | Debug only |

Long-term pattern and revisit signals are Home/Insights surfaces only. They are not system notification intents.

## 3. Cadence Controls

Settings should include:

```text
Notification frequency:
- Off
- Quiet
- Balanced
- Active
- Custom

Daily question:
- Off
- Weekly
- Daily
- Smart

Question style:
- Journaling
- Memory revisit
- Reflective
- Life organization
- Evidence-based
```

## 4. Daily Question Tone

Daily questions can include multiple styles, controlled by preference.

### 4.1 Journaling Prompt

Example:

> What is one small thing worth remembering from today?

### 4.2 Memory Revisit

Example:

> Yesterday you captured a quiet walk after dinner. Do you want to add what changed after it?

### 4.3 Reflective

Example:

> You have mentioned protected morning time more than once. What feels hardest about keeping it?

### 4.4 Life Organization

Example:

> Is this still an open decision, or has it been resolved?

### 4.5 Evidence-Based Clarification

Example:

> You mentioned Alex three times this week. Who is Alex to you?

## 5. Notification Safety

Sensitive topics:

- Health.
- Money.
- Despair.
- Relationship conflict.
- Work stress.
- Family conflict.

Default behavior:

- Sensitive topic questions appear in app only.
- Remote notification copy should be generic.
- No diagnosis language.
- No emotionally intense lock-screen text by default.

## 6. Local vs Remote Notifications

### 6.1 Local Notifications

Use for:

- Daily question prepared on device.
- Reminder based on local-only data.
- Sensitive topics.
- Generic review prompts.

### 6.2 Remote Push

Use for:

- Processing completed on server-driven AI flow.
- Re-engagement if explicitly enabled.
- Cross-device wake-up where local scheduling is insufficient.

Remote push should avoid full memory content unless user explicitly enables rich notification previews.

## 7. Daily Question Generation

Input signals:

- Recent memories.
- Unanswered clarification questions.
- Entity recurrence.
- Place recurrence.
- Open decisions.
- Chapter candidates.
- User preferences.
- Notification frequency budget.

Output:

- Question text.
- Kind.
- Reason.
- Evidence.
- Target.
- Suggested answers if applicable.
- Whether it is suitable for notification.

## 8. Acceptance Criteria

- User can disable all notifications.
- User can use daily questions without remote push.
- Notification frequency is enforced.
- Sensitive questions avoid lock-screen details by default.
- Daily question has evidence or clear purpose.
- Dismissing a daily question affects future ranking.

Current implementation checkpoint:

- Daily questions can already be suggested through the cloud contract and stored locally as clarification questions.
- Daily question notification intents can now be prepared locally behind preferences and V6 flags.
- The policy foundation enforces notification enablement, type enablement, max-per-day, quiet hours, sensitive-topic suppression, and generic lock-screen copy.
- Local notification scheduling can now convert pending local intents into scheduled system notifications when permission already exists.
- A basic user-facing Settings route can now opt into notifications, request system permission, update per-type switches, choose delivery pace, edit max-per-day, edit minimum spacing, edit minute-precise quiet hours, and cancel pending/scheduled local notifications when disabled.
- Local notification delivery/open/dismiss interaction handling can now write back intent status, and notification opens deep-link to specific question cards, memory details, chapter candidates, or reflection details when the payload target supports it.
- App relaunch now performs a lightweight retry/resume pass for interrupted intelligence jobs and pending notification preparation.
- Remote push token/preference sync and delivery interaction writeback now exist, including local retry for failed writebacks. Go has an initial remote delivery queue/worker foundation, but production APNs sender credentials and polished notification settings UX are still pending.
