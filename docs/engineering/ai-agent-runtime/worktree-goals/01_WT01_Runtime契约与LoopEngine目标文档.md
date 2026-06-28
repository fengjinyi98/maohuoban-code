# WT-01 Runtime 契约与 LoopEngine 目标文档

- 更新时间：2026-06-28
- Goal：在现有 `maohuoban-ai-domain` / `maohuoban-ai-application` 内建立 Agent Runtime 核心契约，包括 `AgentSession Workbench`、`AgentDefinition`、`CapabilityCatalog`、`ContextPack`、`MemoryPack`、`AgentEvent`、`LoopEngine` 和 fake loop 测试；为其他 worktree 提供稳定事件、能力目录和 step 边界。
- 执行方式：TDD；只做契约和 fake engine，不接真实 Rig、不改 HTTP、不改 iOS、不改数据库。

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| Runtime 形态 | 自有 `AgentSession` / `AgentSessionRuntime` / `AgentSession Workbench`，对外暴露事件流 |
| Workbench 形态 | Workbench 汇总 AgentDefinition、CapabilityCatalog、ContextPack、MemoryPack 和 ToolCapabilityCatalog |
| Loop 形态 | `LoopEngine` trait 输出 `CallModel`、`CallTools`、`Done` 三类 step |
| 首期实现 | FakeLoopEngine + in-memory session + workbench context，证明事件顺序、能力目录和状态推进 |
| Rig 位置 | 首期先冻结 `LoopEngine` 和 Workbench 契约；Rig adapter 作为 POC 切片接入 |

## 2. 目标边界

### 2.1 本目标期必须完成

| 范围 | 目标 |
|---|---|
| Runtime domain model | 新增 runtime event、turn id、agent id、step、session state 基础类型 |
| Agent Workbench | 新增 `AgentDefinition`、`CapabilityCatalog`、`ContextPack`、`MemoryPack`，表达模型可用能力和可见上下文 |
| LoopEngine trait | 定义输入、输出、错误和可替换边界 |
| AgentSession | 支持提交用户输入和 workbench context、推进 fake loop、收集事件 |
| AgentSessionRuntime | 支持创建当前 session；预留 switch/resume/fork 方法签名或契约占位 |
| 测试 | 覆盖事件顺序、workbench roundtrip、fake loop step、provider error step、tool step |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 直接替换为 Rig 主链路 | 先冻结毛球自有 trait 和 Workbench 契约，避免框架牵动其他 worktree |
| HTTP/SSE 映射 | WT-05 负责 |
| Session 持久化 | WT-04 负责 |
| Tool Gateway 策略 | WT-02 负责 |
| Provider 错误分类实现 | WT-03 负责 |

## 3. 依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| 当前流式事件 | `maohuoban-rust/crates/maohuoban-ai-domain/src/ai/model/stream.rs` | 已有 iOS 稳定 SSE 事件，但缺 turn / runtime 内部事件 |
| 当前 LLM 模型 | `maohuoban-rust/crates/maohuoban-ai-domain/src/ai/model/llm.rs` | 已有 `LlmChatRequest`、`LlmToolCall`、`LlmStreamEvent`，可作为 Loop step 输入输出 |
| 当前 pipeline | `maohuoban-rust/crates/maohuoban-ai-application/src/ai/stream/mod.rs` | 现在是 provider stream 到 SSE 的 pipeline，还不是 Agent Runtime |
| Rig 参考 | `references/agent/rig` | sans-IO step model 适合作为 `LoopEngine` 思路 |
| Pi 参考 | `references/agent/pi/packages/coding-agent/src/core/agent-session.ts` | `AgentSession` 被多种 mode 共享 |

## 4. 推荐数据流

```text
AgentSession.prompt(user_input)
  -> build AgentSessionWorkbench
  -> emit turn_started
  -> LoopEngine.next(session_state)
  -> CallModel / CallTools / Done
  -> emit model/tool/message/turn events
  -> return collected AgentEvent stream
```

## 5. 允许修改

| 文件 / 模块 | 要求 |
|---|---|
| `maohuoban-rust/crates/maohuoban-ai-domain/src/ai/model/runtime.rs` | 新增 runtime domain 类型 |
| `maohuoban-rust/crates/maohuoban-ai-domain/src/ai/model/workbench.rs` 或 `runtime/workbench.rs` | 新增 Workbench、ContextPack、CapabilityCatalog 类型；具体文件名以实现时局部结构为准 |
| `maohuoban-rust/crates/maohuoban-ai-domain/src/ai/model/mod.rs` | 只做 additive export |
| `maohuoban-rust/crates/maohuoban-ai-domain/src/ai/mod.rs` | 只做 additive export |
| `maohuoban-rust/crates/maohuoban-ai-application/src/ai/runtime/` | 新增 runtime application 模块 |
| `maohuoban-rust/crates/maohuoban-ai-application/src/ai/mod.rs` | 只做 additive export |
| `maohuoban-rust/crates/maohuoban-ai-application/tests/runtime_contract.rs` | 新增契约测试 |

## 6. 禁止修改

| 文件 / 模块 | 原因 |
|---|---|
| `maohuoban-ai-http` | WT-05 负责 adapter |
| `maohuoban-ai-infrastructure` | WT-03 / WT-04 负责 |
| `maohuoban/maohuoban/Features/AI` | WT-05 负责 |
| `migrations/` | WT-04 负责 |
| 根 `Cargo.toml` | 本目标不新增 crate |

## 7. TDD 任务拆分

### Task 1：Runtime 事件与 Workbench 契约

| 项 | 内容 |
|---|---|
| 目标 | 定义 `AgentEvent` 和 Workbench 基础类型，并能序列化 / 反序列化冻结事件和能力上下文 |
| 前置依赖 | 无 |
| 回归验证 | `cargo test -p maohuoban-ai-domain` |

#### Slice 1.1：事件枚举 roundtrip

| 项 | 要求 |
|---|---|
| 行为目标 | `turn_started`、`model_call_started`、`tool_started`、`message_delta`、`turn_finished` 可 serde roundtrip |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-domain/tests/runtime_event_roundtrip.rs` |
| 允许修改 | `maohuoban-ai-domain/src/ai/model/runtime.rs` 和 additive export |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-domain runtime_event_roundtrip` |
| 回归命令 | `cargo test -p maohuoban-ai-domain` |
| 完成证据 | 记录测试先因类型不存在失败，再通过 |
| 停止条件 | 需要修改现有 `AiStreamEvent` 才能通过时停止 |

#### Slice 1.2：Workbench roundtrip

| 项 | 要求 |
|---|---|
| 行为目标 | `AgentDefinition`、`CapabilityCatalog`、`ContextPack`、`MemoryPack` 可 serde roundtrip，且测试证明不包含内部字段、数据库字段或安全字段 |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-domain/tests/workbench_contract.rs` |
| 允许修改 | `maohuoban-ai-domain/src/ai/model/runtime*` 或新增同层 workbench 模块，以及 additive export |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-domain workbench_contract` |
| 回归命令 | `cargo test -p maohuoban-ai-domain runtime_event_roundtrip` |
| 完成证据 | 记录 workbench JSON 断言和 forbidden fields 断言 |
| 停止条件 | 需要改 HTTP handler、Provider 或真实工具实现时停止 |

### Task 2：LoopEngine 契约

| 项 | 内容 |
|---|---|
| 目标 | 定义 `LoopEngine` trait 和 fake engine，证明 step 可驱动 |
| 前置依赖 | Task 1 |
| 回归验证 | `cargo test -p maohuoban-ai-application runtime_contract` |

#### Slice 2.1：FakeLoopEngine 输出 step

| 项 | 要求 |
|---|---|
| 行为目标 | fake engine 可按脚本输出 `CallModel -> CallTools -> Done`，并能读取 Workbench 中的能力数量 |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-application/tests/runtime_contract.rs` |
| 允许修改 | `maohuoban-ai-application/src/ai/runtime/*` |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-application runtime_contract` |
| 回归命令 | `cargo check -p maohuoban-ai-application` |
| 完成证据 | 记录 fake step 顺序断言 |
| 停止条件 | 需要真实 Provider 或真实 Tool Gateway 时停止 |

### Task 3：AgentSession 事件流

| 项 | 内容 |
|---|---|
| 目标 | AgentSession 使用 fake engine 产生稳定内部事件顺序 |
| 前置依赖 | Task 1、Task 2 |
| 回归验证 | `cargo test -p maohuoban-ai-application runtime_contract` |

#### Slice 3.1：prompt 产生 turn 事件

| 项 | 要求 |
|---|---|
| 行为目标 | 调用 `prompt()` 并传入 Workbench 后输出 `turn_started -> model_call_started -> model_call_finished -> turn_finished` |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-application/tests/runtime_contract.rs` |
| 允许修改 | `maohuoban-ai-application/src/ai/runtime/session.rs` |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-application agent_session_emits_turn_events` |
| 回归命令 | `cargo test -p maohuoban-ai-application runtime_contract` |
| 完成证据 | 记录事件名序列 |
| 停止条件 | 需要改 HTTP handler 或数据库时停止 |

## 8. 验收门禁

| 类型 | 命令 / 验收 |
|---|---|
| Domain | `cargo test -p maohuoban-ai-domain runtime_event_roundtrip` |
| Application | `cargo test -p maohuoban-ai-application runtime_contract` |
| 构建 | `cargo check -p maohuoban-ai-domain -p maohuoban-ai-application` |

## 9. 不变约束

| 约束 | 说明 |
|---|---|
| 外部协议 | `AiStreamEvent` 由 WT-05 处理，本目标只新增 runtime 内部事件 |
| 框架接入 | `LoopEngine` 先抽象，Rig adapter 后续接入 |
| 持久化 | 所有状态 in-memory，WT-04 负责持久化 |

## 10. 风险

| 风险 | 处理 |
|---|---|
| 契约过度设计 | 每个事件必须有测试消费方；没有消费方的字段不加入 |
| 与 WT-05 事件重复 | Runtime 内部事件可比 SSE 更细，SSE adapter 只映射用户需要的事件 |
