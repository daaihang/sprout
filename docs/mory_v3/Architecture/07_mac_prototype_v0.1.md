# 07. Mac Prototype v0.1

> 文档版本：Mac Prototype v0.1  
> 更新时间：2026-05-13  
> 适用范围：`sprout` 当前仓库、共享领域层抽离、macOS 原型目标、复用现有 Go 后端的验证方案

## 1. 文档目标

本文档回答的问题不是：

- “要不要把当前 iOS App 原样搬到 macOS？”

而是：

- “是否应该做一个 Mac 原型作为下一阶段架构验证器？”
- “这个原型应验证什么，不应验证什么？”
- “如何最大化复用现有后端，同时避免掉进跨平台适配泥潭？”

结论先写在最前面：

> 可以先做 Mac Prototype，但它应被定义为 `架构验证器`，而不是 `正式产品先行端`。

它的作用是：

- 帮助项目先验证统一记忆本体
- 更清晰地观察 `Artifact / Composition / Reflection`
- 借大屏幕优势快速打磨结构
- 在不被 iPhone 输入壳绑架的情况下重构领域层

它不应用于：

- 先做一个完整 Mac 产品再回头做 iOS
- 把现有 iPhone App 直接硬搬到 macOS
- 提前解决订阅、相机、语音、移动端 capture 微交互等问题

## 2. 为什么会考虑 Mac Prototype

### 2.1 当前项目的真正瓶颈

当前项目的主要问题不是“页面不够多”，也不是“后端不够强”，而是：

- `Record` 仍是主根
- `Container / Card` 已经进入空间 UI 世界
- AI 和分析输出还没有稳定中层

也就是说，真正要先验证的是：

- 统一领域模型
- 首页到底是不是 Composition
- 空间组织如何持久化
- AI 输出如何落在 Artifact / Reflection 上

这些问题，恰恰更适合在 Mac 上先做结构验证。

### 2.2 为什么桌面适合验证结构

Mac 原型有三个天然优势：

1. 屏幕大  
   更适合观察 board、grouping、阶段关系、结构可视化

2. 输入轻  
   可以先用简单文本、拖拽、Inspector 完成对象编辑，而不必一开始就做完整移动端 capture 壳

3. 调试清晰  
   数据对象、关系、布局状态、反思输出都更容易做 side-by-side 调试

## 3. 为什么不建议“先做完整 Mac 产品，再做 iOS”

这个方向看起来清楚，但实质风险很高。

### 3.1 当前代码明显偏 iOS

现有 App 深度依赖：

- `UIKit`
- `UIImage`
- `UIApplication`
- `UIPageViewController`
- 相机、图片选择、语音、底部输入条等移动端体验结构

这意味着：

- 当前代码不是天然的“通用 SwiftUI 多端 App”
- 直接迁到 Mac 会先碰到大量平台适配
- 这些适配大多与核心架构问题无关

### 3.2 先做完整 Mac 产品会转移注意力

如果一开始就追求完整 Mac 端产品，会很快被这些工作占据：

- macOS window / toolbar / menu 设计
- 鼠标与键盘交互
- 图片、文件导入路径
- 登录、订阅、权限适配
- 视觉风格跨端统一

这些工作有价值，但不应该先于 ontology 重构。

### 3.3 iOS 仍是最终主战场

当前产品核心 capture 场景天然偏移动端：

- 随手输入
- 拍照
- 语音
- 当下时刻记录
- 与真实生活同行的轻量 capture

因此长期正式产品仍应以 iOS 为主端。  
Mac 更适合在当前阶段承担“结构验证端”。

## 4. Mac Prototype 的正确定位

### 4.1 定义

Mac Prototype v0.1 应定义为：

> 一个复用现有后端、围绕统一记忆本体构建的桌面原型台，用于验证 Artifact、Composition、Reflection 及其关系，而不是一个完整面向终端用户发布的 Mac 产品。

### 4.2 角色

它的角色更像：

- internal architecture workbench
- memory board sandbox
- domain model debugger
- reflection viewer

而不是：

- App Store 可上线客户端
- 多端对等主产品

### 4.3 成功标准

Mac Prototype 成功，不取决于它是否“能发版”，而取决于它是否回答清楚这些问题：

1. `Artifact` 抽象是否足够稳定
2. `Composition` 是否真的是首页和空间视图的正确中层
3. `Record` 如何自然降级为 capture shell
4. AI 输出应该落在哪些 snapshot / reflection 对象上
5. Graph / Arc 未来接入的接口边界是否清晰

## 5. Mac Prototype v0.1 的目标

### 5.1 核心目标

v0.1 只做四件大事：

1. 验证统一领域模型
2. 验证 Composition 视图与持久化
3. 验证 Reflection / Analysis 的落点
4. 验证与现有后端的最小闭环

### 5.2 非目标

v0.1 明确不解决：

- 全量 iOS capture 体验迁移
- Camera / Voice / Photos 的完整多端输入闭环
- 订阅支付闭环
- 面向外部用户的 polish
- 全功能账户体系完善

### 5.3 一句话范围

> v0.1 只证明“新的底层结构可工作”，不证明“完整多端产品已成立”。

## 6. 必须验证的产品与架构问题

### 6.1 Artifact 验证

要验证：

- 文本、图片、音频摘要、地点、天气、链接是否都能被统一表达为 artifact
- 不同 kind 是否能在不扩张对象层级的情况下承载差异
- artifact 是否可以脱离旧 `MediaCard` 存在

### 6.2 Composition 验证

要验证：

- Board / Composition / CompositionItem 是否足以表达首页空间结构
- 布局状态是否应该作为持久化对象存在
- 同一 artifact 是否可被多个 composition 复用

### 6.3 Record 降级验证

要验证：

- 记录仍可作为 capture 边界存在
- 但不再承担 layout truth 和所有内容 truth
- 原始 capture 与上层组织能自然分离

### 6.4 Reflection 验证

要验证：

- Analysis Snapshot 和 Reflection Snapshot 是否应分层
- 单条记录分析与多条材料反思是否应分开触发
- AI 输出如何与 source refs 建立稳定关系

### 6.5 Debuggability 验证

要验证：

- 数据对象能否被直接 inspect
- composition 与 reflection 是否能 side-by-side 查看
- 后端返回结果能否快速映射到模型层

## 7. Mac Prototype v0.1 功能范围

## 7.1 In Scope

### A. Data Workspace

用于直接查看和编辑核心对象：

- Records 列表
- Artifacts 列表
- Compositions 列表
- Reflection Snapshots 列表

能力要求：

- 创建 demo data
- 查看对象详情
- 手动修改关键字段
- 查看对象间引用关系

### B. Board / Composition 画布

一个主工作区，用于展示和调整 Composition。

能力要求：

- 查看某个 board 的 composition
- 拖动 / 重排 composition items
- 修改 item span / zIndex / rotation
- 切换不同 board 场景

### C. Inspector 面板

一个右侧 inspector，用于查看当前选择对象：

- 如果选中 record，显示 capture 信息
- 如果选中 artifact，显示 payload / metadata / refs
- 如果选中 composition item，显示 layout props
- 如果选中 reflection，显示 source refs 与正文

### D. Analyze / Reflect 调试入口

能力要求：

- 选中一个 record aggregate
- 发送到现有后端分析接口
- 展示返回结果
- 保存为本地 snapshot

### E. Demo Search / Filter

基础搜索和过滤：

- 按 type
- 按 person / place / theme
- 按 date

目的不是做完整检索，而是验证对象组织方式是否合理。

## 7.2 Out Of Scope

以下内容明确不做：

- Camera capture
- 实时语音录制
- 完整 Apple Sign In 正式流
- RevenueCat / StoreKit 商品购买流
- CloudKit 正式同步闭环
- 完整 onboarding
- App Store polish

## 8. 用户与使用场景定义

v0.1 的用户首先不是终端消费者，而是：

- 你自己
- 未来协作的设计 / 工程伙伴
- 用于演示结构方向的内部观察者

典型使用场景：

1. 导入或生成一批 demo records / artifacts
2. 在 Mac 大屏中观察 board 布局
3. 选中一个 record 发送 analyze
4. 查看 reflection 如何挂回数据
5. 快速修改模型字段并观察 UI 变化

## 9. 信息架构建议

Mac Prototype v0.1 建议采用三栏或四区工作台结构。

### 9.1 左侧 Sidebar

导航项建议：

- Boards
- Records
- Artifacts
- Reflections
- Debug

### 9.2 中央主区

根据侧边栏选择切换：

- Board canvas
- Table / list view
- Reflection view

### 9.3 右侧 Inspector

展示当前选中对象详情。

### 9.4 底部或浮层 Console

可选，用于显示：

- analyze request payload
- analyze response
- mapping log
- local persistence result

## 10. 技术定位

Mac Prototype v0.1 的技术定位应该是：

- `SwiftUI` 为主
- `macOS native app`
- 共享领域层与网络层
- 先本地存 demo / mock / lightweight persistence
- 复用当前 Go 后端分析接口

这里的关键不是“是否多端统一代码很多”，而是：

> 是否先把可复用的领域层抽出来。

## 11. 代码结构建议

不建议直接在现有 iOS target 里塞大量 `#if os(macOS)`。  
那会很快失控。

建议结构：

```text
sprout/
  Shared/
    Domain/
    Analysis/
    Networking/
    Persistence/
    DemoData/
  iOSApp/
    Existing iOS-specific views and services
  MacPrototype/
    App/
    Workspace/
    Boards/
    Inspectors/
    DebugViews/
```

### 11.1 Shared/Domain

放：

- Artifact
- Record shell
- Composition
- Reflection snapshot
- lightweight graph structs

### 11.2 Shared/Analysis

放：

- analyze request builder
- response parser
- snapshot mapper

### 11.3 Shared/Networking

放：

- API client
- auth token handling for prototype mode
- endpoint config

### 11.4 MacPrototype

只放：

- macOS workspace UI
- inspector
- board canvas
- debug tools

## 12. 与现有后端的复用策略

## 12.1 可以直接复用的部分

- Go backend
- 现有认证框架中的一部分开发态逻辑
- `/api/onboarding/analyze-preview`
- `/api/records/analyze` 的基础链路
- 现有 provider abstraction

### 12.2 需要包装或过渡的部分

- 当前 analyze request 过窄
- 需要增加 prototype builder，把 record/artifacts 打成聚合输入
- 需要本地 snapshot mapper，而不是只消费原始 response

### 12.3 不建议在 v0.1 做的后端改动

- 不要先重做整套 auth
- 不要先加复杂订阅判断
- 不要先做服务端内容主存储

后端在 v0.1 中的职责只需是：

- 接住分析请求
- 返回结构化分析结果

## 13. 数据模型建议

Mac Prototype v0.1 推荐直接围绕目标模型来做，而不是复制当前旧模型。

### 13.1 最小模型集合

- `RecordDraft` 或 `RecordShell`
- `Artifact`
- `Board`
- `Composition`
- `CompositionItem`
- `RecordAnalysisSnapshot`
- `ReflectionSnapshot`

### 13.2 是否要一开始上完整 Graph

不建议。

v0.1 可只保留：

- `EntityReference`
- `EntityMention`

作为轻量结构，先不做完整 graph 持久化。

### 13.3 是否要兼容当前 SwiftData 旧模型

不建议把兼容旧模型作为 v0.1 的核心要求。  
因为这个原型的目标是验证未来结构，不是复刻历史包袱。

## 14. 视图模块建议

### 14.1 Board Workspace

这是整个 Mac prototype 的主界面。

至少应具备：

- 缩放
- 拖拽
- item 选择
- 多种显示模式切换

### 14.2 Artifact Table

列表形式快速看：

- kind
- title / summary
- time
- linked record
- tags / themes

### 14.3 Record Aggregate Detail

展示：

- capture shell
- linked artifacts
- current analysis snapshot
- reflection history

### 14.4 Reflection Viewer

展示：

- reflection 标题
- 正文
- 证据来源
- 引用的 records / artifacts

## 15. 交互原则

Mac Prototype 不需要追求移动端情绪化微交互。  
它应强调：

- 清楚
- 可见
- 可编辑
- 可追踪

交互优先级：

1. 结构可见
2. 引用关系清楚
3. 调试路径短
4. 改一个字段能立即看到结果

## 16. 数据来源策略

v0.1 不应依赖真实完整生产数据。

建议三种数据来源：

### 16.1 Handcrafted Demo Data

人为写的高质量 demo 场景：

- 某个人物关系线
- 某个搬家阶段
- 某段决策过程

### 16.2 Local Fixture Import

本地 JSON 导入 demo aggregate。

### 16.3 Current App Export Later

后续才考虑从当前 iOS 数据导出导入。  
这不应阻塞 v0.1。

## 17. 两周内可完成的最小版本

## Week 1

### Day 1-2

- 新建 `MacPrototype` target
- 抽出 shared domain skeleton
- 建立 demo data

### Day 3-4

- 做 sidebar + board workspace + inspector 框架
- 接入 artifacts / records 基础列表

### Day 5-7

- 做 composition item 展示与拖拽
- 做本地 selection / editing 状态

## Week 2

### Day 8-9

- 接 analyze API
- 构造 aggregate request builder

### Day 10-11

- 做 analysis snapshot / reflection snapshot 展示
- 把 response 挂回本地对象

### Day 12-14

- 做 polish
- 写 demo scripts / fixtures
- 明确验证结论和后续迁移清单

## 18. 里程碑定义

### Milestone A: Workspace Alive

能打开 Mac app，看见：

- sidebar
- board
- inspector
- demo artifacts

### Milestone B: Composition Alive

能：

- 选中 composition item
- 修改布局属性
- 立即看到 UI 变化

### Milestone C: Analysis Alive

能：

- 选中 record aggregate
- 调现有后端 analyze
- 展示结果
- 保存 snapshot

### Milestone D: Architecture Validated

能回答：

- Artifact 抽象是否成立
- Composition 是否应持久化
- Record 如何降级
- Reflection 如何落地

## 19. 风险与规避

### 19.1 风险：Prototype 变成第二个正式客户端

规避：

- 明确 out-of-scope
- 不做订阅 / 相机 / 完整多端 polish
- 以“验证结构”而非“上线产品”为目标

### 19.2 风险：过早写太多共享 UI

规避：

- 先共享 domain 和 networking
- 不强求 iOS / Mac 共用大量视图层

### 19.3 风险：原型太假，无法指导 iOS

规避：

- 至少打通真实 analyze API
- 至少让 composition 可编辑
- 至少让 snapshot 真正落本地

### 19.4 风险：又回到 Record-centric

规避：

- Mac prototype 的数据模型从第一天开始围绕 Artifact / Composition 设计
- Record 只做 shell，不挂 layout truth

## 20. 做完 v0.1 之后应产出的结果

Mac Prototype v0.1 完成后，至少应产出这些明确成果：

1. 一版共享领域模型草案
2. 一版 analyze aggregate request builder
3. 一版 composition 持久化设计
4. 一版 reflection snapshot 结构
5. 一份“回迁 iOS 的改造顺序”

如果做完只得到一个“桌面上看起来还不错的 demo”，那说明方向做偏了。

## 21. 最终建议

可以做 Mac Prototype。  
但必须明确：

- 它不是完整产品先行端
- 它不是为了回避 iOS 难度
- 它是为了先把架构做对

因此最合理的策略是：

1. 先做 `Mac Prototype v0.1`
2. 用它验证 `Artifact / Composition / Reflection`
3. 把共享领域层抽出来
4. 再回到 iOS 正式重构主产品

一句话总结：

> Mac 原型最有价值的地方，不是“看着方便”，而是它能迫使 Mory 先把世界观和结构做清楚，再回到 iPhone 做真正对的产品。
