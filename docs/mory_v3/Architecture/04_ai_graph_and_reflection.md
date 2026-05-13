# 04. AI, Graph And Reflection

## 1. 当前 AI 层的核心问题

当前后端分析接口仍把“记录”主要视为文本内容。  
这对 demo 足够，但对真实产品不够。

原因：

- 实际记录已经是多模态聚合
- AI 输出没有稳定落库位置
- 长期关系和阶段理解没有中层结构
- 每次高层理解都可能被迫重读大量内容

因此必须把 AI、Graph、Reflection 一起设计，而不是孤立设计 prompt。

## 2. 三层能力划分

### 2.1 Analysis Layer

目标：快速看懂单次输入。  
输入单位：`Record Aggregate`。  
输出：`RecordAnalysisSnapshot`。

### 2.2 Graph Layer

目标：把稳定对象和关系写入长期语义层。  
输入单位：analysis result + deterministic signals。  
输出：entity nodes / edges / links。

### 2.3 Reflection Layer

目标：在已有结构之上生成高价值意义。  
输入单位：entities + arcs + grouped artifacts。  
输出：reflection snapshot。

## 3. Record Aggregate 输入协议建议

当前协议应从：

- `record.content`
- `persons[]`

升级为：

```json
{
  "schema_version": "record_aggregate.v1",
  "reason": "create|edit|manual|background",
  "record": {
    "id": "string",
    "created_at": "RFC3339",
    "updated_at": "RFC3339",
    "raw_text": "string",
    "user_mood": "string",
    "user_intensity": 3,
    "capture_source": "composer|voice|photo|import"
  },
  "artifacts": [],
  "known_entities": [],
  "context": {
    "location": {},
    "weather": {},
    "activity": {},
    "linked_decisions": []
  }
}
```

关键原则：

- 以聚合对象为输入，而不是只传一段文本
- 用户显式信息优先
- 多模态内容先文本化摘要，再统一分析

## 4. Analysis 输出建议

建议 `RecordAnalysisSnapshot` 包含：

- `summary`
- `themes`
- `emotion_interpretation`
- `salience_score`
- `retrieval_terms`
- `entity_mentions`
- `candidate_edges`
- `follow_up_candidates`
- `reflection_hint`

这些输出分成两类：

- 稳定结构：可以落库
- 表达性文案：可以展示，但不是唯一真相

## 5. Graph 更新策略

Graph 不应每次都靠大模型“重建人生图谱”。  
推荐策略：

1. 基础对象解析由 analysis 给出候选
2. 实体消歧由本地/规则/轻量服务辅助
3. 边权重主要由 deterministic 累积更新
4. 只有复杂关系解释才调用 AI

这样能把成本压住。

## 6. Entity 类型建议

第一阶段只建议做这些：

- `person`
- `place`
- `theme`
- `decision`

第二阶段再考虑：

- `project`
- `emotion_pattern`
- `life_phase`

## 7. Reflection 触发策略

Reflection 不应和每次 capture 强绑定。  
建议触发时机：

- 重要单条记录完成后
- 某实体近期频繁出现
- 某主题跨周重复出现
- 某阶段结束时
- 用户主动请求复盘时

## 8. Reflection 数据结构建议

建议 `ReflectionSnapshot` 至少包括：

- `id`
- `type`
- `source_record_ids`
- `source_artifact_ids`
- `source_entity_ids`
- `source_arc_ids`
- `title`
- `body`
- `evidence_summary`
- `confidence`
- `created_at`
- `dismissed_at`
- `saved_at`

## 9. AI 风格约束

Mory 中 AI 输出必须遵守：

- 不诊断
- 不夸张人格判断
- 不把单条记录上升为绝对结论
- 不为了“有洞察”而捏造模式

理想语气：

- 观察式
- 证据导向
- 保留余地
- 对用户有尊重

## 10. 本地与服务端职责分工

### 10.1 本地

- artifact 持久化
- deterministic 聚合
- graph 局部统计
- reflection 展示与状态管理

### 10.2 服务端

- 托管模型调用
- 分析协议演进
- 统一 prompt / provider 适配
- 可选的轻量聚合服务

## 11. 成本控制原则

必须坚持：

- 轻分析比深反思多
- 增量更新比全量重算多
- 结构化输出比 prose 优先
- deterministic 先行，AI 后置

否则随着数据积累，AI 成本会快速失控。
