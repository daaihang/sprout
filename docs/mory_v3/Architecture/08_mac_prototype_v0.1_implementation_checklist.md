# 08. Mac Prototype v0.1 Implementation Checklist

> 文档版本：Mac Prototype v0.1 Implementation Checklist  
> 更新时间：2026-05-13  
> 适用范围：`sprout` 当前仓库、Mac Prototype v0.1 开工执行、共享层抽离、首批工程拆分

## 1. 文档目标

这份文档不是再重复讲一遍“为什么要做 Mac prototype”，而是把上一个方案文档落成：

- 实际工程拆分顺序
- 首批文件与目录规划
- 共享层提取边界
- 第一阶段必须完成的任务
- 每一阶段的验收标准

它服务的对象是“准备真正开工的人”。

## 2. 执行原则

开始实现前，先固定四条原则：

1. 不把 Mac prototype 做成第二个完整产品端
2. 不在现有 iOS 代码里大量堆 `#if os(macOS)`
3. 先抽共享领域层，再做 Mac 工作台 UI
4. 先打通 `Artifact / Composition / Reflection`，再考虑 capture 壳细节

## 3. 总体执行顺序

正确顺序应是：

1. 建立文档与命名基线
2. 新建 Mac target 和共享目录骨架
3. 抽共享 Domain / Analysis / Networking
4. 建立 DemoData 和 Workspace 外壳
5. 做 Board / Inspector / Lists
6. 接 analyze API
7. 落 snapshot 与本地状态
8. 做结构验证与收尾

不要颠倒成：

1. 先做一堆 UI
2. 先处理登录和付费
3. 先追求 iOS/macOS 完全共用视图

## 4. 阶段拆分

建议拆成 5 个执行阶段。

### 4.1 Phase A: Project Skeleton

目标：

- 让 Mac Prototype target 能跑起来
- 让共享层目录存在
- 让最小工作台页面出现

### 4.2 Phase B: Shared Domain Extraction

目标：

- 把未来要长期稳定的领域对象抽出来
- 不再让 Mac 直接依赖现有 iOS View 层的数据拼装逻辑

### 4.3 Phase C: Workspace UI

目标：

- 做出 Boards / Records / Artifacts / Reflections 的工作台结构
- 建立 inspector 模式

### 4.4 Phase D: Analysis Loop

目标：

- 打通真实后端分析接口
- 显示并保存 analysis / reflection snapshots

### 4.5 Phase E: Validation And Handoff

目标：

- 形成结构结论
- 输出回迁 iOS 的改造顺序

## 5. 仓库目录建议

建议不要直接把所有新代码塞进 `sprout/sprout/`。

推荐目标结构：

```text
sprout/
  Shared/
    Domain/
    Analysis/
    Networking/
    Persistence/
    DemoData/
    Support/
  MacPrototype/
    App/
    Workspace/
    Boards/
    Inspectors/
    Sidebar/
    Lists/
    Reflections/
    Debug/
  iOSApp/
    Existing iOS-specific migration target later
```

注意：

- `iOSApp/` 在第一步不一定真的立即搬文件
- 但目录层面要预留未来拆分意图

## 6. 首批必须创建的目录

第一天建议至少创建这些目录：

```text
sprout/Shared/Domain
sprout/Shared/Analysis
sprout/Shared/Networking
sprout/Shared/Persistence
sprout/Shared/DemoData
sprout/Shared/Support
sprout/MacPrototype/App
sprout/MacPrototype/Workspace
sprout/MacPrototype/Sidebar
sprout/MacPrototype/Boards
sprout/MacPrototype/Inspectors
sprout/MacPrototype/Lists
sprout/MacPrototype/Reflections
sprout/MacPrototype/Debug
```

## 7. 新 target 建议

## 7.1 Target 目标

建议新增：

- `MoryMacPrototype` 或 `SproutMacPrototype`

建议命名更偏产品而不是平台，例如：

- `MoryPrototype`

但 target 名称应足够清楚，避免和现有 iOS 主 app 混淆。

## 7.2 Bundle 与环境

原型期建议：

- 独立 bundle id
- 独立 local storage
- 可单独配置后端 base URL

目的：

- 不污染现有 iOS app 的配置和运行数据

## 7.3 Config

建议为原型单独准备：

- `Prototype.xcconfig`
- `Prototype-Local.xcconfig`

至少支持：

- API base URL
- debug auth mode
- feature toggles

## 8. 共享层抽离策略

## 8.1 第一批应该抽走什么

先抽“领域定义”和“纯逻辑”，不要先抽复杂 UI。

第一批适合抽离的内容：

- artifact 相关 struct / enum
- composition 相关 struct / enum
- reflection snapshot 相关 struct
- analyze request / response model
- endpoint / API client
- demo fixtures

## 8.2 第一批不要抽什么

这些不应该在第一批动：

- `ContentView`
- `BottomToolbarView`
- `CameraView`
- `SpeechRecognizer`
- 订阅 paywall UI
- 当前 iPhone 专用 pager / gesture 体系

## 8.3 为什么

因为当前最需要被验证的是领域边界，而不是复用尽可能多的旧 UI。

## 9. Shared/Domain 首批文件清单

建议第一版至少有以下文件：

### 9.1 ArtifactKind.swift

职责：

- 定义 artifact 的一级类型

建议内容：

- `text`
- `photo`
- `audio`
- `music`
- `link`
- `location`
- `weather`
- `todo`
- `personMention`
- `decisionNote`

### 9.2 Artifact.swift

职责：

- 定义 artifact 核心结构

建议字段：

- `id`
- `kind`
- `title`
- `summary`
- `textContent`
- `createdAt`
- `updatedAt`
- `metadata`

### 9.3 RecordShell.swift

职责：

- 定义 record 的 capture shell 角色

建议字段：

- `id`
- `createdAt`
- `updatedAt`
- `rawText`
- `captureSource`
- `artifactIDs`
- `userMood`
- `userIntensity`

### 9.4 Board.swift

职责：

- 定义 board 展示上下文

### 9.5 Composition.swift

职责：

- 定义 composition 容器

### 9.6 CompositionItem.swift

职责：

- 定义 board 上可视对象

建议字段：

- `targetType`
- `targetID`
- `widthUnits`
- `heightUnits`
- `zIndex`
- `rotation`
- `scale`
- `positionHint`

### 9.7 ReflectionSnapshot.swift

职责：

- 定义高层 reflection

### 9.8 RecordAnalysisSnapshot.swift

职责：

- 定义记录级结构化分析结果

## 10. Shared/Analysis 首批文件清单

### 10.1 AnalyzeRequestBuilder.swift

职责：

- 把 `RecordShell + [Artifact]` 打包成后端可接受的 aggregate request

### 10.2 AnalyzeResponseMapper.swift

职责：

- 把后端返回结果映射为 `RecordAnalysisSnapshot`

### 10.3 ReflectionBuilder.swift

职责：

- 从 analysis result 和 sources 构建本地 reflection snapshot

第一版可以先做非常轻的实现。

## 11. Shared/Networking 首批文件清单

### 11.1 PrototypeAPIClient.swift

职责：

- 统一封装请求
- 调用 analyze API

### 11.2 PrototypeEndpoint.swift

职责：

- 管理 endpoint path

### 11.3 PrototypeAPIConfig.swift

职责：

- base URL
- auth mode
- request timeout

### 11.4 PrototypeAuthProvider.swift

职责：

- 给 prototype 提供最小认证能力

建议第一版只支持：

- preview mode
- development stub token

## 12. Shared/Persistence 首批文件清单

第一版不必一开始就做复杂 SwiftData schema 迁移。  
可以先用轻量本地 store 或 in-memory，再逐步接入正式 persistence。

建议首批文件：

### 12.1 PrototypeWorkspaceStore.swift

职责：

- 保存当前 workspace 状态

### 12.2 PrototypeSnapshotStore.swift

职责：

- 保存 analysis / reflection snapshots

### 12.3 PrototypeSelectionStore.swift

职责：

- 当前选中对象
- 当前激活 board
- 当前 filter 条件

## 13. Shared/DemoData 首批文件清单

这是 v0.1 极重要的一层，不要省略。

建议文件：

### 13.1 DemoArtifacts.swift

提供若干高质量 demo artifacts。

### 13.2 DemoRecords.swift

提供若干 record shells。

### 13.3 DemoBoards.swift

提供 board 与 composition fixtures。

### 13.4 DemoReflections.swift

提供样例 reflection。

### 13.5 DemoScenarios.swift

按场景组织 demo 数据，例如：

- relationship arc
- relocation phase
- work decision phase

## 14. MacPrototype/App 首批文件清单

### 14.1 MacPrototypeApp.swift

职责：

- app entry
- 注入 store / config / demo workspace

### 14.2 PrototypeRootView.swift

职责：

- 根工作台容器

## 15. MacPrototype/Workspace 首批文件清单

### 15.1 WorkspaceView.swift

职责：

- 三栏或四区主布局

### 15.2 WorkspaceRoute.swift

职责：

- 当前导航路由

### 15.3 WorkspaceState.swift

职责：

- 当前 UI 级工作台状态

## 16. MacPrototype/Sidebar 首批文件清单

### 16.1 SidebarView.swift

显示：

- Boards
- Records
- Artifacts
- Reflections
- Debug

### 16.2 SidebarItem.swift

定义侧边栏项目类型。

## 17. MacPrototype/Boards 首批文件清单

### 17.1 BoardWorkspaceView.swift

主 board 画布。

### 17.2 CompositionCanvasView.swift

承载 composition item 排布。

### 17.3 CompositionItemView.swift

渲染单个 item。

### 17.4 BoardToolbarView.swift

放：

- layout mode
- zoom
- reset
- analyze selected

## 18. MacPrototype/Inspectors 首批文件清单

### 18.1 InspectorPane.swift

右侧统一 inspector 外壳。

### 18.2 RecordInspectorView.swift

### 18.3 ArtifactInspectorView.swift

### 18.4 CompositionItemInspectorView.swift

### 18.5 ReflectionInspectorView.swift

## 19. MacPrototype/Lists 首批文件清单

### 19.1 RecordsListView.swift

### 19.2 ArtifactsListView.swift

### 19.3 ReflectionsListView.swift

### 19.4 BoardsListView.swift

这些列表的目的不是 polish，而是快速看清对象。

## 20. MacPrototype/Reflections 首批文件清单

### 20.1 ReflectionViewer.swift

### 20.2 AnalysisResultView.swift

### 20.3 SourceReferenceListView.swift

## 21. MacPrototype/Debug 首批文件清单

### 21.1 AnalyzeDebugPanel.swift

职责：

- 显示 request payload
- 触发 analyze
- 显示 response

### 21.2 PrototypeConsoleView.swift

职责：

- 打印 mapping / persistence / selection logs

### 21.3 FixtureSwitcherView.swift

职责：

- 切换 demo scenario

## 22. UI 实现顺序

正确顺序建议如下：

1. `PrototypeRootView`
2. `SidebarView`
3. `WorkspaceView`
4. `BoardWorkspaceView`
5. `InspectorPane`
6. `ArtifactsListView / RecordsListView`
7. `AnalyzeDebugPanel`

这样做的原因是：

- 先把工作台骨架立起来
- 再逐步填充内容
- 避免先写孤立页面

## 23. 数据流建议

v0.1 建议采用非常明确的数据流：

1. demo fixtures 或 local store 生成 workspace state
2. sidebar 选择 route
3. board / list 显示对象
4. inspector 观察当前 selection
5. analyze debug panel 基于 selection 触发请求
6. response mapper 写入 snapshot store
7. UI 自动更新

不要一开始做过度复杂的全局状态系统。

## 24. 首批复用现有代码的建议

可以复用的思路：

- 复用后端 URL 配置思路
- 复用 auth session 中开发态 token 的概念
- 参考现有 `RecordMapper` 做“聚合 -> 投影”的过渡设计

谨慎复用的部分：

- iOS View 层
- `UIImage` 驱动的卡片实现
- 依赖 UIKit 的手势与分页体系

一句话：

复用“逻辑与概念”，不要强行复用“移动端壳”。

## 25. 第一阶段任务单

以下任务适合第一轮直接开工。

### Task 1

新增 `MacPrototype` target 和基础目录结构。

验收：

- target 可编译
- 能显示空白 root workspace

### Task 2

创建 Shared domain skeleton。

验收：

- `Artifact`
- `RecordShell`
- `Composition`
- `CompositionItem`
- `RecordAnalysisSnapshot`
- `ReflectionSnapshot`

这些类型能编译并被预览数据使用。

### Task 3

建立 demo scenarios。

验收：

- 至少 3 组 scenario
- 每组有 records、artifacts、board、reflections

### Task 4

做 sidebar + workspace + inspector 骨架。

验收：

- 可以在不同 route 切换
- 右侧 inspector 能随 selection 更新

### Task 5

做 composition canvas。

验收：

- 至少能显示 item
- 选中 item
- 调整基础布局属性

### Task 6

接 analyze API。

验收：

- 能生成 request
- 能发请求
- 能看到 response

### Task 7

保存 snapshots。

验收：

- analysis / reflection 能回挂到当前对象

## 26. 第二阶段任务单

在第一轮跑通后再做：

### Task 8

加入简单编辑能力。

### Task 9

加入 filters / search。

### Task 10

加入 fixture switcher 和 debug console。

### Task 11

把原型验证结论写回架构文档。

## 27. 每阶段验收标准

## Phase A 验收

- Mac app 能打开
- 目录结构已建立
- root workspace 能显示

## Phase B 验收

- shared domain 存在
- demo data 能基于 shared domain 构造

## Phase C 验收

- board / list / inspector 三块能联动
- selection 机制成立

## Phase D 验收

- analyze API 打通
- snapshots 可见且可保存

## Phase E 验收

- 对 ontology 的几个关键问题有结论
- 能给 iOS 重构输出明确 next steps

## 28. 风险清单

### 风险 1：过早做平台适配细节

处理：

- 先不碰相机、语音、付费、移动端交互壳

### 风险 2：共享层过度设计

处理：

- 第一版共享层只放 v0.1 真正要用的对象

### 风险 3：demo 数据质量差

处理：

- 明确手工构造 3 套高质量 scenario
- 不依赖随便生成的假数据

### 风险 4：只是做出一个好看的 board

处理：

- analyze loop 和 snapshot 挂接必须纳入 v0.1

## 29. 完成后必须输出的文档成果

Mac Prototype v0.1 做完后，至少应新增或更新这些文档：

1. 共享 Domain 类型说明
2. Analyze aggregate request 协议草案
3. Composition 持久化字段说明
4. Reflection snapshot 字段说明
5. 回迁 iOS 的重构顺序

## 30. 最终执行建议

如果只想最快开始，第一周只盯住这 5 件事：

1. 新建 target
2. Shared domain skeleton
3. Demo scenarios
4. Workspace 三栏骨架
5. Composition canvas 初版

第二周再做：

1. Analyze API
2. Snapshot 挂接
3. Inspector 深化
4. 验证结论整理

这样最稳，也最符合 Mac Prototype 的真实目的。
