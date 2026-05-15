# 04. AI, Graph And Reflection

## 1. 三层能力划分

### 1.1 Analysis Layer

输入单位：`Record Aggregate`

输出对象：`RecordAnalysisSnapshot`

目标：快速理解单次 capture 及其关联 artifacts。

### 1.2 Graph Layer

输入单位：analysis result + deterministic signals

输出对象：

- `EntityNode`
- `EntityEdge`
- `ArtifactEntityLink`

目标：沉淀长期稳定对象与关系。

### 1.3 Reflection Layer

输入单位：entities + arcs + grouped artifacts

输出对象：`ReflectionSnapshot`

目标：生成高价值意义层解释。

## 2. Record Aggregate 输入协议

```json
{
  "schema_version": "record_aggregate.v1",
  "analysis_reason": "capture_ingest|edit|manual|background",
  "record_shell": {
    "id": "string",
    "created_at": "RFC3339",
    "updated_at": "RFC3339",
    "raw_text": "string",
    "user_mood": "string",
    "user_intensity": 3,
    "capture_source": "composer|voice|photo|import",
    "input_context": "string"
  },
  "artifacts": [],
  "known_entities": []
}
```

关键原则：

- 以聚合对象为输入
- 用户显式信息优先
- 多模态内容先结构化，再统一分析

## 3. Analysis 输出建议

`RecordAnalysisSnapshot` 至少包括：

- `summary`
- `themes`
- `emotionInterpretation`
- `salienceScore`
- `retrievalTerms`
- `entityMentions`
- `candidateEdges`
- `followUpCandidates`
- `reflectionHint`

## 4. Graph 更新策略

1. analysis 给出候选实体和候选关系
2. 本地进行实体消歧与规则累积
3. 边权重通过 deterministic 统计更新
4. 复杂解释只在需要时调用 AI

当前第一版治理字段包括：

- `EntityNode.aliases`
- `EntityNode.provenanceRecordIDs`
- `ArtifactEntityLink.sourceRecordID`
- `ArtifactEntityLink.sourceAnalysisRecordID`
- `ArtifactEntityLink.evidenceSummary`

当前 diagnostics 正式语义包括：

- `analysis_reason` 作为请求原因字段进入 analysis contract
- pipeline trace 至少保留 request body、response body、raw error body、failed stage、status code
- provenance diagnostics 至少保留 entity aliases、provenance record ids、artifact links、analysis evidence

## 5. Temporal Arc

`TemporalArc` 用于把离散 record 与 artifact 组织为阶段对象。

它至少需要：

- 标题
- 摘要
- 状态
- 时间范围
- source record ids
- source artifact ids
- source entity ids
- linked reflection id

## 6. Reflection 触发策略

建议触发时机：

- 重要单条记录完成后
- 某实体近期高频出现
- 某主题跨周重复出现
- 某阶段收束时
- 用户主动请求复盘时

## 7. AI 风格约束

Mory 中 AI 输出必须：

- 证据导向
- 语气克制
- 不做诊断
- 不捏造模式
- 明确保留不确定性

## 8. 本地与服务端分工

本地负责：

- artifact 持久化
- graph 累积
- arc 管理
- reflection 状态管理

服务端负责：

- 模型调用
- 协议版本化
- prompt 管理
- 统一 provider 适配

debug diagnostics 的正式边界：

- 客户端 diagnostics 页面优先展示本地持久化的 pipeline trace
- 无 trace 时才允许展示 reconstructed fallback
- diagnostics 的目标是排查失败点，不是替代正式业务对象
