# 14. Privacy, Security, And Local First

## 1. Principle

Mory's advantage is personal long-term memory. That also makes privacy stricter than ordinary note apps.

v7 rule:

> local data is the source of truth; cloud AI receives only the minimum evidence needed for the selected task.

## 2. Local-Only By Default

Default local-only classes:

- full `SelfProfile`,
- sensitive boundaries,
- raw correction history,
- full relationship graph,
- raw location history,
- private user notes on person profiles,
- rejected/negative correction detail,
- notification interaction history.

Cloud may receive compact summaries only when:

- user enables cloud analysis,
- privacy class permits,
- context pack budget allows,
- payload preview/debug shows what was sent.

## 3. Context Pack Privacy Gate

`PrivacyGate` decisions:

| Decision | Effect |
| --- | --- |
| include | evidence goes to cloud as-is |
| summarize | local summary replaces raw text |
| redact | names/places/details are removed |
| idOnly | only stable local id/classification is sent |
| localOnly | source remains local and is omitted |
| blockAnalyze | cloud call is not made |

Each decision records a reason:

- user setting,
- sensitivity classifier,
- source type,
- profile field privacy,
- notification preview policy,
- legal/OS capability limit.

## 4. Sensitive Notification Policy

Notification content must never expose sensitive details on lock screen by default.

Sensitive categories:

- relationship conflict,
- health/mood crisis,
- private location,
- financial/work decision,
- identity/person name if marked sensitive,
- do-not-track themes.

Routing:

- safe preview: local/APNs allowed,
- redacted preview: generic title/body,
- in-app only: no lock-screen notification,
- suppressed: no notification.

## 5. Cloud Contract Safety

Cloud contracts must:

- use request ids,
- avoid raw full database upload,
- receive snippets with provenance,
- accept redacted profile summaries,
- return proposals rather than direct mutations,
- include uncertainty and safety flags.

Server should not persist raw context packs longer than necessary for the request unless explicit debug mode is enabled.

## 6. User Controls

Required controls:

- disable cloud historical context,
- disable Journaling Suggestions,
- disable App Intents capture,
- disable notification categories,
- mark person/profile field local-only,
- delete AI portrait,
- forget correction signal,
- export privacy report.

## 7. Debug Privacy Report

A privacy report should show:

- last cloud payload preview,
- omitted local-only sources,
- included evidence snippets,
- notification routing decisions,
- sensitive preview suppressions,
- active capability permissions,
- background job network usage.

## 8. Acceptance Criteria

- User can turn off historical cloud context.
- Context pack builder records every privacy decision.
- Sensitive notifications are redacted or in-app only.
- AI proposals cannot mutate trusted graph directly.
- Debug payload preview never bypasses privacy settings.
