# Status And Debug Surfaces

This section records where users or developers can see current system state.

## User-Visible Surfaces

| Surface | Shows | Gap |
| --- | --- | --- |
| Composer | staged cards, affect cards, save/loading errors | Does not explain post-save analysis. |
| Home | board cards and some pipeline status | Analysis readiness is not a cohesive journey. |
| Timeline | memory list and pipeline badge | Status is small and passive. |
| Memory Detail | pipeline status, retry, AI analysis disclosure | Good for a single memory, not global state. |
| Insights | graph/proposal/reflection surfaces | Review model not fully explained. |
| People | person profiles and edits | SelfProfile and evidence not fully productized. |
| Settings | permissions, capture preferences, unified notification management, diagnostics | Notification state is now centralized; broader intelligence status is still incomplete. |

## Debug And Diagnostics

| Debug Surface | Purpose |
| --- | --- |
| Debug Full Diagnostics | Broad local state export/inspection. |
| Debug Analysis Context Pack | Inspect context pack and Analysis request/response shape. |
| Debug Affect Snapshot | Inspect structured affect and Journaling StateOfMind evidence. |
| Debug Person Profile | Inspect person profile data. |
| Notification Management | Single Settings/Debug page for notification queue, history, dedupe, errors, preferences, APNs sync, debug test notification, and push metrics. |
| Debug Cloud Intelligence | Run cloud intelligence endpoints. |
| Platform Capture Diagnostics | Check Journaling, App Group, Share, App Intents, inbox. |
| Capture Card Lab | Inspect card rendering and provenance modes. |

## Missing Status Layer

The app needs a product-level "System Status / Intelligence Status" surface that answers:

- Which memories are pending analysis?
- Which analyses failed and why?
- Which AI proposals need review?
- Which imported items are pending recovery?
- What does Mory know about me?
- What does Mory know about each person, and from which evidence?
- Which features are unavailable because of permission, entitlement, OS, server, or quota?
- Which background triggers ran, what they did, and whether they generated an in-app state, notification, job, or no-op?

## Current Status

`wired`

Notification status is now centralized in one management page. Debug coverage is strong, but product-level AI/background status visibility is still incomplete.
