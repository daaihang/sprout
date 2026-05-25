# Apple Journaling Suggestions Feature Inventory

## User Entry

- Composer action strip "Journaling" button.
- Direct Apple Journaling picker on capable iOS devices.
- Fallback/debug import form when capability is unavailable.
- Platform Capture Diagnostics for capability and App Group checks.

## Expected User Experience

The user selects an Apple suggestion, then Mory imports its context into the normal new-memory composer as editable cards and affect evidence. It must not create a special Journaling-only memory type.

## Current UI Visibility

The composer can show imported cards for location, music, photos/videos, prompt, person context, and affect. The fallback import view can simulate limited evidence. There is no polished "Journaling import detail" screen showing the full original bundle.

## Supported Suggestion Types

| Apple Evidence | Current Mory Mapping | Status |
| --- | --- | --- |
| Location | `.location` artifact | `usable` |
| LocationGroup | multiple `.location` artifacts | `wired` |
| Song | `.music` artifact with artwork data | `usable` |
| Podcast | `.music`-style artifact | `wired` |
| GenericMedia | `.music`-style artifact | `wired` |
| Photo | `.photo` artifact | `usable` |
| Video | `.video` artifact | `wired` |
| LivePhoto | photo and video artifacts | `wired` |
| Workout | body text/activity evidence, not a dedicated card | `wired` |
| WorkoutGroup | body text/activity evidence, not a dedicated card | `wired` |
| MotionActivity | body text/activity evidence, not a dedicated card | `wired` |
| Contact | `.personContext` document artifact | `wired` |
| Reflection | `.promptAnswer` document artifact | `wired` |
| StateOfMind | `AffectSnapshotDraft` with source `journalSuggestionStateOfMind` | `wired` |
| EventPoster | body text/event evidence, image attachment stored | `wired` |

## Data Chain

```mermaid
flowchart LR
    A["Apple JournalingSuggestionsPicker"] --> B["AppleJournalingSuggestionAdapter"]
    B --> C["JournalingEvidenceBundle"]
    C --> D["JournalingSuggestionDraft"]
    D --> E["JournalingSuggestionContextService"]
    E --> F["ExternalCaptureDraftFactory"]
    F --> G["MemoryCaptureDraft"]
    G --> H["UnifiedCaptureComposerView cards"]
    H --> I["RecordShell + Artifact + AffectSnapshot"]
```

## Provenance

Current durable provenance:

- `JournalingSuggestionDraft.version = 3`.
- `MemoryCaptureDraft.inputContext` includes `journalingSuggestion:v3` and `selectedAt=...`.
- Imported artifacts use `captureOrigin=imported`.
- Contact artifact metadata includes `source=journalSuggestion`.
- StateOfMind affect source is `journalSuggestionStateOfMind`.
- Official StateOfMind raw fields are stored in affect evidence metadata.

Current missing provenance:

- No shared `importSessionID` across all artifacts and affect snapshots from one selected suggestion.
- No durable original Apple suggestion identifier.
- No per-evidence `journalingEvidenceID` after flattening into normal artifacts.
- Multiple suggestions imported into one composer can be distinguished only indirectly by order and text/context lines.

## AI Intervention Points

Journaling import itself does not call cloud AI. AI participates after the memory is saved and Analysis runs.

StateOfMind is treated as user-authorized affect evidence, not as AI inference.

## Failure And Retry

- Capability unavailable -> fallback/debug import form.
- Asset copy failure -> diagnostics stored in bundle and input context.
- Missing attachment -> draft can still be created; diagnostics mention missing media.
- User-visible diagnostics are not polished.

## Billing Cut Point

Base import should remain free because it is user-provided system context. Pro gates should apply to downstream intelligence: deeper context pack, reflections, people portraits, and long-term graph analysis.

## Current Status

`wired`

## Gaps And Next Step

1. Add `importSessionID` and per-evidence provenance during draft mapping.
2. Add a read-only bundle inspector in Debug/Settings.
3. Productize StateOfMind and prompt cards.
4. Validate real-device picker and entitlement behavior.
5. Create a later contact-to-person review flow instead of auto-merging contacts into trusted people.
