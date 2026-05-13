# 06. Migration Roadmap

## 1. 迁移目标

迁移的目的不是“看起来更先进”，而是解决一个具体问题：

> 在不打断当前可运行产品的前提下，把 Mory 从 Record-centric 卡片系统过渡到统一记忆本体系统。

## 2. 当前现实约束

迁移设计必须承认这些现实：

- 当前 iOS 端主数据层是 `SwiftData`
- 当前首页依赖 `RecordMapper + StickerGridLayout`
- 当前后端分析协议较窄
- 当前代码仍在持续演进，不能接受大停机重写

因此路线必须是“分层引入、渐进替换”。

## 3. Phase 0: 文档冻结

### 3.1 目标

在编码前先统一语言。

### 3.2 输出物

- 新版 PRD
- 新版技术架构
- 统一对象命名表
- 迁移边界说明

### 3.3 验收标准

团队内部能明确说清：

- 什么是 artifact
- 什么是 composition
- record 为什么降级
- AI 为什么只负责 reflection

## 4. Phase 1: 引入 Artifact

### 4.1 目标

先解决“内容真相层”问题。

### 4.2 动作

- 新增 `Artifact` 模型
- 保留 `MediaCard` 兼容旧逻辑
- 新写入链路把文本、照片、音频、地点等转成 artifacts
- `Record` 与 artifacts 建立引用关系

### 4.3 暂不做的事

- 不急着删除所有旧 card model 路径
- 不急着引入 graph
- 不急着改所有页面

### 4.4 验收标准

- 新产生的记录可双写 `Record + Artifact`
- 至少文本、照片、音频、地点能以 artifact 形式存在

## 5. Phase 2: 引入 Composition

### 5.1 目标

让首页空间结构进入持久层。

### 5.2 动作

- 新增 `Board / Composition / CompositionItem`
- 把 `dashboardCardSpanOverridesData` 的职责迁出 `Record`
- 为首页按天生成 `DayBoard`
- `RecordMapper` 逐步演进为 `CompositionProjector`

### 5.3 验收标准

- 首页 item 的尺寸与关键视觉状态不再由 `Record` 直接拥有
- 同一 artifact 或 record section 可以被稳定地投影到 composition item

## 6. Phase 3: 引入 Analysis Snapshot

### 6.1 目标

让 AI 输出有稳定落点。

### 6.2 动作

- 新增 `RecordAnalysisSnapshot`
- 升级后端请求协议为 `record aggregate`
- capture 后异步写入 analysis snapshot

### 6.3 验收标准

- 单条记录分析结果可本地持久化
- UI 可以直接消费 snapshot，而不是临时文案

## 7. Phase 4: 引入 Entity Graph

### 7.1 目标

建立长期关系层。

### 7.2 动作

- 新增 `EntityNode / EntityEdge / ArtifactEntityLink`
- 先做 person/place/theme/decision 四类
- 基于 analysis + deterministic signals 增量更新 graph

### 7.3 验收标准

- 人物页和主题检索不再只靠 `Record` 反查
- 至少一部分关系能被长期累计

## 8. Phase 5: 引入 Temporal Arcs

### 8.1 目标

从点状记录升级到阶段性理解。

### 8.2 动作

- 新增 `LifePeriod / LifeArc`
- 基于时间密度、实体密度、主题重复度做阶段候选
- 用 AI 只做命名和解释，不做全部发现

### 8.3 验收标准

- 系统能展示至少基础阶段页
- 反思可引用阶段对象而不是只引用单条记录

## 9. Phase 6: 清理旧结构

### 9.1 目标

在新体系稳定后移除旧时代遗留。

### 9.2 清理对象

- `Record.cardType`
- `Record.cardUnits`
- `Record.cardWidthColumns`
- `dashboardCardSpanOverridesData`
- 部分以 `MediaCard` 为中心的旧路径

### 9.3 验收标准

- `Record` 成功降级为 capture shell
- 首页、分析、检索不再依赖旧字段

## 10. 风险与规避

### 10.1 风险：双写期间状态不一致

规避：

- 明确新旧字段优先级
- 用 migration flags 控制新路径

### 10.2 风险：UI 重构过早

规避：

- 先保证底层对象落地
- 渲染层先复用现有组件

### 10.3 风险：AI 协议升级过快

规避：

- 版本化接口
- 先兼容旧请求
- 新旧 snapshot 可并存

## 11. 迁移顺序的原则

正确顺序是：

1. `Ontology`
2. `Artifact`
3. `Composition`
4. `Analysis Snapshot`
5. `Graph`
6. `Temporal Arc`
7. `Cleanup`

不要颠倒成：

1. 先加更多卡片
2. 先做更花的 AI
3. 先做阶段文案

那会继续放大结构问题。

## 12. 最终状态

迁移完成后，理想架构应具备：

- `Record` 只是 capture 壳
- `Artifact` 是内容真相层
- `Composition` 是空间组织层
- `Graph` 是长期关系层
- `Arc` 是阶段层
- `Reflection` 是高价值 AI 输出层

到那时，Mory 才真正从“记录 App”进化成“个人记忆操作系统”。
