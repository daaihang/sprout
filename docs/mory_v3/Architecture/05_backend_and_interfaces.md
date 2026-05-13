# 05. Backend And Interfaces

## 1. 后端的真实定位

当前 Go 后端已经不是“纯无状态 AI 中转层”，但也不是重业务后端。  
它更准确的定位是：

> 轻状态认证与 AI 协调服务。

这一定义比旧架构更接近当前代码现实。

## 2. 当前后端已承担的职责

从当前代码看，后端已经负责：

- Apple 登录校验
- JWT 会话签发与刷新
- onboarding 完成态
- push token 注册
- AI 分析接口
- 默认订阅层级读取

因此架构文档中不能再把它描述成“完全不持有任何业务状态”。

## 3. 后端未来应承担的职责

### 3.1 必须承担

- 统一 AI provider 接入
- 分析协议版本化
- 认证与授权
- 轻量用户状态
- 推送注册与未来任务调度基础

### 3.2 可选择承担

- 远程 feature flags
- provider fallback 策略
- AI usage metering
- reflection batch generation

### 3.3 不应承担

- 用户完整私有内容主存储
- 首页 composition 的主真相层
- 大量与本地一致性强耦合的业务状态

## 4. 接口边界原则

接口设计必须围绕“统一记忆本体”演进。

### 4.1 当前问题

当前 `/api/records/analyze` 协议过窄，无法代表真实 record aggregate。

### 4.2 目标

接口应逐步升级为：

- `/api/analysis/records`
- `/api/reflections/generate`
- `/api/onboarding/analyze-preview`

注意：

不是为了 REST 命名美观，而是为了让“分析”和“记录持久化”边界清楚。

## 5. 推荐 API 分层

### 5.1 Auth API

- `POST /api/auth/apple`
- `POST /api/auth/refresh`

### 5.2 User State API

- `POST /api/onboarding/complete`
- `POST /api/push/register`
- `GET /api/subscription/status`

### 5.3 Analysis API

- `POST /api/analysis/records`
- `POST /api/analysis/preview`

### 5.4 Reflection API

未来可增加：

- `POST /api/reflections/generate`
- `POST /api/reflections/replay`

## 6. 协议版本化

AI 协议必须显式版本化。  
建议每个分析请求和响应都带：

- `schema_version`
- `client_version`
- `analysis_reason`

原因：

- prompt 和字段一定会迭代
- 客户端会跨版本存在
- 输出字段需要兼容老快照

## 7. 服务端数据边界

### 7.1 当前现实

后端已经持久化：

- push tokens
- user profiles / onboarding state

### 7.2 长期建议

继续维持“服务端只持轻状态”的原则，但要更诚实：

- 不再宣称绝对无状态
- 不接管用户完整内容库
- 对上行分析数据范围有明确说明

## 8. 安全与隐私原则

### 8.1 用户内容

如无必要，不在服务端长期保留原始私有内容。

### 8.2 AI 上行

应最小化上行数据，只发送分析所需聚合输入。

### 8.3 审计性

客户端应知道：

- 什么内容被发送
- 为什么发送
- 是否成功
- 得到了什么结构化结果

## 9. 后端演进建议

### 9.1 Phase 1

升级分析协议，不大改整体服务结构。

### 9.2 Phase 2

增加 reflection generation API 和 usage metering。

### 9.3 Phase 3

在不破坏本地优先的前提下，增加更强的异步任务能力。

## 10. 一个重要判断

Mory 的未来不是“把更多东西搬到后端”，而是：

- 用后端托管昂贵和统一的 AI 能力
- 让本地继续持有核心私有内容与主交互状态

这才符合产品承诺和当前工程基础。
