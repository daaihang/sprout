# 16. Context Pack Examples

## 1. Purpose

This document makes `AnalysisContextPack` concrete. v7 should be judged by whether it can build these packs with clear evidence and privacy decisions.

## 2. Example: Job Change Decision

Current memory:

```text
今天收到新 offer，有点兴奋但也怕离开现在团队会后悔。
```

Retrieval signals:

- themes: job, decision, uncertainty,
- people: current manager, recruiter,
- affect: excited + anxious,
- open arcs: job search,
- prior memories: interviews, burnout, salary notes.

Context pack:

| Block | Example |
| --- | --- |
| self brief | user values autonomy and stable routine |
| related memories | last three job/interview records |
| related profiles | manager, recruiter |
| related arcs | job search arc summary |
| prior reflections | “work stress spikes before deadlines” |
| corrections | user previously corrected “excited” to “nervous excitement” |

Expected AI behavior:

- no generic career advice,
- summarize decision pattern,
- ask outcome/status question later,
- create `decisionStatus` proposal, not fact.

## 3. Example: Relationship Change

Current memory:

```text
和 Alex 吃饭，感觉最近没以前那么尴尬了。
```

Risk:

- multiple Alex people,
- relationship changed but evidence may be thin.

Context pack:

- candidate Alex entities,
- not-same negative evidence,
- recent co-occurring places,
- prior emotional pattern with each Alex,
- relationship profile summary,
- relevant memories where “尴尬” appeared.

Expected AI behavior:

- if identity ambiguous, ask which Alex,
- if identity clear, propose relationship-change signal,
- update PersonProfile only as proposal.

## 4. Example: Roommate Ambiguity

Current memory:

```text
舍友又忘记交水电费了，我真服了。
```

Context pack:

- `SelfProfile`,
- role label `舍友`,
- possible people Lily/Max,
- apartment/place profile,
- prior utility bill memories,
- affect correction history for “我真服了”.

Expected AI behavior:

- do not create one person named “舍友”,
- create ambiguous role bucket,
- ask optional clarification,
- mark tone uncertain if no user hint.

## 5. Example: Playful Complaint

Current memory:

```text
他又迟到，我真服了哈哈。
```

Context pack:

- expression pattern: user often uses “真服了” playfully with close friends,
- affect history,
- relationship safety score,
- prior correction “this was joking”.

Expected AI behavior:

- lower confidence irritation,
- propose `toneHint.joking`,
- avoid negative relationship reflection.

## 6. Example: Journaling Suggestion

Current memory:

```text
User selects a system suggestion with photo, location, StateOfMind, and song.
```

Context pack:

- selected location evidence,
- photo OCR/labels,
- music context,
- `StateOfMind` mapped as affect evidence,
- privacy decisions for photo/person content.

Expected AI behavior:

- treat user-selected system context as evidence,
- still ask if person identity is ambiguous,
- do not infer more mood than StateOfMind supports.

## 7. Example: Sensitive Topic

Current memory:

```text
关于健康检查结果的担心。
```

Context pack:

- local-only health-sensitive flag,
- no raw historical health records in cloud payload,
- maybe local summary if user allows.

Expected AI behavior:

- cloud call may be blocked or redacted,
- notification should be in-app only,
- no lock-screen sensitive preview.

## 8. Pack Quality Checklist

- included evidence has source ids,
- ranking explains why each item was included,
- privacy gate explains omissions,
- current record remains central,
- no raw full history dump,
- corrections are represented,
- ambiguity is preserved when unresolved.
