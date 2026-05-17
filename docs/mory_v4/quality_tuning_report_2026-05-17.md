# Mory Quality Tuning Lab Report

Date: 2026-05-17

## Environment

- App: iPhone 17 Pro simulator, clean local batch runs.
- App build setting: `CURRENT_PROJECT_VERSION = 1`.
- Backend: local Go service at `http://127.0.0.1:8080`, started from local `server/.env`.
- Backend mode observed in logs: `ai_mode=live`, `ai_provider=openai_compatible`, `ai_model=deepseek-v4-flash`.
- Go log: `/tmp/mory-quality-go-expanded.log`.
- Final raw app report: `/tmp/mory-quality-expanded-report-20260517-084100.txt`.
- Final batch timestamp: `2026-05-17T00:46:19Z`.
- Execution path: real iPhone 17 Pro simulator, real SwiftData repository, real local Go API. The local batch was driven by XCTest for repeatability; the Simulator UI was also inspected with accessibility and the `Debug > Quality Tuning Lab` entry plus `Run Core Batch` control were reachable.

## Final Parameters

| Parameter | Value | Reason |
| --- | ---: | --- |
| `entityMinimumConfidence` | `0.55` | Keeps real people and decisions while filtering obvious OCR/carrier noise. |
| `themeDecisionMinimumConfidence` | `0.65` | Prevents weak model tags from becoming durable theme/decision anchors. |
| `arcMinimumRecordCount` | `2` | Allows related-memory arcs while rejecting single-note overfit. |
| `arcMinimumClusterStrength` | `0.55` | Baseline topical relatedness threshold. |
| `arcMinimumAverageSalience` | `0.55` | Blocks dense but low-meaning clusters such as dentist, shopping, receipt, and logistics notes. |
| `reflectionMinimumRecordSalience` | `0.75` | Prevents short emotional or neutral notes from becoming reflections. |
| `reflectionMinimumEvidenceCharacters` | `100` | Avoids reflections from tiny fragments without enough evidence. |
| `reflectionMinimumResultConfidence` | `0.70` | Default store gate for reflection quality. |
| `reflectionMinimumBodyCharacters` | `80` | Avoids storing overly thin reflection bodies. |

Additional policy rules:

- Voice transcript reflection can relax request/store gates only when the input is audio or voice, evidence is at least 100 characters, salience is at least `0.30`, and the text contains both recurring-boundary language and writing, morning, creative, or focus anchors. Store confidence can relax to `0.35` only for this voice pattern.
- Explicit decision reflection can relax request/store gates when evidence is at least 100 characters, salience is at least `0.70`, reflection hints are substantial, and the content has both decision signals and reflection signals. Store confidence can relax to `0.60`.
- Arc candidates keep two constraints: cluster strength and average salience. For 3+ record semantic recurring clusters with entity/theme anchors, the effective cluster floor can relax to `0.40` and the average salience floor can relax to `0.45`.
- Link, bookmark, screenshot, receipt, photo, and OCR carrier words are still disallowed as entity or storyline anchors.
- Server canonical entity names are preserved in app mapping; raw mention variants are retained as aliases when they differ.

## Scenario Matrix

Final expanded batch: 72 reports, 71 passed, 1 failed.

| Scenario | Strict | Balanced | Experimental | Notes |
| --- | --- | --- | --- | --- |
| Ordinary short text | PASS | PASS | PASS | Low salience, no arc/reflection. |
| Terse neutral text | PASS | PASS | PASS | No over-inference from tiny input. |
| Long reflective text | PASS | PASS | PASS | Reflection allowed and stored. |
| High emotion short text | PASS | PASS | PASS | Emotion retained, no inferred life pattern. |
| Strong emotion text | PASS | PASS | PASS | Reflection allowed only when enough context exists. |
| Photo / OCR noise | PASS | PASS | PASS | No receipt/OCR/photo entities or arc. |
| Photo with real subject | PASS | PASS | PASS | Inspect-only path stays structurally clean. |
| Link capture | PASS | PASS | PASS | URL/title alone does not create storyline. |
| Speech transcript | PASS | PASS | PASS | Reflection stored around protecting morning writing time. |
| Multi artifact context | PASS | PASS | PASS | Context enriches retrieval, no standalone storyline. |
| Ambient context only | PASS | PASS | PASS | Weather/location/music do not create memory structure alone. |
| Two related events | PASS | PASS | PASS | Arc generated when relationship and topic align. |
| Weak related events | PASS | PASS | PASS | Similar emotion alone does not create arc. |
| Dense unrelated history | PASS | PASS | PASS | Dentist/shopping/bills/weather cluster rejected. |
| Recurring career history | PASS | PASS | PASS | Three-record career arc generated. |
| Chinese mixed language | PASS | PASS | PASS | Chinese/English reflective input stores reflection. |
| Code-switch short text | PASS | PASS | PASS | Short mixed-language text stays low impact. |
| Alias same person history | FAIL | PASS | PASS | Strict remains conservative for `Alex` / `A. Chen` / `Alexander Chen`; balanced and experimental pass. |
| Same-name different people | PASS | PASS | PASS | Avoids merging unrelated people with same name. |
| Relationship conflict shift | PASS | PASS | PASS | Relationship-state evolution can form arc. |
| Long timeline recurring history | PASS | PASS | PASS | Long-term repeated writing-time pattern forms reflection/arc. |
| Sensitive stress short text | PASS | PASS | PASS | Short sensitive stress note is not generalized. |
| Real OCR screenshot | PASS | PASS | PASS | Screenshot/OCR carrier terms rejected. |
| Link metadata trap | PASS | PASS | PASS | Metadata-only link does not form entity/arc/reflection. |

## Key Samples

Noise rejection: OCR and screenshot-like captures returned no durable carrier entities, no edges, no arcs, and no reflections.

Voice reflection: `I keep returning to the same question about how to protect mornings for writing before meetings.` generated reflection calls and stored writing-time reflections without creating an unrelated career arc.

Career arc: three career-transition notes around Linh, launch scope, and smaller launch decisions generated recurring career arcs across all profiles after focused semantic candidate fallback.

Dense unrelated counterexample: dentist, groceries, bills, exercise, and weather records stayed unclustered as a storyline because cluster strength and average salience did not both justify an arc.

Alias residual: strict failed to form an arc from `Alex`, `A. Chen`, and `Alexander Chen` despite canonical mapping preserving `Alexander Chen`. This is an intentional remaining decision point: loosening strict further risks false merges, while balanced/experimental already cover the product-positive path.

## Implementation Notes

- Added local `QualityTuningPreference` persistence with `schemaVersion`, `syncKey`, `updatedAt`, prompt profile, thresholds, and future sync shape.
- Added request IDs from `MoryAPIClient` through pipeline status, diagnostics, and tuning reports.
- Made tuning thresholds active only inside an active tuning scope, so Debug sliders cannot leak into normal app behavior.
- Added scenario/session scoping for tuning runs so strict, balanced, and experimental do not feed each other as accidental history.
- Added expanded 24-scenario local batch coverage across strict, balanced, and experimental profiles.
- Fixed analysis upsert to key by `recordID`, preventing duplicate analyses and candidate-builder crashes during reruns.
- Added canonical-name mapping with raw mention aliases for entity variants.
- Added focused semantic recurring candidate fallback for recurring long-term themes without requiring identical decision labels.
- Added explicit decision and voice transcript reflection exceptions with narrow, explainable gates.
- Added an opt-in simulator XCTest batch runner: create `/tmp/mory-run-local-quality-batch.flag` to run the local Go-backed expanded batch.

## Verification

- iOS targeted tests passed:
  - `xcodebuild -project mory/mory.xcodeproj -scheme mory -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:moryTests/AnalyzeResponseMapperTests test`
- Full iOS tests passed:
  - `xcodebuild -project mory/mory.xcodeproj -scheme mory -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
- Expanded local live batch ran against `127.0.0.1:8080` and produced `/tmp/mory-quality-expanded-report-20260517-084100.txt`.
- Go toolchain blocker: `go` was not available in `PATH`, `/opt/homebrew/bin/go`, `/usr/local/go/bin/go`, or `/usr/local/bin/go`, so backend unit tests could not be run in this environment. The existing local server binary was healthy and handled live app requests, but the latest Go prompt source changes were not rebuilt into that binary during this run.

## Untested Or Partially Tested

- Real binary image pixels and real audio files were not injected; image/audio cases used structured artifacts and transcripts.
- Large messy OCR documents, long PDFs, and multi-page screenshots need a later data-heavy pass.
- More languages beyond English, Chinese, and short code-switch examples remain uncovered.
- Network-failure behavior for link metadata fetches was not stress-tested.
- Real user months-long memory corpora were not available; synthetic long/short history was used.
- Cloud sync was intentionally not tested; only local SwiftData preference persistence and sync-ready fields were implemented.

## Future Preference Sync

Local preferences now have the right sync shape: `schemaVersion + syncKey + updatedAt`. A future cloud sync can upsert by `syncKey`, use `updatedAt` for conflict resolution, and preserve unknown future fields by `schemaVersion`.
