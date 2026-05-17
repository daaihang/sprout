# 09. Onboarding, Permissions, And Empty States

## 1. Purpose

Onboarding should help users make a first memory quickly and understand why optional permissions matter. It should not become a long tutorial.

## 2. First-Run Flow

Steps:

1. Welcome.
2. Local-first explanation.
3. Quick capture prompt.
4. Optional permission education.
5. First memory capture.
6. Today Board with saved memory and processing state.

Rules:

- User can skip optional permission requests.
- The app should not request every permission at launch.
- Permission prompts should appear when relevant to a user action.

## 3. Permission Strategy

### 3.1 Progressive Requests

| Permission | Request Moment |
|------------|----------------|
| Photos | User taps photo input |
| Microphone | User starts voice/audio capture |
| Speech | User records or imports audio for transcription |
| Location | User opens composer/context or location picker |
| Music | User enables music context |
| Weather | After location is available and weather context is useful |

### 3.2 Denied State

Denied state must show:

- What is unavailable.
- Why it helps.
- Open Settings action.
- Continue without it action.

## 4. Empty States

### 4.1 Today Empty

Message:

- Mory is ready to capture a first memory.
- Start with text or voice.
- Optional context can be added later.

Action:

- Add first memory.

### 4.2 Memories Empty

Message:

- Saved memories will appear here.
- Capture from toolbar.

Action:

- Add memory.

### 4.3 Insights Empty

Message:

- Insights appear after enough memories form patterns.
- Keep capturing real moments.

Action:

- View Memories or add memory.

### 4.4 Search Empty

Message:

- No results for query/filter.
- Suggest clearing filters.

Action:

- Clear filters.

### 4.5 Permission Empty

Message:

- Context type unavailable because permission is off.

Action:

- Enable permission or continue without it.

## 5. Processing States

### 5.1 Pending

Show:

- Saved locally.
- Waiting for analysis.

### 5.2 Running

Show:

- Analyzing.
- Nonblocking state.

### 5.3 Completed

Show:

- Analysis available.

### 5.4 Failed

Show:

- Saved source is safe.
- Retry action.
- Friendly error.

Internal builds may show raw debug details.

## 6. Copy Tone

Use:

- Calm.
- Specific.
- Short.
- Actionable.

Avoid:

- Overexplaining AI.
- Therapy language.
- Technical stage names in public copy.
- Fear-based permission prompts.

## 7. Acceptance Criteria

- User can complete first capture without granting optional permissions.
- No public empty state looks like debug output.
- Permission denial does not block core capture.
- Failed analysis is recoverable.
- Onboarding does not require reading long text.

