# 毛球AgentProvider能力协议目标文档

- 更新时间：2026-06-30
- Goal：定义毛球 Agent 的 `Provider Capability Contract`，明确哪些协议层在所有 provider 间统一，哪些能力按 `provider profile` 单独适配，并把 `DeepSeek` 放在正确的位置上
- 执行方式：先目标文档后实现；坚持“工具协议统一、provider capability 单独适配”，不为单个厂商再发明一整套 Agent 协议

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| Provider 是否需要单独适配 | 需要 |
| 适配的层在哪 | 在 `Provider Capability / Provider Profile` 层，不在工具协议层 |
| 工具协议是否按厂商分叉 | 不应该 |
| 最佳实践 | 保持内部 `LlmChatRequest / LlmToolSchema / LlmToolCall / LlmStreamEvent` 稳定，由 provider adapter 自己转换 |
| DeepSeek 应放哪里 | `DeepSeek` 应作为 `OpenAI-compatible family` 下的单独 profile，而不是单独一套工具协议 |
| 当前毛球现状 | 已有 `OpenAiCompatibleLlmProvider`、`DeepSeekLlmProvider`、`ModelRouter`、`SseStreamDecoder`、`ProviderErrorCategory`，方向正确，但还没把 capability 文档化 |

## 2. 目标边界

### 2.1 本目标期必须明确

| 范围 | 目标 |
|---|---|
| 统一协议层 | 明确哪些结构在所有 provider 间保持一致 |
| Provider Profile | 明确每个 provider/profile 可以声明哪些能力 |
| 请求能力 | 明确 `response_format / reasoning / tool_choice / max_tokens` 是否支持 |
| 流式能力 | 明确 `delta / reasoning_delta / tool_call_delta / finish / usage` 的支持面 |
| 错误分类 | 明确 provider 错误如何统一映射 |
| 预算能力 | 明确 context / output / compression threshold 的 provider profile 配置方式 |
| DeepSeek 定位 | 明确它是 profile，而不是第二套工具协议 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 多厂商全量接入 | 当前先把 `openai_compatible` 与 `deepseek` 立住 |
| provider 自动打分路由 | 后续再做模型路由策略 |
| 真正的 fallback 编排策略 | 当前先定义 capability，不直接做完整故障切换编排 |

## 3. 依据

### 3.1 项目内依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| Provider 配置层 | `maohuoban-ai-infrastructure/src/Infrastructure/provider/config.rs` | 当前已经把 `LlmProviderKind` 分成 `OpenAiCompatible` 和 `DeepSeek` |
| DeepSeek Provider | `maohuoban-ai-infrastructure/src/Infrastructure/provider/deepseek.rs` | 当前 `DeepSeekLlmProvider` 明确复用 `OpenAiCompatibleLlmProvider` |
| Request Body | `maohuoban-ai-infrastructure/src/Infrastructure/provider/openai_body.rs` | 当前内部请求会统一映射到 OpenAI-compatible body |
| Non-stream Parse | `maohuoban-ai-infrastructure/src/Infrastructure/provider/openai_response.rs` | 当前可统一解析 `content / reasoning_content / tool_calls / finish_reason` |
| Stream Parse | `maohuoban-ai-infrastructure/src/Infrastructure/provider/sse.rs` | 当前可统一解析 `content delta / reasoning_content / tool_calls / finish_reason / usage` |
| Request Policy | `maohuoban-ai-infrastructure/tests/openai_request_policy.rs` | 当前已明确 provider 不应偷偷覆盖 request 级 temperature/json/token limit |
| DeepSeek 测试 | `maohuoban-ai-infrastructure/tests/deepseek.rs` | 当前已证明 DeepSeek 复用 OpenAI-compatible 协议，并有自己 profile 特性 |
| Error Taxonomy | `OpenAiCompatibleLlmProvider::map_status_error/map_request_error` | 当前已有 `NotConfigured / RateLimited / Timeout / Upstream / InvalidResponse / StreamInterrupted` 等统一分类 |

### 3.2 参考实现依据

| 参考项目 | 启发 |
|---|---|
| `pi` | 统一工具协议，不同 provider adapter 各自映射 Anthropic / OpenAI / Google |
| `openclaw` | 工具协议薄，provider replay / reasoning / sanitizing 单独做 |
| `hermes-agent` | 工具 schema 统一是 OpenAI-format，provider 路由与能力差异由运行时另管 |

## 4. Provider 能力协议的目标

### 4.1 统一层 vs 可变层

| 层 | 是否统一 | 说明 |
|---|---|---|
| `LlmChatRequest` | 统一 | Runtime 只认识这一层 |
| `LlmToolSchema` | 统一 | 工具协议不按 provider 分叉 |
| `LlmToolCall` | 统一 | 模型申请工具的稳定内部表示 |
| `LlmChatResponse` | 统一 | 非流式响应统一收口 |
| `LlmStreamEvent` | 统一 | 流式事件统一收口 |
| `Provider Profile` | 可变 | 每个厂商声明自己支持什么 |
| `Body/Chunk Parser` | 可变 | 每个厂商 adapter 负责转换 |

### 4.2 为什么要这样拆

| 原因 | 说明 |
|---|---|
| 避免 Runtime 被厂商绑死 | loop/request/tool/finalizer 都应只依赖统一协议 |
| 避免工具协议分叉 | 模型对函数调用的训练分布本来就是主流 schema |
| 厂商差异真实存在 | reasoning、json output、tool delta、finish_reason 的确不同 |
| 测试更清晰 | 统一协议做 contract test，profile 做 provider-specific test |

## 5. Provider Profile 应该声明什么

建议抽象一个 profile：

| 维度 | 说明 |
|---|---|
| `family` | `openai_compatible` / `anthropic_native` / 未来其他 |
| `supports_tool_calling` | 是否支持 function/tool call |
| `supports_streaming` | 是否支持流式 |
| `supports_reasoning_content` | 是否支持 reasoning_content 或同等字段 |
| `supports_response_format_json` | 是否支持 `response_format` |
| `supports_request_max_output_tokens` | 是否支持请求级输出上限 |
| `supports_request_tool_choice` | 是否支持 `tool_choice` |
| `supports_eager_tool_delta` | 是否能在流式中逐步发出 tool_call 参数片段 |
| `supports_usage_in_finish` | finish 事件是否带 usage |
| `requires_sanitized_tool_schema` | 是否要求 schema 额外裁剪 |
| `preferred_history_budget` | 建议上下文预算 |
| `preferred_output_budget` | 建议输出预算 |
| `error_mapping_policy` | 状态码 / chunk / body 如何映射错误 |

## 6. 毛球当前统一协议层

当前内部稳定协议已经基本具备：

| 类型 | 当前文件 | 说明 |
|---|---|---|
| `LlmChatRequest` | `maohuoban-ai-domain/src/ai/model/llm.rs` | Runtime 对 provider 的统一输入 |
| `LlmToolSchema` | 同上 | 工具 schema 统一层 |
| `LlmToolCall` | 同上 | 模型工具调用统一层 |
| `LlmChatResponse` | 同上 | 非流式统一层 |
| `LlmStreamEvent` | 同上 | 流式统一层 |

这意味着：
- **工具协议已经不该再按 provider 分叉**
- provider 只需要把自己的 body/chunk 映射回来

## 7. OpenAI-compatible Profile

### 7.1 基本能力

| 能力 | 当前状态 |
|---|---|
| `messages` | 支持 |
| `tools` | 支持 |
| `tool_choice` | 支持 |
| `response_format` | 支持，但是否启用由 request 决定 |
| `max_tokens` | 支持 |
| `reasoning_content` | 当前已透传支持 |
| `stream` | 支持 |
| `tool_calls` 流式 delta | 支持，靠 `SseStreamDecoder` 聚合 |

### 7.2 当前设计约束

| 约束 | 依据 |
|---|---|
| provider 默认值不能覆盖 request 级策略 | `openai_request_policy.rs` 已测试覆盖 |
| `response_format` 只有 request 明确要求时才发 | 同上 |
| `tool_calls` 流式片段需要聚合 | `sse.rs` |
| `reasoning_content` 是能力，不是强制字段 | `openai_response.rs` / `sse.rs` |

## 8. DeepSeek Profile

### 8.1 正确定位

| 问题 | 结论 |
|---|---|
| DeepSeek 是不是独立工具协议 | 不是 |
| DeepSeek 是不是独立 provider profile | 是 |
| 当前代码是不是已经这么做 | 是 |

证据：
[deepseek.rs](/Users/fengjinyi/Developer/maohuoban-code/maohuoban-rust/crates/maohuoban-ai-infrastructure/src/Infrastructure/provider/deepseek.rs)

### 8.2 当前 DeepSeek 已知特性

| 能力 | 当前测试结论 |
|---|---|
| 协议面 | 走 OpenAI-compatible `/v1/chat/completions` |
| `response_format` | 当前 profile 默认不强制注入 |
| `max_output_tokens` | 当前 profile 默认不强制注入 |
| `reasoning_content` | 支持流式 delta |
| `tool_calls` 流式 | 支持，且会分片发送 arguments |
| finish_reason | 会返回 `tool_calls` |

证据：
[deepseek.rs 测试](/Users/fengjinyi/Developer/maohuoban-code/maohuoban-rust/crates/maohuoban-ai-infrastructure/tests/deepseek.rs)

### 8.3 为什么需要单独 profile

| 原因 | 说明 |
|---|---|
| JSON output 行为不稳定 | 不能默认强制 `response_format` |
| tool delta 行为有自己节奏 | 需要专门 parser/测试保护 |
| reasoning 字段存在特性差异 | 要单独声明支持面 |
| 预算策略可能不同 | context/output/compression 阈值以后要单列 |

## 9. 请求能力协议

### 9.1 必须由 request 决定，不由 provider 默认偷改

| 字段 | 原则 |
|---|---|
| `temperature` | 以 request 为准 |
| `response_format` | 以 request 为准 |
| `max_output_tokens` | 以 request 为准 |
| `tool_choice` | 以 request 为准 |

当前这条原则已经正确：
[openai_request_policy.rs](/Users/fengjinyi/Developer/maohuoban-code/maohuoban-rust/crates/maohuoban-ai-infrastructure/tests/openai_request_policy.rs)

### 9.2 provider 默认值只做什么

| 允许 | 不允许 |
|---|---|
| base_url | 强行改写 request response_format |
| default model route | 强行改写 request max tokens |
| timeout | 强行给某个厂商硬塞 JSON 输出 |

## 10. 流式能力协议

### 10.1 内部统一事件

| 事件 | 说明 |
|---|---|
| `Delta` | 正文文本增量 |
| `ReasoningDelta` | 推理文本增量 |
| `ToolCall` | 已聚合完成的工具调用 |
| `Finish` | 结束原因和 usage |
| `Error` | provider 流错误 |

### 10.2 provider parser 负责的事

| 任务 | 说明 |
|---|---|
| 聚合 tool call 参数分片 | 例如 DeepSeek/OpenAI-compatible SSE |
| 映射 finish_reason | `stop/length/tool_calls/...` |
| 映射 reasoning 字段 | `reasoning_content` 或其他厂商字段 |
| 把无效 chunk 归类为 `InvalidResponse` | 不把厂商噪音扩散到上层 |

## 11. 错误分类协议

建议统一保持当前分类体系：

| 类别 | 含义 |
|---|---|
| `NotConfigured` | key/base_url/model route 问题 |
| `RateLimited` | 429 或额度限制 |
| `Timeout` | 请求超时 |
| `Upstream` | 厂商 5xx 或上游异常 |
| `InvalidResponse` | body/chunk/tool_calls 结构错误 |
| `StreamInterrupted` | 流式中断 |

provider profile 只负责：
- 如何识别
- 如何映射

而不是自己发明第二套错误枚举。

## 12. 预算与压缩能力协议

### 12.1 不写死在全局

| 项 | 原则 |
|---|---|
| context 上限 | profile 声明 |
| 输出预算 | profile 声明 |
| 触发压缩阈值 | 基于 profile 声明的建议值 |

### 12.2 对 DeepSeek 的直接含义

| 项 | 建议 |
|---|---|
| `ContextBudgetPolicy` | 应支持 `default_for_deepseek_*` 这类 profile 预算入口 |
| `SessionSummaryCompressor` | 应按 provider profile 选择是否更早压缩 |
| `AgentRuntimeRequestPolicy` | 以后可根据 profile 决定最终回答阶段是否禁用某些 request 字段 |

## 13. 对毛球当前实现的直接要求

| 要求 | 说明 |
|---|---|
| 新增 `ProviderCapabilityContract` 文档对应的领域抽象 | 统一描述 provider profile |
| `DeepSeek` 保持为独立 profile | 不升级成独立工具协议 |
| `OpenAiCompatibleLlmProvider` 保持统一请求/响应入口 | family 统一层 |
| provider-specific 差异继续只放在 adapter / parser / config | 不渗透进 tool/runtime/finalizer |
| 后续新增厂商时先写 capability profile 测试 | 先 contract 再接入 |

## 14. 不变约束

| 约束 | 说明 |
|---|---|
| 工具协议不按 provider 分叉 | 继续使用统一 `LlmToolSchema/LlmToolCall` |
| provider 可以有独立 profile | 但只影响 adapter/capability 层 |
| request 优先级高于 provider 默认值 | 不让厂商配置偷偷覆盖 runtime 策略 |
| DeepSeek 特调不写到业务链路 | 只能写到 provider profile / parser / request shaping |

## 15. 风险

| 风险 | 处理 |
|---|---|
| 把 DeepSeek 变成第二套协议 | 会导致 runtime/tool/finalizer 分叉，后续维护失控 |
| provider 默认值覆盖 request | 会让同一个 runtime 行为不可预测 |
| stream parser 不做 profile 保护 | tool_call / reasoning / finish_reason 容易回归 |
| 预算策略不按 profile 配 | 某些厂商的压缩和输出稳定性会继续脆弱 |

