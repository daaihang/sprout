# 05. Capture Presentation Components

## 1. Goal

Capture UI must become robust, componentized, and fast to iterate.

## 2. Component Map

Recommended components:

- QuickCaptureToolbar.
- QuickTextComposer.
- VoiceHoldButton.
- AudioCaptureInputView.
- PhotoInputView.
- LinkInputView.
- LocationPickerView.
- ContextCandidateListView.
- ArtifactStagingListView.
- CaptureSaveBar.
- CaptureErrorRecoveryView.

## 3. Audio State Machine

Audio capture should use a dedicated model:

```swift
enum AudioCaptureState {
    case idle
    case preparing
    case recording(startedAt: Date)
    case finalizing
    case transcribing
    case transcriptReady(String)
    case failed(String)
    case cancelled
}
```

Rules:

- Stop is idempotent.
- Cancel is always available while recording/preparing.
- Finalizing has timeout fallback.
- Transcription failure keeps audio/transcript recovery path if possible.

## 4. Link Component

Responsibilities:

- URL entry.
- Body auto-detection display.
- Metadata loading state.
- Final URL display in internal/debug contexts.
- Error state.

Does not:

- Own memory save.
- Own AI analysis.

## 5. Photo Component

Responsibilities:

- Picker result display.
- Thumbnail.
- OCR/vision state.
- Low confidence/noisy OCR warning.
- Remove action.

## 6. Location Component

LocationPickerView owns:

- Current location.
- Search.
- Map selection.
- Selected place preview.

Composer owns:

- Presenting picker.
- Receiving selected location draft.
- Including selected location in final drafts.

## 7. Context Candidate Component

Responsibilities:

- Display candidates.
- Toggle selection.
- Show capturedAt.
- Refresh action.
- Permission recovery actions.

Rules:

- Candidate is a snapshot.
- Save uses selected candidates only.

## 8. Tests

Required:

- Text draft output unchanged.
- Link metadata draft output unchanged.
- Auto-detected link output unchanged.
- Selected context included in save.
- Unselected context excluded.
- Location picker draft saves as location artifact.
- Audio stop can be called repeatedly.
- Failed transcription does not freeze UI.

