# 07. Memory Views And Archives

## 1. Purpose

Mory should not rely only on system Form/List views. V6 should introduce richer native-feeling memory views that match the emotional nature of memory.

These views are not separate data models. They are renderers over the same memory/artifact/graph/composition system.

## 2. Core View Modes

### 2.1 Library List

Purpose:

- Reliable browsing.
- Filtering.
- Editing.
- Search fallback.

This remains the dense utility surface.

### 2.2 Timeline

Purpose:

- Date-based review.
- Day/week/month grouping.
- Historical browsing.

Timeline is a view mode of the memory library, not a separate domain object.

### 2.3 Home Board

Purpose:

- Today's live memory desk.
- User-owned layout.
- AI suggestions.

### 2.4 Film Gallery

Purpose:

- Photo-first review.
- Visual memory wall.
- Good for trips, meals, events, places, people.

Rendering:

- Native SwiftUI grid.
- Photo thumbnails from artifacts.
- Date/person/place overlays only when useful.

### 2.5 Storage Jar

Purpose:

- A playful archive metaphor.
- Good for low-pressure revisit.
- Can group by mood, period, person, place, theme, or random memory.

### 2.6 Sticker Wall

Purpose:

- Mixed lightweight memories.
- Small cards, photos, quotes, music, places.
- Useful for user-curated collections.

### 2.7 Multimedia Article

Purpose:

- Long-form memory/chapter composition.
- User can reorder text, photos, audio transcript, location, music, and reflections.

This should be a future extension of Composition, not a separate content universe.

## 3. Complete Memory Presentation

Users should see a complete memory, not scattered artifacts.

Detail should present:

- Title.
- Main body or refined transcript.
- Source media.
- Context row.
- Related people/places/themes.
- AI analysis if available.
- Questions if unresolved.
- Source artifacts when expanded.

## 4. View Mode Selection

View modes can appear in:

- Memories tab.
- Person detail.
- Place detail.
- Chapter detail.
- Search results.
- Yesterday panel.

## 5. Acceptance Criteria

- List and timeline remain functional.
- At least one visual view mode ships in v6 beta.
- Film gallery uses real photo artifacts.
- Complete memory detail remains the source of truth.
- View modes do not create duplicate data.
- Accessibility labels exist for visual media cards.

