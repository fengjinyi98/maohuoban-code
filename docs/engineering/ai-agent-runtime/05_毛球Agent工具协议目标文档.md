# 毛球Agent工具协议目标文档

- 更新时间：2026-06-30
- Goal：定义符合主流大模型训练分布与 Agent 最佳实践的毛球工具协议，明确模型侧工具协议与运行时侧工具协议的分层边界，避免自创怪协议
- 执行方式：先目标文档后实现；模型侧协议对齐 OpenAI / Anthropic 主流函数调用形态，运行时侧保留毛球自己的策略、权限、事实、进度与审计元数据

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 总原则 | 不自己发明一套给模型看的工具协议 |
| 最佳实践 | 模型侧统一收敛到 `name + description + JSON Schema parameters/input_schema + tool_call_id + arguments + tool_result` |
| 毛球该怎么做 | 保持双层协议：`模型侧工具协议` 对齐主流，`运行时工具协议` 保留毛球自己的安全与业务元数据 |
| 当前毛球现状 | 已经有 `LlmToolSchema`、`LlmToolCall`、`ToolRegistry`、`AiToolDefinition`、`AiToolMetadata`、`AiToolResult`，方向是对的 |
| 当前主要问题 | 模型协议层和运行时协议层还没有在文档上正式拆开 |
| 直接结论 | `05` 的目标不是发明新协议，而是**固定边界**：什么给模型看，什么只留在 Runtime |

## 2. 目标边界

### 2.1 本目标期必须明确

| 范围 | 目标 |
|---|---|
| 模型侧工具协议 | 明确对齐 OpenAI / Anthropic / OpenAI-compatible 的最小工具字段集合 |
| 运行时侧工具协议 | 明确毛球特有的 scope、风险、确认、事实、进度等字段放哪一层 |
| 工具注册协议 | 明确工具如何注册、发现、过滤、暴露 |
| 工具调用协议 | 明确模型发起的 tool call 如何进入 Tool Gateway |
| 工具结果协议 | 明确 tool result 如何回灌模型、如何进入 transcript / event / audit |
| 工具发现协议 | 明确什么时候给模型全量 schema，什么时候只给摘要或按需展开 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| MCP 完整接入协议 | 后续可做，但本期先把毛球自有工具协议立住 |
| 用户自定义工具平台 | 当前底层先只支持工程内注册 |
| 多模型专属特调 prompt hack | 应该纳入 provider capability/profile，不写进工具协议层 |

## 3. 依据

### 3.1 参考项目依据

| 参考项目 | 模型侧协议 | 运行时侧协议 |
|---|---|---|
| `codex` | `ToolDefinition { name, description, input_schema }` | `ToolCall { turn_id, call_id, tool_name, payload, environment, history }` |
| `pi` | `Tool { name, description, parameters }`，Anthropic 转 `input_schema`，OpenAI 转 `function.parameters` | `beforeToolCall / afterToolCall / ToolResultMessage / ToolExecutionMode` |
| `openclaw` | `ToolProtocolDescriptor { name, description, inputSchema }` | `ToolDescriptor` 分出 `owner / executor / availability / outputSchema / annotations` |
| `hermes-agent` | 明确返回 OpenAI-format tool schemas：`{type:function,function:{...}}` | registry 保留 `toolset / schema / handler / check_fn / dynamic_schema_overrides` |
| `package` | 输入严格 JSON Schema 化，调用围绕 `call_id/task_id/arguments` | background/isolation/team/permission 等运行时控制面元数据另存 |

### 3.2 项目内依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| 模型侧 schema | `maohuoban-ai-domain/src/ai/model/llm.rs` | 已有 `LlmToolSchema { name, description, parameters }` 与 `LlmToolCall { id, name, arguments }` |
| Request 投影 | `maohuoban-ai-application/src/ai/runtime/agent_runtime_request_policy.rs` | 当前会把 `ToolRegistry` 定义映射成模型可见 `LlmToolSchema` |
| OpenAI 兼容适配 | `maohuoban-ai-infrastructure/src/Infrastructure/provider/openai_body.rs` | 当前已按主流 `type=function / function.name / function.description / function.parameters` 组装请求 |
| 工具定义 | `maohuoban-ai-application/src/ai/tools/definition.rs` | 当前 `AiToolDefinition` 已分离 `parameters_schema()` 和 `metadata()` |
| 运行时元数据 | `maohuoban-ai-application/src/ai/tools/metadata.rs` | 当前已持有 `scope / read_only / concurrency_safe / risk_level / requires_confirmation / toolset / progress_text / result_fact_schema` |
| 工具结果 | `maohuoban-ai-application/src/ai/tools/result.rs` | 当前已分离 `allowed / denied / failed / requires_confirmation / facts / citations / returned_ref_ids / failure` |
| 工具装配 | `maohuoban-ai-http/src/Infrastructure/ai/router/chat/runtime_tools.rs` | 当前请求级 Tool Gateway 已存在 |

## 4. 推荐协议分层

### 4.1 双层协议

| 层 | 名称 | 面向谁 | 目的 |
|---|---|---|---|
| L1 | 模型侧工具协议 | 大模型 / provider | 让模型知道能调用什么、怎么传参 |
| L2 | 运行时侧工具协议 | Tool Gateway / Policy / UI / Audit | 控制工具真实执行、安全、事实回灌和观测 |

### 4.2 为什么必须双层

| 原因 | 说明 |
|---|---|
| 模型训练分布要对齐主流 | 模型最熟悉 OpenAI/Anthropic 风格函数调用 |
| 运行时需求更复杂 | scope、确认、并发、安全、事实 schema 不是模型协议字段 |
| 避免污染模型输入 | 把过多内部字段暴露给模型，会降低工具调用稳定性 |
| 避免运行时能力被模型协议绑死 | 模型侧保持薄，运行时才有演化空间 |

## 5. 模型侧工具协议

### 5.1 标准形态

建议毛球内部的稳定模型侧工具协议就是：

```rust
pub struct LlmToolSchema {
    pub name: String,
    pub description: String,
    pub parameters: serde_json::Value,
}

pub struct LlmToolCall {
    pub id: String,
    pub name: String,
    pub arguments: String,
}
```

这与你们当前 [llm.rs](/Users/fengjinyi/Developer/maohuoban-code/maohuoban-rust/crates/maohuoban-ai-domain/src/ai/model/llm.rs) 一致。

### 5.2 对齐 OpenAI 兼容请求

对外组装时应固定为：

```json
{
  "type": "function",
  "function": {
    "name": "...",
    "description": "...",
    "parameters": { "...": "JSON Schema" }
  }
}
```

这与你们当前 [openai_body.rs](/Users/fengjinyi/Developer/maohuoban-code/maohuoban-rust/crates/maohuoban-ai-infrastructure/src/Infrastructure/provider/openai_body.rs) 已一致。

### 5.3 对齐 Anthropic

Anthropic 侧应在 provider adapter 里转为：

```json
{
  "name": "...",
  "description": "...",
  "input_schema": { "...": "JSON Schema" }
}
```

这应该属于 provider adapter 的职责，不应该反向污染毛球内部稳定协议。

### 5.4 模型侧只保留这些字段

| 字段 | 必须 |
|---|---|
| `name` | 是 |
| `description` | 是 |
| `parameters` / `input_schema` | 是 |
| `tool_call_id` / `call_id` | 调用时必须 |
| `arguments` | 调用时必须 |

### 5.5 模型侧禁止出现这些毛球内部字段

| 字段 | 为什么不能进模型协议 |
|---|---|
| `scope` | 这是运行时权限语义，不是模型调用字段 |
| `risk_level` | 这是策略层决策字段 |
| `requires_confirmation` | 这是 Runtime/Policy 约束，不该让模型控制 |
| `concurrency_safe` | 这是执行器调度元数据 |
| `progress_text` | 这是 UI 展示信息 |
| `result_fact_schema` | 可用于增强 description，但不应成为额外协议字段 |
| `toolset` / `domain_tags` | 属于工具发现与可见性层 |

## 6. 运行时侧工具协议

### 6.1 定义层

当前方向是正确的：

| 类型 | 当前文件 | 作用 |
|---|---|---|
| `AiToolDefinition` | `definition.rs` | 工具注册协议 |
| `AiToolMetadata` | `metadata.rs` | 运行时控制元数据 |
| `AiToolResult` | `result.rs` | 工具返回协议 |
| `ToolRegistry` | `registry.rs` | 工具发现、执行入口、PolicyGuard 接入 |

### 6.2 运行时元数据应该保留什么

| 字段 | 是否保留 | 原因 |
|---|---|---|
| `scope` | 保留 | 鉴权与审计需要 |
| `read_only` | 保留 | 调度与确认策略需要 |
| `concurrency_safe` | 保留 | 并发执行策略需要 |
| `risk_level` | 保留 | 高风险工具必须受控 |
| `requires_confirmation` | 保留 | 写入与敏感动作必须确认 |
| `toolset` | 保留 | 影响本轮工具可见性 |
| `domain_tags` | 保留 | 支撑发现和按需展开 |
| `progress_text` | 保留 | 前端执行态展示需要 |
| `result_fact_schema` | 保留 | 事实投影、evidence planner、tool disclosure 需要 |

### 6.3 工具结果协议

推荐继续保持当前分层：

| 结果形态 | 作用 |
|---|---|
| `allowed` | 执行成功 |
| `allowed_with_facts` | 执行成功并返回事实与引用 |
| `denied` | 授权拒绝 |
| `failed` / `failed_with_failure` | 执行失败 |
| `requires_confirmation` | 等待确认 |

这是 Agent 最佳实践，因为：
- 模型调用成功不等于工具执行成功
- 工具执行失败不等于越权拒绝
- 写入确认不能伪装成失败或成功

## 7. 工具注册协议

### 7.1 推荐注册契约

```rust
#[async_trait]
pub trait AiToolDefinition: Send + Sync {
    fn name(&self) -> &str;
    fn description(&self) -> &str;
    fn parameters_schema(&self) -> serde_json::Value;
    fn metadata(&self) -> AiToolMetadata;
    async fn execute(&self, ctx: &AiToolContext, args: &serde_json::Value) -> AiToolResult;
}
```

这是合理的，不需要改形。

### 7.2 注册时必须保证

| 规则 | 说明 |
|---|---|
| 名称唯一 | 防止工具阴影冲突 |
| schema 完整 | 模型必须能稳定调用 |
| metadata 完整 | Runtime 才能调度 |
| execute 只通过 Tool Gateway 暴露 | 不允许业务层旁路调用 |

## 8. 工具发现协议

### 8.1 最佳实践

不是每轮都把所有 schema 全量塞给模型。

建议分三层发现：

| 层 | 说明 |
|---|---|
| `toolset visibility` | 当前这轮有哪些工具集合可见 |
| `group summary` | 先给摘要，告诉模型有哪些能力域 |
| `schema expansion` | 只在需要时展开具体工具 schema |

### 8.2 毛球当前基础

| 当前实现 | 说明 |
|---|---|
| `ToolsetGroupSummary` | 已有 toolset 分组摘要 |
| `ToolGroupSummary / ToolGroupSchema` | 已有按组摘要和按需展开设计 |
| `AgentRuntimeRequestPolicy.visible_tool_schemas` | 已在按 workbench 决定本轮可见 schema |

### 8.3 目标原则

| 原则 | 说明 |
|---|---|
| 公共问答隐藏私域工具 | 当前已在做，继续保持 |
| 不默认暴露全部写工具 | 写工具应更严格可见 |
| 模型侧 description 增强，但不加私有字段 | 可用自然语言说明 fact schema，不扩协议字段 |

## 9. 工具调用协议

### 9.1 模型发起的调用

模型产出：

```json
{
  "id": "call_xxx",
  "name": "load_pet_identity_context",
  "arguments": "{\"pet_id\":\"...\"}"
}
```

### 9.2 Runtime 处理顺序

```text
LlmToolCall
  -> ToolRegistry.get
  -> PolicyGuard.evaluate
  -> ToolDefinition.execute
  -> AiToolResult
  -> LoopToolResult
  -> 回灌模型 / 写 event / 写 audit
```

### 9.3 运行时控制权

| 决策 | 归谁 |
|---|---|
| 工具是否存在 | ToolRegistry |
| 目标是否授权 | PolicyGuard |
| 是否需要确认 | PolicyGuard + metadata |
| 是否并发执行 | executor/concurrency_safe |
| 如何回灌模型 | runtime/tool_messages |

## 10. 工具结果回灌协议

### 10.1 回灌模型

模型只应看到两类东西：

| 类型 | 内容 |
|---|---|
| `tool_result message` | 安全裁剪后的事实文本或错误文本 |
| `assistant followup context` | 必要的 tool result 摘要 |

### 10.2 不应回灌给模型的内容

| 内容 | 原因 |
|---|---|
| 审计字段 | 模型不需要知道内部审计主键 |
| 内部失败原因全文 | 容易泄漏系统实现细节 |
| 未授权目标存在性细节 | 会造成枚举风险 |

## 11. 毛球当前协议应怎么收紧

| 方向 | 当前状态 | 建议 |
|---|---|---|
| 模型侧 schema | 已基本正确 | 保持 `LlmToolSchema` 极简，不再加毛球内部字段 |
| provider 映射 | OpenAI 兼容已正确 | 后续补 Anthropic 适配时按 provider 层转换 |
| 运行时 metadata | 已有丰富字段 | 正式写入 `Tool Contract`，不向模型泄漏 |
| discovery | 已有摘要与展开 | 继续按组和 toolset 控制暴露粒度 |
| result | 已有 allowed/denied/failed/confirmation | 保持，不合并成单一字符串协议 |
| audit | 已有 session 级工具访问日志 | 后续建议补 `turn_id` 归属 |

## 12. 不变约束

| 约束 | 说明 |
|---|---|
| 模型协议不自创 | 继续对齐 OpenAI/Anthropic 主流 |
| 运行时协议可以扩展 | 但这些扩展字段只能留在 Runtime 层 |
| 工具必须经 Registry 和 PolicyGuard | 禁止旁路调用 |
| 事实返回必须裁剪 | 不让模型看见内部实现和敏感存在性信息 |

## 13. 风险

| 风险 | 处理 |
|---|---|
| 把内部 metadata 暴露给模型 | 严格拆分模型侧和运行时侧协议 |
| 不对齐主流函数调用协议 | provider 兼容性和模型调用稳定性都会下降 |
| 为每个 provider 各写一套内部协议 | 坚持内部 `LlmToolSchema/LlmToolCall` 稳定协议，provider adapter 自己转换 |
| 工具结果只返回字符串 | 会失去 denied/failed/confirmation/facts 的结构化语义 |

