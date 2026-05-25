# Current Status

Audit date: 2026-05-25

## Git State At Audit Time

The working tree already contained unrelated local changes before this handbook pass:

| Path | State | Included In This Handbook Change |
| --- | --- | --- |
| `mory/mory.xcodeproj/project.pbxproj` | modified | No |
| `docs/mory-ios-app-ai-native-happy-treehouse.md` | untracked | No |
| `public/` | untracked | No |

The handbook treats current code as source of truth and old v3-v7 docs as historical context.

## Product State Summary

| Area | Current Status | User Visibility | Main Gap |
| --- | --- | --- | --- |
| Unified capture composer | `usable` | Visible in product | Source/provenance is not fully visible to users. |
| Capture cards | `usable` | Visible in composer/detail | Prompt/person/affect cards are basic status-style cards. |
| Journaling Suggestions | `wired` | Product toolbar plus fallback/debug | Real-device stability and per-suggestion provenance need stronger status. |
| External Capture / Share | `wired` | Share extension and recovery inbox | Handoff is intended primary path; recovery/status still needs clearer product feedback. |
| Voice refinement | `wired` | Composer loading card | Cloud refinement can overwrite edited transcript if it returns after user edits. |
| Analysis | `usable` | Detail/Timeline/Home show pipeline status partially | Users do not get a clear "analysis ready / needs review" journey. |
| Self/Profile/People graph | `wired` | People UI and Debug | SelfProfile has no polished product management screen. |
| GraphDelta proposals | `wired` | Insights/Debug review | Reject/reason/undo UX is incomplete. |
| Notifications/background | `usable` | Settings/Debug | Background triggers now share `BackgroundOperationOrchestrator`; real device BGTask/APNs behavior still needs field validation. |
| Billing/entitlements | `backend_only` | Not productized | Feature gating and server-enforced quotas are not implemented. |

## Current Architecture Fact

Mory has a broad v7 architecture foundation, but the product does not yet expose a single understandable state surface. This handbook therefore records not only code capability but also whether users can see, trust, retry, or correct each step.

## Minimum Status Code Decision

No new status code is added in this pass. Current Debug/Settings surfaces are enough to document the first truth layer. Missing product visibility is recorded as a roadmap gap instead of silently adding more UI.
