# 01. Identity And Self Profile

## 1. Problem

Mory 当前没有稳定的“我”的语义档案。文本里的“我 / 自己 / 我妈 / 我老板 / 我室友”只能被当作普通语言片段，不能稳定参与长期分析。

这会导致三个问题：

- AI 分析不知道用户本人是什么身份、长期目标、表达习惯和敏感边界。
- 人物关系只能围绕单条记忆猜测，不能形成稳定关系图。
- “舍友”“同事”“老板”这类角色标签容易被误建成一个固定人物。

v7 要新增 `SelfProfile`，把用户本人变成长期智能的中心实体。

## 2. Domain Model

```swift
struct SelfProfile: Codable, Hashable, Sendable {
    var id: UUID
    var selfEntityID: UUID
    var displayName: String?
    var aliases: [String]
    var pronouns: [String]
    var lifeRoles: [SelfRole]
    var longTermGoals: [SelfGoal]
    var preferences: [SelfPreference]
    var sensitiveBoundaries: [SensitiveBoundary]
    var importantRelationshipIDs: [UUID]
    var commonPlaceIDs: [UUID]
    var commonThemeIDs: [UUID]
    var expressionPatterns: [ExpressionPattern]
    var privacyMode: SelfProfilePrivacyMode
    var updatedAt: Date
}
```

`selfEntityID` 是 graph 里的特殊 entity。它不是普通 person，也不能被 AI 自动 merge 到其他人。

## 3. Field Semantics

| Field | Purpose | Source | Cloud policy |
| --- | --- | --- | --- |
| `aliases` | 解析“我/自己/昵称/英文名”等 self reference | onboarding, user correction, local rules | snippets only if needed |
| `lifeRoles` | 学生、创业者、伴侣、子女、管理者等 | user input, repeated memory evidence | summarized |
| `longTermGoals` | 找工作、搬家、修复关系、健康目标等 | user input, repeated decisions | opt-in summarized |
| `sensitiveBoundaries` | 不分析/不通知/不上传的主题 | user controls | local only |
| `expressionPatterns` | “我真服了”常是吐槽还是认真烦躁 | affect correction, voice/text history | compact signal only |
| `importantRelationshipIDs` | 高频/高重要人物 | profile ranking | id + summary only |

## 4. Self Reference Resolution

`SelfReferenceResolver` runs before entity extraction writes to graph.

Inputs:

- current text / transcript,
- `SelfProfile.aliases`,
- local language rules,
- relationship patterns (`我妈`, `我老板`, `我的室友`),
- prior correction events.

Outputs:

- `selfMention`: direct user self mention,
- `ownedRoleMention`: a role tied to self, such as `my roommate`,
- `ambiguousRoleMention`: role cannot be resolved yet,
- `notSelfMention`: explicitly someone else.

Example:

```text
Input: "我和舍友又因为水电费吵了一架"
Output:
  selfMention -> SelfProfile.selfEntityID
  "舍友" -> role mention, ambiguous group candidate, not a concrete person yet
```

## 5. Privacy Boundary

`SelfProfile` is local-first by default.

Cloud Analyze may receive:

- minimal `self_context_brief`,
- non-sensitive goals if enabled,
- expression pattern hints needed for tone interpretation,
- stable IDs that cannot identify real-world identity outside Mory.

Cloud Analyze must not receive:

- full self profile,
- sensitive boundaries,
- raw correction history,
- full relationship graph,
- private user notes unless explicitly included as evidence.

## 6. User Controls

Required domain actions:

| Action | Effect |
| --- | --- |
| `markAsMe(entityID)` | converts an entity into a self alias candidate or links mention to self |
| `notMe(entityID)` | writes negative evidence so future resolver does not map it to self |
| `updateSelfAlias(alias)` | changes local first-person alias list |
| `hideFromAI(field)` | marks a self profile field as local-only |
| `forgetSelfSignal(signalID)` | removes one derived self-profile signal and schedules recompute |

All controls write `CorrectionEvent`, not just UI state.

## 7. Acceptance Criteria

- “我/自己/我的...” references resolve before generic entity creation.
- Role labels tied to user do not become concrete people without evidence.
- Self profile can be inspected and edited in debug UI before public UI polish.
- Analysis receives a bounded `self_context_brief`, not the raw full profile.
- User correction prevents repeated self-reference mistakes.
