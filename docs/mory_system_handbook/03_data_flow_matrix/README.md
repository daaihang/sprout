# Data Flow Matrix

This matrix maps features from user input to local persistence, API, AI output, and UI surfaces.

## Capture Save Path

| Step | Object | Notes |
| --- | --- | --- |
| User input | `UnifiedCaptureComposerView` state | Body, staged artifacts, affect drafts, context candidates. |
| Draft | `MemoryCaptureDraft` | Title, rawText, mood, inputContext, provenance, artifacts, affectSnapshots, cardArrangement. |
| Artifact conversion | `MemoryCaptureArtifactBuilder` | Creates `Artifact` records and metadata. |
| Record persistence | `RecordShellStore` | Primary capture shell. |
| Artifact persistence | `ArtifactStore` | Text/media/metadata payloads. |
| Digest persistence | `ArtifactSemanticDigestStore` | Structured media/text-derived meaning for future analysis. |
| Arrangement persistence | `MemoryCardArrangementStore` | User-authored visual card layout with order, stack/group, sticker attachments, nudge, rotation, and z-index; masonry frames are derived at render time and excluded from default AI analysis input. |
| Mood persistence | `AffectSnapshotStore` | Structured affect evidence. |
| Pipeline status | `MemoryPipelineStatusStore` | Save-only path writes `notScheduled`; explicit analysis moves to pending/running/completed/failed. |
| Search | Spotlight index | Indexed after save and after analysis completion. |

Render-time card object metrics are derived from recipe + size + density and are not persisted. This keeps the visual object ratio separate from the stored grid occupancy and prevents UI sizing from becoming semantic fact.

## Analysis Path

| Step | Object | Notes |
| --- | --- | --- |
| Query context | `AnalysisContextPackBuilder` | SelfProfile, profiles, related memories, arcs/reflections, corrections, privacy/budget. |
| Request | `AnalysisRequestPayload` | Sent to `/api/analyze`. |
| Response | `AnalysisResponseEnvelope` | Analysis plus proposals. |
| Mapping | `AnalysisResponseMapper` | Creates local analysis/proposal snapshots. |
| Graph update | `GraphUpdater` and place resolver | Local trusted graph is updated through policy and persistence ports. |
| Persistence | pipeline ports/repository | analysis, graph, affect, deltas, reflections, questions, arcs. |
| UI | Detail, Timeline, Home, Insights, Debug | Status and results are visible in multiple places but not as one cohesive journey. |

## Journaling Data Path

| Apple Evidence | Bundle Field | Draft Output | Persisted Output |
| --- | --- | --- | --- |
| Location | `locations` | `.location` | `ArtifactKind.location` |
| LocationGroup | `locationGroups` | multiple `.location` | `ArtifactKind.location` |
| Song/Podcast/GenericMedia | `media` | `.music` | `ArtifactKind.music` |
| Photo/Video/LivePhoto | `photoVideos` + attachments | `.photo` / `.video` / `.livePhoto` | `ArtifactKind.photo` / `ArtifactKind.video` / `ArtifactKind.livePhoto` |
| Workout/MotionActivity | `activities` | body/context evidence | text/context plus metadata |
| Contact | `contacts` | `.personContext` | `ArtifactKind.document` |
| Reflection | `reflections` | `.promptAnswer` | `ArtifactKind.document` |
| StateOfMind | `stateOfMind` | `AffectSnapshotDraft` | `AffectSnapshotStore` |
| EventPoster | `eventPosters` | body/context evidence | text/context plus attachment metadata |

## External Capture Data Path

| Source | Wire Object | Conversion | Persisted Output |
| --- | --- | --- | --- |
| Share text | `ExternalCaptureRequest` | text draft | text artifact |
| Share URL | `ExternalCaptureRequest` | link draft | link artifact |
| Share image | attachment draft | photo draft | photo artifact |
| AppIntent | `ExternalCaptureRequest` | text/context draft | normal memory |
| Recovery inbox | `ExternalCaptureInboxItem` | `ExternalCaptureInboxCodec.makeDraft` | normal memory or composer seed |

## Current Data Flow Gaps

1. Workout, motion activity, and event poster evidence are not first-class capture card types.
2. AI proposal provenance is inspectable but not yet user-friendly.
3. Billing/entitlement state is not part of capture or analyze request gating.
