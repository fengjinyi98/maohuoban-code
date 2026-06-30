# 毛球Agent完整运行链路与参考实现映射目标文档

- 更新时间：2026-06-30
- Goal：回答“毛球 Agent 从用户输入到最终完成任务，完整运行链路是什么”，并给出毛球当前 Rust 架构的第一版映射与底层协议边界
- 执行方式：参考实现对照 + 当前代码映射 + 协议边界收敛

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 文档命名 | `01_毛球Agent完整运行链路与参考实现映射目标文档.md` |
| Agent 本质 | Agent 不是“一次 prompt -> 一次回答”，而是“有状态的 session/turn runtime” |
| 完整运行链路 | 至少包含 `入口适配 -> 会话定位 -> 本轮上下文冻结 -> 模型采样 -> 工具执行 -> 结果回灌 -> 继续采样 -> 终止判定 -> 收尾持久化 -> 对外投递` |
| 五个参考项目的共同答案 | `Codex`、`Pi`、`OpenClaw`、`Hermes`、`Claude Code package` 的主干都符合这个循环，只是入口、工具层、持久化层、投递层的形态不同 |
| 对毛球的直接要求 | 毛球底层必须先把这条链路做成稳定协议，再谈 UI、真机联调、补救逻辑和产品话术 |
| 当前毛球所处位置 | 已经有 `入口 / workbench / runtime loop / provider / SSE / diagnostics` 雏形，但 `session contract / turn contract / tool contract / provider capability contract / finalizer contract / transcript contract` 还没有完全收紧 |

## 2. 核心问题

| 问题 | 本文要回答的内容 |
|---|---|
| 一个真正的 Agent 是什么 | 不是单次聊天接口，而是可持续推进任务的运行时系统 |
| 从用户输入到最终完成，中间有哪些步骤 | 要拆成可测试、可观测、可替换的稳定阶段 |
| 参考项目如何回答这个问题 | 提炼共同主干，而不是照抄具体产品外形 |
| 毛球该怎么落地 | 用当前 Rust 分层映射出第一版底层协议边界 |

## 3. 参考项目回答

### 3.1 五个项目的共识主链路

```text
用户输入 / 渠道事件
  -> 入口适配层规范化请求
  -> 会话定位或创建
  -> 构造本轮 TurnContext / Workbench
  -> 投影 system prompt / skills / context / visible tools
  -> 发起模型流式或非流式采样
  -> 识别 tool call / reasoning / final text
  -> 通过 Tool Gateway 执行工具
  -> 把 tool result 写回 transcript
  -> 继续下一轮模型采样
  -> 命中终止条件
  -> 执行 finalizer / persistence / delivery / diagnostics
```

### 3.2 五个项目分别怎样回答这个问题

| 参考项目 | 这个项目给出的核心回答 | 关键证据 |
|---|---|---|
| `codex` | 把一次用户任务建模成可中断、可恢复、可工具回灌的 `turn` 状态机；主干是 `session -> run_turn -> tool runtime -> task finish` | `references/agent/codex/codex-rs/core/src/session/handlers.rs` `references/agent/codex/codex-rs/core/src/session/turn.rs` `references/agent/codex/codex-rs/core/src/tools/router.rs` `references/agent/codex/codex-rs/core/src/tasks/mod.rs` |
| `pi` | 把 CLI/TUI 壳层和 agent loop 内核分离；`coding-agent` 管会话壳，`agent-core` 专注“assistant -> tool -> toolResult -> next turn”循环 | `references/agent/pi/packages/coding-agent/src/main.ts` `references/agent/pi/packages/coding-agent/src/core/agent-session.ts` `references/agent/pi/packages/agent/src/agent-loop.ts` `references/agent/pi/packages/coding-agent/src/core/session-manager.ts` |
| `openclaw` | 多入口最终统一收敛到一个 agent 内核；CLI、HTTP、node event、reply channel 都汇入 `agentCommandInternal -> runAgentAttempt` | `references/agent/openclaw/src/agents/agent-command.ts` `references/agent/openclaw/src/agents/embedded-agent-runner/run/attempt.ts` `references/agent/openclaw/src/commands/agent-via-gateway.ts` `references/agent/openclaw/src/auto-reply/reply/agent-runner.ts` |
| `hermes-agent` | 网关层负责平台路由、会话和上下文；`AIAgent` 负责模型循环、工具执行、收尾持久化；系统提示按稳定层级缓存 | `references/agent/hermes-agent/gateway/run.py` `references/agent/hermes-agent/gateway/session.py` `references/agent/hermes-agent/agent/conversation_loop.py` `references/agent/hermes-agent/agent/system_prompt.py` `references/agent/hermes-agent/agent/turn_finalizer.py` |
| `package` | 一个可恢复的递归查询循环；`query()` 负责“组装上下文 -> 模型流式采样 -> 工具执行 -> tool_result 回灌 -> 下一轮”，并先做 transcript recovery | `references/agent/package/cli.js.map` 内嵌 `../src/QueryEngine.ts` `../src/query.ts` `../src/services/tools/toolExecution.ts` `../src/utils/conversationRecovery.ts` `references/agent/package/sdk-tools.d.ts` |

### 3.3 从参考项目抽象出的完整 Agent 形态

| 层 | 必要职责 | 协议要求 |
|---|---|---|
| Ingress Adapter | 把 HTTP、CLI、App、渠道消息统一成内部请求 | 输入结构固定，禁止把上游平台差异泄漏到运行时核心 |
| Session Resolver | 定位或创建 session，恢复历史、scope、权限、owner | `session_id / session_key / actor / scope` 必须稳定且可持久化 |
| Turn Context / Workbench | 冻结本轮可见上下文、可见工具、模型选择、权限边界 | 每轮生成一次，后续流程只读它，避免运行中被外部改写 |
| Prompt / Context Projection | 把系统规则、上下文、技能、工具说明投影给模型 | 投影格式稳定、可测试、对模型友好 |
| Model Runtime | 发起流式或非流式采样，产出 delta / reasoning / tool call / finish | provider 差异进入适配层，主循环不散写 provider 分支 |
| Tool Registry | 声明工具 schema、权限、可见性、并发属性 | 工具必须可枚举、可过滤、可审计 |
| Tool Gateway | 统一执行工具、注入 actor/scope、记录结果、处理错误 | 所有工具都必须走统一入口，禁止旁路调用 |
| Loop Orchestrator | 负责 `model -> tool -> tool_result -> next model` 递归推进 | 明确继续条件、终止条件、异常条件 |
| Finalizer | 在完成或失败后做 transcript、summary、memory、cleanup | 终态收口唯一，禁止各入口各自拼装收尾逻辑 |
| Transcript / Persistence | 记录用户消息、assistant、tool call、tool result、turn 状态 | 可恢复、可回放、可审计 |
| Delivery Adapter | 把最终结果发回 SSE、App、渠道、CLI | 只消费终态和流式事件，不反向污染 runtime |
| Diagnostics / Eval | 记录每层事件，支撑调试、回放、评测、回归 | 每层都有固定观测点和字段合同 |

## 4. 毛球当前映射

### 4.1 当前链路与文件映射

| 通用步骤 | 毛球当前文件 | 当前状态 |
|---|---|---|
| 入口适配 | `maohuoban-rust/crates/maohuoban-ai-http/src/Infrastructure/ai/router/chat/turn_preparation.rs` | 已有 HTTP/chat 入口、request 规范化、session/message id 生成 |
| 会话与首轮持久化 | `.../chat/persistence/session_persistence.rs` | 已有 session/user message 落库和 gate 审计 |
| Workbench 构造 | `.../chat/composition/workbench_builder.rs` `maohuoban-ai-domain/src/ai/workbench/*` | 已有本轮工作台与 context pack 雏形 |
| Runtime bridge | `.../chat/runtime_stream_bridge.rs` `.../chat/non_stream_handler.rs` | 已有 HTTP 到 runtime 的桥接层 |
| Runtime loop | `maohuoban-ai-application/src/ai/runtime/agent_runtime_loop_engine.rs` | 已有自研 `self_hosted` loop 主干 |
| 模型请求投影 | `maohuoban-ai-application/src/ai/runtime/runtime_request.rs` `.../workbench_prompt_projection.rs` | 已有请求消息、工具 schema、workbench prompt 投影 |
| Provider 适配 | `maohuoban-ai-infrastructure/src/Infrastructure/provider/openai_compatible.rs` `.../deepseek.rs` | 已有 OpenAI 兼容协议适配，DeepSeek 当前复用该协议面 |
| Tool 执行 | `maohuoban-ai-application/src/ai/runtime/tool_executor.rs` `maohuoban-ai-http/src/Infrastructure/ai/router/chat/runtime_tools.rs` | 已有 ToolRegistry 与执行入口，但合同还不够收紧 |
| SSE 投影 | `.../chat/runtime_stream_projector.rs` `.../chat/stream_handler.rs` | 已有 runtime event -> SSE 的稳定映射 |
| Diagnostics | `maohuoban-ai-application/src/ai/runtime/agent_runtime_diagnostics.rs` `maohuoban-ai-infrastructure/src/Infrastructure/provider/openai_diagnostics.rs` `maohuoban-ai-http/src/Infrastructure/ai/router/diagnostics.rs` | 已有较完整观测点 |

### 4.2 当前缺口

| 缺口 | 当前表现 | 为什么必须先补底层协议 |
|---|---|---|
| Session Contract 不够明确 | session 具备持久化，但 session 与 transcript 的正式合同还未独立成协议层 | 后续做恢复、继续对话、补发、重试会变脆 |
| Turn Contract 不够收紧 | 已有 workbench，但本轮冻结边界、turn 状态和终态分类还不够显式 | 容易出现中途混写和边界漂移 |
| Tool Contract 不够独立 | ToolRegistry 已有，但 schema、并发、确认、返回事实合同还没有完全独立建模 | 工具一多就容易引入临时分支和补丁 |
| Provider Capability Contract 缺失 | DeepSeek 当前主要走 OpenAI 兼容协议复用 | provider 差异会继续渗透到调用现场 |
| Finalizer Contract 缺失 | 当前更偏“loop + SSE 输出”，终态后的 summary/memory/cleanup 还不是独立协议 | 终态收尾会散在各入口和各阶段 |
| Transcript Contract 不够清晰 | 已有会话与消息持久化，但“哪些事件进入 transcript，哪些只进 diagnostics”仍需明确 | 调试、恢复、回放会不一致 |

## 5. 第一阶段协议结论

| 结论 | 说明 |
|---|---|
| 毛球底层必须先做窄腰 | 所有入口都先统一到 `session + turn + runtime + tool gateway + finalizer` |
| 模型不是主流程，Runtime 才是主流程 | 模型只负责生成文本、reasoning、tool call；流程推进权在代码 |
| Tool Gateway 必须成为唯一工具入口 | 所有宠物事实读取、写入确认、外部连接都只能走统一工具网关 |
| Provider 差异必须进入能力模型 | `DeepSeek/OpenAI/未来 provider` 的差异应进入显式 capability/profile，不写在业务现场 |
| Diagnostics 必须跟协议层对齐 | 每层固定产生日志与事件，后续回归、评测、问题复盘才有抓手 |
| 开发阶段禁止 fallback/legacy | 发现底层契约缺口时，补协议、补测试、补诊断，不用兼容逻辑遮住问题 |

## 6. 下一步应继续定义的协议

| 顺序 | 协议 | 目标 |
|---|---|---|
| P0 | `Session Contract` | 明确 session id、session key、history、resume、owner/scope |
| P0 | `Turn Contract` | 明确 turn state、finish reason、event、终态分类 |
| P0 | `Tool Contract` | 明确 tool schema、可见性、并发、确认、结果类型 |
| P0 | `Provider Capability Contract` | 明确 model label、context length、tool-call delta、reasoning、stream error 分类 |
| P0 | `Finalizer Contract` | 明确 transcript flush、summary、memory、cleanup、delivery 前后顺序 |
| P0 | `Transcript Contract` | 明确哪些数据进入用户历史，哪些只进 diagnostics |

## 7. 本文暂不展开

| 暂不展开项 | 原因 |
|---|---|
| DeepSeek 专项优化 | 这属于 provider capability/profile 阶段，应该放在下一份协议文档 |
| 多 agent / subagent 编排 | 这是 runtime 窄腰稳定后的上层能力，不应抢在底层协议之前 |
| UI/真机联调体验 | 当前目标是底层协议，不是交互细节 |
| 旧模式兼容与 fallback | 本轮明确禁止进入开发方案 |

## 8. 对毛球当前开发的直接要求

| 要求 | 说明 |
|---|---|
| 所有后续 Agent 重构都以本文链路为基线 | 先判断新改动落在哪一层，再实现 |
| 任何“多打一层兜底”的修法一律先停 | 先问它破坏的是哪一个底层合同 |
| 新代码优先落到职责明确的目录 | 遵守 `Domain / Application / Infrastructure / HTTP` 分层与文件规则 |
| 每补一层协议，就补对应测试和 diagnostics | 底层必须稳，上层才能联调 |

