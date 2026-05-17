# 06. Memories Library

## 1. Purpose

Memories is the user's complete library.

It should be the place to find, review, correct, and understand saved material without needing to know the AI graph structure.

## 2. Primary Views

Memories should support:

1. Timeline.
2. Search.
3. Artifact filters.
4. Date grouping.
5. Memory detail.
6. Artifact detail.

## 3. Library List

Each memory row/card should show:

- Title or first meaningful line.
- Summary/excerpt.
- Date/time.
- Artifact type indicators.
- Context chips where useful.
- Processing state if not completed.

List rules:

- Recent memories first by default.
- Date sections for scanning.
- Failed processing visible but not noisy.
- Deleted memories disappear immediately.

## 4. Filters

Filter dimensions:

- Date range.
- Artifact type: text, photo, audio, link, location, weather, music, document, todo.
- Processing status: pending, running, completed, failed.
- Context availability: has location, has weather, has music.
- Insight availability: has storyline, has reflection, has entities.

Filter UI:

- Uses chips or compact sheet.
- Can clear all.
- Does not require advanced syntax.

## 5. Search

Search should query:

- Raw text.
- Artifact title/summary/text content.
- Analysis summary.
- Retrieval terms.
- Entity names.
- Storyline titles.
- Reflection titles.

Search result types:

- Memories.
- Storylines.
- Reflections.
- People.
- Places.
- Themes.
- Decisions.

Rules:

- Memory results should lead.
- AI-derived results should show type labels.
- Result snippets should explain match reason when possible.

## 6. Memory Detail

Memory detail should show:

1. Source capture.
2. Attachments/artifacts.
3. Context.
4. Processing status.
5. Analysis summary.
6. Entities.
7. Related storylines.
8. Related reflections.
9. Edit/correction actions.

Design requirements:

- Source content should feel primary.
- AI analysis should feel secondary and explainable.
- Corrections should be obvious but not dominant.
- Long debug payloads must stay internal.

## 7. Artifact Detail

Artifact detail should adapt by kind:

- Photo: image, OCR, labels, metadata.
- Audio: transcript, duration, file metadata.
- Link: URL, final URL, title, description, preview image.
- Location: map preview, address, coordinates.
- Weather: condition, temperature, humidity, wind, captured time.
- Music: track, artist, album, artwork if available.
- Text: body and source metadata.

## 8. Correction Flow

Users can:

- Edit raw memory text.
- Add correction/supporting text.
- Retry analysis when failed.
- Trigger rerun after edit.

Rules:

- Rerun purges stale derived data for the memory.
- UI must indicate that analysis may update.
- User should not see duplicate old/new entities after rerun.

## 9. Empty And Error States

No memories:

- Explain capture.
- Offer quick text and voice actions.

No search results:

- Show query.
- Offer filter reset.

Failed processing:

- Show retry.
- Explain that saved source is still safe.

## 10. Acceptance Criteria

- User can browse all memories.
- User can search and filter.
- User can open memory detail.
- User can inspect artifacts.
- User can edit and rerun.
- UI does not expose orphan derived data.
- Detail view feels like a product page, not a debug report.

