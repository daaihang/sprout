# 05. Structured Mood And Affect

## 1. Problem

Current mood is too thin: a free-text mood plus optional intensity cannot support long-term affect trends or tone ambiguity such as:

- “我真服了” as joking complaint,
- real irritation,
- exhausted venting,
- sarcasm,
- nervous excitement.

v7 mood must support user chip input, AI analysis, speech/text uncertainty, Journaling Suggestions, and user correction.

## 2. Model Choice

v7 uses a layered affect model:

| Layer | Purpose |
| --- | --- |
| VAD/PAD vector | numeric trend/search foundation: valence, arousal, dominance/control |
| PANAS-style chips | quick user input for positive/negative affect words |
| Emotion labels | product-readable tags such as irritated, relieved, playful |
| Tone hints | joking, sarcastic, venting, serious, tender, uncertain |
| Appraisal | why the feeling exists: agency, control, certainty, goal alignment, social safety |
| Evidence/source | user selected, AI inferred, voice prosody, Journaling Suggestion, corrected |

## 3. AffectSnapshot

```swift
struct AffectSnapshot: Codable, Hashable, Sendable {
    var id: UUID
    var recordID: UUID
    var valence: Double?      // -1.0 negative ... 1.0 positive
    var arousal: Double?      // 0.0 calm ... 1.0 activated
    var dominance: Double?    // 0.0 low control ... 1.0 high control
    var intensity: Double?    // 0.0 weak ... 1.0 strong
    var labels: [AffectLabel]
    var toneHints: [ToneHint]
    var appraisal: AffectAppraisal?
    var sources: [AffectEvidenceSource]
    var confidence: Double?
    var userConfirmed: Bool
    var createdAt: Date
}
```

`RecordShell.userMood` stays for migration/backward compatibility, but new code should read `AffectSnapshot`.

## 4. Appraisal

```swift
struct AffectAppraisal: Codable, Hashable, Sendable {
    var agency: AppraisalAgency?          // self, other, situation, unknown
    var certainty: Double?                // unclear ... certain
    var control: Double?                  // low control ... high control
    var goalAlignment: GoalAlignment?     // blocked, neutral, supported
    var socialSafety: Double?             // unsafe ... safe
    var novelty: Double?                  // familiar ... surprising
    var copingPotential: Double?          // cannot handle ... can handle
    var targetEntityIDs: [UUID]
    var targetThemeIDs: [UUID]
}
```

This is the layer that helps distinguish playful complaint from real distress.

## 5. Sources

```swift
enum AffectEvidenceSource: String, Codable, Sendable {
    case userSelected
    case userFreeform
    case aiInferredText
    case aiInferredImage
    case voiceProsody
    case journalSuggestionStateOfMind
    case healthOrWorkoutContext
    case userCorrected
}
```

Apple Journaling Suggestions `StateOfMind` should be mapped as evidence, not treated as a complete Mory mood model.

## 6. User Input Chips

Initial chip groups:

| Quadrant | Examples |
| --- | --- |
| high valence + high arousal | excited, inspired, proud, curious |
| high valence + low arousal | calm, grateful, relieved, warm |
| low valence + high arousal | irritated, anxious, tense, overwhelmed |
| low valence + low arousal | tired, sad, lonely, numb |
| tone | joking, sarcastic, venting, serious, uncertain |

The UI can stay simple, but the saved data must be structured.

## 7. Joking vs Irritated

Example playful complaint:

```json
{
  "valence": 0.1,
  "arousal": 0.6,
  "dominance": 0.7,
  "labels": ["amused", "mock_frustrated"],
  "toneHints": ["joking", "playful"],
  "appraisal": { "socialSafety": 0.85, "control": 0.7 },
  "confidence": 0.55
}
```

Example real irritation:

```json
{
  "valence": -0.7,
  "arousal": 0.8,
  "dominance": 0.25,
  "labels": ["irritated", "stressed"],
  "toneHints": ["serious", "venting"],
  "appraisal": { "goalAlignment": "blocked", "control": 0.2 },
  "confidence": 0.62
}
```

If confidence is low or tone is ambiguous, the model should ask for user confirmation.

## 8. AffectCorrectionEvent

User correction examples:

- “这是开玩笑”
- “是真的烦”
- “只是吐槽”
- “不是焦虑，是累”
- “不要分析这类语气”

Corrections update:

- current snapshot trust,
- expression pattern in `SelfProfile`,
- future context pack correction signals,
- model evaluation set.

## 9. Acceptance Criteria

- Mood can be numeric, multi-label, and source-aware.
- Voice/text ambiguity can be represented without false certainty.
- User correction feeds future analysis.
- Journaling Suggestions mood evidence can be stored without replacing user input.
- Long-term charts use vector fields, not label strings.
