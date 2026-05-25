# External Capture, Share Extension, And AppIntent Feature Inventory

## User Entry

- iOS Share Extension.
- AppIntent shortcut text capture.
- Deep link `mory://external-capture?id=...&action=compose`.
- External Capture recovery/debug inbox.

## Expected User Experience

External content should land in the same unified composer as in-app capture. The recovery inbox is durability and diagnostics, not the primary user experience.

## Current UI Visibility

- Share extension writes a shared capture envelope and attempts handoff.
- Main app can read the pending item and seed `UnifiedCaptureComposerView`.
- Settings/Debug expose External Capture draft review and platform diagnostics.

## Data Chain

```mermaid
flowchart LR
    A["Share / AppIntent"] --> B["ExternalCaptureRequest"]
    B --> C["App Group inbox item"]
    C --> D["mory://external-capture deep link"]
    D --> E["MoryRootView fetches inbox item"]
    E --> F["ExternalCaptureDraftFactory"]
    F --> G["UnifiedCaptureSeed.externalDraft"]
    G --> H["Unified composer"]
    H --> I["Save memory"]
    I --> J["mark inbox item imported"]
```

## Supported Inputs

| Input | Draft Mapping | Status |
| --- | --- | --- |
| Shared text | `.text` | `usable` |
| Shared URL | `.link` and text | `usable` |
| Shared image | `.photo` via App Group attachment | `wired` |
| Shared file/video | `.video` fallback | `wired` |
| AppIntent text | external request text | `wired` |

## Provenance

Current durable provenance:

- `ExternalCaptureRequest.sourceKind`: shareSheet, appIntent, shortcut, journalingSuggestion, health, fitness, unknown.
- `ExternalCaptureInboxItem.id`, `payloadKind`, `sourceKind`, `status`, `receivedAt`, `importedRecordID`.
- Artifact metadata includes `source`, `storedFileName`, `contentType`, `attachmentRole`, and `captureOrigin=imported`.

Current missing provenance:

- No product-level handoff status visible after Share if system does not open the app.
- No unified import session surface showing all imported artifacts and diagnostics.
- No server-side external capture concept; this is local/app-side.

## AI Intervention Points

External Capture does not call AI before composer. After save, normal Analysis runs.

## Failure And Retry

- If handoff fails, pending inbox item remains available.
- Missing/corrupt attachment becomes a recoverable draft diagnostic.
- Normal user flow still lacks a strong "saved to Mory, open now" success/failure explanation.

## Billing Cut Point

External capture entry should remain free. Downstream AI analysis quota should be server-enforced.

## Current Status

`wired`

## Gaps And Next Step

1. Make handoff outcome user-visible in the extension and main app.
2. Keep recovery inbox out of the normal path but easy to inspect in diagnostics.
3. Add import session provenance if multiple external items are composed together.
