# 状态、调试和用户可见性

Mory 当前最大的问题之一，是很多能力存在，但用户和产品负责人看不见状态。

## 用户应该能看见什么

用户不需要看到所有技术细节，但至少需要知道：

- 这条记忆是否保存成功。
- AI 是否正在分析。
- AI 是否分析完成。
- 分析失败后能不能重试。
- 有没有需要自己确认的问题。
- 哪些人物画像或关系是 Mory 推断的。
- 哪些内容来自手记建议或外部分享。
- 哪些通知是系统主动推荐的。

## 开发者 Debug 应该能看见什么

开发者需要能追踪更细的链路：

- Capture draft 里到底有什么。
- 每种卡片 recipe 和 size 是否能正确展示。
- 响应式 masonry 列数、object metrics、placement、overflow、occupancy 是否合理。
- composer/detail/debug 下卡片 role、runtime state 和 actions 是否一致。
- Journaling bundle 收到了哪些 evidence。
- Share Extension 是否成功写入共享容器。
- 外部导入 item 是否 pending、imported 或 failed。
- Context Pack 包含了哪些历史证据，丢弃了哪些。
- Analysis request 和 response 的结构。
- GraphDelta proposal 的状态。
- 通知 intent 的生成和投递状态。
- 后台 trigger、operation run、operation event 的执行状态。
- 登录 token 和 401 恢复状态。

## 当前已有的可见面

| 位置 | 能看什么 | 当前问题 |
| --- | --- | --- |
| 新建记忆页 | 草稿卡片、compact masonry board、输入内容和保存错误 | 来源和后续分析状态不够明显。 |
| 记忆详情 | 保存后的记忆内容和 arrangement-driven board | AI 分析过程和证据来源仍需强化。 |
| People 页面 | 人物和画像 | 证据和用户纠错入口还需更清晰。 |
| Insights 页面 | 反思、章节、问题和用户可读的智能产出 | 信息架构仍需从“审核后台”收敛成复盘入口。 |
| Settings | 权限、外部捕获、通知等 | 太多状态仍偏开发者理解。 |
| Debug Center | 详细诊断 | 普通用户不会进入，也不该依赖它。 |
| Card Debug | 四层卡片健康度、类型目录、Masonry Policy、Visual Recipes、Masonry Board Lab、Card States & Actions、压力 fixtures | 已是卡片/布局验收面板，但不是正式用户状态页。 |
| Notification Management | 通知队列、历史、去重、错误、偏好和 push metrics | 已统一通知状态，但不解释所有后台任务。 |
| Background Operations | 后台 run/event、job、pipeline status、push state | 已有统一后台调试页；日志是 owner-scoped JSON/UserDefaults 诊断状态，还不是面向普通用户的状态页。 |

## 当前最该补的产品状态页

建议优先做一个面向用户或高级用户的“智能状态”页面，展示：

- 最近几条记忆的分析状态。
- 正在等待用户确认的问题。
- 最近 AI 生成的 proposal。
- 分析失败和可重试项。
- Journaling / Share 最近导入记录。
- Self Profile 和 Person Profile 的更新时间。

这个页面不需要美化，但需要让人知道系统有没有正常运转。

## Debug 和正式 UI 的边界

Debug 页面可以显示原始 JSON、trace、payload、confidence、内部 ID。

正式 UI 应该显示：

- “来自手记建议”
- “来自分享”
- “Mory 推断”
- “你已确认”
- “需要确认”
- “分析失败，可重试”

不要把 Debug 当作用户状态页。Debug 是排错工具，正式 UI 才是用户体验。

## 为什么这件事重要

Mory 的价值来自长期信任。用户必须知道：

- Mory 记住了什么。
- Mory 为什么这样理解。
- 自己能不能纠正。
- 纠正后会不会真的影响后续分析。

如果这些状态不透明，功能越多，用户越容易觉得不可控。
