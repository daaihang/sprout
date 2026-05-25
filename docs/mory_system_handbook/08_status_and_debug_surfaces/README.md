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
| Settings | permissions, capture preferences, notifications, diagnostics | Many system states are split across sections. |

## Debug And Diagnostics

| Debug Surface | Purpose |
| --- | --- |
| Debug Full Diagnostics | Broad local state export/inspection. |
| Debug Analysis Context Pack | Inspect context pack and v7 request/response shape. |
| Debug Affect Snapshot | Inspect structured affect and Journaling StateOfMind evidence. |
| Debug Person Profile | Inspect person profile data. |
| Debug Remote Push Diagnostics | Inspect push registration/enqueue/writeback. |
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

## Current Status

`wired`

Debug coverage is strong. Product status visibility is incomplete.
