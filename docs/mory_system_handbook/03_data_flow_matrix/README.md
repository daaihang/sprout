# Data Flow Matrix

This matrix maps features from user input to local persistence, API, AI output, and UI surfaces.

## Capture Save Path

| Step | Object | Notes |
| --- | --- | --- |
| User input | `UnifiedCaptureComposerView` state | Body, staged artifacts, affect drafts, context candidates. |
| Draft | `MemoryCaptureDraft` | Title, rawText, mood, inputContext, captureSource, artifacts, affectSnapshots. |
| Artifact conversion | `MemoryCaptureArtifactBuilder` | Creates `Artifact` records and metadata. |
| Record persistence | `RecordShellStore` | Primary capture shell. |
| Artifact persistence | `ArtifactStore` | Text/media/metadata payloads. |
| Mood persistence | `AffectSnapshotStore` | Structured affect evidence. |
| Pipeline status | `MemoryPipelineStatusStore` | pending -> running -> completed/failed. |
| Search | Spotlight index | Indexed after save and after analysis completion. |

## v7 Analyze Path

| Step | Object | Notes |
| --- | --- | --- |
| Query context | `AnalysisContextPackBuilder` | SelfProfile, profiles, related memories, arcs/reflections, corrections, privacy/budget. |
| Request | `AnalyzeV7RequestPayload` | Sent to `/api/analyze/v7`. |
| Response | `AnalyzeV7ResponseEnvelope` | Analysis plus proposals. |
| Mapping | `AnalyzeV7ResponseMapper` | Creates local analysis/proposal snapshots. |
| Graph update | `GraphUpdater` and place resolver | Local trusted graph is updated through policy and persistence ports. |
| Persistence | pipeline ports/repository | analysis, graph, affect, deltas, reflections, questions, arcs. |
| UI | Detail, Timeline, Home, Insights, Debug | Status and results are visible in multiple places but not as one cohesive journey. |

## Journaling Data Path

| Apple Evidence | Bundle Field | Draft Output | Persisted Output |
| --- | --- | --- | --- |
| Location | `locations` | `.location` | `ArtifactKind.location` |
| LocationGroup | `locationGroups` | multiple `.location` | `ArtifactKind.location` |
| Song/Podcast/GenericMedia | `media` | `.music` | `ArtifactKind.music` |
| Photo/Video/LivePhoto | `photoVideos` + attachments | `.photo` / `.video` | `ArtifactKind.photo` / `ArtifactKind.video` |
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

1. Journaling and external capture need a durable import session concept across artifacts and affect snapshots.
2. Workout, motion activity, and event poster evidence are not first-class capture card types.
3. AI proposal provenance is inspectable but not yet user-friendly.
4. Billing/entitlement state is not part of capture or analyze request gating.
