# Current Status

Audit date: 2026-05-31

## Git State At Audit Time

The working tree already contained unrelated local changes before this handbook pass:

| Path | State | Included In This Handbook Change |
| --- | --- | --- |
| `public/` | untracked | No |

The handbook treats current code as source of truth and old v3-v7 docs as historical context.

## Product State Summary

| Area | Current Status | User Visibility | Main Gap |
| --- | --- | --- | --- |
| Unified capture composer | `usable` | Visible in product | Source/provenance and post-save analysis status are not fully visible to users. |
| Capture cards and arrangement | `usable` | Visible in composer/detail and Card Debug | Fixed-column masonry arrangement, adaptive card heights, object metrics, media-ratio cards, and density rendering are wired; final product drag/reorder polish still needs more UX work. |
| Journaling Suggestions | `wired` | Product toolbar plus fallback/debug | Real-device stability and per-suggestion provenance need stronger status. |
| External Capture / Share | `wired` | Share extension and recovery inbox | Handoff is intended primary path; recovery/status still needs clearer product feedback. |
| Voice refinement | `wired` | Composer loading card | Cloud refinement can overwrite edited transcript if it returns after user edits. |
| Analysis | `usable` | Detail/Timeline/Home show pipeline status partially | Save now defaults to `.notScheduled`; users still do not get a clear "analysis ready / needs review" journey. |
| Self/Profile/People graph | `wired` | People UI and Debug | SelfProfile has no polished product management screen. |
| GraphDelta proposals | `wired` | Insights/Debug review | Reject/reason/undo UX is incomplete. |
| Notifications/background | `usable` | Settings/Debug | Background triggers now share `BackgroundOperationOrchestrator`; real device BGTask/APNs behavior still needs field validation. |
| Billing/entitlements | `backend_only` | Not productized | Feature gating and server-enforced quotas are not implemented. |

## Current Architecture Fact

Mory has a broad architecture foundation and the record-facts capture layer is now independently usable without AI. The product still does not expose a single understandable state surface. This handbook therefore records not only code capability but also whether users can see, trust, retry, or correct each step.

## Minimum Status Code Decision

No new status code is added in this pass. Current Debug/Settings surfaces are enough to document the first truth layer. Missing product visibility is recorded as a roadmap gap instead of silently adding more UI.
