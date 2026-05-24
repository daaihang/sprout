# 07. UI Debug And Settings Audit

本文审计正式 UI、Debug Center、Settings 和原生功能入口。目标不是视觉评价，而是判断 UI 是否越权、是否能承载 v7 数据路径、是否把 debug fallback 当成产品主路径。

## 1. UI 总原则

- 正式 UI 负责展示、选择、确认、调用 action。
- Durable business rules 由 Domain / Repository / Infrastructure 拥有。
- Debug UI 可以更直接，但不能新增旁路语义。
- 当前阶段接受“原生 SwiftUI 接入，暂不 polish”。

## 2. 正式 UI 模块

| 模块 | 职责 | 当前状态 | 问题 |
| --- | --- | --- | --- |
| Home | 今日 board、快速浏览、系统卡片 | 可用 | HomeScreen 仍较大 |
| Capture | 新建/编辑 capture draft、cards、输入工具 | v7 功能已接入 | Composer 和 CardView 大 |
| Memories/Detail | 记忆列表、详情、编辑 | 有统一 mutation path | detail mode views 仍可继续拆 |
| People/Entities | 人物、实体、profile、merge/split | 基础入口可用 | identity correction UX 还需加强 |
| Insights | GraphDelta review、insights presentation | 已接 proposal review | apply/reject 解释性不足 |
| Settings | preferences、diagnostics、data controls | section 已拆分 | settings 与 debug 的边界需清楚 |
| Search/Timeline/Arcs/Reflections | 浏览和检索 | 基础清楚 | 后续可接更多 v8 value surfaces |

## 3. Capture UI

当前能力：

- structured mood picker。
- Journaling toolbar picker control。
- prompt/person/music/photo/video cards。
- external capture seed。
- audio/link/music/todo/location/camera sheet。

问题：

- `UnifiedCaptureComposerView` 管理过多 state。
- `CaptureCardView` 是新增 card type 的冲突热点。

解决方案：

- Composer state view model。
- Card type 分文件。
- 所有卡片保存仍走 `MemoryCaptureDraft`。

## 4. People / Identity UI

当前能力：

- Person detail。
- Person profile edit。
- Person merge/split。
- 人物管理入口。

问题：

- “联系人上下文 -> 人物实体”仍未形成正式 correction flow。
- merge/split 的证据展示和撤销体验仍基础。

解决方案：

- `IdentityReviewView`：
  - same person
  - not same
  - this is me
  - role/group
  - split evidence
- 所有选择写入 `CorrectionEvent` 或 `GraphDelta`。

## 5. Insights / Proposal Review UI

当前能力：

- GraphDelta review。
- Apply / reject / undo-reject 基础路径。

问题：

- 用户难以理解 proposal 为什么出现。
- GraphDelta operation summary 需要映射到自然语言。

解决方案：

- 提供 evidence snippets、source memory、confidence、operation preview。
- Apply 前显示影响范围。
- Reject 必须写 correction signal。

## 6. Settings UI

当前状态：

- SettingsScreen 已拆出多个 section 文件，方向良好。
- Notification preferences、permissions、privacy、data controls、capture preferences、account 已分区。
- Memory Intelligence / Platform Capture Diagnostics 有入口。

问题：

- Settings 同时承载正式偏好和开发诊断入口，需要确保 release build 下 debug visibility 受 runtimeEnvironment 控制。

解决方案：

- 正式设置只暴露用户可理解控制。
- Diagnostics 保持 internal/debug gate。

## 7. Debug Center

当前能力：

- Analysis context pack viewer。
- Affect snapshot viewer。
- Clarification questions viewer。
- Job queue / GraphDelta apply。
- Cloud intelligence debug。
- Server health。
- Semantic search debug。
- Capability/platform tests。
- Full diagnostics report。

问题：

- 多个 debug 文件仍大，特别是 `DebugFullDiagnosticsView`。
- report building、payload formatting、view state、actions 混合。

解决方案：

- 拆三层：
  - `DebugXView`
  - `DebugXViewModel`
  - `DebugXReportFormatter`
- Debug action 调用正式 repository method。

## 8. UI 越权检查

| 检查项 | 当前判断 | 建议 |
| --- | --- | --- |
| UI 是否直接写 SwiftData | 正式 Features 未发现直接 SwiftData | 保持 |
| UI 是否拥有 merge/split 规则 | 目前通过 repository mutation | 保持 |
| UI 是否生成 AI proposal | 否 | 保持 |
| Debug 是否可直连内部状态 | 是，可接受 | 需隔离 release 可见性 |
| Settings 是否混入 debug | 有 debug/diagnostics entry | 用 runtime gate 控制 |

## 9. 大 View 风险

| 文件 | 风险 | 建议 |
| --- | --- | --- |
| `CaptureCardView.swift` | 多卡片实现聚合 | card type 分文件 |
| `UnifiedCaptureComposerView.swift` | 多输入 state 聚合 | view model + sheet coordinator |
| `DebugFullDiagnosticsView.swift` | report/view/action 混合 | formatter + subviews |
| `DebugDiagnosticsView.swift` | debug hub 复杂 | route registry model |
| `HomeScreen.swift` | home data/view 聚合 | board section components |

## 10. UI 后续路线

1. 先保证所有正式入口走正确业务路径。
2. 再拆大 view 文件降低冲突。
3. 再做视觉 polish。
4. 最后做 onboarding/empty states，解释 v7 智能能力。

这符合项目原则：先完成业务代码和 debug 测试，再考虑正式 UI。
