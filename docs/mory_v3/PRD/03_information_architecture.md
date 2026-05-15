# 03. Information Architecture

## 1. 统一世界模型

`Mory v3` 的产品对象分为五层：

1. `Artifact`
2. `Composition`
3. `Entity Graph`
4. `Temporal Arc`
5. `Reflection`

页面、导航和 AI 都必须围绕这五层展开。

## 2. Artifact

`Artifact` 是最小的可引用记忆材料。

例子：

- `text`
- `photo`
- `audio`
- `music`
- `location`
- `weather`
- `link`
- `todo`
- `document`

边界：

- `Artifact` 表达内容事实载体。
- `person mention`、`decision fragment` 这类语义来自 analysis / graph，不再当作一级 artifact kind。
- 当前默认 capture composer 先覆盖 `text / photo / audio / location / link / todo`。

它是内容事实层，不是卡片类型。

## 3. Composition

`Composition` 是把多个材料组织进一个空间上下文的对象。

它回答：

- 哪些东西被摆在一起
- 大小和层级是什么
- 哪些对象彼此相邻或重叠
- 某一天、某个人物页、某个阶段页如何被组织

## 4. Entity Graph

`Entity Graph` 表达长期稳定对象与关系。

节点可以包括：

- Person
- Place
- Theme
- Decision

它支撑：

- 人物页
- 主题检索
- 关系回看
- 结构化搜索

## 5. Temporal Arc

`Temporal Arc` 用于表达阶段性结构，例如：

- 某段关系变化期
- 某个搬家或找工作阶段
- 某段高密度情绪区间
- 某个长期主题集中出现的时期

## 6. Reflection

`Reflection` 是系统基于前四层生成的高价值解释层。

它不是简单摘要，而是：

- 模式解释
- 阶段解释
- 关系解释
- 证据导向的高层回顾

## 7. RecordShell 的位置

`RecordShell` 仍然存在，但只作为 capture 边界对象。

它负责：

- 时间
- 来源
- 原始输入上下文
- 对 artifacts 的引用

它不再承担内容真相、布局真相或长期语义真相。

## 8. 一级导航

推荐一级结构：

1. `Home`
2. `People`
3. `Memories`
4. `Arcs`
5. `Search`

## 9. 首页结构

首页应理解为：

`Board -> Composition -> CompositionItem -> Renderer`

这意味着：

- 首页不是简单时间线
- 首页不是卡片列表
- 首页是空间化记忆面板

## 10. 设计原则

1. 页面不是产品真相。
2. 卡片不是领域对象。
3. 视觉表现可以变化，对象边界必须稳定。
