# 11. AI Governance, Review, And Editing Boundaries

## 1. Purpose

V6 makes Mory more active. That requires stricter governance, not looser behavior.

This document defines what AI may do, what must be reviewed, and how users stay in control.

## 2. Core Rule

AI can prepare, suggest, organize, and ask.

AI cannot silently rewrite the user's life.

## 3. Truth Levels

Every AI-derived object should belong to a truth level.

| Level | Meaning | Example |
| --- | --- | --- |
| source | Direct user/system material | Typed text, audio file, photo, GPS sample |
| extracted | Deterministic or low-risk extraction | Date, weather, OCR text |
| inferred | Model/rule guess | "This may be work stress" |
| suggested | Candidate waiting for user action | "Is Alex your coworker?" |
| confirmed | User-approved durable structure | Alex relationship = coworker |
| rejected | User said no | Entity merge rejected |

UI and persistence should never confuse inferred with confirmed.

## 4. Allowed Autonomous Actions

Mory may do these in the background:

- Create local intelligence jobs.
- Extract low-risk signals.
- Rank existing memories for revisit.
- Generate candidate questions.
- Generate home suggestion cards.
- Index content locally.
- Prepare notification intents.
- Refresh stale local derived data.

These actions do not alter user-authored source content.

## 5. Actions That Need User Confirmation

Require explicit user action:

- Merge people.
- Set relationship to user.
- Rename a person/place/theme.
- Create a life chapter as saved object.
- Mark a theme as sensitive or tracked.
- Convert a sentence into a task/reminder.
- Publish a notification category that includes sensitive content.
- Send memory content to cloud AI if the setting is off.

## 6. Voice Transcript Exception

Voice refinement is the main allowed transformation path.

It must keep:

- Original audio.
- Raw transcript if available.
- Refined transcript.
- Metadata showing refinement provider and time.

User controls:

- Use refined transcript.
- Show original.
- Revert.
- Disable automatic refinement.

Allowed transformations:

- Punctuation.
- Paragraph breaks.
- Remove filler.
- Remove duplicated phrases.
- Generate title.
- Light wording polish.

Not allowed:

- Add new facts.
- Change emotional meaning.
- Remove important uncertainty.
- Convert into a polished essay unless the user chooses that mode.

## 7. Evidence Requirements

Every AI suggestion should have evidence.

Examples:

```text
Question: "Who is Alex to you?"
Evidence: "Alex appeared in 4 memories this month."
```

```text
Chapter candidate: "Job transition"
Evidence: "7 records mention interview, resume, manager, and moving schedule."
```

Evidence display can be compact, but it must exist.

## 8. Confidence Rules

Confidence should drive UX, not just storage.

| Confidence | UX |
| --- | --- |
| high | Show suggestion in normal surface |
| medium | Show in review/debug or lower priority |
| low | Do not bother user; keep as internal signal |
| sensitive | Apply stricter threshold and notification policy |

Never show low-confidence sensitive claims as if they are facts.

## 9. Review Surfaces

V6 should have review points:

- Home question cards.
- Entity detail "Help Mory understand" row.
- Memory detail suggestion section.
- Settings review log.
- Developer/debug intelligence queue.

The user should not need to enter a giant review inbox for daily use.

## 10. Dismissal Semantics

Dismissal is meaningful.

Dismissal options:

- Not now.
- Do not ask again for this item.
- This is wrong.
- This topic is sensitive.
- Show less like this.

Each should write different preference or graph state.

## 11. Undo And Audit

V6 should preserve:

- When an AI-derived suggestion was created.
- What evidence produced it.
- Whether user accepted/rejected/dismissed it.
- What graph delta was applied.
- Whether it can be reverted.

The user-facing UI can stay simple; the data model should be audit-ready.

## 12. Privacy Copy Requirements

Settings should answer:

- What is processed on-device?
- What may be sent to cloud AI?
- Which notification types are enabled?
- Whether notification previews include memory content.
- Whether voice refinement is automatic.
- Whether sensitive topics can generate questions.

Copy should be plain, not legalistic.

## 13. Failure Behavior

If AI fails:

- User source record remains saved.
- Job is marked failed/retryable.
- Home does not show broken cards.
- Notification is not sent.
- Debug surface shows cause.

Failure should degrade to a quiet archive, not a broken experience.

## 14. Acceptance Criteria

- Inferred and confirmed data are stored separately.
- All accepted graph/profile changes pass through `GraphDelta` or equivalent policy.
- User can reject or dismiss suggestions.
- Voice refinement preserves original material.
- Settings explain local/cloud AI behavior.
- Low-confidence sensitive suggestions do not surface aggressively.
