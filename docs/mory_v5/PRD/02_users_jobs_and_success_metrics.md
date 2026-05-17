# 02. Users, Jobs, And Success Metrics

## 1. Target Users

### 1.1 Reflective Capturer

The user captures small moments throughout the day: thoughts, conversations, decisions, links, photos, songs, locations.

Needs:

- Fast capture.
- Minimal typing.
- Context preserved automatically.
- Confidence that rough input is acceptable.

Pain points:

- Traditional journaling feels heavy.
- Notes apps become cluttered.
- Voice notes are hard to rediscover.

### 1.2 Memory Revisitor

The user returns later to understand what happened and why it mattered.

Needs:

- Search by memory, person, topic, place, or timeframe.
- Clean detail views.
- Source transparency.
- Ability to correct bad analysis.

Pain points:

- AI summaries can feel ungrounded.
- Chronological lists do not reveal patterns.
- Photos/links/audio are disconnected.

### 1.3 Insight Seeker

The user wants to see recurring patterns, relationships, decisions, emotional shifts, and long-term arcs.

Needs:

- Storylines that make sense.
- Reflections that are concise and respectful.
- Ability to save, dismiss, or inspect insights.
- Clear evidence trail.

Pain points:

- Generic AI advice feels cheap.
- Overeager pattern detection feels invasive.
- Unclear confidence damages trust.

### 1.4 Privacy-Sensitive User

The user is interested in memory intelligence but cautious about personal data.

Needs:

- Local-first explanation.
- Permission controls.
- Data export and deletion.
- Account state visibility.

Pain points:

- Apps hide AI data behavior.
- Permissions feel irreversible.
- Account/logout/delete controls are often hard to find.

## 2. Jobs To Be Done

| Job | Trigger | Desired Outcome |
|-----|---------|-----------------|
| Capture a thought | User has a passing idea | Save it in seconds without organizing |
| Save a real-world context | User is somewhere, hearing something, or seeing something | Preserve enough context to understand later |
| Record a voice thought | User cannot type | Hold, speak, release, review transcript |
| Add a link | User finds an article/post | Save metadata and personal note |
| Review today | User opens app | See relevant memories and active signals |
| Find an old memory | User remembers a fragment | Search/filter to retrieve the source |
| Understand a pattern | User sees repeated behavior or relationship | Inspect storyline/reflection with sources |
| Control privacy | User worries about data | Find settings and adjust permissions/data |

## 3. User Journey

### 3.1 First Session

1. User signs in or continues in allowed local mode.
2. App explains local-first capture.
3. User sees Today with clear empty state.
4. User taps text capture or holds voice capture.
5. User saves first memory.
6. App shows processing state without blocking.
7. User can inspect saved memory.

### 3.2 Daily Session

1. User opens Today.
2. Today shows recent captures, pending analysis, and one or two insight prompts.
3. User adds a quick note from bottom toolbar.
4. User optionally reviews a reflection.
5. User leaves without needing to manage structure.

### 3.3 Review Session

1. User opens Memories.
2. User filters by date/artifact/person/search.
3. User opens a memory detail.
4. User sees source artifacts and AI analysis.
5. User corrects the memory if needed.

### 3.4 Insight Session

1. User opens Insights.
2. User selects Storylines, Reflections, People, Places, Themes, or Decisions.
3. User opens an item.
4. User inspects source memories.
5. User saves, dismisses, archives, or continues exploring.

## 4. Success Metrics

### 4.1 Quantitative Metrics

| Metric | Target |
|--------|--------|
| First capture completion | > 80% |
| Quick capture start time | < 5 seconds from app open |
| Capture save success | > 98% |
| Memory detail load | < 1 second local median |
| Settings discoverability | Reachable in 1 tap from top nav |
| User-controlled dismiss/hide actions | Persist locally and survive relaunch |

### 4.2 Qualitative Signals

The app is working when users say:

- "I know where to add something."
- "I understand why this card is here."
- "I can find what I saved."
- "The insights feel connected to my real memories."
- "I can control what the app sees."

The app is failing when users say:

- "I do not know what this card means."
- "This feels like a debug tool."
- "I cannot tell whether this was saved."
- "I cannot stop recording."
- "I cannot find settings."

## 5. Public Beta Research Questions

1. Does the two-row bottom area feel powerful or crowded?
2. Is press-hold voice capture discoverable?
3. Do users prefer Today as a board or as a feed?
4. Are AI reasons and source counts enough to create trust?
5. Which Settings items are expected immediately?
6. Does Insights feel like a destination or a secondary tab?
7. Does visual warmth reduce the "database" feeling without hurting clarity?

