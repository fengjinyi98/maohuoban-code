# 毛球Agent会话协议与数据库写入目标文档

- 更新时间：2026-06-30
- Goal：定义符合 Agent 最佳实践、又贴合毛球当前 Rust 架构的会话协议分层与数据库写入路径，确保后续 `session / turn / transcript / event / summary` 不偏移
- 执行方式：先目标文档后实现；优先复用现有 `ai_chat_sessions / ai_messages / ai_session_events / ai_chat_session_summaries`，只补必要协议层

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 最佳实践会话协议 | 应该采用 `Session Header + Turn Ledger + Transcript + Event Log + Summary` 五层结构 |
| 毛球当前基础 | 已经有 `Session Header`、`Transcript`、`Event Log`、`Summary` 四层，缺正式 `Turn Ledger` |
| 当前最关键缺口 | `turn_id` 只是 Runtime 内存概念，还没有成为数据库一等对象 |
| 设计原则 | 不重造一套系统；在现有表上按 Agent 最佳实践收紧边界 |
| 当前推荐方向 | 保留 `ai_chat_sessions`、`ai_messages`、`ai_session_events`、`ai_chat_session_summaries`，新增 `ai_session_turns`，并把 `ai_messages` 绑定 `turn_id` |
| 写库原则 | 采用 `Ingress Tx -> Runtime Append -> Finalizer Tx` 三段式写入，不做一个贯穿全 turn 的超长事务 |

## 2. 目标边界

### 2.1 本目标期必须明确

| 范围 | 目标 |
|---|---|
| 会话分层 | 明确 `session / turn / message / event / summary` 五层职责 |
| 数据库结构 | 复用现有表并定义必要新增字段/表 |
| 写入时序 | 定义用户输入进入数据库、运行中事件进入数据库、完成收尾进入数据库的顺序 |
| 读取时序 | 定义会话列表、历史消息、恢复上下文、事件回放分别读哪些表 |
| 状态机 | 定义 session 和 turn 的状态枚举，不把状态散落在 message/event 中 |
| 不变约束 | 明确哪些是用户可见事实，哪些是内部运行事件，哪些是压缩派生物 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 多入口 `session_key` 完整路由体系 | 毛球当前主要是 App/HTTP 单入口，先不把渠道路由复杂度引入底层 |
| 完整事件 sourcing 重建所有状态 | 现阶段只要求 append-only replay 能力，不要求所有视图都只从 event 回放 |
| turn 级别完整重试编排器 | 先把协议立住，重试策略后续接 `Turn Contract` 文档 |
| 会话分叉 / fork / tree | 当前产品形态还不需要 |

## 3. 依据

### 3.1 项目内依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| Session Header | `maohuoban-rust/migrations/0026_ai_chat_tables.sql` | 已有 `ai_chat_sessions`，负责 `actor_user_id`、`primary_pet_id`、`surface`、`source_hint_id`、`source_task_id`、`title`、`status` |
| Transcript | `maohuoban-rust/migrations/0026_ai_chat_tables.sql` | 已有 `ai_messages`，负责持久化 user/assistant/system message |
| 审计日志 | `maohuoban-rust/migrations/0026_ai_chat_tables.sql` | 已有 `ai_tool_access_logs` 和 `ai_request_gate_logs` |
| Event Log | `maohuoban-rust/migrations/0029_ai_session_events.sql` | 已有 append-only `ai_session_events`，并已包含 `session_id + turn_id + event_name + payload` |
| Summary | `maohuoban-rust/migrations/0032_ai_chat_session_summaries.sql` | 已有 `ai_chat_session_summaries`，负责压缩摘要和 `compressed_until_message_id` |
| Runtime Session | `maohuoban-rust/crates/maohuoban-ai-application/src/ai/runtime/session.rs` | 当前 in-memory `AgentSession` 已以 `chat_session_id` 和 `turn_id` 驱动 Runtime 事件输出 |
| 首轮持久化 | `maohuoban-rust/crates/maohuoban-ai-http/src/Infrastructure/ai/router/chat/persistence/session_persistence.rs` | 当前请求进入时已经先写 session 和 user message |
| 历史投影 | `maohuoban-rust/crates/maohuoban-ai-application/src/ai/conversation_history/mod.rs` | 当前恢复上下文依赖 `session + messages + active summary`，符合 Agent 历史恢复方向 |
| 领域模型 | `maohuoban-rust/crates/maohuoban-ai-domain/src/ai/model/session.rs` | 当前 `AiChatSession` 和 `AiMessage` 已定义，但还没有 `AiSessionTurn` |

### 3.2 参考实现依据

| 参考项目 | 启发 |
|---|---|
| `codex` | 会话长期配置与本轮 `TurnContext` 分离，turn 是主要执行单元 |
| `pi` | transcript 是一等对象，agent loop 和会话壳分离 |
| `openclaw` | 多入口最终汇总到同一 agent 内核，再统一持久化与投递 |
| `hermes-agent` | 用户消息先落库，tool 前增量持久化，turn 结束统一 finalize |
| `package` | resume/recovery 先修 transcript，再继续 query loop |

## 4. 推荐协议

### 4.1 五层协议

| 层 | 名称 | 作用 | 是否用户可见 |
|---|---|---|---|
| L1 | `Session Header` | 一段持续对话的稳定身份与归属 | 部分可见 |
| L2 | `Turn Ledger` | 一次用户输入触发的一次完整执行单元 | 间接可见 |
| L3 | `Transcript` | 用户看到的消息历史 | 可见 |
| L4 | `Event Log` | 运行中的内部事件、工具、provider、失败、重放线索 | 不可见 |
| L5 | `Summary` | 压缩后的上下文摘要和边界标记 | 不直接可见 |

### 4.2 各层职责边界

| 层 | 只负责什么 | 不负责什么 |
|---|---|---|
| `Session Header` | 归属、主宠物、入口来源、会话状态、列表页展示 | 不承载每轮执行状态 |
| `Turn Ledger` | turn 开始、结束、意图、gate、终态、失败码、引用 message | 不承载长文本和 delta |
| `Transcript` | user/assistant/system 的最终可见文本快照 | 不承载运行中内部推理与工具细节 |
| `Event Log` | append-only 记录 turn 内部事件 | 不直接作为列表页或聊天页主读模型 |
| `Summary` | 历史压缩、恢复边界、引用事件 | 不是宠物事实权威来源 |

## 5. 数据库设计

### 5.1 保留现有表

| 表 | 保留原因 | 建议 |
|---|---|---|
| `ai_chat_sessions` | 已承担会话 header 角色 | 保留并补少量字段 |
| `ai_messages` | 已承担 transcript 角色 | 保留并绑定 `turn_id` |
| `ai_session_events` | 已符合 append-only event log 最佳实践 | 保留 |
| `ai_chat_session_summaries` | 已承担摘要和压缩边界角色 | 保留 |
| `ai_tool_access_logs` | 已承担工具审计角色 | 保留 |
| `ai_request_gate_logs` | 已承担入口 gate 审计角色 | 保留 |

### 5.2 新增表：`ai_session_turns`

这是下一步必须补的核心表。

建议字段：

```sql
CREATE TABLE IF NOT EXISTS ai_session_turns (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id           UUID NOT NULL REFERENCES ai_chat_sessions(id) ON DELETE CASCADE,
    actor_user_id        UUID NOT NULL,
    user_message_id      UUID NOT NULL REFERENCES ai_messages(id) ON DELETE RESTRICT,
    assistant_message_id UUID REFERENCES ai_messages(id) ON DELETE SET NULL,
    intent               TEXT NOT NULL DEFAULT '',
    gate_decision        TEXT NOT NULL DEFAULT '',
    resolved_pet_id      UUID,
    engine_mode          TEXT NOT NULL DEFAULT 'self_hosted',
    status               TEXT NOT NULL DEFAULT 'running',
    failure_code         TEXT,
    retryable            BOOLEAN,
    started_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    finished_at          TIMESTAMPTZ
);
```

推荐索引：

```sql
CREATE INDEX IF NOT EXISTS idx_ai_session_turns_session
    ON ai_session_turns (session_id, started_at ASC);

CREATE INDEX IF NOT EXISTS idx_ai_session_turns_actor
    ON ai_session_turns (actor_user_id, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_ai_session_turns_status
    ON ai_session_turns (status, started_at DESC);
```

### 5.3 `ai_chat_sessions` 建议补字段

| 字段 | 原因 |
|---|---|
| `last_message_at TIMESTAMPTZ` | 会话列表排序不必只依赖 `updated_at` |
| `last_turn_id UUID` | 便于快速定位最近一次执行单元 |

### 5.4 `ai_messages` 建议补字段

| 字段 | 原因 |
|---|---|
| `turn_id UUID REFERENCES ai_session_turns(id)` | transcript 必须能归属于明确 turn |
| `updated_at TIMESTAMPTZ` | assistant streaming / finalize 时更新快照 |
| `sequence_in_turn INTEGER` | 可选，便于稳定排序和排查同 turn 多消息 |

说明：`message delta` 不建议逐条写 `ai_messages`。  
最佳实践是：
- `ai_messages` 只存最终快照或当前快照
- `ai_session_events` 存增量事件

## 6. 状态机设计

### 6.1 Session 状态

| 状态 | 说明 |
|---|---|
| `active` | 可继续对话 |
| `archived` | 用户归档或删除后不可继续作为默认入口 |

当前 `AiChatSessionStatus` 已够用。

### 6.2 Turn 状态

| 状态 | 说明 |
|---|---|
| `running` | 已开始执行，尚未结束 |
| `completed` | 已成功生成最终结果 |
| `failed` | 已失败并终止 |
| `interrupted` | 被用户中断、连接中断或外部取消 |
| `requires_confirmation` | 等待用户确认工具写入或高风险动作 |

说明：`turn` 才是 Agent 执行状态的一等对象，`message.status` 只是消息快照状态。

## 7. 写入时序

### 7.1 推荐三段式写入

| 阶段 | 事务 | 写入内容 |
|---|---|---|
| `Ingress Tx` | 短事务 | session header、user message、turn row、gate log |
| `Runtime Append` | append-only | event log、tool access log、assistant 快照更新 |
| `Finalizer Tx` | 短事务 | finalize assistant message、turn 终态、session 更新时间、summary 替换 |

### 7.2 Ingress Tx

```text
HTTP Request
  -> current_user_id
  -> prepare_chat_turn_context
  -> BEGIN
       upsert ai_chat_sessions
       insert ai_messages(user)
       insert ai_session_turns
       insert ai_request_gate_logs
     COMMIT
```

为什么这么做：

| 原因 | 说明 |
|---|---|
| 用户输入先落库 | 即使后续 Runtime 崩了，也能知道这轮请求已经开始 |
| turn 先建行 | 运行中事件和 assistant message 才有稳定归属 |
| gate 先审计 | 后续可区分“根本没进入 Runtime”和“进入后失败” |

### 7.3 Runtime Append

```text
Runtime Loop
  -> append ai_session_events
  -> append ai_tool_access_logs
  -> assistant message 快照写入或更新
```

推荐原则：

| 规则 | 说明 |
|---|---|
| `ai_session_events` append-only | 不回写，不修改旧事件 |
| `ai_tool_access_logs` 每次工具独立插入 | 保持审计完整 |
| assistant streaming 不逐 delta 写消息表 | delta 进 event log；message 表只保留当前快照或最终快照 |

### 7.4 Finalizer Tx

```text
Turn Finished
  -> BEGIN
       update ai_messages(assistant final snapshot)
       insert citations / proposed actions
       update ai_session_turns(status, finished_at, failure_code, retryable)
       update ai_chat_sessions(updated_at, last_turn_id, last_message_at, primary_pet_id)
     COMMIT
  -> async summary compression
```

说明：

| 项 | 说明 |
|---|---|
| summary 建议异步 | 不阻塞主回复完成 |
| turn 终态必须唯一收口 | 不允许在各 handler 里各自拼终态 |
| assistant message id 由 Ingress/Turn 固定 | 与前端 placeholder、SSE message_started 一致 |

## 8. 读取时序

### 8.1 会话列表

| 读表 | 用途 |
|---|---|
| `ai_chat_sessions` | 列表页 header 信息 |
| 可选 `ai_chat_session_summaries` 最新一条 | 列表副标题或恢复提示 |

### 8.2 消息详情

| 读表 | 用途 |
|---|---|
| `ai_messages` | 用户可见 transcript |
| `ai_session_turns` | 给前端提供每轮状态、是否失败、是否确认中 |

### 8.3 恢复上下文

| 读表 | 用途 |
|---|---|
| `ai_chat_sessions` | 校验归属与主宠物 |
| `ai_chat_session_summaries` | 若有摘要，从压缩边界后恢复 |
| `ai_messages` | 加载压缩边界之后的最近历史 |

这与你们当前 [conversation_history/mod.rs](/Users/fengjinyi/Developer/maohuoban-code/maohuoban-rust/crates/maohuoban-ai-application/src/ai/conversation_history/mod.rs) 的方向一致。

### 8.4 回放与诊断

| 读表 | 用途 |
|---|---|
| `ai_session_turns` | 确定具体 turn |
| `ai_session_events` | 重放内部执行链路 |
| `ai_tool_access_logs` | 看工具授权与拒绝 |

## 9. 对毛球当前代码的直接要求

| 要求 | 原因 |
|---|---|
| 新增 `AiSessionTurn` 领域模型 | 让 `turn` 成为一等对象 |
| 新增 `SessionTurnRepository` 端口与 Postgres 实现 | 不把 turn 写库逻辑混入 message repository |
| 给 `ai_messages` 加 `turn_id` | transcript 必须归属 turn |
| 在 `persist_session_and_user_message` 中补 turn row 创建 | Ingress 阶段形成完整壳 |
| 新增 assistant message finalize/update 入口 | 避免只会 insert 不会 finalize |
| Finalizer 独立收口 turn 终态 | 不让状态散在 handler/SSE 层 |

## 10. 不变约束

| 约束 | 说明 |
|---|---|
| `ai_chat_sessions` 不是事实表 | 只保存会话 header 和展示快照 |
| `ai_messages` 只存用户可见文本快照 | 推理细节和工具过程不塞进去 |
| `ai_session_events` append-only | 作为 replay 与诊断事实源 |
| `ai_chat_session_summaries` 是派生层 | 可替换、可 supersede，不是权威事实 |
| `turn` 是执行单位 | 任何 provider/tool/retry/failure 都必须归属明确 turn |

## 11. 风险

| 风险 | 处理 |
|---|---|
| 继续只用 `session + messages`，不补 `turn` | 后续重试、确认、恢复、评测都会继续脆弱 |
| 把过多运行信息写进 `ai_messages` | transcript 会污染，前后端边界会混乱 |
| 使用单个长事务贯穿整轮 | 流式长连接和工具执行会拖垮事务边界 |
| 让 summary 承担事实权威 | 会造成恢复与真实事实漂移 |

