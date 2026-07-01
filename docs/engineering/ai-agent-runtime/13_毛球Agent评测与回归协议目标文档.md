# 毛球Agent评测与回归协议目标文档

- 更新时间：2026-06-30
- Goal：定义毛球 Agent 的 `Evaluation & Regression Contract`，明确底层协议如何被持续验证、如何构建合同测试与回放测试、哪些命令构成回归门禁，以及什么证据才允许宣称协议稳定
- 执行方式：先目标文档后实现；以现有 `ai_contract / runtime_loop_engine / runtime_event_roundtrip / runtime_stream_projector / eval_case` 为基础收敛

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 为什么需要单独评测协议 | 没有评测与回归协议，前面 01-12 的协议文档都会慢慢漂 |
| 评测不是一个测试文件 | 应拆成 `领域契约 / 运行时契约 / provider 契约 / HTTP 合同 / replay / eval cases / diagnostics` 多层门禁 |
| 当前毛球现状 | 已经有较强基础：`ai_contract` 总入口、runtime 闭环测试、domain roundtrip、SSE projector 测试、eval_case 解析测试 |
| 当前核心缺口 | 还没有把“哪些测试证明哪一层协议稳定”写成正式工程门禁 |
| 直接结论 | 协议稳定性的判定必须基于固定命令、固定样例、固定证据格式，而不是主观感觉 |

## 2. 目标边界

### 2.1 本目标期必须明确

| 范围 | 目标 |
|---|---|
| 测试分层 | 明确每层协议应该由哪类测试守护 |
| 门禁命令 | 明确最小绿灯命令和大回归命令 |
| 样例结构 | 明确 eval case、replay case、failure case 的组织方式 |
| 证据格式 | 明确什么输出能作为“已验证”证据 |
| 回归触发 | 明确改哪层协议时必须跑哪些测试 |
| 漂移防护 | 明确冻结事件名、schema、状态机、SSE 事件、diagnostics 字段的测试边界 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 外部 benchmark 排行 | 当前先守住本项目协议稳定性 |
| 复杂线上自动评测平台 | 先把本地/CI 门禁立住 |
| 人工标注评分平台 | 当前先做确定性合同测试与最小 eval 样例 |

## 3. 依据

### 3.1 项目内依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| 总合同入口 | `maohuoban-rust/tests/ai_contract.rs` | 已将 AI 合同测试按子模块聚合 |
| Runtime 事件契约 | `maohuoban-ai-domain/tests/runtime_event_roundtrip.rs` | 已冻结 `AgentEvent / InternalTurnEvent / UserVisibleTurnEvent / LoopStep` 事件名与 roundtrip |
| Session Event 契约 | `maohuoban-ai-domain/tests/session_event_roundtrip.rs` | 已验证 `AgentSessionEventEntry` 的事件名与 payload roundtrip |
| Runtime 闭环 | `maohuoban-ai-application/tests/runtime_loop_engine.rs` | 已验证模型 -> 工具 -> 再生成闭环 |
| Runtime Regression | `maohuoban-ai-application/tests/runtime_regression_cases.rs` | 已有回归样例套件 |
| Runtime Streaming | `maohuoban-ai-application/tests/runtime_loop_engine_streaming.rs` | 已有流式闭环测试 |
| SSE 投影契约 | `maohuoban-ai-http/tests/runtime_stream_projector.rs` | 已冻结 runtime event -> SSE 投影边界 |
| Eval 样例 | `maohuoban-ai-application/tests/eval_case.rs` | 已有样例解析与 gate 对齐测试 |
| HTTP/Provider 合同 | `maohuoban-rust/tests/ai_contract/*` | 已有 stream/non-stream/provider/workbench/diagnostics/history/persistence/replay/memory_postgres 合同测试 |
| Provider 策略 | `maohuoban-ai-infrastructure/tests/openai_request_policy.rs` | 已验证 request 级参数不被 provider 默认值覆盖 |
| DeepSeek Profile | `maohuoban-ai-infrastructure/tests/deepseek.rs` | 已验证 DeepSeek profile 的行为边界 |

## 4. 评测分层协议

### 4.1 建议分层

| 层 | 目标 | 测试类型 |
|---|---|---|
| L1 Domain Contract | 冻结领域模型、事件名、枚举、值对象 | roundtrip / boundary / contract tests |
| L2 Runtime Contract | 冻结 loop step、状态机、tool 回灌、终态 | runtime loop / regression / streaming tests |
| L3 Provider Contract | 冻结 request/response/stream/error 映射 | provider unit tests |
| L4 HTTP Contract | 冻结 API 路由、SSE 协议、持久化链路 | ai_contract integration tests |
| L5 Replay / Diagnostics | 冻结 replay 事件、diagnostics 字段、安全脱敏 | replay / diagnostics tests |
| L6 Eval Cases | 守护典型业务样例和意图边界 | eval_case tests |

### 4.2 为什么必须这样分层

| 原因 | 说明 |
|---|---|
| 失败定位更快 | 出问题时知道是 domain、runtime、provider 还是 HTTP 合同 |
| 降低测试噪音 | 不用每次都跑所有测试才能确认一个小协议 |
| 防止“绿了但没守住关键边界” | 每层都有明确冻结对象 |

## 5. 冻结对象协议

### 5.1 必须冻结的对象

| 对象 | 为什么必须冻结 |
|---|---|
| `AgentEvent.event_name()` | 这是 replay、SSE、diagnostics 的基础键 |
| `InternalTurnEvent.event_name()` | 内部运行时诊断链依赖它 |
| `UserVisibleTurnEvent.event_name()` | 客户端协议和 projector 依赖它 |
| `LoopStep.step_name()` | Runtime 调试和状态推进依赖它 |
| `AiIntent` 枚举值 | 入口 gate、planner、light response 依赖它 |
| `LlmToolSchema/LlmToolCall` 形态 | 模型协议层依赖它 |
| `AiFactStrength` 语义 | 事实解释、确认、写回依赖它 |
| `AiStreamEvent.event_name()` | SSE 合同依赖它 |

### 5.2 当前已覆盖的冻结对象

| 当前测试 | 覆盖对象 |
|---|---|
| `runtime_event_roundtrip.rs` | `AgentEvent/InternalTurnEvent/UserVisibleTurnEvent/LoopStep` |
| `intent_gate.rs` | `AiIntent` 和 gate 语义 |
| `runtime_stream_projector.rs` | `AiStreamEvent` 投影边界 |
| `deepseek.rs` / `openai_request_policy.rs` | provider profile 行为 |

## 6. 回归样例协议

### 6.1 样例类型

| 类型 | 用途 |
|---|---|
| `happy path` | 守正常闭环 |
| `safety path` | 守 prompt injection / cost abuse / unauthorized |
| `evidence path` | 守取证逻辑 |
| `confirmation path` | 守待确认写入 |
| `provider failure path` | 守 timeout / invalid_response / stream interruption |
| `summary boundary path` | 守会话压缩与恢复 |

### 6.2 当前毛球应该至少维持的样例族

| 样例族 | 当前基础 |
|---|---|
| 宠物档案查询 | `runtime_loop_engine` / `runtime_regression_cases` |
| 饮食上下文查询 | `chat_stream_diet_context.rs` |
| 库存线索查询 | `chat_stream_inventory_hints.rs` |
| 待确认候选 | `chat_stream_confirmation_candidates.rs` |
| Workbench 边界 | `chat_workbench.rs`, `chat_non_stream_workbench.rs` |
| 历史与 replay | `history.rs`, `replay.rs` |
| diagnostics 链路 | `chat_stream_diagnostics.rs` |

## 7. Replay 协议

### 7.1 replay 要验证什么

| 项 | 说明 |
|---|---|
| session event 顺序稳定 | append-only 重放可预测 |
| turn 聚合正确 | 同一 turn 的 event 可完整收集 |
| projector 可再现用户可见结果 | 从 event 能还原用户可见完成链路 |

### 7.2 当前基础

| 当前实现 | 价值 |
|---|---|
| `SessionEventRepository::list_by_turn/list_by_session` | 已具备按 turn/session 回放 |
| `session_event_roundtrip.rs` | 已冻结 event entry 结构 |
| `replay.rs` 合同测试 | 已有 replay 测试入口 |

## 8. Diagnostics 协议

### 8.1 diagnostics 应验证什么

| 项 | 说明 |
|---|---|
| request/response/tool/event 是否完整串起 | 链路可观察 |
| 是否泄露敏感字段 | API key / authorization / raw secret 不能出现在 diagnostics |
| 最终文本、verification、finish_reason 是否记录 | 便于回放和问题定位 |

### 8.2 当前基础

| 当前测试 | 作用 |
|---|---|
| `chat_stream_provider.rs` | 已验证 provider 日志不泄露 key |
| `chat_stream_diagnostics.rs` | 已有诊断链路测试 |

## 9. 门禁命令协议

### 9.1 最小命令

| 层 | 最小命令 |
|---|---|
| Domain Runtime Events | `cargo test -p maohuoban-ai-domain runtime_event_roundtrip --tests` |
| Session Event | `cargo test -p maohuoban-ai-domain session_event_roundtrip --tests` |
| Runtime Loop | `cargo test -p maohuoban-ai-application --test runtime_loop_engine` |
| Runtime Regression | `cargo test -p maohuoban-ai-application --test runtime_regression_cases` |
| Runtime Streaming | `cargo test -p maohuoban-ai-application --test runtime_loop_engine_streaming` |
| SSE Projector | `cargo test -p maohuoban-ai-http --test runtime_stream_projector` |
| Provider Policy | `cargo test -p maohuoban-ai-infrastructure --test openai_request_policy` |
| DeepSeek Profile | `cargo test -p maohuoban-ai-infrastructure --test deepseek` |
| AI Contract | `cargo test --test ai_contract` |

### 9.2 大回归命令

| 类型 | 命令 |
|---|---|
| 编译门禁 | `cargo check --workspace --all-targets` |
| Rust 格式 | `cargo fmt --all --check` |
| AI 核心回归 | `cargo test -p maohuoban-ai-domain -p maohuoban-ai-application -p maohuoban-ai-infrastructure -p maohuoban-ai-http --all-targets` |
| 全工作区回归 | `cargo test --workspace` |

## 10. 什么证据才算“验证通过”

### 10.1 必备证据

| 类型 | 证据 |
|---|---|
| Contract | 相关测试名和通过信号 |
| Runtime | 至少一个闭环样例通过 |
| Provider | request/stream/error 样例通过 |
| Diagnostics | 敏感信息未泄露 |
| Replay | session/turn 回放仍可读 |

### 10.2 不足以宣称稳定的情况

| 情况 | 为什么不够 |
|---|---|
| 只过 `cargo check` | 只能说明能编译，不代表协议没漂 |
| 只过单个 happy path | 安全、失败、确认态都可能已经坏了 |
| 只跑 HTTP 层 | 可能 domain/runtime/provider 已经偏移 |

## 11. 改动到哪层，必须跑哪些测试

| 改动层 | 必跑测试 |
|---|---|
| `AiIntent / Gate` | `intent_gate`, `eval_case`, `ai_contract` 中相关 chat gate case |
| `Turn / Event / LoopStep` | `runtime_event_roundtrip`, `session_event_roundtrip`, `runtime_loop_engine`, `runtime_stream_projector` |
| `Tool Contract` | `runtime_loop_engine`, `chat_stream_runtime_tools`, provider/tool tests |
| `Provider Capability` | `openai_request_policy`, `openai_compatible`, `deepseek`, `sse_stream_parser` |
| `Finalizer / Persistence` | `persistence`, `history`, `replay`, `chat_non_stream`, `chat_stream_diagnostics` |
| `Memory / Retrieval / Summary` | `memory_postgres`, `conversation_history`, `session_summary`, `eval_case` |

## 12. 样例文件协议

### 12.1 Eval Case

| 要求 | 说明 |
|---|---|
| 用固定 JSON fixture | 避免样例漂移 |
| 每个样例必须标注期望 intent / 是否进入 workbench / 是否加载上下文 | 便于入口协议守护 |
| 后续应逐步扩到期望 toolset / expected terminal state | 逐步增强 |

### 12.2 Replay Case

| 要求 | 说明 |
|---|---|
| 固定 turn event 序列 | 守 event_name / ordering |
| 固定 SSE 事件序列 | 守 projector 结果 |

## 13. 当前毛球下一步应怎么做

| 步骤 | 说明 |
|---|---|
| 1 | 将 `01-12` 每份协议文档对应到一组固定测试入口 |
| 2 | 给 `ai_contract` 增加更明确的协议维度命名和注释 |
| 3 | 恢复并重新建立 `eval_cases` fixture 目录，不再依赖零散样例 |
| 4 | 在 CI 中区分最小协议门禁和全量回归门禁 |

## 14. 不变约束

| 约束 | 说明 |
|---|---|
| 测试必须按协议层分层 | 不允许全塞进一个大测试里 |
| 协议冻结对象必须有 roundtrip/contract 测试 | 否则容易漂移 |
| 敏感信息脱敏必须进入门禁 | 不允许只靠人工检查 |
| 评测不能只看 happy path | 必须包含安全、失败、确认、恢复 |

## 15. 风险

| 风险 | 处理 |
|---|---|
| 文档越来越多但没人知道改哪个测什么 | 通过本协议建立“改动层 -> 必跑测试”映射 |
| 只跑集成测试，问题定位越来越慢 | 保持 domain/runtime/provider/http 分层门禁 |
| replay 和 diagnostics 无人维护 | 将其纳入正式门禁，不当可选项 |

