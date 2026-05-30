# 数据和 AI 怎么工作

这一页用人话解释 Mory 的数据链路。

## 一条记忆从哪里来

Mory 的记忆可以来自这些入口：

- App 内手动新建。
- 拍照、相册、视频、录音。
- 链接、地点、天气、音乐、todo。
- Apple Journaling Suggestions。
- 系统 Share Extension。
- App Intent / Shortcuts。
- 未来可能还有 Health、Fitness、Calendar 等来源。

无论入口是什么，最终都应该走向同一个目标：形成一条普通记忆，而不是产生很多互不兼容的特殊记录类型。

## 新建前的数据形态

在用户还没保存时，Mory 使用“草稿”来承载内容。草稿里可以包含：

- 正文文字。
- 图片、视频、音频、链接等附件。
- 地点、天气、音乐等上下文。
- mood / affect 情绪证据。
- prompt-answer 问答。
- person context 人物上下文。
- 来源信息，例如来自手记建议、分享、手动输入。

草稿的作用是让用户能继续编辑。它还不是长期记忆事实。

## 保存后的数据形态

用户保存后，Mory 会把草稿拆成几类长期数据：

| 数据 | 用途 |
| --- | --- |
| `RecordShell` | 这条记忆本身，包含时间、正文、来源、上下文和 artifact IDs。 |
| `Artifact[]` | 图片、视频、音频、链接、音乐、地点、天气、todo、文档等内容事实。 |
| `ArtifactSemanticDigest[]` | OCR、caption、label、transcript、duration、dimensions、local identifier 等结构化媒体语义。 |
| `MemoryCardArrangement` | 用户视觉排布，包括 visual recipe、size、order、stack/group、grid placement、rotation/nudge/zIndex。 |
| `AffectSnapshot[]` | 用户或系统提供的心情和语气证据。 |
| 人物/地点/主题实体 | Mory 从内容里识别出的长期对象。 |
| 用户自己的档案 | 关于“我”的长期信息、偏好、目标、边界。 |
| 人物画像 | 关于某个人和用户关系的长期信息。 |
| AI proposal | AI 建议，但还不一定是可信事实。 |
| Arc / Reflection | 跨时间的故事线和反思。 |

## AI 什么时候介入

| 时机 | AI 或智能处理做什么 | 会不会挡住用户 |
| --- | --- | --- |
| 导入图片后 | 本地提取图片相关线索，后续参与云端分析 | 不应该挡住保存 |
| 录音结束后 | 转写、可能润色或结构化 | 可能影响正文，需要保护用户编辑 |
| 保存记忆后 | 默认只写入 `.notScheduled`，不自动代表 AI 已启动 | 不挡住保存 |
| 显式触发分析后 | 构造上下文并调用 Analysis | 不应该挡住保存 |
| 分析完成后 | 保存分析结果、proposal、问题、反思 | 不应该静默覆盖用户确认内容 |
| 每日问题 | 根据近期记忆和画像生成问题 | 不应该过度打扰 |
| 通知准备 | 决定是否提醒用户回顾或回答 | 需要明确节奏 |

## Analysis 做什么

显式触发分析后，Mory 不只是把这条记录发给 AI。它会先构造一个上下文包，包含：

- 当前这条记忆。
- 这条记忆的 ordered artifacts。
- 这条记忆的 ordered semantic digests。
- 用户自己的档案。
- 相关人物、地点、主题。
- 相关历史记忆。
- 相关 Arc 和 Reflection。
- 过去的纠错和用户确认。
- 隐私和预算限制。

`MemoryCardArrangement` 不进入 Analysis 输入。它是用户视觉表达，不是语义事实。

然后调用服务端 `/api/analyze`。返回结果再被拆成：

- 当前记忆的分析摘要。
- 情绪和语气建议。
- 图谱变化建议。
- 人物或 profile 更新建议。
- 需要用户确认的问题。
- Reflection / Arc 候选。

## AI 会不会直接改用户输入

原则上不应该。

Mory 的目标是 proposal-first：AI 先提出建议，用户确认后再变成更可信的长期事实。

但当前仍有几个需要继续加强的点：

- 语音转写或润色不能静默覆盖用户已编辑正文。
- 人物合并、关系变化、敏感画像不能直接写成事实。
- 手记建议的 StateOfMind 可以作为高可信证据，但仍应该保留来源。

## 来源追踪为什么重要

同样一句“今天很烦”，可能来自：

- 用户自己点选心情。
- 语音 AI 推断。
- Apple Journaling Suggestions 的 StateOfMind。
- 后续 Health/Fitness 的心情记录。
- AI 从文本里猜出来。

这些来源可信度不同，也应该在 UI 和数据里区分。否则未来长期分析会混乱，用户也无法知道 Mory 为什么得出某个结论。

当前最需要补强的是：

- 每次导入的 session 标识。
- 每个证据的来源类型。
- Journaling suggestion 的来源时间和证据 ID。
- 用户确认和 AI 推断的清晰分层。
