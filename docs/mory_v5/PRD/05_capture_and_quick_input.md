# 05. Capture And Quick Input

## 1. Purpose

Capture is the most important action in Mory.

The user should be able to add a memory before the thought disappears. v5 must make capture feel immediate while still allowing rich artifacts and context when the user has time.

## 2. Capture Entry Points

| Entry | Trigger | Result |
|-------|---------|--------|
| Quick text | Tap toolbar text button | Opens compact text composer |
| Quick voice | Press and hold toolbar voice button | Records while held; release finalizes |
| Full composer | Toolbar menu or expanded composer | Supports text, photo, audio, link, location, context |
| Share/import future entry | External source | Out of v5 default scope unless separately approved |

## 3. Bottom Quick Toolbar

Required controls:

1. Text button.
2. Voice button.
3. More/input mode button.

Behavior:

- Tap text: open composer focused on text field.
- Long press voice: start recording.
- Release voice: stop recording and begin transcription.
- Drag/cancel gesture: cancel recording before release if needed.
- If recording fails: show recovery state and keep app usable.

Toolbar rules:

- Stable height.
- Does not resize due to labels.
- Uses icons with accessibility labels.
- Respects keyboard/safe area.
- Haptic feedback on record start/stop if available.

## 4. Voice Capture

### 4.1 State Machine

States:

1. Idle.
2. Preparing.
3. Recording.
4. Finalizing.
5. Transcribing.
6. TranscriptReady.
7. Failed.
8. Cancelled.

Rules:

- Every state has a visible exit path.
- Stop operation must be idempotent.
- Finalizing cannot trap the UI.
- Permission denial opens recovery guidance.
- Transcript is editable before save.

### 4.2 Live Transcription

Preferred direction:

- Show partial transcription while recording when stable enough.
- Preserve final transcript as the source of truth after release.
- Do not save partial transcript automatically.

Fallback:

- If live transcription is unreliable, keep release-to-transcribe but make the state robust.

Acceptance:

- User can stop recording every time.
- User can edit transcript.
- User can discard transcript.
- App does not freeze if speech recognition returns no result.

## 5. Text Capture

Text composer should support:

- Multiline entry.
- Optional mood.
- Optional title only when needed.
- Auto-detected link preview.
- Selected context candidates.
- Save button fixed and reachable.

Rules:

- Raw rough input is allowed.
- Nonsense or low-signal input should save safely and be filtered by analysis gates.
- Prompt injection text must remain user content and not become app instructions.

## 6. Link Capture

Link handling:

- Detect first URL in body text.
- Normalize URL.
- Resolve redirects when safe.
- Fetch title, site name, description, image when available.
- Store final URL and display input/final difference in debug/internal views.

User experience:

- If metadata loads, show preview.
- If metadata fails, still allow save.
- If only URL exists, do not overstate insight.
- If user adds explanation, user text dominates AI meaning.

## 7. Photo Capture

Photo handling:

- Pick one or multiple photos when supported.
- Generate thumbnail.
- Run OCR and image labels.
- Show low-confidence or noisy OCR indication.
- Allow user to remove photo before save.

Rules:

- OCR noise should not create core entities.
- Receipts, screenshots, menus, and random text should be handled as artifacts, not story anchors.
- Photo preview must be clear enough to confirm the selected image.

## 8. Location Capture

Location is selected through a dedicated LocationPickerView.

Required modes:

- Use current location.
- Search a place.
- Pick point on map.

Rules:

- Composer should not become a map-heavy page.
- Selected location appears as a candidate/artifact preview.
- Multiple location support is future-friendly but v5 can start with one selected location plus auto context candidate.

## 9. Music Context

Music context is a snapshot.

Rules:

- Captured track is fixed at candidate capture time.
- Saving uses selected candidate only.
- If track changes after the composer opens, user must refresh to update.
- Candidate shows captured time, track, artist, album when available.
- Multiple tracks/albums can be future support; v5 should design UI that does not block it.

## 10. Context Candidates

Supported candidates:

- Location.
- Weather.
- Music.

Behavior:

- Composer opens and starts context collection.
- Successful candidates are selected by default.
- User can unselect.
- User can refresh.
- Permission missing state shows enable/recovery action.
- Save writes selected candidates in the initial memory snapshot.
- No hidden late append after save.

## 11. Full Composer Layout

Sections:

1. Primary input.
2. Artifact staging.
3. Context candidates.
4. Save/cancel actions.
5. Error/recovery area.

Rules:

- Primary input and save action must be reachable.
- Artifact-specific controls are componentized.
- Sheet routing handles location picker, photo picker, and advanced inputs.
- Composer owns aggregation but not every subview's internal UI.

## 12. Acceptance Criteria

- Text capture from toolbar works.
- Press-hold voice capture can start, stop, cancel, transcribe, edit, and save.
- Link auto-detection works from body text.
- Location picker is separate from composer.
- Music candidate is snapshot-stable.
- Context candidates save in initial memory.
- Low-signal and noisy content does not break save or overproduce insights.

