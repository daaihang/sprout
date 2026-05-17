# 07. Insights Experience

## 1. Purpose

Insights is where Mory turns captured memories into understandable patterns.

It should organize AI-derived and graph-derived information without making the user feel judged, overanalyzed, or confused.

## 2. Primary Sections

Insights contains:

1. Storylines.
2. Reflections.
3. People.
4. Places.
5. Themes.
6. Decisions.

Optional later sections:

- Activities.
- Objects.
- Relationship reminders.
- Anniversaries.

## 3. Insights Home

The Insights landing screen should show:

- Highlighted active storyline.
- Suggested reflections.
- Recently updated people/places/themes.
- Search/filter entry.
- Explanation of what insights are based on.

It should not show every graph node as an equal list.

## 4. Storylines

Public label: Storylines.

Storyline card content:

- Title.
- Summary.
- Source memory count.
- Dominant person/place/theme/decision.
- Date range.
- Status.
- Last updated.

Detail view:

- Summary.
- Source memories.
- Related people/themes.
- Linked reflection.
- Merge/archive actions if appropriate.
- Confidence/evidence indicators.

Rules:

- Storylines must be grounded in multiple records or very explicit high-signal events.
- Weak clusters should not appear as public storylines.
- User should be able to archive or inspect.

## 5. Reflections

Reflection card content:

- Title.
- Short body.
- Evidence summary.
- Confidence.
- Status: suggested, saved, dismissed, archived.
- Source count.

Actions:

- Save.
- Dismiss.
- Archive.
- Open sources.

Rules:

- Suggested reflections are not permanent unless saved.
- Saved reflections leave suggestion surfaces.
- Dismissed reflections should not keep resurfacing.
- Low-confidence content should be filtered before public display.

## 6. People

People view should show:

- Person name.
- Related memory count.
- Related storylines.
- Related reflections.
- Recent memories.
- Themes involving the person.

Rules:

- People entities need deduplication.
- Low-confidence names should not dominate.
- User corrections are future scope but UI should allow eventual merge/rename.

## 7. Places

Places view should show:

- Place name.
- Related memories.
- Map preview when possible.
- Repeated context.
- Storylines involving the place.

Rules:

- Coordinates without name should display gracefully.
- Automatic location should not imply exactness if reverse geocoding is weak.

## 8. Themes

Themes view should show:

- Theme label.
- Related memories.
- Related people/places.
- Related storylines/reflections.

Rules:

- Technical artifacts like OCR, screenshot, receipt, bookmark, and link should not become themes.
- Themes should be user-meaningful.

## 9. Decisions

Decision view should show:

- Decision title.
- Related memories.
- People involved.
- Storyline if part of a larger arc.
- Follow-up prompts when useful.

Rules:

- Decisions should not be hallucinated from vague emotions.
- Different labels for the same long-term decision can cluster if evidence is strong.

## 10. Tone

Insights should be:

- Respectful.
- Evidence-based.
- Calm.
- Nonjudgmental.
- Easy to dismiss.

Avoid:

- Therapy-like certainty.
- Overdramatic language.
- Pretending a single short note proves a life pattern.
- Generic motivational text.

## 11. Acceptance Criteria

- User can browse Storylines and Reflections from Insights.
- User can inspect sources.
- Suggested vs saved reflection state is clear.
- People/places/themes/decisions are understandable.
- Insights do not require Debug to validate.
- Weak/noisy artifacts do not dominate public insight surfaces.

