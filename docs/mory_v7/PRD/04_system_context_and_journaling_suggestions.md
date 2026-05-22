# 04. System Context And Journaling Suggestions

## 1. Product Goal

Mory should reduce capture burden without pretending it can run invisibly forever in the background.

v7 should let users bring in context from:

- App Intents,
- Shortcuts/Siri,
- Share Sheet,
- photos/screenshots/links,
- location/weather/music,
- Journaling Suggestions,
- local speech/photo/OCR processing.

All sources become normal `CaptureDraft` evidence. No source should create hidden memories without user intent.

## 2. Product Principles

1. User selected context is stronger than guessed context.
2. System suggestions are evidence, not truth.
3. Mory should explain the source of each context card.
4. Every context source must have a disabled/fallback state.
5. Context should help reflection, not make the capture screen feel heavy.

## 3. Journaling Suggestions Role

Journaling Suggestions is valuable because it can surface user-selected life context:

- places,
- photos and videos,
- music/podcasts/media,
- workouts/activity,
- contacts/social moments,
- reflection prompts,
- StateOfMind where available.

It does not solve voice tone detection by itself.

It is not:

- automatic access to the Journal app,
- automatic background harvesting,
- a universal emotional intelligence API,
- a replacement for Mory `AffectSnapshot`.

## 4. User Journey

```text
User starts a memory
  -> taps "Add from system suggestion"
  -> iOS picker shows eligible suggestions
  -> user selects one
  -> Mory converts assets to context evidence
  -> draft shows compact cards
  -> user saves
  -> analysis receives context/mood evidence with provenance
```

## 5. Evidence Mapping

| Suggestion asset | Mory mapping | Trust level |
| --- | --- | --- |
| location | `PlaceContextEvidence` | high if user selected |
| photo/video | `CaptureArtifactDraft.photo/video` + visual/OCR hints | medium |
| media/song | `MusicContextEvidence` | high if selected |
| workout/activity | `ActivityContextEvidence` | high if selected |
| contact/social moment | `PersonContextCandidate` | medium, needs identity resolver |
| reflection prompt | `PromptContextEvidence` | high for prompt text |
| StateOfMind | `AffectEvidenceSource.journalSuggestionStateOfMind` | high as user-recorded mood evidence |

## 6. Consent And Availability

Required behavior:

- show capability only when entitlement and OS availability are present,
- never block normal capture if unavailable,
- store source and availability status for debug,
- clearly differentiate “user selected from system” from “Mory inferred”.

## 7. App Intents And Share

v7 should support quick capture from outside the main app:

- record text,
- record voice,
- save link,
- save screenshot/image,
- save selected text,
- save current context if permission allows.

These paths must create the same domain objects as in-app capture:

- `CaptureDraft`,
- `CaptureArtifactDraft`,
- `ContextEvidence`,
- `AffectSnapshot` when mood evidence exists,
- `AnalysisJob`.

## 8. Local Preprocessing

Local frameworks can add lightweight evidence:

| Framework | Product use |
| --- | --- |
| Speech | transcribe voice and mark uncertainty |
| NaturalLanguage | detect language, keywords, lightweight entities |
| Vision/VisionKit | OCR, document/ticket clues, image labels |
| Core ML | optional local tone/classification |
| AVFoundation | camera/audio capture |

All local model output is lower trust than direct user confirmation.

## 9. Success Criteria

- User can add system suggestions without leaving Mory.
- System context appears as editable/removable evidence cards.
- Journaling mood evidence maps into `AffectSnapshot`.
- If capability is unavailable, capture still works normally.
- Analyze v7 receives evidence source metadata.
