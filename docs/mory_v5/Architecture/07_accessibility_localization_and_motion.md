# 07. Accessibility, Localization, And Motion

## 1. Goal

v5 must be usable beyond the default simulator size and language.

## 2. Dynamic Type

Requirements:

- Primary flows support large text.
- Buttons do not truncate essential verbs.
- Cards can grow vertically.
- Toolbar keeps stable touch targets.
- Long titles use wrapping or line limits with detail fallback.

## 3. VoiceOver

Required labels:

- Quick text capture.
- Hold to record voice memory.
- Cancel recording.
- Stop recording.
- Save memory.
- Open Settings.
- Pin card.
- Hide card.
- Dismiss reflection.
- Open source memories.

Card VoiceOver format:

```text
Card type, title, reason, source count, action.
```

## 4. Contrast

Requirements:

- Text/background contrast should be readable in light and dark mode.
- Accent colors cannot be the only status signal.
- Error/warning/success states use icon and label.

## 5. Reduced Motion

When Reduce Motion is enabled:

- Avoid bouncing toolbar.
- Avoid looping recording animations.
- Use opacity/label changes instead.
- Preserve haptic/audio cues only if appropriate.

## 6. Localization

Supported:

- English.
- Simplified Chinese.

Rules:

- No hardcoded public copy.
- Debug-only copy may be English if clearly internal, but preferred to localize common controls.
- String keys use feature prefixes.
- Avoid long strings inside small buttons.

## 7. Text Fitting

Rules:

- Compact cards use smaller headings.
- Hero typography only in real hero/empty states.
- Buttons have stable width/height.
- Chips can wrap or scroll depending on context.

## 8. Acceptance Criteria

- Primary flows pass manual Dynamic Type review.
- Toolbar controls have accessibility labels.
- Recording state is perceivable without motion.
- English and Chinese strings exist for public UI.
- No public UI shows raw key names.

