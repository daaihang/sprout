# 09. Problem Matrix And Refactor Roadmap

本文把架构问题按严重程度、影响面和建议修复顺序整理成实施路线。这里的目标不是马上重构全部，而是让后续每次代码改动都能沿着清晰方向前进。

## 0. 当前执行状态

| Batch | 状态 | 结果 | 剩余差口 |
| --- | --- | --- | --- |
| Batch 1: Repository Port Split | completed | `MoryMemoryRepositorying` 已拆成 capture、library、profile/graph、intelligence、settings、external capture、debug 等小端口；核心 intelligence/notification/capture services 已改为接收更窄依赖 | App environment、Settings、Debug 仍保留 composite repository；use case service extraction 属于 Batch 2/C2 后续工作 |

## 1. Critical

| ID | 问题 | 影响 | 解决方案 | 验证 |
| --- | --- | --- | --- | --- |
| C1 | `MoryMemoryRepositorying` 超大协议 | 测试难、UI/Debug 误用、service 依赖面过宽 | 已完成第一轮 port split；继续逐步迁移 broad consumers | focused compile + service tests 通过 |
| C2 | `MoryMemoryRepository` 仍是 God object | 多事务、多 helper、多 service 聚合，长期难维护 | 抽 use case service：memory creation、mutation、entity mutation、external import | repository tests 不减少，新增 service tests |
| C3 | `MemoryFeatureModels.swift` 承担过多 domain/presentation/protocol | Domain 层成为杂物间，后续 v8 模型难定位 | 拆 Capture/Library/Search/GraphPresentation/RepositoryPorts | 全量 build + model tests |
| C4 | Analyze pipeline 直接依赖 `ModelContext` | Analysis 逻辑被 SwiftData 绑定，后台/测试/替换困难 | 引入 `AnalysisPipelineQuerying/Persisting/Tracing` | pipeline unit tests 不启动 SwiftData |

## 2. Important

| ID | 问题 | 影响 | 解决方案 | 验证 |
| --- | --- | --- | --- | --- |
| I1 | `CaptureCardView.swift` 聚合所有卡片内容 | 新卡片冲突多，UI 维护成本高 | 按 card type 拆 view，保留 shared chrome | CaptureCardModelsTests + UI build |
| I2 | `UnifiedCaptureComposerView` 状态过多 | 输入扩展继续增加复杂度 | 抽 composer state view model 和 sheet coordinator | create/save focused tests |
| I3 | `ExternalCaptureWireModels.swift` 混合 wire model、Journaling bundle、attachment IO | shared contract 不纯，extension 编译负担变大 | 拆 wire、attachment store、inbox、bundle 文件 | ExternalCaptureInboxTests |
| I4 | `MoryAPIClient.swift` 聚合所有 endpoint | 网络层增长不可控 | 按 endpoint family 拆 extension | CloudIntelligenceClientTests + build |
| I5 | Debug 大文件 report/action/view 混合 | Debug 继续膨胀，难测 | 拆 formatter、view model、view | DebugCenterModelsTests |
| I6 | Go `handlers.go` / `sqlite.go` 过大 | server v8 扩展成本高 | 按 route/store concern 拆 | `go test ./...` |
| I7 | Proposal review 体验不足 | 用户不理解 AI 为什么建议 | evidence/impact preview +统一 ProposalReviewService | GraphDelta review tests |
| I8 | contact-to-person resolution 未产品化 | Journaling contacts 只能做 context，不能稳定进入人物关系 | 独立 identity review flow | EntityResolutionServiceTests + UI path |

## 3. Cleanup

| ID | 问题 | 影响 | 解决方案 | 验证 |
| --- | --- | --- | --- | --- |
| CL1 | Sentry upload script每次 build 运行 | 构建噪音和耗时 | 调整 run script dependency 或仅 archive/release 上传 | build log |
| CL2 | v7 docs 已多次追加状态 | 文档查找成本上升 | 保留 handbook 作为当前架构入口，v7 docs 作为历史 phase 记录 | docs link check |
| CL3 | Debug/Settings 入口较多 | 产品/内部功能边界模糊 | runtimeEnvironment gate + route grouping | debug visibility tests |
| CL4 | Analyzer compatibility types 未完全分离 | 新人误解 legacy/v7 边界 | 文件名和注释标清 legacy bridge | contract tests |

## 4. 推荐重构路线

### Batch 1: Repository Port Split

目标：

- 不改变行为。
- 只拆协议和注入类型。
- 让 service 和 UI 依赖更小端口。
- 当前状态：completed。Composite `MoryMemoryRepositorying` 暂时保留，用于 App environment、Settings、Debug 和全量能力入口。

步骤：

1. 新增 `RepositoryPorts` 文件组。
2. 从 `MoryMemoryRepositorying` 提取小协议。
3. `MoryMemoryRepository` 继续 conform 所有协议。
4. 逐步修改 service/view 构造参数，只接收需要的协议。
5. 测试 mock 改小。

验收：

- build 通过。
- 相关 focused tests 通过。
- `MoryMemoryRepositorying` 只保留组合用途或逐步删除。

### Batch 2: Analysis Pipeline Ports

目标：

- `ArchitecturePipelineExecutor` 不再直接 import SwiftData。

步骤：

1. 定义 query/persist/tracing ports。
2. Repository 实现 ports。
3. Pipeline 使用 ports 查询历史、保存结果。
4. 迁移 tests 到 mock ports。

验收：

- Pipeline unit tests 不需要 ModelContainer。
- v7 production create memory tests 仍通过。

### Batch 3: Domain Model Split

目标：

- `MemoryFeatureModels.swift` 拆成稳定领域文件。

步骤：

1. 只做 pure move。
2. 按 capture/library/search/graph/timeline/repository ports 拆。
3. 不改类型名，避免大范围业务变更。

验收：

- git diff 清晰。
- build 通过。
- 不做行为变更。

### Batch 4: Capture UI Split

目标：

- 降低 composer/card 冲突。

步骤：

1. Card content 按 type 拆文件。
2. Composer sheet state 抽 coordinator。
3. 保存路径不变。

验收：

- CaptureCardModelsTests 通过。
- 外部 capture / Journaling focused tests 通过。

### Batch 5: ExternalCaptureShared Pure Contract

目标：

- shared 模块职责清楚，App/Extension 共享更安全。

步骤：

1. 拆 wire models、attachment models、attachment store、Journaling bundle。
2. 保持 public type names。
3. 更新 imports 和 tests。

验收：

- Share Extension build 通过。
- ExternalCaptureInboxTests 通过。

### Batch 6: Server File Split

目标：

- Go server 为 v8 API 做准备。

步骤：

1. `handlers.go` 按 route 拆。
2. `sqlite.go` 按 store 拆。
3. provider 按 operation 拆。

验收：

- `GOCACHE=/tmp/mory-go-cache go test ./...` 通过。

## 5. 不建议马上做的事

- 不建议先做视觉 polish；当前最大风险是架构边界和 workflow 可维护性。
- 不建议继续盲目按行数拆所有文件；应优先拆协议、端口、事务职责。
- 不建议让 Journaling contact 自动进入 trusted person graph；应先做 review flow。
- 不建议让 AI proposal 自动 apply 高风险 graph/profile mutation。
- 不建议把 Debug recovery inbox 当成正式产品主入口。

## 6. 成功标准

未来架构健康应满足：

- 新 feature 可以只依赖 1-2 个小端口，而不是整个 repository。
- 新 capture source 只需实现 draft factory，不需要新 memory type。
- 新 AI proposal 只需扩展 proposal review pipeline，不直接写 trusted graph。
- 新 server endpoint 有独立 handler 和 contract test。
- Debug 能看到所有关键 payload，但不拥有业务事实。
