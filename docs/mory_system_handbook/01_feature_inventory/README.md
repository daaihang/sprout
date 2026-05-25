# Feature Inventory

This section lists user-facing and near-user-facing Mory features. Each feature uses the same evaluation frame so future work can update status without re-reading the whole codebase.

## Status Matrix

| Feature | Current Status | Product Entry | Debug/Diagnostics | Main Next Step |
| --- | --- | --- | --- | --- |
| Unified capture composer | `usable` | Global capture / composer | Capture Card Lab | Make source/provenance clearer. |
| Text capture | `stable` | Composer body | Diagnostics fixtures | Keep as baseline. |
| Photo capture | `usable` | PhotosPicker/camera | Photo capability test | Clarify local processing vs cloud analysis. |
| Video capture | `wired` | Imported/Journaling | Artifact diagnostics | Improve card/player presentation. |
| Audio and voice capture | `wired` | Voice/audio sheet | Cloud intelligence debug | Prevent AI refinement from overwriting user edits. |
| Link capture | `usable` | Link sheet/Share | Link metadata debug | Expose metadata failures. |
| Place/weather/music context | `usable` | Auto context/action strip | Permission matrix | Clarify selected vs auto-collected context. |
| Structured mood | `wired` | Mood sheet/Journaling | Affect snapshot debug | Productize affect history and correction. |
| Journaling Suggestions | `wired` | Composer toolbar | Platform diagnostics/fallback | Add stronger provenance and real-device checklist results. |
| External Capture / Share | `wired` | Share extension/AppIntent | External draft review/inbox | Make handoff outcome visible. |
| Self and people profiles | `wired` | People screens | Person profile debug | Add My Profile surface and evidence viewer. |
| GraphDelta review | `wired` | Insights review | Debug review | Add reject reason and undo clarity. |
| Notifications | `wired` | Settings/notification permissions | Remote push diagnostics | Validate real-device timing and APNs delivery. |
| Subscription/paywall | `backend_only` | None | Server subscription verify | Define and enforce entitlement boundaries. |

## Required Feature File Template

Each feature document must include:

- User entry
- Expected user experience
- Current UI visibility
- Supported input or object types
- Draft/domain model
- Persistence model and key fields
- API calls
- AI intervention points
- Blocking behavior
- Possible user-input overwrite
- User-visible status
- Failure/retry path
- Debug/diagnostic entry
- Billing/entitlement cut point
- Current status
- Gaps and next step

## First Batch Documents

- [Capture](capture.md)
- [Journaling Suggestions](journaling_suggestions.md)
- [External Capture](external_capture.md)
- [Voice And Audio](voice_audio.md)
- [Mood And Affect](mood_affect.md)
- [Analysis](analysis.md)
- [People, Self, And Graph](people_self_graph.md)
- [Notifications And Background](notifications.md)
