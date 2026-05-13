# 03. Information Architecture

## 1. 为什么这一章是新版 PRD 的中心

Mory 当前最关键的问题，不是缺页面，也不是缺一个新功能，而是产品内部存在多套对象体系：

- 数据层的 `Record / Person / Decision / MediaCard`
- UI 层的 `Container / Card / Grid / Layout`
- AI 层的 `tags / emotion / themes / reflection`

如果 PRD 还继续围绕“页面功能列表”写，而不先冻结核心对象，产品会越来越依赖 mapper，最后每层都在翻译另一层。

因此新版 PRD 必须先定义统一信息架构。

## 2. 统一世界模型

Mory 的产品对象应定义为五层：

1. `Artifact`
2. `Composition`
3. `Entity Graph`
4. `Temporal Arc`
5. `Reflection`

这是产品视角的统一宇宙。

### 2.1 Artifact

`Artifact` 是最小的可引用记忆材料。

它可以是：

- 一段文本
- 一张照片
- 一段音频
- 一个地点快照
- 一次天气快照
- 一个人物提及
- 一首歌
- 一个链接
- 一个待办片段
- 一个决策片段

Artifact 的意义：

- 它是“内容事实层”
- 它不是卡片
- 它不是页面
- 它不必须附属于唯一的 UI 展示

### 2.2 Composition

`Composition` 是把多个 artifacts 组织到一个视觉/叙事空间中的对象。

它表达：

- 哪些东西被放在一起
- 相对大小和层级关系
- 哪些元素相邻、重叠、聚合
- 某个首页、某天、某专题、某阶段是怎样被摆放出来的

Composition 不是“纯 UI 技术细节”，它本身就是记忆组织结果。

### 2.3 Entity Graph

`Entity Graph` 负责表达稳定对象和稳定关系。

节点可以包括：

- Person
- Place
- Theme
- Decision
- Mood
- Project
- LifePhase

Graph 的作用不是为了炫技，而是：

- 长期检索
- 关系回看
- 降低 AI 重复理解成本
- 支撑人物页、阶段页、主题页

### 2.4 Temporal Arc

`Temporal Arc` 表达离散记录背后的长期阶段。

例如：

- 搬来上海后的前三个月
- 某段关系逐渐变近的时期
- 找工作阶段
- 焦虑加剧的那几周
- 某个兴趣沉迷期

用户真正想理解的，常常不是一条记录，而是一段时期。

### 2.5 Reflection

`Reflection` 是系统生成的意义层。

它不等于所有 AI 输出。  
它专指那些高价值的解释与提炼，例如：

- 你在多个阶段里反复推迟同一件事
- 某个人总在你做重大决定前出现
- 某段时间你的记录主题持续偏向离开、犹豫、疲惫

Reflection 是高级层，不该承担所有基础结构工作。

## 3. Record 的重新定义

`Record` 在新版 PRD 中仍然保留，但不再是宇宙中心。

它被重新定义为：

> 一次 capture event，或者一次时间点上的记忆聚合壳。

Record 的职责：

- 表示某次记录行为发生了
- 记录时间、来源、输入上下文
- 连接到若干 artifacts
- 触发分析、排序、回顾流程

Record 不再应该承担：

- 拥有所有内容真相
- 充当所有卡片布局状态容器
- 充当 AI 长期记忆层

## 4. 产品级导航结构

### 4.1 一级导航建议

Mory 应围绕“记忆对象”而不是“功能模块”组织主导航。

推荐一级结构：

1. `Home`
2. `People`
3. `Moments / Records`
4. `Arcs`
5. `Search`

### 4.2 Home 的角色

Home 不是简单 timeline，也不是 dashboard 杂烩。

Home 的职责是：

- 当前或当天记忆空间
- 捕获入口
- 空间化回看入口
- 系统推荐回顾的承载页

### 4.3 People 的角色

People 不是通讯录，而是长期关系记忆索引。

应该包含：

- 人物基本信息
- 相关 artifacts
- 高频主题
- 共同地点/共同阶段
- 与重要记录/决定的连接

### 4.4 Moments / Records 的角色

这里保留传统时间序列入口，用于：

- 查看原始记录流
- 手动编辑和纠错
- 做精确时间回溯

### 4.5 Arcs 的角色

Arcs 是未来高价值差异化入口。

它展示：

- 阶段
- 长时段模式
- 主题聚类
- 关系发展

### 4.6 Search 的角色

Search 不应该只是全文检索。

应逐步支持：

- 人物
- 地点
- 主题
- 情绪
- 阶段
- 时间范围
- 多模态 artifact

## 5. 首页对象结构

首页不再理解为“卡片列表”，而应理解为：

`Board -> Composition -> CompositionItem -> ArtifactRenderer`

这层级意味着：

- 一个 Board 是某个首页上下文
- Composition 是其中的空间结构单元
- CompositionItem 指向具体 artifact 或 record section
- 渲染层才决定最终用什么视觉卡片形式展示

## 6. 页面不是产品真相

新版 PRD 要避免一个常见误区：

> 不要因为当前 UI 上有卡片，就把“卡片”写成产品一级对象。

卡片只是展示手段。  
真正稳定的产品对象是：

- artifact
- composition
- entity
- arc
- reflection

页面会变，视觉会变，但这些对象应尽量稳定。

## 7. 核心对象之间的关系

建议产品层关系如下：

- 一个 `Record` 可以引用多个 `Artifact`
- 一个 `Artifact` 可被多个 `CompositionItem` 引用
- 一个 `Artifact` 可连接多个 `Entity`
- 多个 `Artifact` 可共同构成一个 `Temporal Arc`
- 一个 `Reflection` 通常基于多个 `Artifact / Entity / Arc`

## 8. 为什么这套信息架构更适合未来

它解决的是长期扩展问题：

- 新增内容类型时，不需要新增一整套“业务卡片宇宙”
- UI 空间关系可以进入持久层，而不是只停留在 View
- AI 输出可以围绕稳定对象落地，而不是漂浮在 prompt 里
- 时间阶段和关系网络有真正的数据位置

## 9. 本章的产品约束

从这章开始，任何新需求都必须回答：

1. 它属于哪一层对象？
2. 它是内容事实，还是展示形式？
3. 它是否会让 `Record` 再次膨胀成宇宙中心？
4. 它能否复用 `Artifact / Composition / Graph / Arc / Reflection` 中已有抽象？

如果答不出来，说明需求还没准备好进入开发。
