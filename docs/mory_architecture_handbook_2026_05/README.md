# Mory 架构手册与全面审计 2026-05

本文档包基于当前仓库快照，对 Mory 的 iOS App、Share Extension、ExternalCaptureShared 共享合同和 Go server 做系统级架构审计。它不是 v8 PRD，也不是视觉 UI 方案；它的目标是把已经变大的 v7.6 架构重新梳理成可维护的模块边界、运行工作流、问题矩阵和重构路线。

## 审计范围

覆盖：

- `mory/mory`：iOS App 主工程。
- `mory/moryShareExtension`：Share Extension。
- `mory/ExternalCaptureShared`：App 与 Share Extension 共用的外部捕获 wire contract。
- `server`：Go 后端，包含 auth、AI、HTTP、SQLite、push notification。
- `docs/mory_v7` 和关键 v6 文档：用于校对目标是否偏离。

不覆盖：

- 旧 `sprout/` app。
- `sample_app/`。
- `public/`。
- 未跟踪的 `docs/mory-ios-app-ai-native-happy-treehouse.md`。

审计时工作树状态：mory 主工程无未提交修改，仅有上述无关未跟踪项。文档以当前磁盘代码为事实；当现有 v7 文档与当前代码存在表达差异时，以代码为准，并在问题矩阵中记录。

## 总体结论

Mory 当前已经形成了较清晰的分层方向：

- `Domain` 保存稳定业务模型和 repository 协议，不直接依赖 SwiftData 或 SwiftUI。
- `Infrastructure` 承接 AI、context collection、Journaling、Search、Notifications、Auth、Networking。
- `Persistence` 承接 SwiftData stores、mappers、repository 实现和 owner-scoped local data session。
- `Features` 承接正式 SwiftUI 页面和最小原生产品入口。
- `Debug` 承接开发期诊断、回放、测试触发和 payload inspection。
- `ExternalCaptureShared` 让 Share Extension 和 App 使用同一组 Codable payload。
- Go server 已有 `/api/analyze/v7`、provider、auth、push 和 SQLite persistence。

这说明 v7 的主方向没有偏离：Mory 正在从“单条记录分析器”走向“identity-aware long-term memory system”。真正的问题不再是“有没有模块”，而是：

1. 核心 repository 和 domain protocol 仍然过大。
2. 一些 workflow 已经横跨 Capture、Persistence、Analysis、Debug、Server，需要更明确的端口和事务边界。
3. Debug 和 UI 原生接入已经可用，但多个大 view 文件仍承担过多展示和诊断组装逻辑。
4. External Capture 与 Journaling 的 typed evidence 方向正确，但 shared contract 文件仍混合了 wire model、附件文件 IO 和 flatten 兼容接口。
5. Go server 可以支撑 v7，但 `handlers.go`、`sqlite.go`、provider 文件开始出现同类大文件风险。

## 严重问题摘要

| 严重度 | 问题 | 影响 | 建议 |
| --- | --- | --- | --- |
| Critical | `MoryMemoryRepositorying` 是超大协议，`MoryMemoryRepository` 仍是中心 God object | UI、Debug、Notification、Search、Graph、Capture 全部耦合到同一个仓库接口，测试和并行开发成本高 | 拆成 `RecordRepositorying`、`ProfileRepositorying`、`GraphRepositorying`、`ExternalCaptureRepositorying`、`DebugRepositorying` 等小端口 |
| Critical | `MemoryFeatureModels.swift` 聚合过多领域 | Capture、Library、Search、Graph、Timeline、Debug、Repository protocol 混在一个 Domain 文件 | 拆成业务模型包：Capture、Library、Search、GraphPresentation、RepositoryPorts |
| Important | `ArchitecturePipelineExecutor` 直接依赖 `ModelContext` | Analysis pipeline 和 SwiftData 查询绑定，难以独立测试、替换持久层或后台执行 | 引入 pipeline query/persistence port，由 repository 或 data session 注入 |
| Important | Capture card 与 Debug view 文件仍过大 | 新卡片类型和新诊断面板会持续制造冲突 | 按 card type 和 debug feature 拆 view + formatter |
| Important | `ExternalCaptureWireModels.swift` 混合合同和文件 IO | Share Extension 和 App 都依赖同一大文件，职责不够纯 | 拆成 wire models、attachment store、inbox models、Journaling bundle models |
| Cleanup | Go server 的 handler、SQLite、provider 文件变大 | 后续 v8/v9 API 会继续堆叠 | 按 route group、store concern、provider v7 path 拆文件 |

## 文档目录

1. [01 System Overview And Runtime Flows](01_system_overview_and_runtime_flows.md)
2. [02 Layer Boundaries And Dependency Audit](02_layer_boundaries_and_dependency_audit.md)
3. [03 iOS Module Inventory](03_ios_module_inventory.md)
4. [04 Persistence Repository And Data Model Audit](04_persistence_repository_and_data_model_audit.md)
5. [05 AI Intelligence Architecture Audit](05_ai_intelligence_architecture_audit.md)
6. [06 Capture Context And Journaling Audit](06_capture_context_and_journaling_audit.md)
7. [07 UI Debug And Settings Audit](07_ui_debug_and_settings_audit.md)
8. [08 Server Architecture Audit](08_server_architecture_audit.md)
9. [09 Problem Matrix And Refactor Roadmap](09_problem_matrix_and_refactor_roadmap.md)

## 推荐阅读顺序

如果只想把握系统全貌，先读：

1. `01_system_overview_and_runtime_flows.md`
2. `02_layer_boundaries_and_dependency_audit.md`
3. `09_problem_matrix_and_refactor_roadmap.md`

如果准备做代码重构，按这个顺序读：

1. `04_persistence_repository_and_data_model_audit.md`
2. `05_ai_intelligence_architecture_audit.md`
3. `06_capture_context_and_journaling_audit.md`
4. `07_ui_debug_and_settings_audit.md`

如果准备做服务端或云端 AI，读：

1. `05_ai_intelligence_architecture_audit.md`
2. `08_server_architecture_audit.md`
3. `09_problem_matrix_and_refactor_roadmap.md`

## 已接受的开发阶段临时形态

这些不是立即要修的错误，而是开发阶段可接受、但发布前要有计划的形态：

- UI 以原生 SwiftUI 最小接入为主，视觉 polish 不作为 v7 架构完成条件。
- Debug 页面可以比正式页面更直连 repository，但不能拥有 durable mutation semantics。
- External Capture 仍保留 debug/recovery inbox，正式路径应优先 handoff 到 composer。
- Journaling Suggestions 在真机能力、entitlement、系统建议稳定性上仍需要设备验证。
- Analyze v7 的 proposal-first 策略是正确边界，AI 输出不应直接变成 trusted graph。

## 验证建议

每次架构手册更新或相关代码重构后，至少运行：

```sh
git diff --check
jq empty mory/mory/Localizable.xcstrings
plutil -lint mory/mory/Info.plist mory/moryShareExtension/Info.plist
xcodebuild -project mory/mory.xcodeproj -scheme mory -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /tmp/mory-architecture-handbook-derived-data build
rm -rf /tmp/mory-architecture-handbook-derived-data
```

服务端相关改动后运行：

```sh
cd server
GOCACHE=/tmp/mory-go-cache go test ./...
rm -rf /tmp/mory-go-cache
```
