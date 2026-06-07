# Mory iOS App 总体诊断报告

**日期：** 2026-05-18
**范围：** 8 个核心模块的 v5 PRD + v6 PRD + 实际代码三方比对
**结论：** 工程能力强，产品语义层与 v6 承诺差距大；多个发布阻塞问题需先处理

---

## Executive Summary

**范围**：mory iOS app 八个核心模块（Onboarding / AI Pipeline / Today Board / Capture / Insights·Search·Settings / Memory Detail / Entity Detail / Auth）的 v5+v6 PRD 与实际代码三方比对。输出 72 项可执行项 + 12 类成熟态验收指标。

**核心发现**：工程深度已达中后期产品水平（Apple Sign-In、Claude tool-use、SwiftData、quality gates 全到位），但**产品语义层（用户主权、AI 透明度、错误恢复、隐私控制）停在 demo 阶段**。

**关键风险**：8 个发布阻塞 + 9 个致命问题须在公开 beta 前处理——含数据泄漏（多用户共设备）、GDPR 阻塞（无 delete account）、网络断假登录、AI 失败摧毁用户资产、调试文案暴露给用户。

**战略路径（三段并行）**：
1. **1 个月**：止血 + 合规 + 兑现 6 个"infra 已建未接 UI"的免费 v6 进度（reflection save/dismiss、followUp 展示、confidence、aliases 等）
2. **2-3 个月**：v6 schema 升级（artifact role/position、entity relationship、composition order）+ Home Masonry + Yesterday Panel + Entity correction 全套
3. **借 iOS 26 Foundation Models**：把 server AI 流量大部分下沉本地，兑现 "private + AI-native + Apple-native" 定位

**核心判断**：不需要新增 v6 之外的概念——**v6 PRD 完整实现就是 Section 0 North Star 里描述的成熟态产品**。差距不在"做什么"，而在"做完最后一公里 UI 和稳健性"。

> 阅读顺序建议：先读 §0 North Star 看终点 → §11 总览表 扫全貌 → §3-§5 看必修问题 → §9 看路线图 → §12 看怎么测是否到位。

---

## 0. North Star — 成熟态 mory 的用户体验

> 这一节定义"终点"。下面的诊断章节都应该对照这个终点理解差距。

### 一句话定位

成熟的 mory 像一张持续整理自己的书桌——你不必每天打扫，但每次回到桌前都发现昨天的零散物件已经归位、你需要的东西被推到了手边，而你**没失去任何东西的所有权**。

### 核心氛围（四个词）

- **安静**：不打扰、不催、不推
- **准备好的**：每次打开都有东西在等你，是"昨天的内容被照顾到了"，不是"今日推送"
- **可证据化**：每个 AI 推断都能 trace 回 source memory，每个洞察都标着置信度
- **完全属于你**：你的内容、布局、人物、解释；AI 是工具不是主角；关掉云 AI 后 app 仍然有用

### 早上 30 秒（典型场景）

7:43 am 打开 mory：
- Today Board 还是你上周亲手摆好的样子，没动过
- 顶上多了一条窄横条："昨天 3 条记忆已整理"——点开看 Yesterday Panel
- 一张柔和的问题卡："上周你提到 Alex 三次。这是你的合伙人吗？" → 你点"是合伙人"，卡片消失
- 30 秒里你没编辑任何东西，但 mory 比你刚关 app 时更懂你

### 中午突然记录

会议中按住锁屏 widget 录音 18 秒，松开 → 保存。下午看时：
- 原始录音保留
- 自动转录被 AI 顺过（去填充词、加标点），旁边有 "edited" 标签 + "View original" 链接
- AI 识别出与"产品定位"主题的关联，悬浮提示"这是第 4 次提到"——你可以选择跳到相关 memory 检索结果（不是聊天界面，是带"为什么命中"标记的卡片列表）

### 周末回顾

进 Memories tab → 切到 **Film Gallery** 看本周照片胶片化排布；切到 **Storage Jar** 看 memory 按情绪着色的玻璃罐视图。

进 Insights tab：
- "本周高亮 storyline" 写得平淡而准确，不写"你成长了"
- People / Open decisions / Themes 各显示证据数和置信度
- 每个洞察都可点回 source memory 列表

### Daily question 的克制感

晚上 9:48 锁屏 reflective 通知："你提到 '保护早晨创作时间' 三次。本周做到了吗？" 点开是 review 界面（不是聊天），显示触发这个问题的 3 条原始 memory + 简短输入框。**不答也不会再问同一个问题 7 天。**

### 一年后

- People 列表 23 个人物，每个都有你确认的关系、别名、关系演变时间线
- 47 个 decisions，38 closed、9 still open
- 4 个保留的 life chapter（删掉过 3 个 AI 提议但你不认同的）
- Semantic search "那次让我想清楚 pricing 的对话" 命中 6 月和 11 月的两条 memory——它们无关键词重叠，只有语义关联
- 看到 1 年前 vs 现在的反应模式差异，mory 不写"你成长了"，只列证据让你自己判断

### 它**不**像的样子

- 不会跳 chat 窗口
- 不会主动写"今天过得怎样？"
- 不会在你没确认前合并两个 entity
- 不会因为 7 天没记录推送"我们想你"
- 不会把 AI 改过的文字当成你的原话
- 不会让你找不到"关掉云 AI"按钮
- 不会在版本更新时丢失你的布局或人物关系数据

### 与当前差距的关键判断

成熟态需要：
1. **Foundation 已就位**（已完成 ~60%）：五层 domain model、Apple Sign-In、Claude tool-use、SwiftData、Vision OCR、Speech 转录、quality gates
2. **缺的是用户主权层**（最大缺口）：correction actions、entity merge、reflection save、follow-up 展示、grid 布局、yesterday panel、多媒体视图
3. **缺的是体验完整性**：onboarding 衔接、错误恢复、network offline 态、stale 引导、隐私控制可视化

**这两公里走完，mory 就接近成熟态。** v6 PRD 描述的产品形态如果完整实现，就是上面的故事。

---

## 0.5 未来技术路径 — Apple 本地 ML + AI-Native 深化

> 这一节描述从当前到成熟态的"技术放大器"。不修复现有 bug，而是把现有架构拉到下一代体验。

### 核心判断

mory 的隐含 positioning 是 **private + AI-native + Apple-native**——在 iPhone 上和 Apple Intelligence 长期共生的产品。v6 PRD `01_product_thesis:90-100` 已经把"local intelligence handles lightweight classification / salience hints / recurrence / embedding"写进去；现有 domain model 的 confidence 字段、quality gate 架构、local artifact processor 模式都已经为本地 ML 留好位置——**技术承接难度极低，关键是是否承认这是 mory 的核心定位**。

---

### 现在就能用的 Apple 本地 ML 框架

#### A. NLEmbedding — 当下最有价值

`NaturalLanguage.NLEmbedding` 提供句子级 embedding，Apple 训练好，多语言（中英日韩 20+），完全本地。

直接解决 v6 `06_search` Current Gap：
- 用户搜 "那次让我想清楚 pricing 的对话" → query 转 embedding → 和所有 memory embedding 做 cosine 相似度
- 500 条 memory ≈ 500 × 512 维 float ≈ 1MB 存储
- 查询 < 50ms
- **不需要 Claude，不需要 Core Spotlight，不需要任何后端**

比 v6 Architecture `05_core_ml_and_core_spotlight.md` 规划的 Core Spotlight 路径更可控（无 OS 支持判断的不确定性）。

#### B. Foundation Models（iOS 26）— 战略级

Apple 在 WWDC 2024 发布的 Foundation Models framework 让 app 直接调用设备上 Apple Intelligence LLM。

可下沉到本地的当前后端 Claude 任务：
- Voice transcript refinement（v6 §8 允许的"轻量编辑"清单）
- Title generation
- Theme labeling
- Short summary
- Daily question 改写润色
- Entity disambiguation 判断
- Clarification question 生成

**意味着 v6 server-side AI 大部分流量可下沉本地——成本/隐私/延迟三赢**。Helicone 收集请求体的隐私担忧基本消除。

应保留 Claude 的场景：
- 长 context 跨多 record 的 reflection
- Chapter naming（需要更强的语言能力）
- 复杂 storyline 总结

Settings "Cloud AI: ask / on / off" 的中间挡 "ask" 借此真正落地——本地搞得定的不问，搞不定的才询问用户。

#### C. NLTagger — 免费的轻量 NLP

提供词性标注、专名识别（personalName / placeName / organizationName）、情感分析。

直接价值：
- Capture 时本地预先识别专名，减少 Claude 出错率，节省 token
- 本地情感分数对照 Claude emotion 输出——矛盾时 low confidence
- 文本中人/地名在保存时就标记，让 known_entities 上下文更准确

实现成本极低，让 quality gate 更可信。

#### D. CreateML 个性化模型

用 CreateML 训练 per-user 模型（数据永远不离开设备，BGProcessingTask 夜间充电时训练）：

| 目标 | 训练信号 | 输出 |
|------|---------|------|
| Personal salience scoring | 用户 pin/hide/dismiss + themes + context + 时间 | 个人化 salience score，替代固定阈值 0.75 |
| Card preference learning | Home Board 卡片 accept/ignore | 未来卡片 priority，让 "More/Less like this" 真正学习 |
| Notification timing | 用户开/忽略通知的时间 | 自适应 daily question 推送时段 |

效果：经过 1 个月使用后，AI 提示的"重要时刻"开始符合**你**的标准。

#### E. Sound Analysis — voice memo 的 ambient context

识别 ~300 种音频事件（talking/music/laughter/traffic/cafe/rain）。

用户在咖啡馆录的 voice memo → 自动识别"cafe ambience + multi-person conversation"作为 weak context signal → 喂给 AI 做更丰富的 cluster。

#### F. Vision 深化（已用 OCR + classification）

可加：
- `VNDetectFaceCaptureQualityRequest`：识别是否人物照（不存身份，只存"is portrait"）
- `VNGenerateImageFeaturePrintRequest`：本地照片特征向量，做"和这张类似的其他照片"
- `VNRecognizeAnimalsRequest`：宠物记忆
- `VNDetectBarcodesRequest`：识别票据/二维码，主动标记为"非情感记忆"（解决前面 Capture 诊断里"麻辣烫成 entity"问题）

#### G. App Intents → Siri 整合

```
"Hey Siri, capture a thought" → 录音 → mory voice memory
"Hey Siri, show recent memories about Alex" → 跳过滤页
"Hey Siri, what did I do yesterday?" → Yesterday Panel
```

iOS 13+ Shortcuts 就支持，不需要 Apple Intelligence。**让 mory 从 app 变成 OS 一部分**的关键。

---

### Apple Intelligence 成熟后的进一步接入

#### Writing Tools（iOS 18.1+）

让用户在 Memory Detail 编辑 body 时长按选中 → 弹 "Rewrite / Proofread / Summarize"。

价值：v6 voice transcript refinement 可以**用 Writing Tools UI 而不是自己造**——Apple 主导的体验用户信任已建立，mory 不需要再解释"我们的 AI 改了你的文字"。

#### Genmoji / Image Playground

- 给 Person entity 生成 placeholder 头像
- 给 storyline 卡片可生成 cover image
- 完全本地，无隐私顾虑

#### App Intent + 系统跨 app context（未来 iOS 19+）

mory 通过 App Intents 暴露 Person / Place / Memory / Reflection 作为 AppEntity：
- 收到关于 Alex 的邮件 → Siri "Save this conversation to Alex memory?"
- Maps 标记地点 → mory "User flagged Place X as meaningful"

需要：暴露 `IntentDescription` + `AppEntity` 让系统理解 mory 核心对象。

---

### 超越 ML 的 AI-Native 优化

#### 1. 流式响应

当前是 request → wait → response。改 SSE 流后：用户保存 memory → summary 一字一字出现，3 秒内有反馈，而不是转圈 15 秒。失败时已显示部分可保留。

#### 2. Prompt Caching（Anthropic 已支持）

System prompt（[prompt.go](server/internal/ai/prompt.go) 1500+ tokens）+ known entities 每次重复——应该 cache。每次 analysis 节省 ~50% 成本 + 提速。**几小时工程改动，几个月成本节省**。

#### 3. RAG 替代固定 known entities

[ArchitecturePipelineExecutor:33](mory/mory/Infrastructure/Analysis/Pipeline/ArchitecturePipelineExecutor.swift:33) 按 updatedAt 取最近 20 个 entity——粗暴且不相关。

改用 RAG：
- 新 record 转 embedding（NLEmbedding 本地）
- 检索 entity 库 top-20 相关 entity
- 喂相关的，不是最近的

效果：用户写"和 Alex 吃饭"拿到的是 Alex 关联的最近 person/place/theme，不是 graph 里随便的最近 20 个。**v6 entity dedup 质量的核心提升点**。

#### 4. Outbox 模式

[CaptureOrchestrator](mory/mory/Infrastructure/Capture/CaptureOrchestrator.swift) 直接 `Task { refreshMemoryPipeline }`——网络断直接失败。

改为：
- Save → 写 outbox（SwiftData 持久化的 pending queue）
- 后台 worker 不断重试
- 前台 / 网络恢复时立即 flush

效果：用户在地铁里写 5 条 memory，出地铁后自动全部分析完。**这也是 v6 "continuous intelligence" 真正持续的基础**。

#### 5. Token / 成本可观测

服务端 [anthropic.go:215](server/internal/ai/anthropic.go:215) log 有 token 但没存 DB。

要做：
- 每次 Claude 调用写 `(user_id, model, input_tokens, output_tokens, cost_usd, request_kind, timestamp)` 表
- 每天/每月聚合
- 用户级预算：tier=free 每月 $0.5 cost，超了 throttle
- Settings 显示用户当月用量

**成熟 AI-Native 产品必须有的基础设施——否则一个 bug 账单就爆**。

#### 6. 多模型路由

成熟态不是"二选一全替换"，是按任务类型路由：
- 简单任务（title/theme/labeling）→ DeepSeek / Haiku（便宜快）
- 复杂任务（reflection/chapter naming）→ Claude Sonnet / Opus
- 用户本地选项 → Foundation Models

服务端 provider abstraction（[provider.go](server/internal/ai/provider.go)）已经有，改造 per-request 路由不大。

#### 7. 失败的温柔降级

成熟态：网络断 / AI 失败时不显示 "Failed"，显示：
- "本地版本已保存"
- "AI 分析将在网络恢复时自动完成"
- 用户随时可看本地 OCR / NLTagger 抽取的初步信息

**让用户感觉 app 永远"在工作"**，区别只是"完整工作 vs 部分工作"。

---

### 推荐实施顺序

#### 阶段 A（1-2 周）：免费 AI-Native 升级

| 项目 | 价值 | 难度 |
|------|------|------|
| NLEmbedding 上 semantic search | 直接兑现 v6 §6 核心承诺，完全本地 | 中 |
| NLTagger 给 capture 加本地实体识别 | 提升 Claude 分析质量 | 小 |
| Prompt caching 服务端启用 | 50% 成本节省 + 提速 | 小 |
| Outbox 模式 | 解决网络断的"假登录"和分析丢失 | 中 |
| App Intents 基础（"capture a thought" Siri） | OS 一部分的存在感 | 中 |

#### 阶段 B（1-2 个月）：Apple Intelligence 准备层

| 项目 | 价值 |
|------|------|
| Foundation Models 接入（iOS 26） | refine/title/theme/short reflection 下沉本地 |
| Writing Tools 整合 Memory Detail | 用 Apple 自带 UI 做 refinement |
| Sound Analysis 给 voice memo 加 ambient | 更丰富的 context cluster |
| Vision 升级（face quality/feature print/barcode） | 更聪明的 photo artifact |
| Token / Cost 后端可观测 | 公开发布前必须 |

#### 阶段 C（3-6 个月）：个人化学习层

| 项目 | 价值 |
|------|------|
| CreateML 个人 salience model | AI 的"重要"开始符合你的标准 |
| CreateML 卡片偏好 model | More/Less like this 真正学习 |
| RAG 替代固定 known entities | entity dedup 质量飞跃 |
| 多模型路由（DeepSeek + Claude + Foundation Models） | 成本/质量自动平衡 |
| BGProcessingTask 夜间训练 | 不影响前台体验的学习 |

---

### 关键观察

1. **mory 当前架构对接 Apple 本地 ML 的适配难度极低**——domain model 已有 confidence 字段，pipeline 已有 local artifact processing 概念，quality gates 是 "decision based on signals" 架构
2. **v6 PRD 设计时就为 Apple ML 留了位置**（`01_product_thesis:90-100`），只是实现时还没补
3. **一旦承认 "local-first AI" 是 mory 核心定位，上面所有路径都是顺其自然的实现**
4. **Foundation Models 是分水岭事件**——iOS 26 正式发布后，"server AI vs 本地 AI"的产品决策范式会彻底改变，mory 提前对接受益最大

---

## 1. 已诊断的 8 个模块

| # | 模块 | v5 完成度 | v6 准备度 |
|---|------|----------|----------|
| 1 | Onboarding | 30%（缺 4/6 步） | 10%（v6 无专属文档） |
| 2 | Analysis Pipeline / AI 质量 | 75% | 50% |
| 3 | Today Board / Home | 70%（list 而非 grid） | 30%（schema 缺 x/y） |
| 4 | Capture 流程 | 60-70%（toolbar 3 选 1 完整） | 30%（缺 role/position） |
| 5 | Insights / Search / Settings | 60% | 25% |
| 6 | Memory Detail / 错误恢复 | 80% | 40% |
| 7 | Entity / Person Detail | 55% | **15%**（最大缺口） |
| 8 | Auth / Session / Keychain | 85% | 60% |

---

## 2. 跨模块发现的六个核心主题

### A. 数据所有权层级未定义
SwiftData（设备级，无 userID 列）+ Keychain（iCloud 同步）+ Server user profile（Apple sub 主键）—— 三层混用，无统一 ownership model。后果：sign-out 不清本地数据；多用户共设备会看到对方记忆；换 Apple ID 老数据成孤魂。

### B. "Infrastructure 建好 UI 不接"模式
反复出现：FollowUpCandidate / EntityNode.aliases / EntityNode.confidence / ArtifactEntityLink.evidenceSummary / ReflectionStatus 三态 —— 数据全有，UI 完全不展示。v6 大量功能"差最后一公里"。

### C. 静默失败遍布
Entity quality drop / Reflection gate reject / Photo OCR fail / Context permission denied / Pipeline arc skip —— 全部默不作声。质量 funnel 永远不可观测。

### D. 两套并行代码
- sprout AuthSessionManager（`.signedIn` 含 hasCompletedOnboarding）vs mory AuthSessionManager（`.authenticated/.unauthenticated`）
- sprout OnboardingFlowView（try-before-sign）vs mory MoryOnboarding（4-step carousel，死代码）

每套都是部分完成，没人统一。

### E. AI 失败时摧毁用户已有资产
[refreshMemoryPipeline](mory/mory/Persistence/Repositories/MoryMemoryRepository.swift) 先 purge 现有 analysis/graph/arcs/reflections 再 retry。retry 失败 = 用户失去所有 AI 资产。原子 pipeline + 无重试 = 一次网络抖动毁掉一条 memory 的所有沉淀。

### F. v6 把 "user-controlled" 设为核心，但当前所有 detail 都是只读浏览
v6 `02:153-165` 要求 9 个 correction actions，PersonDetail / EntityDetail / MemoryDetail / Insights 一个都没实现 reflection save/dismiss、merge people、less-like-this。**v6 的 product thesis 不可能在当前 UI 上兑现。**

---

## 3. 发布阻塞（公开 beta 前必修）

| # | 问题 | 模块 | 修复成本 |
|---|------|------|---------|
| 1 | OnboardingFlowView 调试文案暴露（"v3 memory-layer result" / "snapshot" pills） | Onboarding | 5 分钟（藏在 debug flag） |
| 2 | Sign-out 不清 SwiftData → 多用户共设备数据泄漏 | Auth | 小（决策 + 实现） |
| 3 | 网络断时 sign-in 进"假登录"，API 全 401 | Auth | 小（加 .localOffline 显式态） |
| 4 | Settings Privacy 缺 AI on/off + cloud reflection 控制 | Settings | 中（v6 控制集 + GDPR） |
| 5 | iOS Notification settings 完全缺失 | Settings | 中（App Review） |
| 6 | Delete Account 服务端端点缺失 | Server/Auth | 中（GDPR） |
| 7 | Refresh token 服务端无撤销机制 | Server/Auth | 中 |
| 8 | `SignedInOnboardingView` `/api/me/onboarding/complete` 无 local fallback → 弱网卡死 | Onboarding | 小 |

---

## 4. 致命问题（用户日常被伤害）

| # | 问题 | 模块 | 关键修法 |
|---|------|------|---------|
| 9 | Edit pipeline failure → purge 已删旧分析 = 数据丢失 | Detail | Purge 时机改"成功后才删" |
| 10 | Reflection 在 detail 无 Save/Dismiss UI 但模型支持 | Detail | 加 5 行 UI |
| 11 | Memory delete 无确认对话框 + cascading 大 | Detail | 加 alert |
| 12 | Photo+Audio 串行处理 5-10s 阻塞 save，违反"立即捕获" | Capture | Save 立刻成功，处理转后台 |
| 13 | Today Home 是 List 不是 grid（违反 v5 §3 "spatial layout"） | Today Board | v6 重写必经 |
| 14 | Hands-free voice lock 没做（v5 §3.33） | Capture | 半天 dev |
| 15 | Context check-in button 没做（v5 §3.34，无文字捕获缺失） | Capture | 半天 dev |
| 16 | DEBUG `"dev-user"` fallback + 服务端 `DevAuthEnabled` 可能漏到生产 | Auth | 加 guard + 单测 |
| 17 | Preview 记忆登录后归属未定义（onboarding） | Onboarding | 加文案 or 实现迁移 |

---

## 5. 严重问题（定位裂缝）

| # | 问题 | 模块 |
|---|------|------|
| 18 | 后端 `max_tokens=800/700` 太紧，JSON 易截断 | AI |
| 19 | 客户端 pipeline 无重试（5xx/network） | AI |
| 20 | Reflection 质量门禁是英文硬编码短语（`"from pottery"` `"apartment lobby"`） | AI |
| 21 | AI provider 无 fallback（Anthropic 挂 = 全产品瘫痪） | AI |
| 22 | Pipeline 8 entities 硬截断；20 known entities 按时间取 → 老朋友被当新人 | AI |
| 23 | Confidence 数据在 model，所有 UI 不显示 | Entity Detail |
| 24 | Entity merge / rename / alias 操作完全缺失（v6 §02 必须） | Entity Detail |
| 25 | FollowUpCandidate 数据流通但 UI 不展示（v6 clarification 第一步免费可做） | Entity Detail |
| 26 | Today Board reflection 优先级 70-80 永被 memory 38-97 压下去 | Today Board |
| 27 | 没有 "yesterday" surface（v6 核心承诺） | Today Board |
| 28 | Search 还是 `.contains` 关键词，距 v6 "semantic" 差一代 | Search |
| 29 | Search 每次全量加载 graph 入内存 | Search |
| 30 | Settings Privacy 是纯文案不是控制台 | Settings |
| 31 | Insights 硬上限 5 + 无分页 + 无"基于什么"解释 | Insights |
| 32 | EntityDetailView 一视图同时服务 place/theme/decision（违反 v5 §7-9） | Entity Detail |
| 33 | Stale analysis 无警告（用户不知道 AI 看的是哪个版本内容） | Detail |
| 34 | Helicone 默认收集所有请求体（隐私边界模糊） | AI |
| 35 | 两套 AuthSessionManager 并行 | Auth |
| 36 | 噪声 OCR 污染 entity graph（"麻辣烫"会成 entity） | Capture |
| 37 | Live transcription 单行截断（`.lineLimit(1)`） | Capture |

---

## 6. 中等问题

38. 媒体文件丢失静默渲染（photo 被系统清理后 artifact 仍显示）
39. Edit draft 不持久（用户输入 200 字后台 = 丢失）
40. Pipeline status 在 detail 不 live update
41. 无 stale state 引导（7+ 天没记录看到啥都没变）
42. Composer 缺 link / location 入口（v5 §5）
43. 多 photo 不支持（v5 暗示 + v6 §3 必须）
44. Suggested vs Saved reflection 视觉不区分
45. 错误细节藏在 debug 面板，普通用户看不到 statusCode/failedStage
46. Place detail 无地图预览（v5 §7.116）
47. Decision 无 open/closed 状态显示（v5 §9.146）
48. PersonDetailView 无 mention count / first-last mentioned at / relationship
49. Apple sub 变化时无 email/handle 备份
50. Identity token 永久保留 keychain
51. Subscription verify 不在 refresh
52. Biometric lock 是 UserDefaults UI gate，不锁 keychain
53. Keychain `AfterFirstUnlock` 跨设备 iCloud 同步无用户告知
54. 后端无 rate limit + 无 per-user token 计费追踪
55. 客户端无显式 timeout（依赖 URLSession 默认 60s vs server 15s）
56. Settings 有 `promptTone` 调优开关却给普通用户看到
57. Capture preferences 缺 default context 不允许"只 location 不要 music"等组合
58. Permission Weather 是假权限，UI 单独列让用户困惑
59. Context candidates 默认全勾且视觉等同主内容（违反 v6 §4）
60. 4-second voice finalization timeout 硬编码，慢设备会丢转录

---

## 7. v6 阻塞（必须先做的 schema / 架构改动）

| # | 缺失项 | 影响 |
|---|--------|------|
| A | `Artifact.role` 字段 | 阻塞 voice refinement（原文 vs 精修双轨） |
| B | `Artifact.position / sectionID` | 阻塞 multimedia article mode 和 detail 排序 |
| C | `EntityNode.relationship` 字段 | 阻塞"Who is Alex to you?"的关系字段 |
| D | `CompositionItem.userSortIndex` 和 masonry layout | 阻塞 Home masonry spatial 布局 |
| E | Yesterday Panel 概念 | 阻塞 v6 核心承诺"打开看到昨天整理好" |
| F | IntelligenceJob / GraphDelta / ClarificationQuestion model | 阻塞 v6 continuous intelligence |
| G | Core Spotlight 索引 | 阻塞 v6 semantic search |
| H | UserSettingsPreference 缺 9 项 v6 控制 | 阻塞 user-controlled AI |
| I | RecordAnalysisSnapshot.basedOnRecordHash | 阻塞 stale detection |

---

## 8. 跨面板有"基础设施已建未接 UI"的免费 v6 进度

按"成本/收益"排：

| 优先 | 工作 | 数据来源 | UI 工作量 |
|------|------|---------|----------|
| 1 | Reflection Save/Dismiss 按钮（detail + insights） | ReflectionStatus 三态全有 | 半天 |
| 2 | FollowUp 显示在 PersonDetail | `FollowUpCandidate` 已持久化 | 一天 |
| 3 | Mention count + first/last mentioned 显示 | `provenanceRecordIDs` + `firstSeenAt/lastSeenAt` 已存 | 半天 |
| 4 | Confidence 显示 | 三处 model 都有 | 半天 |
| 5 | Aliases 列表显示 | `EntityNode.aliases` 已存 | 半天 |
| 6 | EvidenceSummary 显示在 entity 详情 | `ArtifactEntityLink.evidenceSummary` 已存 | 一天 |

**6 项加起来 = 3-4 天工作量，能让 v6 "clarification 系统的展示侧"几乎免费跑起来。**

---

## 9. 优先级路线图建议

### 立刻（本周内，止血）
- 隐藏 `OnboardingFlowView.persistedResultCard`（调试文案）
- `SignedInOnboardingView` 加 local fallback
- Memory delete 加 confirmation alert
- Detail `refreshMemoryPipeline` 改"成功后才 purge"
- Live transcription `.lineLimit(nil)`

### 短期（本月内，可观测 / 安全）
- 网络断显式 `.localOffline` 态 + 顶 banner
- DEBUG `dev-user` fallback 加严格 guard
- Quality funnel 计数器（entity drop / reflection gate）
- Photo+Audio 处理改后台 + save 立即成功
- Reflection Save/Dismiss UI（免费 v6 进度 #1）
- FollowUp 在 PersonDetail 显示（免费 v6 进度 #2）

### v6 alpha 前（合规 + 统一）
- Delete Account 服务端端点
- Refresh token revocation
- Sign-out 决策（清 SwiftData or per-user 隔离）
- 统一 sprout/mory 的 AuthSessionManager
- Settings 补齐 9 项 v6 控制 + Notification 占位
- 写 v6 专属 onboarding 文档（`mory_v6/PRD/13_onboarding_and_first_run.md`）

### v6 alpha 期（schema 升级 + 核心 surface）
- Artifact role / position / sectionID schema 改 + 迁移
- EntityNode.relationship 加字段
- CompositionItem x/y 坐标加字段
- IntelligenceJob / GraphDelta 新 model
- Home Masonry 新 feature 模块（v5 list 留兜底）
- Yesterday Panel domain model

### v6 beta（用户主权 + AI 深化）
- Entity merge / rename / alias UI
- Mark context wrong / Mark chapter wrong / Less like this
- Voice transcript 双轨（原文 + 精修）
- Place detail 地图 / Decision detail 状态
- Core Spotlight semantic search
- Daily question 引擎

### v6 rc
- 多媒体视图（Film Gallery / Storage Jar / Sticker Wall 至少一个进 P1）
- Search 引擎反馈学习
- 成本 / token 用量追踪

---

## 10. 一句话总判

**Mory iOS app 的工程深度（domain model、pipeline、auth、persistence）已经达到中后期产品水平，但产品语义层（用户主权、错误恢复、AI 透明度、隐私控制）停在了 demo 阶段。** v6 的方向正确，但通往 v6 的路径上有 7 个发布阻塞和 9 个致命问题必须先处理；同时有 6 个"免费 v6 进度"可以以极低成本兑现 v6 核心承诺。

最该执行的策略：**用 1 个月时间集中处理"止血 + 合规 + 6 个免费 v6 进度"**，让 alpha 阶段的 dogfooding 不被低级问题污染；然后再用 2-3 个月做 v6 schema 升级和新 surface。

---

## 11. 总览表 — North Star 要素 × 当前状态 × 下一步

> 优先级编码：🔴 立刻（本周）｜🟠 短期（本月）｜🟡 v6 alpha 前｜🟢 v6 alpha 期｜🔵 v6 beta+

### 11.1 Capture 体验

| 要素 | 成熟态 | 当前状态 | 关键缺口 | 下一步 | 优先级 |
|------|--------|---------|---------|--------|--------|
| 快速录音 | 锁屏 widget 长按 / hands-free lock 长录音 | press-hold 基础有，无 lock | slide-right lock 没做 | 加 lock 手势 + widget | 🟠 |
| 无文字 check-in | 右侧按钮一键存 location+weather+music | "+" 按钮打开 composer 仍要输入 | v5 §3.34 未实现 | 加 context check-in button | 🟠 |
| 多张照片 | 单 record 可含多 photo | UI 仅支持 1 张 | v5 暗示 + v6 §3 必须 | 改 PhotosPicker 多选 + UI | 🟢 |
| Voice 转录双轨 | 原文 + AI 精修，可随时切换 | 仅最终转录，无 double-track | artifact.role 字段缺 | schema 加 role + 双显示 | 🟢 |
| 实时转录预览 | 录音时滚动显示 partial transcript | 启用了但单行截断 | `.lineLimit(1)` | 改 `.lineLimit(nil)` + scrollable | 🔴 |
| 噪声 OCR 识别 | 收据/截图标记为 artifact 不当 anchor | 全部进 summary 污染 entity | 无 confidence 标识 | 加 OCR confidence + 票据检测 | 🟠 |
| Save 立即返回 | photo OCR + 转录全后台，UI 秒级反馈 | 串行处理 5-10s 阻塞 | 违反"立即捕获" | 改为 outbox + 后台 worker | 🟠 |

### 11.2 Today Board / Home

| 要素 | 成熟态 | 当前状态 | 关键缺口 | 下一步 | 优先级 |
|------|--------|---------|---------|--------|--------|
| Spatial masonry | 用户按顺序整理固定列宽、自适应高度卡片 | List + 微旋转装饰 | UI 层完全重写 | v6 feature flag 新 Home 模块 | 🟢 |
| Yesterday Panel | 早上一条"昨天 3 条已整理"窄横条 | 完全不存在 | 概念缺失 | 加 domain model + UI | 🟢 |
| 用户层 vs 建议层 | 用户主权层不被 AI 移动 | pin/hide/dismiss 实现但同层 | 双层抽象未建 | 加 suggestion layer | 🟢 |
| Reflection 凸显 | High-confidence reflection 进 top 3 | priority 70-80 < memory 38-97 | 公式让 memory 永远压 reflection | 重排 priority 公式 / 分层 surface | 🟠 |
| Stale 引导 | 7+ 天没记录看到温和召回 | 啥也不显示 | 概念缺失 | 加 stale prompt | 🟡 |
| Live update | pipeline 完成自动刷新卡片 | task 出现时一次 + 5s 轮询 | 未订阅 notification | 订阅 pipelineDidComplete | 🟠 |
| Context cluster | top 3 最相关聚类 | 取 single largest | 算法简化过头 | 改 top-N | 🟡 |

### 11.3 Memory Detail

| 要素 | 成熟态 | 当前状态 | 关键缺口 | 下一步 | 优先级 |
|------|--------|---------|---------|--------|--------|
| Edit 不丢分析 | retry 失败旧分析保留 | purge → retry 失败 = 数据丢失 | purge 时机错 | 改"成功后才 purge" | 🔴 |
| Reflection Save/Dismiss | 在 detail 直接接受/拒绝 | 仅展示无动作 | UI 未接 model | 加 2 个按钮 | 🔴 |
| Edit draft 持久 | 输入到一半切后台不丢 | `@State` 内存丢失 | 不持久 | 写 SwiftData key by recordID | 🟠 |
| Delete 确认 | 二次确认 + 显示影响 | swipe 立即删 | 无 alert | 加 confirmation alert | 🔴 |
| Stale analysis 警告 | "此分析基于编辑前内容" | 旧分析无声残留 | 无 hash/version | 加 basedOnRecordHash 字段 | 🟠 |
| 媒体丢失检测 | "Media unavailable + Re-attach" | 静默渲染空 | 无 fileExists 校验 | 加文件存在性检查 | 🟡 |
| Edit 不强制 reanalysis | 用户可选择"仅保存"或"重分析" | 任何 edit 全量重跑 | 成本失控 | 加"Save without re-analysis"按钮 | 🟠 |
| Mark context wrong | 标记 weather/location 错 | 完全无 | v6 §10 必须 | 加 artifact-level 操作 | 🟢 |
| Attachment delete/reorder | edit 模式可删可重排 | 仅能追加 text | 缺 position 字段 | schema 加 position + UI | 🟢 |

### 11.4 Entity / Person Detail

| 要素 | 成熟态 | 当前状态 | 关键缺口 | 下一步 | 优先级 |
|------|--------|---------|---------|--------|--------|
| FollowUp 展示 | "Who is Alex to you?" 卡片 | 数据存了 UI 无 | 30-50 行 UI | 在 PersonDetail 加 Open Questions 区 | 🟠 |
| Mention count + 时间 | "本周 4 次 / 总 23 次 / 自 6 月" | 不显示 | 字段已存 | 加 stats 卡 | 🟠 |
| Confidence 显示 | "Alex 88% confidence" | 字段存 UI 无 | 三处 model 都有 | 加 confidence indicator | 🟠 |
| Aliases 显示+编辑 | 别名列表 + 加/删 | 数据存 UI 完全无 | 用户无法发现错误合并 | 加 aliases 列表 UI | 🟠 |
| EvidenceSummary | 显示"为什么 link 到该 entity" | 字段全空白 | 后端未填 / UI 未读 | 后端 prompt + UI 接 | 🟡 |
| Relationship 字段 | "my partner / colleague" | 字段缺失 | EntityNode schema 缺 | schema 加 relationship 字段 | 🟢 |
| Merge people | "This person is the same as..." | 完全无 | v6 §02 必须 | repo 方法 + UI wizard | 🟢 |
| Mark not same | 反向纠错 | 完全无 | v6 §02 必须 | UI + repo 反向标记 | 🟢 |
| Per-kind 专属视图 | Place 地图、Decision 状态、Theme 排除噪声 | 通用 view | v5 §7-9 各自 spec | 拆 PlaceDetail/DecisionDetail/ThemeDetail | 🔵 |

### 11.5 Insights / Search

| 要素 | 成熟态 | 当前状态 | 关键缺口 | 下一步 | 优先级 |
|------|--------|---------|---------|--------|--------|
| Semantic search | "那次让我想清楚 pricing 的对话" 命中 | `.contains` 关键词 | 距 v6 差一代 | 上 NLEmbedding 本地 | 🟠 |
| 查询建议 | "本周 / 照片 / Alex / Open decisions" | 空白 prompt | 无建议生成 | 加 query suggestion 列 | 🟡 |
| 结果命中解释 | "matched OCR / transcript / context" | 无 | v6 §10 | 加 match reason 标签 | 🟢 |
| 9 类结果 | memory/person/place/theme/decision/chapter/reflection/media/question | 4 类 | 缺 5 类 | 扩 result types | 🟢 |
| Insights 解释源 | "基于近 30 天 X 条 memory" | 无 | v5 §3.35 | 加 explanation 卡 | 🟠 |
| Insights 分页 | 完整查看 themes/people | 硬上限 5 | 看不到全貌 | 加"View All"+ 分页 | 🟠 |
| 高亮 storyline | 综合 active+confidence+engagement | 取第一个 .accepted | 算法太弱 | 改综合排序 | 🟡 |

### 11.6 Settings / Privacy / Auth

| 要素 | 成熟态 | 当前状态 | 关键缺口 | 下一步 | 优先级 |
|------|--------|---------|---------|--------|--------|
| AI cloud 控制 | ask/on/off 显式 | 无 | v6 §3 + GDPR | Settings 加 cloud AI toggle | 🟡 |
| Notification settings | frequency/cadence/style 完整 | 完全无 | App Review 阻塞 | 加 Notification section | 🟡 |
| Voice refinement 控制 | "ask first run" | 无 toggle | v6 §10 | Settings 加 | 🟢 |
| Local intelligence on/off | toggle | 无 | v6 §3 | Settings 加 | 🟢 |
| Semantic search 控制 | on/off + rebuild index | 无 | v6 §6 | Settings 加 | 🟢 |
| Sign-out 清数据 | 明示+清 SwiftData 或 per-user 隔离 | 不清，多用户泄漏 | 数据所有权未定义 | 决策 + 实现 | 🔴 |
| Delete Account | server 端点 + 全清 | 无 | GDPR 阻塞 | 加 /api/me/delete | 🟡 |
| Refresh token revocation | sign-out 服务端撤销 | 30 天有效 | 安全漏洞 | 加 revocation list | 🟡 |
| 网络断显式 offline | banner + 自动同步 | 假登录态 API 全 401 | 静默退化 | 加 `.localOffline` 显式态 | 🔴 |
| DEBUG dev-user guard | 严格 production 隔离 | 可能漏到 TestFlight | 安全风险 | 加单测 + guard | 🟠 |
| 统一 AuthSessionManager | 一套 | sprout + mory 两套 | 维护负担 | 合并 | 🟡 |

### 11.7 Onboarding

| 要素 | 成熟态 | 当前状态 | 关键缺口 | 下一步 | 优先级 |
|------|--------|---------|---------|--------|--------|
| 调试文案隐藏 | 纯净首次体验 | "v3 memory-layer result" 暴露 | 5 分钟修 | 加 debug flag | 🔴 |
| Local-first 解释 | 首次启动明示"内容在本机" | 跳过这一步 | v5 6 步缺 4 步 | 补 local-first 屏 | 🟡 |
| Permission 教育 | 渐进 + "为什么需要" | 完全跳过 | v5 6 步缺 | 补 permission 教育 | 🟡 |
| Preview 归属明确 | 标"演示" 或登录后迁移 | 未定义 | 数据丢失风险 | 加文案 or 迁移 | 🔴 |
| Finish Setup 网络 fallback | 弱网也能进 | POST 失败卡死 | 无 local fallback | 加 fallback | 🔴 |
| 升级路径 | v5→v6 老用户清晰过渡 | 未设计 | 5 种"首次"未分流 | 写 v6 专属 onboarding doc | 🟢 |
| 三 tab 引导 | 首次到达 Insights | 落在 Today 无引导 | 发现成本高 | 加 tab tour | 🔵 |

### 11.8 AI 质量 / 后端

| 要素 | 成熟态 | 当前状态 | 关键缺口 | 下一步 | 优先级 |
|------|--------|---------|---------|--------|--------|
| Pipeline 分阶段独立 | 每 step 失败不毁前面 | 原子全失败 | 体验脆弱 | 拆 step + 各自持久化 | 🟠 |
| 客户端重试 | 5xx/network 自动 2 次 | 仅 401 重试 | 网络抖一下就败 | 加指数退避 | 🟠 |
| max_tokens 充足 | analyze 1500-2000 | 800/700 易截断 | JSON 不完整 | 上调 + stop_reason 检测 | 🟠 |
| Reflection tool-use | structured output 保证 | 字符串 prompt + 正则解析 | 脆弱 | reflection 升级为 tool-use | 🟢 |
| Provider failover | Anthropic 挂自动 OpenAI | 二选一无 fallback | 服务故障 = 全瘫 | 加 fallback 路由 | 🟡 |
| RAG known entities | embedding 检索相关 | 时间最近 20 个 | dedup 质量差 | 用 NLEmbedding 检索 | 🟢 |
| Prompt caching | system+entities cache | 全量重发 | 50% 成本浪费 | Anthropic cache_control | 🟠 |
| 流式响应 | SSE 实时显示 | 等完整响应 | 转圈 15s | 加 SSE | 🟢 |
| Token/cost 追踪 | per-user 月度预算 | 仅 log | 账单失控风险 | 加 DB 表 + 用户面板 | 🟡 |
| 多模型路由 | 简单任务 Haiku、复杂任务 Sonnet | 启动单选 | 成本不优化 | per-request 路由 | 🔵 |
| Quality funnel 计数器 | 每 drop/gate 可见 | 全静默 | 不可观测 | 加 counters + debug 面板 | 🟠 |
| Reflection gate 短语 | 后端 prompt 判断 | 客户端硬编码 | 英文短语 / 中文不支持 | 挪到 server | 🟢 |
| Helicone 默认关 | 仅 staging 启用 | 默认全收集请求体 | 隐私边界模糊 | 改默认 + Settings 告知 | 🟠 |

### 11.9 Apple 本地 ML 整合

| 要素 | 成熟态 | 当前状态 | 下一步 | 优先级 |
|------|--------|---------|--------|--------|
| NLEmbedding semantic search | 完全本地语义搜索 | 无 | 上 NLEmbedding 索引 | 🟠 |
| NLTagger 实体识别 | 本地预提取专名 | 仅 Vision | capture 时加 NLTagger | 🟠 |
| Foundation Models LLM | iOS 26 本地 refine/title/theme | 全部 server | 接入 LanguageModelSession | 🟢 |
| Writing Tools 整合 | Memory Detail 长按 rewrite | 无 | 接入 WritingTools API | 🟢 |
| Sound Analysis ambient | voice memo 自动加场景 | 仅 location | 加 SoundAnalysis service | 🔵 |
| Vision 升级 | face quality / barcode / animals | 仅 OCR + classify | 加 Vision 请求 | 🔵 |
| App Intents Siri | "Hey Siri capture a thought" | 无 | 实现 AppIntent | 🟠 |
| CreateML 个人 salience | per-user 模型 | 固定阈值 | 训 MLClassifier | 🔵 |
| BGProcessingTask 夜训 | 充电时学习 | 无 | 加后台任务 | 🔵 |

### 11.10 跨切面

| 要素 | 成熟态 | 当前状态 | 下一步 | 优先级 |
|------|--------|---------|--------|--------|
| Outbox 模式 | capture/analysis 永不丢 | 失败即死 | 加 outbox queue | 🟠 |
| 失败温柔降级 | "本地已保存，网络恢复继续" | "Failed" 黑盒 | 改文案 + 部分结果 | 🟠 |
| 老用户升级 | Day 0 体验明确 | 未设计 | 写迁移策略 | 🟢 |
| 中文 reflection 支持 | 中文短语全覆盖 | 仅 plan 信号有中文 | 补 reflection 信号 | 🟠 |
| Accessibility | VoiceOver / Dynamic Type 完整 | 未审视 | accessibility 审计 | 🔵 |
| App Review 准备 | Privacy Manifest / 通知 / 删账户 | 多项缺 | 公开发布前清单 | 🟡 |

---

### 总览统计

- 🔴 立刻：**8 项**（本周内）
- 🟠 短期：**21 项**（本月内）
- 🟡 v6 alpha 前：**14 项**
- 🟢 v6 alpha 期：**18 项**
- 🔵 v6 beta+：**11 项**

**合计 72 项可执行项**——覆盖从止血到成熟态完整路径。

---

## 12. 成熟态验收指标

> North Star 描述的是"感觉起来"，这一节定义"测得出来"。每条指标都应该是**反操纵**的——优化它就等于让产品更接近 North Star，而不是让团队作弊达标。

### 12.1 North Star 四词的可测代理

| 氛围词 | 代理指标 | 目标值 | 反指标 |
|--------|---------|--------|--------|
| **安静** | 用户每日 notification 接收数 | ≤ 2 | 通知关闭率 > 25% = 设计失败 |
| **安静** | 用户主动 dismiss/hide 卡片占比 | < 15% | > 30% = AI 在打扰 |
| **准备好的** | 早晨首次打开 → Yesterday Panel 点击率 | > 40% | < 10% = panel 内容无价值 |
| **准备好的** | 用户回 app 后 3 秒内看到 AI 新内容比例 | > 60% | — |
| **可证据化** | "查看来源"点击率（per AI 卡） | > 20% | 0% = 用户不信或不需 |
| **可证据化** | "为什么命中"标签 search 结果展开率 | > 15% | — |
| **完全属于你** | Cloud AI=off 用户数 / app 仍每周活跃 | ≥ 10% | < 1% = 本地模式没真用 |
| **完全属于你** | 用户编辑过 entity (rename/merge/alias) 比例 | > 30% | < 5% = 用户不知道能改 |

---

### 12.2 产品参与指标（行为）

| 指标 | 目标值 | 说明 |
|------|--------|------|
| Day-1 → Day-7 retention | > 50% | 跨过 onboarding 留下来 |
| Day-30 retention | > 30% | 找到使用节奏 |
| Day-90 retention | > 20% | 形成长期习惯 |
| 周均 capture 次数（active user） | ≥ 5 | 不要求每天，但要"常想起" |
| Voice : Photo : Text capture 占比 | 多模态分布而非单一 | 单一模态 > 80% = quick toolbar 没起作用 |
| Tab 切换：用户在 Insights tab 周均访问 | ≥ 2 次 | 进 Insights = 体会到长期价值 |
| 多媒体视图（Film/Storage Jar）使用率 | > 25% | 非 list 视图被发现 |
| Quick capture toolbar 使用占比 | > 40% | v5 PRD 核心目标 |

---

### 12.3 AI 质量指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| Reflection save rate（显示后保存 vs 显示后忽略） | > 30% | v6 已定 |
| Reflection dismiss rate | < 25% | > 25% = AI 在生硬推 |
| Question answer rate（per kind 分别看） | > 30% | 不能按总均值 game |
| Question "do not ask again" 触发率 | < 10% | 频繁触发 = 提问过激 |
| Entity merge correction rate（用户合并 AI 没合并的） | < 5% / 月 | 高 = dedup 弱 |
| Entity "not same" correction rate（用户拆 AI 错合并的） | < 3% / 月 | 高 = AI 激进合并 |
| Search success rate（点开结果 / 搜索次数） | > 40% | v6 已定 |
| Semantic vs keyword search 命中率分别看 | semantic ≥ keyword | 否则 semantic 没价值 |
| Stale analysis 检测后 AI rerun 成功率 | > 90% | edit 后重新分析的可靠性 |
| AI 输出 confidence ≥ 0.7 占比 | > 60% | 低 confidence 太多 = 模型未训好 |

---

### 12.4 信任 / 隐私指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| Cloud AI 设置分布（off / ask / on） | off 5-15% / ask 30-50% / on 50-70% | 健康分布 |
| Settings → Privacy 访问率（per user 月度） | > 20% | 用户在意 |
| Settings 找到"关闭 cloud AI"的中位数点击次数 | ≤ 2 | v5 PRD 必须 |
| Delete Account 触发后 server + local 完全清除时间 | < 24h | GDPR 合规 |
| Per-user 月度 token 用量曝光（Settings 可见） | 100% | 透明度 |
| 数据导出（Export Local Data）触发率 | 不期待高，但必须可触发 | 出 bug 时是用户最后保障 |
| 多设备共享 token 用户告知率 | 100%（首次启用时） | iCloud Keychain 同步透明 |

---

### 12.5 系统健康指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| Capture → Save → UI 反馈 p95 latency | < 500ms | "立即捕获" |
| Capture → AI 分析完成 p50 latency | < 8s | 流式响应基础上 |
| Pipeline success rate（per stage） | > 95% | analysis / graph / arc / reflection 分别看 |
| 跨阶段独立 success（analysis 成功但 reflection 失败的 record 仍可用） | > 80% | 拆原子 pipeline 后的指标 |
| Outbox 完成延迟 p95（网络恢复后） | < 60s | continuous intelligence 基础 |
| 每月 cost per MAU | < $0.30 | 商业可持续 |
| Crash rate | < 0.1% | App Store baseline |
| Token 截断（max_tokens reached）率 | < 2% | JSON 完整性 |
| Helicone / Anthropic 上行 PII 比例 | 0%（采样审计） | 隐私边界 |

---

### 12.6 Apple-native 体感指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| VoiceOver 全 surface 可用率 | 100% 主要页 | accessibility 必须 |
| Dynamic Type 不破布局的范围 | xSmall → AX5 | 全部支持 |
| Reduce Motion 用户首页加载时间 | ≤ 标准首页 | 不能因关动效退化 |
| Widget 安装率 | > 15% | "锁屏长按录音"被用 |
| Siri intent 月度调用率 | > 10% | "Hey Siri capture a thought" |
| Foundation Models 本地推理占总 AI 任务比 | > 50%（iOS 26+） | 本地优先真正落地 |
| Apple Sign-In 之外有备份登录路径 | 至少一种 | 防 Apple sub 变化 |
| Writing Tools 在 Memory Detail editor 可用 | 100% | iOS 18.1+ 整合 |

---

### 12.7 长期价值指标（90 天后才能测）

| 指标 | 目标值 | 说明 |
|------|--------|------|
| 用户的 Person profile 完整度（display+alias+relationship） | > 60% person 字段非空 | clarification 系统有效 |
| Open decision → closed 转化率（30 天内） | > 25% | mory 在帮决策推进 |
| Chapter 提议保留率（用户接受 / AI 提议） | > 40% | AI 对生活阶段感觉准 |
| 30+ 天前 memory 被重新打开的比例 | > 15% / 月 | 不是写完就死 |
| 90+ 天 entity 反复出现的"重连"通知触发率 | 至少触发 1 次 / 用户 / 季度 | revisit 功能有意义 |
| 每月生成 Yesterday Panel 至少一次的用户比例 | > 60% | 早晨仪式形成 |

---

### 12.8 反指标（红线）

| 红线 | 触发后行动 |
|------|----------|
| 多用户共设备数据泄漏报告 ≥ 1 | 立即热修 + 召回声明 |
| "我的记忆丢了" 工单 / 月 > 0.5% MAU | 暂停 destructive 操作 |
| "AI 把我说的话改了" 工单 / 月 > 0.3% MAU | 关闭 voice refinement 默认开 |
| Notification opt-in 后 7 天内关闭率 > 25% | 降通知频次 + 重审策略 |
| 安装后 7 天内删账率 > 8% | 重审 onboarding |
| Apple App Review 拒绝（隐私 / 通知 / 删账） | 阻塞发布 |
| 任何一次 cost spike 单用户 > $5/天 | 立即 throttle + 调查 |
| Entity 错合并被用户撤销率 > 10% | 暂停自动 merge / 改人工确认 |

---

### 12.9 验收门槛分层

#### 🟡 Public Beta Ready（最低门槛）
- 所有 🔴 立刻项目修完
- 所有 🟠 短期项目 ≥ 80% 完成
- 反指标全部低于红线
- App Review 必备项齐全（删账户 / Notification settings / Privacy Manifest）

#### 🟢 v6 Alpha Done
- v6 schema 升级完成（artifact role/position、entity relationship、composition x/y）
- Foundation Models 接入 ≥ 3 个任务
- Home masonry + Yesterday Panel 上线
- Entity correction 全套操作可用
- 验收 12.3 AI 质量指标 ≥ 80%

#### 🌟 Mature Product（North Star 抵达）
- 12.1 氛围代理全部达标
- 12.7 长期价值指标 ≥ 6/6 项达标
- Day-90 retention > 20%
- Cost per MAU < $0.30
- Apple Intelligence 本地推理 > 50%
- 主动 NPS（"我会推荐 mory" 比例） > 40%

---

### 12.10 指标搭建的优先顺序

测量需要基础设施。建议这样上：

1. **第一波（与"止血 + 合规"同期）**：基础 telemetry
   - 12.5 系统健康（capture latency、pipeline success rate）
   - 12.8 反指标监控（cost spike、crash rate）

2. **第二波（v6 alpha 前）**：质量指标
   - 12.3 AI 质量（reflection save、question answer、search success）
   - 12.4 信任（cloud AI 分布、settings 深度）

3. **第三波（v6 beta 前）**：体验指标
   - 12.1 North Star 代理
   - 12.2 产品参与
   - 12.6 Apple-native

4. **第四波（产品满 6 月后）**：长期指标
   - 12.7 长期价值（需要数据积累）

**没有这套测量体系，"我们是否到达 North Star"就永远是主观判断**——这是 AI-Native 产品最容易陷入的陷阱。

---

## 13. Stakeholder Brief（对外版）

> 此节是面向投资人、联合创始人、顾问、潜在收购方或交接接手人的高级版本。隐去技术细节、文件路径、代码引用，保留战略叙事。

---

### What Mory Is

**Mory 是个人记忆的操作系统**——一款 iOS 原生 app，帮用户保存、组织、连接、重新理解构成他们生活的人、时刻、阶段和决定。

不是日记 app，不是 AI chatbot，不是社交产品。它的定位是 **private + AI-native + Apple-native**：内容默认留在用户设备，AI 在后台持续整理但不喧哗，深度融合 Apple 生态（Sign-In、Speech、Vision、未来的 Apple Intelligence）。

**核心承诺**：用户**没有失去任何东西的所有权**——记忆是他们的，AI 只是工具。

---

### Where We Are

经过对 8 个核心模块的 v5/v6 PRD 与实际代码三方比对：

**工程深度**：已达中后期产品水平。Apple Sign-In + JWKS 验证 + 双 token 刷新、Claude tool-use 结构化输出、五层 domain model（artifact / record / graph / arc / reflection）、SwiftData 持久化、Vision OCR + Speech 转录的本地预处理、quality gates 三层架构——这些都是行业 senior 级别完成度。

**产品语义层**：处于 demo 阶段。用户主权机制（合并人物、纠正 AI 错误、Save/Dismiss reflection）、错误恢复（AI 失败时的优雅降级）、AI 透明度（confidence、evidence 可见）、隐私控制（关闭云 AI 的明确入口）——这些 v6 PRD 承诺的"AI-native 核心"在 UI 层面大部分还未实现。

**关键观察**：v6 PRD 描述的产品形态是合理的——不需要新增概念，只需把已有的工程能力**最后一公里**接到 UI 上。

---

### The Bet（成熟态愿景）

一年后的成熟 mory 应该是这样：

> 早上 7:43 打开 app。Today Board 还是你上周亲手摆好的样子。顶上多了一条"昨天 3 条记忆已整理"。一张柔和的卡片问"上周你提到 Alex 三次，他是合伙人吗？"——点确认，消失。30 秒里你没做任何编辑，但 mory 比你刚关 app 时更懂你。
>
> 一年后你的 People 列表有 23 个人物，每个都有你确认的关系、别名、关系演变时间线。47 个 decisions，38 已完成、9 still open。Semantic search "那次让我想清楚 pricing 的对话" 命中 6 月和 11 月两条无关键词重叠但语义相关的 memory。
>
> mory 不写"你成长了"这种话，只列证据让你自己判断。

四个核心氛围词：**安静 / 准备好的 / 可证据化 / 完全属于你**。

这是个**长期产品**——用户与它的关系按月、按年累积价值，不靠每日 DAU 拉新驱动。

---

### Strategic Position

mory 的三重护城河：

1. **私密性**：内容本地存储，云 AI 用量用户显式可控。在用户对 AI 数据安全焦虑日益强烈的今天，这是稀缺的产品姿态。

2. **Apple-native 深度整合**：随 iOS 26 Foundation Models 框架成熟，mory 可把大部分 AI 任务下沉到设备本地的 Apple Intelligence——成本、延迟、隐私三赢。这是非 Apple 平台 AI 产品（GPT app、Notion AI 等）做不到的。

3. **认知模型而非工具**：mory 的数据模型是"五层记忆本体论"（artifact → record → graph → arc → reflection），不是简单的笔记+标签。这让累积出的价值随时间不可替代——用户的一年使用历史无法迁移到任何竞品。

---

### Known Risks（已识别，已有应对路径）

每个风险都已诊断到具体根因，应对路径清晰：

| 风险类别 | 具体问题 | 应对方向 | 时间 |
|---------|---------|---------|------|
| **合规** | 缺 Delete Account / Notification settings / 隐私控制 toggle | 加 server 端点 + Settings 控制集 | 1-2 个月 |
| **数据安全** | 多用户共设备会看到对方记忆（SwiftData 设备级而非用户级） | 决策 sign-out 清数据 or 实现 per-user 隔离 | 1 个月 |
| **可靠性** | AI 失败时摧毁用户已有分析；网络断时进入"假登录"状态 | Outbox 模式 + 失败温柔降级 + 网络断显式 offline 态 | 1 个月 |
| **成本** | 缺用户级 token 追踪，单次 bug 可能账单爆炸 | DB 表 + 月度预算 + Prompt caching（-50% 成本） | 1 个月 |
| **AI 质量** | Reflection 门禁硬编码英文短语，中文用户路径缺失 | 挪到 server prompt + 加中文信号词 | 2-4 周 |
| **服务可用性** | Anthropic 故障 = 全产品瘫痪（无 provider fallback） | 加 DeepSeek/OpenAI fallback 路由 | 1 个月 |

**没有任何风险是"不知道怎么修"的——全部是"还没修"的。**

---

### Three-Phase Path Forward

**Phase 1（1 个月）：止血 + 合规 + 信任建立**

- 8 个发布阻塞 + 9 个致命问题全部清零
- 兑现 6 个"基础设施已建未接 UI"的免费 v6 进度（reflection save/dismiss、followUp 展示、confidence、aliases、mention count、evidence summary）
- 上 NLEmbedding semantic search（本地，零成本）
- 部署 token / cost 可观测体系

**结果**：内部 dogfooding + closed beta 可以开始，alpha 用户不会被低级问题污染体验。

**Phase 2（2-3 个月）：v6 schema 升级 + 新 surface**

- Artifact role/position + EntityNode.relationship + Composition x/y 三个核心 schema 改动
- Home Masonry 作为新 feature 模块上线（v5 list 留兜底）
- Yesterday Panel 概念实现
- Entity correction 全套（merge / not-same / rename / alias / less-like-this）

**结果**：v6 alpha → beta，"continuous intelligence" 真正开始持续。

**Phase 3（3-6 个月，与 Phase 2 部分重叠）：Apple Intelligence 整合**

- 接入 iOS 26 Foundation Models 做本地 LLM 任务（refine、title、theme、short reflection 等）
- Writing Tools 整合到 Memory Detail 编辑
- App Intents Siri 整合（"Hey Siri capture a thought"）
- CreateML 个人化模型（salience、card preference 学习）

**结果**：产品定位从"AI app on iOS"升级为"Apple Intelligence 的延伸"，差异化护城河成型。

---

### Why This Works

1. **存量资产质量高**：8 个模块诊断显示底层 domain model、AI pipeline、auth 系统都是 senior 级别。这意味着我们不是"重写"，是"补完"。

2. **v6 PRD 与成熟态愿景一致**：v6 文档是合理的产品蓝图，问题在实现完成度而非方向错误。意味着规划不需要返工。

3. **Apple 平台杠杆即将到位**：iOS 26 Foundation Models、Writing Tools、Core Spotlight semantic、Apple Intelligence 跨 app context——这些都会在未来 6-12 个月成为 default capability。mory 提前对接，受益最大。

4. **可量化、可验收**：Section 12 列出 12 类成熟态指标，每条都"反操纵"——优化它就等于让产品更接近 North Star。不是凭主观感觉判断。

5. **风险全部已知**：本文档列出 72 项可执行项，每一项都有明确的修复路径、成本估算、优先级。没有"未知未知"。

---

### Success Criteria（成熟态门槛）

mory 到达 North Star 的标志：

- **Day-90 retention > 20%**：用户跨过"新鲜感"留下
- **AI 输出 confidence ≥ 0.7 占比 > 60%**：模型对用户语境理解到位
- **Cloud AI=off 用户中仍周活跃比例 ≥ 10%**：本地优先真的有用
- **Per-user 月度 cost < $0.30**：商业可持续
- **iOS 本地 AI 处理占总任务比 > 50%**（iOS 26+）：Apple-native 兑现
- **主动 NPS > 40%**：用户愿意推荐
- **30 天前 memory 被重新打开率 > 15% / 月**：长期价值兑现

---

### One-Liner

**mory 已经把"难做的部分"做完了 60%——基础工程已经达到中后期产品水平。剩下 40% 是接 UI 的最后一公里、补合规、和借 Apple Intelligence 把成本/隐私护城河做厚。这是个"完成基础上的执行"问题，不是"找方向"问题。**

---

## 14. 风险架构 — 计划本身可能出错的地方

> 前面的章节假设"按路线图执行就能到 North Star"。这一节质疑这个假设——列出**计划本身**的脆弱点，附早期预警信号和应对策略。

### 14.1 Schema 迁移风险

**问题**：v6 路线图依赖 3 个 schema 改动（artifact.role/position、EntityNode.relationship、CompositionItem order/layout metadata）。SwiftData 迁移历史上有 silent data loss 案例。

**最坏情况**：用户升级 app → SwiftData 自动 migration 失败 → 老 record / entity / composition 不可读 → 用户失去一年的记忆累积 → 退款 + 社交媒体公关危机。

**早期预警**：
- 内部 dogfooding 时主动测试"v5 数据库 → v6 schema"路径
- 每次 schema 改动加 unit test 覆盖 v5 fixture 加载
- TestFlight 阶段强制 100% 老用户先迁移成功，再放新版

**应对**：
- Migration **永远不删数据**——只新增字段、不删字段、不改字段类型
- Pre-migration backup（自动导出 JSON 到 Documents）
- Migration 失败时进 "safe mode"：app 用 v5 schema 只读模式启动，给用户手动选择回滚或导出

### 14.2 关键路径依赖链风险

**问题**：很多 v6 功能有隐性依赖，单点失败可能阻塞下游一串。

| 上游 | 下游被阻塞的功能 |
|------|----------------|
| `artifact.role` schema | Voice refinement 双轨 → Writing Tools 整合 → "ask first run" Settings |
| `CompositionItem.userSortIndex` / masonry layout | Home Masonry → Yesterday Panel 视觉 → 多媒体视图（Film Gallery 也需要布局协议） |
| `IntelligenceJob` model | Clarification questions → Daily questions → Notification 通知 |
| Outbox 模式 | Continuous intelligence → 离线 capture → 网络断态体验 |
| `userID 列加进 SwiftData` | 多用户支持 → 跨设备同步 → 真正的 AI-native（不只是设备级） |

**早期预警**：每周回顾被阻塞的下游功能。如果"做 X 必须先做 Y"链条 ≥ 3 层，警报。

**应对**：
- Schema 改动按依赖关系优先级排序，**最长依赖链先做**
- 用 feature flag 让下游可以提前用 mock data 开发，等上游就绪再切真实数据

### 14.3 时间 / 人力假设的脆弱

**问题**：路线图写"1 个月止血 + 2-3 个月 v6 schema"——这假设了什么样的团队？

| 假设场景 | 实际进度估算 |
|---------|------------|
| 单人全职 + 经验丰富 | 路线图基本可达，1 个月止血现实 |
| 单人全职 + 中级 | 加 50% 时间，1.5 个月 |
| 多人但分工不清 | 协调成本侵蚀进度，1.5-2 个月 |
| 兼职 / 业余 | 路线图至少 ×3，3 个月止血 |

**没有人力配置的前提下，路线图只是"理想下界"**——实际执行可能慢 2-3 倍。

**早期预警**：
- 第一周记录每个止血项实际耗时 vs 估算
- 如果第一周完成率 < 50%，立刻重估全路线图
- 不要硬撑路线图，调整发布节奏

**应对**：
- 路线图按"最小可发布"切分，每个里程碑都能独立 ship
- "止血"完成度 80% 即可进 closed beta，不必等 100%
- 引入兼职 / 顾问优先解决合规 + Apple 平台特定的工作（这类工作可外包）

### 14.4 Scope Creep — "免费 v6 进度"陷阱

**问题**：路线图列了 6 个"infra 已建未接 UI"的免费 v6 进度（reflection save/dismiss、followUp 显示等）。每个看起来是"加 UI 按钮"，但**真正落地时会暴露设计决策**：

- Reflection dismiss 之后，dismissed reflection 去哪里？Archive 可见吗？永久删除还是 30 天后清？
- FollowUp 显示在哪里？PersonDetail 顶部？需要打开"Open Questions"页？过期的 question 如何处理？
- Mention count 显示什么粒度？总数？本月？分阶段？
- Aliases 编辑 UI 长什么样？加完别名是否触发 entity 重新合并？

**每一个"小 UI"决策都可能展开成一周的设计 + 实施 + 测试**。

**早期预警**：每个"免费 v6 进度"项目，提前写出"3 个未决决策"清单。如果决策超过 5 个，重估时间。

**应对**：
- 设定"先做最朴素的实现，后续迭代"原则——比如 reflection dismiss = 软删除 + 加个 "Dismissed" 列表入口在 Settings，不做花哨的归档系统
- 每个项目设硬性 deadline（如 2 天），到点没完就 scope down 而非延期

### 14.5 Apple Intelligence 时间风险

**问题**：路线图把 Foundation Models 作为"Phase 3 战略级"——假设：
- iOS 26 按 Apple WWDC 承诺时间发布
- Foundation Models framework 实际可用于第三方 app
- 用户升级到 iOS 26 的速度足够快
- A17 Pro / M-series 设备覆盖率足够

**潜在裂缝**：
- Apple 可能推迟 Foundation Models 正式发布（已有先例）
- 即使发布，3 个月后 iOS 26 用户占比可能仍 < 50%
- 大量 mory 用户在 iPhone 13/14（非 Apple Intelligence 兼容）
- Foundation Models 输出质量可能比 Claude Haiku 还弱（早期版本）

**最坏情况**：mory 公开发布时声称 "Apple-native local AI"，但 70% 用户实际无法用上，只能 fallback 到云端。

**早期预警**：
- WWDC 后立刻测试 Foundation Models 实际能力 vs Claude Sonnet
- 监控目标用户群体的 iOS 版本分布
- 测试 voice refinement 等典型任务，本地 vs 云端的盲测对比

**应对**：
- **不要把 Apple Intelligence 当作 v6 发布的前置依赖**——v6 alpha/beta 应该完全用云 AI 也能工作
- Foundation Models 作为"用户额外获益"而非"产品核心"
- 路线图加入 fallback：本地推理可用时用本地，否则云端

### 14.6 AI Provider 风险

**问题**：
- Anthropic 可能涨价（Claude API 历史上涨过 2-3 次）
- Anthropic 可能 deprecate 模型（如 Claude 3 Sonnet 已不可用）
- Anthropic 服务故障（2024 年多次小时级中断）
- DeepSeek 等替代品有地缘 / 监管风险（中国出口管制等）
- 任何 provider 都可能 breaking API change

**最坏情况**：mory 主要发版前两周，Anthropic 涨价 3 倍——成本预算被打穿，要么涨用户价格（信任崩塌）要么降级到弱模型（质量崩塌）。

**早期预警**：
- 订阅 Anthropic / OpenAI / DeepSeek 的官方 changelog
- 季度测试主备 provider 在 mory 真实 prompt 下的质量对比
- 监控 mory 单位用户成本曲线

**应对**：
- 现在就把 provider abstraction 跑通 fallback 路径（路线图已列）
- Prompt 模板抽象化，确保切 provider 时改动最小
- 用户层面引入 "AI 模型偏好"（off / fast / quality），让用户接受降级而非默默扣质量
- 大幅采用本地 ML（NLEmbedding / Foundation Models）减少云依赖比重

### 14.7 成本曲线风险

**问题**：路线图目标"per-user 月度 cost < $0.30"——但**这条曲线可能在用户量增长时失控**：

| MAU | 月度 AI cost（$0.30/MAU） |
|-----|--------------------------|
| 1k | $300 |
| 10k | $3,000 |
| 100k | $30,000 |
| 1M | $300,000 |

如果免费用户占 80%（典型 freemium 比例），实际成本要靠 20% 付费用户覆盖——单付费用户成本被放大到 $1.5/月。

**最坏情况**：MAU 增长快但订阅转化率低（< 5%），mory 每增 1 用户净亏钱，烧钱速度超过 runway。

**早期预警**：
- 第一波公开发布后两周内紧密监控 per-user cost
- 计算 LTV / CAC：每个付费用户终身价值是否覆盖 acquisition + 平均年度 AI cost
- 跟踪免费用户的 AI 用量分布（top 10% 重度用户可能消耗 60% 成本）

**应对**：
- 免费 tier 设置硬上限（每月 N 条 memory 享受 cloud AI 分析）
- 重度用户成本通过 Foundation Models 转嫁到本地（用户自己设备 = 用户自己买单）
- Prompt caching 把 50% 重复成本省下
- 多模型路由（简单任务 Haiku、复杂任务 Sonnet）至少节省 30%

### 14.8 Apple App Review 风险

**问题**：mory 触及多个 App Review 高敏感区域：
- AI 生成内容 / LLM 接入
- 用户健康/心理相关讨论（reflection 涉及情感）
- 隐私 manifest 完整性
- 通知策略
- 订阅 / IAP（如果未来开收费）

Apple 2024 起加强 AI app 审核，多个 AI app 经历多次拒审。

**最坏情况**：v6 公开发布提交 App Review → 因为 reflection 包含"我们的 AI 觉得你..."文案被拒（"medical/therapy claim"分类）→ 重大返工 + 延期 1-2 个月。

**早期预警**：
- TestFlight 内测时观察 Apple 是否提示任何文案问题
- 提前研究类似 AI app 的拒审案例（Replika、Wysa、Reflectly 等）
- 隐私 manifest 在 Phase 1 完成而不是发布前

**应对**：
- Reflection 文案严格走"evidence-based"路线（v6 PRD 已要求），杜绝"我们觉得"
- 内置 AI 来源标注 + 用户可关闭 cloud AI 的清晰路径
- 提前提交 Apple 审核 pre-review（developer support）
- 准备双语言 Privacy Policy + AI 使用披露文档

### 14.9 产品-市场契合度风险

**问题**：路线图聚焦"如何把产品做好"，但**没有解决"谁是用户"和"为什么用 mory 而不是 Apple Journal"**：

- Apple Journal 已经免费送 iOS 用户，自带照片 / 位置 / 健康整合
- Day One 是成熟竞品，14 年历史，付费用户量大
- Notion / Obsidian 重度 PKM 用户已经有自己的系统
- Reflectly / Stoic / Daylio 占据"情绪记录"心智

mory 的"AI-native 长期记忆系统"是新分类——**用户认知成本高，初期获客难**。

**最坏情况**：v6 上线后，技术上完美，但用户问"和 Apple Journal 有什么不同？" mory 没有 10 秒可答的差异化。

**早期预警**：
- closed beta 阶段做用户访谈：用户为什么选 mory？解释成本多高？
- 比较测试：让用户同时用 mory 和 Apple Journal 一周，哪个留得住？

**应对**：
- 明确目标用户细分：可能不是"所有想写日记的人"，而是"已有重度 capture 习惯但缺乏整合的人"（创业者、研究员、知识工作者）
- 差异化叙事在产品里**第一屏就讲清楚**：mory = "你的人物 / 决策 / 阶段网络"，不是另一本日记
- 长期看依赖**累积价值**（用了 1 年和 1 天体验差异巨大）——但这意味着新用户首月体验必须有"未来感"

### 14.10 人员 / 知识集中风险

**问题**：本次诊断暴露的所有复杂性集中在少数人头脑中——Domain model 五层本体论、Pipeline 多阶段 quality gates、Auth keychain 多格式兼容、SwiftData 14 个 store 的清理逻辑——**这是"巴士因子 1"的项目**。

**最坏情况**：核心开发者无法继续（健康、机会成本、个人原因）→ 接手人需要 2-3 个月才能理解整套架构 → 实际进度归零。

**早期预警**：核心代码的 commit 是否还是同一个人？文档更新频率是否健康？

**应对**：
- **本文档本身是缓解**——North Star、诊断、路线图、验收指标都在这里
- 引入 contractor / 顾问做特定模块（auth 合规、Apple Intelligence 接入、accessibility 审计），形成知识冗余
- 关键决策 ADR（Architecture Decision Record）化，写下"为什么这么设计"

### 14.11 竞争与时间窗

**问题**：成熟态描述的体验（Apple-native AI 记忆 OS）是**有时间窗的**：
- Apple 自己可能 1-2 年内升级 Journal app 到类似定位
- 大型 PKM 玩家（Notion、Roam Research）可能整合 LLM
- 新创公司涌入 "personal AI memory" 赛道

如果 mory 的 v6 公开发布拖到 2027 年中之后，**这个窗口可能关闭**。

**早期预警**：
- 季度做竞品扫描，特别关注 Apple Journal 更新和大模型 app 发布
- 关注 WWDC / iOS 更新中的 personal data 相关 API

**应对**：
- 不追求"功能完整再发"——v6 alpha 可以小范围、不完美但**先建立**用户群和品牌
- 强化 mory 的 unique combo：private + AI-native + Apple-native + memory-ontology——单独任何一点都有人做，**全部都做的目前只有 mory**
- 用户绑定通过累积价值实现（一年用户的数据无法迁移到 Apple Journal）

### 14.12 双代码库 / 多版本 PRD 的认知负担

**问题**：诊断暴露两套并行：sprout / mory 两个 AuthSessionManager + 两套 onboarding；v3/v4/v5/v6 四代 PRD 同时影响决策。

**最坏情况**：新加入的开发者花两周才搞清楚 "现在到底在做 v5 还是 v6"，进度损耗严重。

**应对**：
- 短期：**统一 sprout/mory 命名空间**（合并到 mory）——路线图已列
- 短期：在每个 PRD 文档顶部明确"本文档现状：已完成 / 部分实施 / 已被 v6 取代"
- 长期：单一 active PRD（v6），其他作为 historical reference

### 14.13 早期预警信号仪表板

把以上风险压缩成一个"每周检查 5 个指标"的简表：

| 信号 | 红线 | 检查频次 |
|------|------|---------|
| 第一周止血项实际完成率 | < 50% → 重估路线图 | 每周 |
| Schema migration test 通过率 | < 100% → 暂停 schema 改动 | 每次 PR |
| TestFlight 用户的 iOS 版本分布 | iOS 26 < 30% → 推迟 Foundation Models 依赖 | 每月 |
| Per-user 月度 cost | > $0.50 → 紧急 cost 优化 | 每周 |
| 核心开发者最近 30 天 commit 占比 | > 90% → 引入接手人 | 每月 |
| Apple Journal 是否发布 v3 重大更新 | 是 → 重新评估差异化 | 实时 |
| 用户工单 "我的数据丢了 / 改了" | 任意 1 例 → 暂停 destructive 改动 | 实时 |

---

### 关键判断

**路线图本身是个假设**——假设了人力、时间、Apple Intelligence 兑现、AI provider 稳定、用户接受度。任何一个假设破裂，路线图都需要重写。

**这一节不是劝退，是要求路线图执行时**："每周用 14.13 这张表对照自检，发现红线立刻调整路线，而不是硬撑到 quarter 末发现已经 off track"。

成熟态产品的差异不在"做了什么"，而在"何时停下来调整"。
