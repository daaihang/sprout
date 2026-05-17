# 08. Account, Settings, And Privacy

## 1. Purpose

Account / Settings is required for public beta.

Users need a normal product surface for identity, permissions, privacy, preferences, language, appearance, data export, deletion, and diagnostics. Debug pages cannot substitute for Settings.

## 2. Entry Point

Settings is opened from the top trailing account button on every primary tab.

Presentation:

- Sheet on compact screens.
- NavigationStack inside the sheet.
- Can deep link to specific settings sections.

## 3. Settings Sections

### 3.1 Account

Shows:

- Login method.
- User ID or local guest state.
- Account email/name if available.
- Sign out.
- Re-authentication state if needed.

Actions:

- Sign out.
- Continue local mode when allowed.
- Manage account future action.

### 3.2 Capture Preferences

Controls:

- Default prompt/profile preference when exposed to users.
- Default context candidate selection.
- Voice transcription language preference.
- Save raw transcript option.
- Link preview auto-detection toggle.

Rules:

- Preferences are local-first.
- Store sync-ready keys even before cloud sync.

### 3.3 Permissions

Shows permission state for:

- Location.
- Photos.
- Microphone.
- Speech.
- Apple Music.
- Weather availability.

Actions:

- Request if not determined.
- Open system settings if denied.
- Explain why the permission helps.

### 3.4 Privacy

Content:

- Local-first explanation.
- What is stored locally.
- What may be sent to AI backend.
- What is never sent unless user captures it.
- How deletion works.
- How Debug differs from public app.

Tone:

- Plain language.
- No legal fog.
- No overpromising.

### 3.5 Data

Actions:

- Export data.
- Clear local debug/test data in internal builds.
- Delete all local data.
- Delete account future action if backend support exists.

Export should include:

- Memories.
- Artifacts metadata.
- Analysis summaries.
- Storylines.
- Reflections.
- Settings/preferences.

### 3.6 Appearance

Controls:

- Follow system.
- Light.
- Dark.
- Optional accent style future setting.

### 3.7 Language

Controls:

- Opens app language settings.
- Displays current app language.

### 3.8 Diagnostics

Only internal builds:

- Environment.
- Auth diagnostics.
- Server health.
- Permission matrix.
- Storage integrity.
- Quality lab.
- Home Board rules.

Public builds:

- Diagnostics section hidden or reduced to nontechnical "Support".

## 4. Account State Requirements

| State | UI |
|-------|----|
| Authenticated | Show account identity and sign out |
| Guest/local | Show local mode explanation and sign-in option |
| Loading | Show progress and do not block Settings shell |
| Error | Show recoverable error and retry |

## 5. Privacy Copy Requirements

Settings must clearly say:

- Captures are saved locally first.
- AI analysis may use captured text/artifact context.
- Location/weather/music are optional candidates.
- Permission denial does not prevent text capture.
- Deleting a memory removes derived local graph/story/reflection data tied to that memory.

## 6. Local Preference Model

Settings preferences should include:

- `syncKey`
- `schemaVersion`
- `updatedAt`
- `captureDefaults`
- `voiceLanguage`
- `linkAutoDetectEnabled`
- `contextDefaults`
- `appearanceMode`
- `insightFrequency`
- `homeBoardPreferenceSummary`

## 7. Acceptance Criteria

- Settings exists in public UI.
- Account state is visible.
- User can sign out.
- User can inspect permissions.
- User can open system settings for denied permissions.
- User can understand local-first and AI behavior.
- User can export/delete local data or see disabled future actions with clear copy.
- Debug-only diagnostics are gated by runtime environment.

