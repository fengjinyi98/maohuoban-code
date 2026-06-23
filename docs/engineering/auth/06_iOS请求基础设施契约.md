# iOS 请求基础设施契约

## 1. 目标

本文记录 iOS `MHBHTTPClient` 与后端 HTTP middleware 的请求链路约定。目标是让客户端诊断、后端日志、网关日志和错误反馈可以通过同一组标识串联。

## 2. 请求头约定

| Header | 方向 | 生成方 | 规则 |
|---|---|---|---|
| `x-request-id` | iOS -> 后端 | iOS HTTP client | 每次请求没有显式值时自动生成 UUID；已有值必须保留 |
| `traceparent` | iOS -> 后端 | iOS HTTP client | 遵循 W3C Trace Context 形态：`00-{trace-id}-{span-id}-01`；已有值必须保留 |
| `Authorization` | iOS -> 后端 | authenticated HTTP client | 登录态接口统一注入 `Bearer <access_token>`；业务 Repository 不再手动拼接 |
| `Idempotency-Key` | iOS -> 后端 | iOS HTTP client | `POST` / `PATCH` / `DELETE` 没有显式值时自动生成 UUID；同一次重试保持不变 |
| `x-maohuoban-user-id` | iOS -> 后端 | 业务 Repository | 过渡期业务上下文 header；后续后端完成鉴权收敛后由 access token 解析用户身份 |

## 3. 响应头约定

| Header | 方向 | 生成方 | 规则 |
|---|---|---|---|
| `x-request-id` | 后端 -> iOS | 后端 middleware | 后端必须回写最终 request id；iOS 诊断记录为 `response_request_id` |

## 4. 诊断日志约定

| 字段 | 来源 | 规则 |
|---|---|---|
| `request_id` | 请求 `x-request-id` | 记录客户端请求 id |
| `response_request_id` | 响应 `x-request-id` | 记录后端回写 request id |
| `traceparent` | 请求 `traceparent` | 记录跨端 trace |
| URL | 请求 URL | 诊断日志中的敏感 query 值必须脱敏 |

敏感 query key 包括：`access_token`、`authorization`、`code`、`id_token`、`lat`、`latitude`、`lng`、`location`、`longitude`、`password`、`phone`、`refresh_token`、`token`。

## 5. Retry 与 refresh

| 场景 | iOS 行为 |
|---|---|
| 传输错误 | 仅对可分类的短暂网络错误重试 |
| HTTP `408` / `429` / `500` / `502` / `503` / `504` | 仅对幂等安全请求重试 |
| 写请求重试 | 必须带 `Idempotency-Key`，并在重试中保持同一个值 |
| HTTP `401 auth.session_expired` / `auth.token_invalid` | authenticated HTTP client 自动 refresh 一次，并重放原请求 |
| 并发 401 | token refresh 通过单飞协调器合并，只发起一次 refresh |

## 6. iOS 验证覆盖

| 测试 | 覆盖 |
|---|---|
| `MHBHTTPClientRequestInfrastructureTests` | request id、traceparent、响应 request id、专用 session、Auth 中间件、query 脱敏、retry、幂等键、token refresh 单飞和请求重放 |
| Repository 契约测试 | Home、SameCity、Merchant、Pet、Profile、Settings 仓储均通过 authenticated client 注入 Authorization |
