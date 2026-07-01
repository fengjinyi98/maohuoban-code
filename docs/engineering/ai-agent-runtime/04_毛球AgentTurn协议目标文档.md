# 毛球AgentTurn协议目标文档

- 更新时间：2026-06-30
- Goal：定义毛球 Agent 的 `Turn Contract`，明确一次用户输入如何成为一次完整执行单元，并把它和 `session / message / event / tool / summary` 的边界收紧
- 执行方式：先目标文档后实现；以当前 Runtime 代码和 `03_会话协议` 为基础，不引入兼容旧模式

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| Turn 是什么 | `turn` 是“一次用户输入触发的一次完整 Agent 执行单元” |
| Turn 在链路里的位置 | 它位于 `session` 之内，统领这轮 `message / tool / event / finalizer` |
| 为什么必须有 Turn Contract | 因为 session 太粗、message 太细、event 太散，只有 turn 能把一次执行收口成工程化状态机 |
| 毛球当前现状 | Runtime 内已经有 `AgentTurnId`、`AgentTurnStatus`、`LoopStep`、`TurnStarted/TurnFinished/TurnFailed` 等概念，但数据库还没有正式 `turn ledger` |
| 当前核心缺口 | `turn` 还是内存态协议，不是持久化的一等对象 |
| 直接结论 | `Turn Contract` 是 `Session Contract` 落地后的下一层核心协议，也是后续 `Tool Contract / Finalizer Contract / Retry Contract` 的基础 |

## 2. 目标边界

### 2.1 本目标期必须明确

| 范围 | 目标 |
|---|---|
| Turn 定义 | 明确什么是一个 turn，何时开始，何时结束 |
| Turn 状态机 | 明确状态、转移、终态 |
| Turn 字段 | 明确必须持久化的字段 |
| Turn 与其他层关系 | 明确和 session/message/event/tool/summary 的关系 |
| Turn 读写时序 | 明确什么时候建 turn、什么时候结束 turn |
| Turn 在毛球链路中的职责 | 明确它为什么是执行账本和调试主键 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| turn 级自动重试编排策略 | 应放到后续 `Retry Contract` |
| turn 分叉 / fork / subtree | 当前产品链路不需要 |
| 多 agent parent/child turn lineage | 这属于后续多 agent 编排问题 |

## 3. 依据

### 3.1 项目内依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| Turn Id | `maohuoban-ai-domain/src/ai/model/runtime_agent_turn_id.rs` | 已有 `AgentTurnId`，说明 Runtime 已把 turn 视为独立身份 |
| Turn Status | `maohuoban-ai-domain/src/ai/model/runtime_turn_status.rs` | 已有 `AgentTurnStatus`，说明 turn 已有显式终态概念 |
| Session State | `maohuoban-ai-domain/src/ai/model/runtime.rs` | `AgentSessionState` 已持有 `current_turn_id`，并通过 `begin_turn()` 开启新 turn |
| Runtime Event | `maohuoban-ai-domain/src/ai/model/runtime.rs` | 已有 `AgentEvent::TurnStarted / TurnFinished / TurnFailed / NeedsConfirmation` |
| LoopStep | `maohuoban-ai-domain/src/ai/model/runtime.rs` | 已有 `LoopStep::CallModel / MessageDelta / CallTools / Done` |
| Runtime Outer Loop | `maohuoban-ai-application/src/ai/runtime/session.rs` | 当前 `AgentSession` 在收到输入后先 `begin_turn()`，再逐步产出 turn 事件 |
| Runtime Main Loop | `maohuoban-ai-application/src/ai/runtime/agent_runtime_loop_engine.rs` | 当前状态机已能产生 `Completed / Failed / AwaitingConfirmation` 终态 |
| Tool Confirmation | `maohuoban-ai-application/src/ai/runtime/tool_executor.rs` | 工具执行已能返回 `requires_confirmation`，说明 turn 必须承载等待确认状态 |
| Session/Event 入库基础 | `03_毛球Agent会话协议与数据库写入目标文档.md` | 已明确 `ai_session_turns` 应作为 turn ledger 新增 |

### 3.2 参考实现依据

| 参考项目 | 对 Turn Contract 的启发 |
|---|---|
| `codex` | `turn` 是主要执行单元，session 与 turn context 分离 |
| `pi` | 一次 prompt 对应一次 agent loop 执行单元，消息和工具都归入该轮 |
| `hermes-agent` | 一轮 `run_conversation` 是完整执行边界，工具和 finalize 都在轮次内完成 |
| `package` | 一次 query 循环是可恢复的递归执行单元 |

## 4. Turn 是什么

### 4.1 定义

| 问题 | 定义 |
|---|---|
| 什么是 turn | 一次用户输入触发的一次完整 Agent 执行 |
| 从哪开始 | 从用户输入被接受并写入系统开始 |
| 到哪结束 | 到这轮进入明确终态时结束 |
| 它不是谁 | 它不是 session，不是单条 message，也不是单条 event |

### 4.2 在链路里的位置

```text
Session
  -> Turn 1
       -> user message
       -> model call
       -> tool call/result
       -> assistant message
       -> summary/finalizer
  -> Turn 2
  -> Turn 3
```

关系：

| 对象 | 关系 |
|---|---|
| `session` | 包含多个 turn |
| `turn` | 对应一次完整执行 |
| `message` | 从属于某个 turn |
| `event` | 从属于某个 turn |
| `tool call/result` | 从属于某个 turn |
| `summary` | 基于多个 turn 派生 |

## 5. Turn 的作用

| 作用 | 说明 |
|---|---|
| 执行边界 | 把“一次输入到一次完成”收成单独对象 |
| 状态机载体 | 明确这轮是运行中、成功、失败、中断还是等待确认 |
| 归因主键 | provider 错误、tool 拒绝、assistant 文本都能归到一轮 |
| 恢复边界 | 网络断开、前端重连、用户重试都知道恢复哪一轮 |
| 评测单元 | 成功率、失败率、工具命中率都按 turn 统计 |
| 审计单元 | 调试、回放、问题复盘都按 turn 聚合 |

如果没有 turn：

| 问题 | 后果 |
|---|---|
| 只有 session | 粒度太粗，无法知道哪一轮失败 |
| 只有 message | 粒度太细，无法还原整个执行过程 |
| 只有 event | 太散，前后端和业务侧很难理解 |

## 6. Turn 状态机

### 6.1 建议状态

| 状态 | 含义 |
|---|---|
| `running` | 已开始执行，尚未完成 |
| `completed` | 正常完成，有最终结果 |
| `failed` | 失败终止 |
| `interrupted` | 被用户或系统取消、中断 |
| `requires_confirmation` | 暂停，等待用户确认敏感工具或写入动作 |

### 6.2 当前 Runtime 已覆盖的状态基础

| 当前代码 | 对应状态 |
|---|---|
| `AgentTurnStatus::Completed` | `completed` |
| `AgentTurnStatus::Failed` | `failed` |
| `AgentTurnStatus::AwaitingConfirmation` | `requires_confirmation` |

当前还建议补：

| 应补状态 | 原因 |
|---|---|
| `interrupted` | 现在只有失败/确认/完成，还不够区分取消型结束 |

### 6.3 推荐状态流转

```text
new turn
  -> running
     -> completed
     -> failed
     -> interrupted
     -> requires_confirmation
          -> resumed running
          -> failed
          -> interrupted
```

### 6.4 终态定义

| 终态 | 是否还能继续 |
|---|---|
| `completed` | 否，下一轮必须新建 turn |
| `failed` | 否，下一轮必须新建 turn |
| `interrupted` | 否，是否重试由后续新 turn 决定 |
| `requires_confirmation` | 是，确认后继续当前 turn 或派生 follow-up turn，后续实现需固定策略 |

## 7. Turn 字段设计

### 7.1 必备字段

| 字段 | 用途 |
|---|---|
| `turn_id` | 本轮唯一身份 |
| `session_id` | 属于哪个会话 |
| `actor_user_id` | 谁发起这轮 |
| `user_message_id` | 本轮用户输入消息 |
| `assistant_message_id` | 本轮最终回复消息 |
| `intent` | 本轮意图分类 |
| `gate_decision` | 本轮 gate 决策 |
| `resolved_pet_id` | 本轮最终目标宠物 |
| `engine_mode` | 使用哪个 runtime engine |
| `status` | 当前状态 |
| `failure_code` | 失败分类 |
| `retryable` | 失败是否允许重试 |
| `started_at` | 开始时间 |
| `finished_at` | 结束时间 |

### 7.2 可选字段

| 字段 | 说明 |
|---|---|
| `confirmation_task_id` | 若进入等待确认 |
| `provider_profile` | 若后续有 provider capability/profile 切换 |
| `summary_version_id` | 若本轮 завершement 后触发 summary 替换 |

## 8. Turn 与其他协议层的关系

### 8.1 与 Session

| Session 管什么 | Turn 管什么 |
|---|---|
| 长期容器、归属、主宠物、入口来源 | 本轮执行状态、意图、失败、确认、产出 |

### 8.2 与 Message

| Message | Turn |
|---|---|
| 用户可见文本快照 | 一次执行总账本 |

要求：
- 每条 `ai_messages` 必须属于一个 turn
- 一个 turn 至少有一个 `user_message`
- 一个 turn 最多一个主 `assistant_message` 作为终态文本快照

### 8.3 与 Event

| Event | Turn |
|---|---|
| 内部步骤、增量、工具事件、provider 事件 | 这些事件的聚合边界 |

要求：
- `ai_session_events` 必须带 `turn_id`
- 回放和诊断优先按 turn 聚合

### 8.4 与 Tool

| Tool Result | Turn |
|---|---|
| 单个工具调用结果 | 所属执行轮次 |

要求：
- `ai_tool_access_logs` 应可通过 `session_id + created_at` 或后续直接 `turn_id` 关联到 turn
- 后续建议直接为工具审计补 `turn_id`

### 8.5 与 Summary

| Summary | Turn |
|---|---|
| 多个 turn 的压缩产物 | summary 的原始来源 |

要求：
- summary 不替代 turn
- summary 只记录压缩边界和引用，不篡改 turn ledger

## 9. 写入与读取时序

### 9.1 创建 Turn

推荐时机：

```text
prepare_chat_turn_context
  -> 生成 session_id / user_message_id / assistant_message_id
  -> 创建 turn_id
  -> Ingress Tx 写 session + user_message + turn
```

也就是说：

| 问题 | 结论 |
|---|---|
| 先建 turn 还是先跑 Runtime | 先建 turn |
| 为什么 | 这样 event / tool / assistant 都有稳定归属 |

### 9.2 运行中更新

| 阶段 | 建议写法 |
|---|---|
| model start/finish | 写 `ai_session_events` |
| tool start/finish | 写 `ai_session_events` + `ai_tool_access_logs` |
| message delta | 写 `ai_session_events` |
| assistant snapshot | 更新或插入 `ai_messages` |

### 9.3 结束 Turn

| 终态 | 必须更新 |
|---|---|
| `completed` | `assistant_message_id`、`status`、`finished_at` |
| `failed` | `failure_code`、`retryable`、`status`、`finished_at` |
| `interrupted` | `status`、`finished_at` |
| `requires_confirmation` | `status`、可选 `confirmation_task_id` |

## 10. 当前毛球代码对应关系

| 当前代码概念 | 在 Turn Contract 中的意义 |
|---|---|
| `AgentSessionState.current_turn_id` | 当前 turn 内存态身份 |
| `begin_turn()` | turn 开始入口 |
| `AgentEvent::TurnStarted` | turn 生命周期开始事件 |
| `LoopStep::Done { status }` | turn 终态来源 |
| `AgentEvent::TurnFinished / TurnFailed / NeedsConfirmation` | turn 用户可见生命周期输出 |
| `AgentRuntimeLoopEngine` | turn 内部状态机推进器 |

## 11. 对实现的直接要求

| 要求 | 说明 |
|---|---|
| 新增领域模型 `AiSessionTurn` | 让 turn 正式进入 domain |
| 新增 `ai_session_turns` 表 | 让 turn 正式进入数据库 |
| 在 `ai_messages` 中补 `turn_id` | transcript 绑定 turn |
| 在 `ai_tool_access_logs` 中考虑补 `turn_id` | 工具审计直接归轮 |
| Ingress 阶段先插入 turn row | 运行中所有事件有归属 |
| Finalizer 阶段统一关闭 turn | 不把 turn 终态散在不同 handler |

## 12. 不变约束

| 约束 | 说明 |
|---|---|
| 一个用户输入只开启一个主 turn | 不要一条输入并行开多个同级 turn |
| turn 终态必须唯一收口 | 不允许 completed/failed 双写 |
| turn 不承载长文本正文 | 长文本在 `ai_messages`，turn 只存执行摘要字段 |
| turn 不替代 event log | 详细执行链仍在 `ai_session_events` |
| turn 不替代 summary | summary 只做压缩恢复 |

## 13. 风险

| 风险 | 处理 |
|---|---|
| 只在 Runtime 内存里保留 turn | 会继续导致恢复、重试、诊断脆弱 |
| 把过多运行细节塞进 turn 表 | turn ledger 会变成第二个 event log |
| 确认态没有正式状态 | 后续写入确认流会很乱 |
| 中断态缺失 | 失败与取消混在一起，后续重试策略会失真 |

