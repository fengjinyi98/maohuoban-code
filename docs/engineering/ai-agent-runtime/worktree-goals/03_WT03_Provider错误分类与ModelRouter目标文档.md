# WT-03 Provider 错误分类与 Model Router 目标文档

- 更新时间：2026-06-28
- Goal：建立 Provider Error Taxonomy 和 Model Router，让未配置、超时、限流、上游失败、流式中断、响应格式错误能被统一分类，并支持 `lite` / `primary` / `pro` / `memory` 模型标签路由。
- 执行方式：TDD；只改 Provider / ModelRouter 相关 domain、application port、infrastructure provider，不改 Tool、HTTP、iOS、数据库。

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| Provider 错误 | 属于系统失败态，不能伪装成普通助手回答 |
| 用户文案 | 对用户统一显示 `暂时无法获取回答，请稍后重试。`，内部保留分类 |
| Model Router | 用 label 表达能力层级，避免业务直接引用具体 provider model |
| 重试策略 | 按错误分类决定 retryable，首期只定义分类和测试，不做复杂 fallback 平台 |

## 2. 目标边界

### 2.1 本目标期必须完成

| 范围 | 目标 |
|---|---|
| 错误分类 | 新增或扩展 Provider error category |
| 错误映射 | OpenAI compatible provider 将 HTTP status、超时、SSE 解析失败映射到 category |
| Model Router | 根据 label 返回 configured model，未配置返回稳定错误 |
| 测试 | 覆盖未配置、401/429/500、超时、invalid SSE、label route |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 多 Provider 灰度平台 | 后续独立目标 |
| 复杂 fallback | 首期只定义 taxonomy 和 route |
| 前端重试 UI | WT-05 负责 |
| Eval 统计 | WT-06 负责 |

## 3. 依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| 当前错误 | `maohuoban-rust/crates/maohuoban-ai-domain/src/ai/error.rs` | 已有 `ProviderNotConfigured`、`ProviderRequestFailed`、`ProviderStreamError` |
| 当前 Provider | `maohuoban-rust/crates/maohuoban-ai-infrastructure/src/Infrastructure/provider/openai_compatible.rs` | 已接 OpenAI compatible provider |
| 当前测试 | `maohuoban-rust/crates/maohuoban-ai-infrastructure/tests/openai_compatible.rs` | 可扩展错误映射测试 |
| Anda 参考 | `references/agent/anda` | model label routing 可借鉴 |

## 4. 推荐数据流

```text
ModelRouter.resolve("primary")
  -> Provider config / env
  -> LlmChatRequest.model
  -> OpenAiCompatibleLlmProvider
  -> ProviderErrorCategory
  -> AgentEvent::provider_error
```

## 5. 允许修改

| 文件 / 模块 | 要求 |
|---|---|
| `maohuoban-rust/crates/maohuoban-ai-domain/src/ai/model/provider_error.rs` | 新增 provider 错误分类类型 |
| `maohuoban-rust/crates/maohuoban-ai-application/src/ai/model_router/` | 新增 ModelRouter |
| `maohuoban-rust/crates/maohuoban-ai-application/src/ai/ports/llm.rs` | 只做必要 additive 类型调整 |
| `maohuoban-rust/crates/maohuoban-ai-infrastructure/src/Infrastructure/provider/` | 错误映射和 model label config |
| `maohuoban-rust/crates/maohuoban-ai-infrastructure/tests/openai_compatible.rs` | 扩展测试 |

## 6. 禁止修改

| 文件 / 模块 | 原因 |
|---|---|
| `maohuoban-ai-application/src/ai/tools*` | WT-02 负责 |
| `maohuoban-ai-http` | WT-05 负责 |
| `migrations/` | WT-04 负责 |
| iOS AI 目录 | WT-05 负责 |

## 7. TDD 任务拆分

### Task 1：Provider error taxonomy

| 项 | 内容 |
|---|---|
| 目标 | 分类表达 Provider 错误并决定 retryable |
| 前置依赖 | 无 |
| 回归验证 | `cargo test -p maohuoban-ai-domain provider_error` |

#### Slice 1.1：错误分类 roundtrip

| 项 | 要求 |
|---|---|
| 行为目标 | `not_configured`、`timeout`、`rate_limited`、`upstream`、`stream_interrupted`、`invalid_response` 可 serde roundtrip |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-domain/tests/provider_error_roundtrip.rs` |
| 允许修改 | `maohuoban-ai-domain/src/ai/model/provider_error.rs` 和 additive export |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-domain provider_error_roundtrip` |
| 回归命令 | `cargo test -p maohuoban-ai-domain provider_error` |
| 完成证据 | 记录分类和 retryable 断言 |
| 停止条件 | 需要改 HTTP response 时停止 |

### Task 2：OpenAI compatible 错误映射

| 项 | 内容 |
|---|---|
| 目标 | HTTP / SSE / timeout 错误映射到 Provider category |
| 前置依赖 | Task 1 |
| 回归验证 | `cargo test -p maohuoban-ai-infrastructure openai_compatible` |

#### Slice 2.1：429 和 5xx 映射

| 项 | 要求 |
|---|---|
| 行为目标 | 429 -> `rate_limited`，5xx -> `upstream`，invalid SSE -> `invalid_response` |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-infrastructure/tests/openai_compatible.rs` |
| 允许修改 | `maohuoban-ai-infrastructure/src/Infrastructure/provider/*` |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-infrastructure openai_compatible_maps_provider_errors` |
| 回归命令 | `cargo test -p maohuoban-ai-infrastructure openai_compatible` |
| 完成证据 | 记录 mock server status 和 category 断言 |
| 停止条件 | 需要改应用层 pipeline 时停止 |

### Task 3：Model Router

| 项 | 内容 |
|---|---|
| 目标 | label 到 model config 的稳定解析 |
| 前置依赖 | 无 |
| 回归验证 | `cargo test -p maohuoban-ai-application model_router` |

#### Slice 3.1：label route

| 项 | 要求 |
|---|---|
| 行为目标 | `primary` 可解析默认模型；未知 label 返回稳定错误 |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-application/tests/model_router.rs` |
| 允许修改 | `maohuoban-ai-application/src/ai/model_router/*` |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-application model_router_resolves_labels` |
| 回归命令 | `cargo test -p maohuoban-ai-application model_router` |
| 完成证据 | 记录 `lite` / `primary` / unknown 断言 |
| 停止条件 | 需要新增配置文件格式时停止，首期只做 in-memory config |

## 8. 验收门禁

| 类型 | 命令 / 验收 |
|---|---|
| Domain | `cargo test -p maohuoban-ai-domain provider_error` |
| Application | `cargo test -p maohuoban-ai-application model_router` |
| Infrastructure | `cargo test -p maohuoban-ai-infrastructure openai_compatible` |
| 构建 | `cargo check -p maohuoban-ai-domain -p maohuoban-ai-application -p maohuoban-ai-infrastructure` |

## 9. 不变约束

| 约束 | 说明 |
|---|---|
| 密钥安全 | 错误、日志、测试输出不能包含 API key |
| 用户文案 | Provider 详细错误只进诊断，用户文案保持统一 |
| Provider 解耦 | Domain / Application 不依赖 reqwest 或 OpenAI DTO |

## 10. 风险

| 风险 | 处理 |
|---|---|
| 错误分类过细 | 首期只保留 6 个大类，后续通过诊断扩展 |
| ModelRouter 变配置平台 | 首期 in-memory / env 映射，灰度后续独立目标 |
