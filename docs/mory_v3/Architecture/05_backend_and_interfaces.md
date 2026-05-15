# 05. Backend And Interfaces

## 1. 后端定位

`Mory v3` 后端是：

> 轻状态认证与 AI 协调服务。

它负责统一模型调用、会话与少量账户状态，但不接管用户完整私有内容库。

## 2. 必须承担的职责

- Apple 登录校验
- JWT 会话签发与刷新
- 分析协议版本化
- AI provider 统一接入
- 轻量用户状态
- 推送注册与未来任务调度基础

## 3. 不应承担的职责

- 用户完整记忆主存储
- 首页 composition 主真相层
- 高频本地交互状态
- 需要强本地一致性的 board 结构

## 4. API 分层

### 4.1 Auth API

- `POST /api/auth/apple`
- `POST /api/auth/refresh`

### 4.2 User State API

- `POST /api/onboarding/complete`
- `POST /api/push/register`
- `GET /api/subscription/status`

### 4.3 Analysis API

These are the canonical paths used by `server/internal/http/server.go` and `server/openapi.yaml`.

- `POST /api/analysis/records`
- `POST /api/analysis/preview`

### 4.4 Reflection API

- `POST /api/reflections/generate`
- `POST /api/reflections/replay`

## 5. 协议版本化

每个分析请求和响应都应带：

- `schema_version`
- `client_version`
- `analysis_reason`

## 6. 隐私与数据边界

1. 原始私有内容尽量不在服务端长期保留。
2. 上行只发送分析所需聚合输入。
3. 客户端必须可解释“发送了什么、为什么发送、得到了什么结果”。

## 7. 长期原则

Mory 的未来不是把更多东西搬到后端，而是：

- 用后端托管昂贵且统一的 AI 能力
- 让本地继续持有核心私有内容与主交互状态
