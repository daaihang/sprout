# 03. Information Architecture

## 1. Primary Navigation

v5 uses three bottom tabs:

1. Today
2. Memories
3. Insights

These are the only public primary tabs.

## 2. Bottom Area

The bottom area has two rows:

### 2.1 Row 1: Quick Capture Toolbar

Position: directly above the tab bar.

Required controls:

- Text capture button: tap opens a compact text composer.
- Voice capture button: press and hold records; release finalizes and transcribes.
- Optional context/menu button: opens additional artifact inputs when needed.

Rules:

- Toolbar must be visible from Today, Memories, and Insights unless a modal/detail is active.
- Toolbar must not cover scroll content.
- Toolbar must respect keyboard and safe-area behavior.
- Long press state must be visually obvious.
- Recording must always have a cancel/recover path.

### 2.2 Row 2: Tab Bar

Tabs:

| Tab | Icon Direction | Purpose |
|-----|----------------|---------|
| Today | calendar/home signal | Daily board and immediate actions |
| Memories | stacked cards/library signal | Full memory library |
| Insights | spark/graph signal | Storylines, reflections, people, themes |

## 3. Top Navigation

Top navigation changes by tab but follows a stable structure:

| Position | Today | Memories | Insights |
|----------|-------|----------|----------|
| Leading | Date / Today title | Library title | Insights title |
| Center | Optional date picker / segment | Optional search context | Optional segment |
| Trailing | Search, Account | Filter, Search, Account | Filter, Account |

Global account button:

- Always in top trailing cluster.
- Opens Account / Settings.
- Does not occupy a bottom tab.

## 4. Route Model

Global route families:

- `memory(recordID)`
- `artifact(artifactID)`
- `arc(arcID)`
- `reflection(reflectionID)`
- `entity(entityID)`
- `search(query/filter)`
- `settings(section)`
- `capture(mode)`

Rules:

- Tapping a board card navigates directly to its target.
- Returning once should return to the source surface.
- Modal capture does not pollute navigation history.
- Settings is a sheet or stack presented over the current tab.
- Debug routes are internal only.

## 5. Object Hierarchy

Mory's UI should represent the user's life material in this hierarchy:

1. Memory
2. Artifact
3. Entity
4. Storyline
5. Reflection
6. Board card
7. System prompt

The UI should avoid exposing raw implementation terms when a human label is clearer.

Examples:

| Internal Object | Public Label |
|-----------------|--------------|
| TemporalArc | Storyline |
| ReflectionSnapshot | Reflection |
| EntityNode person | Person |
| EntityNode theme | Theme |
| CaptureArtifactDraft | Attachment |
| PipelineStatus | Processing |

## 6. Surface Responsibilities

### 6.1 Today

Responsible for:

- Daily board.
- Latest memories.
- Active storylines.
- Suggested reflections.
- Pending processing.
- System prompts.

Not responsible for:

- Full archive browsing.
- Deep graph browsing.
- Settings management.

### 6.2 Memories

Responsible for:

- Full memory list.
- Timeline grouping.
- Artifact filters.
- Search.
- Detail viewing.
- Corrections.

Not responsible for:

- Primary insight overview.
- Board personalization.

### 6.3 Insights

Responsible for:

- Storylines.
- Reflections.
- People.
- Places.
- Themes.
- Decisions.
- Source exploration.

Not responsible for:

- Raw chronological archive.
- Capture.

### 6.4 Account / Settings

Responsible for:

- Identity.
- Login state.
- Permissions.
- Capture preferences.
- AI preference controls.
- Privacy explanation.
- Data export/deletion.
- Language/appearance.
- Diagnostics for internal builds.

## 7. Navigation Acceptance Criteria

- Public app has exactly three bottom tabs.
- Account/Settings is reachable in one tap from all primary tabs.
- Capture is reachable from all primary tabs.
- Details return to source surface with one back action.
- Voice recording cannot trap the user.
- Debug tab is never visible in public beta builds.

