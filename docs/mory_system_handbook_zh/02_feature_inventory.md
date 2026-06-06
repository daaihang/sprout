# 功能清单和完成度

这份清单按用户能感知到的功能来写，不按代码模块来写。

## 新建记忆

| 能力 | 现在能不能用 | 当前说明 |
| --- | --- | --- |
| 输入文字 | 能用 | 用户直接写正文，保存后进入普通分析链路。 |
| 添加照片 | 能用 | 照片会成为记忆附件，可参与本地处理和后续 AI 分析。 |
| 添加视频 | 已接入 | 可以从图库导入并作为媒体保存，记录卡片已有首帧预览；视频理解和播放器体验还需要继续做。 |
| 添加语音 | 已接入 | 语音可转文字，后续需要更明确区分原文、转写、AI 润色。 |
| 添加链接 | 能用 | 链接作为附件保存，可用于后续分析。 |
| 添加地点 | 能用 | 地点可来自用户选择、上下文采集或手记建议。 |
| 添加天气 | 能用 | 天气作为上下文，不是核心记忆内容。 |
| 添加音乐 | 能用 | 音乐可作为上下文卡片，手记建议可能带来多首歌。 |
| 添加 todo | 已接入 | 可记录待办型内容，后续还需和提醒/任务关系明确。 |
| 添加心情 | 已接入 | 已有结构化 mood/affect，但可视化和纠错还不完整。 |
| 添加问答 | 已接入 | Reflection prompt 可以变成问答卡，用于更结构化记录。 |
| 添加人物上下文 | 已接入 | 联系人和人物上下文可以保存，但不会自动合并为真实人物实体。 |
| 卡片排布 | 可用 | 新建页和详情页使用同一套 arrangement 语义：visual recipe、order、stack/group、贴纸挂点、rotation/nudge/zIndex；瀑布流 frame 运行时派生。 |

## 卡片和排布

卡片不是新的事实模型，而是用户表达层。当前规则是：

- `MemoryCardArrangement` 保存视觉排布，不写进 `Artifact.metadata`。
- 底层是固定列宽瀑布流：列数由可用宽度决定，每张卡片固定列宽、自适应高度。
- `MemoryCardObjectMetrics` 只在渲染时从 recipe + density + column width 派生物件尺寸和文本详略，不持久化。
- `Card Debug` 用来验收类型、density、masonry 布局、状态和动作，不等同于正式 UI。

## Apple Journaling Suggestions

Journaling Suggestions 不是一种新的记忆类型。它是系统给 Mory 的一组上下文证据，最后仍然进入普通新建记忆。

| 系统建议类型 | 当前处理方式 | 状态 |
| --- | --- | --- |
| 地点 | 转成地点上下文 | 可用 |
| 多首歌 | 每首歌应成为音乐上下文 | 已接入，仍需真机验证 |
| Podcast / 媒体 | 转成媒体上下文 | 已接入 |
| 照片 | 转成图片附件 | 可用 |
| 视频 | 转成视频附件 | 已接入 |
| Live Photo | 作为单个 Live Photo artifact，内部保留 still + paired video | 已接入，仍需真机验证 |
| 运动 / 活动 | 转成活动上下文或文档证据 | 已接入，展示不完整 |
| 联系人 | 转成人物上下文证据 | 已接入，不自动合并人物 |
| Reflection prompt | 转成问答卡 | 已接入 |
| StateOfMind | 转成高可信情绪证据 | 已接入 |
| Event poster | 转成事件上下文 | 已接入，展示不完整 |

## Share / External Capture

| 来源 | 预期体验 | 当前状态 |
| --- | --- | --- |
| 分享文本 | 从系统分享进入 Mory，打开新建记忆并预填文本 | 已接入 |
| 分享 URL | 进入新建记忆并形成链接卡 | 已接入 |
| 分享图片 | 进入新建记忆并形成图片卡 | 已接入，需真机验收 |
| App Intent | 从 Siri/Shortcuts 触发记录草稿 | 已接入 |
| 恢复 Inbox | 如果跳转失败，仍能在 App 内找回 | 已接入 |

## AI 和长期记忆

| 能力 | 当前状态 | 解释 |
| --- | --- | --- |
| Self Profile | 已接入 | 有用户自己的档案结构，但缺少清晰产品页面。 |
| Person Profile | 已接入 | 有人物画像和关系字段，但证据展示还不够。 |
| Entity Resolution | 已接入 | 能做实体解析和纠错，但高风险合并仍需要用户确认。 |
| Analysis Context Pack | 可用 | 分析前会构造长期上下文包。 |
| Analysis | 可用 | 新记忆分析主链路已经统一为 Analysis。 |
| GraphDelta proposal | 已接入 | AI 结论先作为 proposal，用户可 review。 |
| Reflection / Arc | 已接入 | 能生成反思和故事线，但产品解释还要继续加强。 |
| Clarification Question | 已接入 | Mory 可以向用户提问以补充长期记忆。 |

## 通知和后台

| 能力 | 当前状态 | 解释 |
| --- | --- | --- |
| 每日问题 | 已接入 | 目前更多依赖 App 生命周期和本地调度。 |
| 本地通知 | 已接入 | 可用于提醒和回访。 |
| 远程推送 | 已接入 | 服务端和客户端都有基础链路。 |
| BGTask | 已接入 | 可用于后台刷新和处理，但真机调度不可精确控制。 |
| 分析完成提醒 | 已接入 | 还需要更明确的用户体验和时机策略。 |
| 统一通知管理 | 已接入 | `NotificationOrchestrator` 是唯一生成/去重/policy/routing 入口，系统通知只保留 dailyQuestion、analysisReady、reflectionReady、debugTest。 |
| 后台运行记录 | 可用基础版 | `BackgroundOperationOrchestrator` 已接收启动、前台、BGTask、silent push、pipeline completed、APNs token、URLSession 触发，并记录运行日志；日志是 owner-scoped JSON/UserDefaults 诊断状态，不进入 SwiftData 记忆事实库。 |

## 订阅和付费

当前还没有正式面向用户的付费墙。未来更适合收费或限额的部分包括：

- 云端 AI 分析次数。
- 长期 Context Pack 深度。
- 多模态导入和批量分析。
- 高级人物画像、关系变化、Arc/Reflection。
- 历史搜索和长期趋势。
- 高级导出、回顾报告、提醒策略。

这些边界应该由服务端最终执行，不能只靠 App UI 隐藏按钮。
