# 毛球AgentFinalizer协议目标文档

- 更新时间：2026-06-30
- Goal：定义毛球 Agent 的 `Finalizer Contract`，明确一次 turn 进入终态后由谁、按什么顺序、把哪些产物写入 transcript / citation / action / summary / diagnostics / cleanup
- 执行方式：先目标文档后实现；以现有 `Turn Contract`、`Session Contract`、`Tool Contract` 为前提，不引入兼容旧路径

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| Finalizer 是什么 | `Finalizer` 是 turn 进入终态后的唯一收口层 |
| 它的作用 | 把运行时结果变成稳定持久化产物，并决定哪些同步完成、哪些异步后处理 |
| 为什么必须单独立协议 | 当前写入逻辑散在 `runtime projector / non-stream handler / session summary / response helper` 多处，后续很容易漂移 |
| 毛球当前现状 | 已经有 assistant message 持久化、citation/action 写入、verification、summary compressor、event log 仓储，但没有单独的 finalizer 层 |
| 最关键缺口 | 没有一个统一地方负责“turn 结束后该写什么、按什么顺序写、哪些失败不能影响主回复返回” |
| 直接结论 | `Finalizer Contract` 是 Turn Contract 的后半段，是 session/tool/memory/summary/diagnostics 的唯一收口点 |

## 2. 目标边界

### 2.1 本目标期必须明确

| 范围 | 目标 |
|---|---|
| Finalizer 职责 | 明确 finalizer 只管什么、不管什么 |
| 同步收口 | 明确哪些内容必须在主请求返回前写完 |
| 异步收口 | 明确哪些内容可以延后处理 |
| 终态分支 | completed / failed / interrupted / requires_confirmation 分别怎样收口 |
| 持久化产物 | transcript、citation、proposed action、summary、event、audit 的写入顺序 |
| 不可回退约束 | 明确什么是权威写入，什么是派生物，什么失败后要 fail-open |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 复杂后台任务调度器 | 当前先定义 finalizer 合同，不引入完整任务系统 |
| 自动记忆升级流水线 | 后续应放入独立 `Memory Finalizer / Candidate Pipeline Contract` |
| 多渠道 delivery 编排 | 当前重点是后端收口，不展开多渠道发送策略 |

## 3. 依据

### 3.1 项目内依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| Summary 压缩 | `maohuoban-ai-application/src/ai/session_summary/mod.rs` | 当前已能生成会话摘要、替代旧摘要、记录压缩边界 |
| SSE 终态投影 | `maohuoban-ai-http/src/Infrastructure/ai/router/chat/runtime_stream_projector.rs` | 当前 `TurnFinished/TurnFailed/NeedsConfirmation` 会投影为用户可见完成/错误/确认事件 |
| Event 仓储 | `maohuoban-ai-infrastructure/src/repository/session_event.rs` | 当前 event 已 append-only 入库，可作为 runtime replay 事实源 |
| 非流式完成处理 | `maohuoban-ai-http/src/Infrastructure/ai/router/chat/non_stream_handler.rs` | 当前已存在 final_text、verification、citation、assistant message 落库逻辑 |
| 助手消息持久化 | `maohuoban-ai-http/src/Infrastructure/ai/router/chat/persistence/assistant_message_persistence.rs` | 当前已存在 assistant message 最终落库路径 |
| Proposed Action | `AiSessionRepository::insert_proposed_action` | 当前建议动作已有独立落库端口 |
| Citation | `AiSessionRepository::insert_message_citations` | 当前引用已有独立落库端口 |
| Verification | `runtime_stream_helpers.rs` / `non_stream_handler.rs` | 当前回答校验在完成阶段发生，说明 finalizer 必须纳入 verification |

### 3.2 参考实现依据

| 参考项目 | 启发 |
|---|---|
| `hermes-agent` | turn 结束后统一 finalize，再做记忆和后台审查触发 |
| `codex` | task finish 后统一 flush rollout / lifecycle / persistence |
| `pi` | message_end 持久化，但 session 结束后的 compaction/continuation 是后处理 |
| `openclaw` | transcript、session、delivery 分阶段完成 |

## 4. Finalizer 是什么

### 4.1 定义

| 问题 | 定义 |
|---|---|
| Finalizer 是谁 | turn 终态后的统一收尾编排器 |
| 它输入什么 | turn id、session id、assistant final text、verification、citations、actions、status、tool/audit 结果 |
| 它输出什么 | 稳定持久化结果 + 可选异步后处理任务 |
| 它不是谁 | 它不是 runtime loop，不是 provider adapter，不是 UI projector |

### 4.2 在链路中的位置

```text
Runtime Loop
  -> Turn reaches terminal status
  -> Finalizer
       -> finalize transcript
       -> write citations
       -> write proposed actions
       -> close turn
       -> update session header
       -> schedule summary / memory follow-up
  -> return stable response
```

## 5. Finalizer 的职责边界

### 5.1 它必须负责的事

| 职责 | 说明 |
|---|---|
| 最终 assistant message 定稿 | 最终文本、provider/model、verification、usage 写入 transcript |
| turn 终态收口 | 更新 `ai_session_turns.status/finished_at/failure_code` |
| session header 刷新 | `updated_at / last_turn_id / last_message_at / primary_pet_id` |
| citations 写入 | 助手消息引用落库 |
| proposed actions 写入 | 待确认动作落库 |
| summary 触发 | 决定是否压缩摘要 |
| diagnostics 完成事件 | 记录最终链路完成信号 |

### 5.2 它不应该负责的事

| 不负责 | 原因 |
|---|---|
| 继续推进模型循环 | 这是 runtime loop 的职责 |
| 解析模型 tool_call | 这是 tool/runtime 协议层职责 |
| 构造 workbench/context | 这是 turn context builder 职责 |
| 执行工具 | 这是 tool gateway 职责 |
| 主观生成产品话术 | finalizer 只收口结果，不重新做业务生成 |

## 6. 终态分类与 Finalizer 分支

### 6.1 `completed`

| 项 | 处理 |
|---|---|
| assistant message | 写最终正文 |
| verification | 必须写入 |
| citations | 写入 |
| proposed actions | 写入 |
| turn status | `completed` |
| summary | 可触发 |

### 6.2 `failed`

| 项 | 处理 |
|---|---|
| assistant message | 若有安全 fallback 文本，则写安全文本；否则可为空或系统失败文本 |
| verification | 可选，通常跳过正常答案校验 |
| citations | 通常不写 |
| proposed actions | 通常不写 |
| turn status | `failed`，写 `failure_code/retryable` |
| summary | 不做正常摘要压缩 |

### 6.3 `interrupted`

| 项 | 处理 |
|---|---|
| assistant message | 可写部分文本或中断说明，但不能伪装完成 |
| turn status | `interrupted` |
| summary | 不做正常摘要压缩 |

### 6.4 `requires_confirmation`

| 项 | 处理 |
|---|---|
| assistant message | 不写伪完成正文 |
| proposed action / confirmation task | 必须落库 |
| turn status | `requires_confirmation` |
| summary | 不做最终摘要压缩，等待后续确认流程继续 |

## 7. 同步 vs 异步收口

### 7.1 必须同步完成

| 项 | 原因 |
|---|---|
| assistant message 最终快照 | 聊天页历史必须立即可见 |
| turn 终态更新 | 当前轮状态必须立即一致 |
| session 更新时间 | 会话列表排序立即正确 |
| citations 写入 | 历史详情和引用 UI 依赖它 |
| proposed action / confirmation task | 确认链路不能丢 |

### 7.2 可以异步完成

| 项 | 原因 |
|---|---|
| session summary 压缩 | 这是恢复优化，不应阻塞主回复 |
| 记忆候选抽取 | 属于后处理管线 |
| 后台评测打点 | 不影响主用户请求 |

## 8. 推荐数据流

### 8.1 Completed 路径

```text
TurnFinished
  -> verify final_text
  -> normalize safe final_text
  -> derive citations
  -> derive proposed actions
  -> BEGIN
       finalize ai_messages(assistant)
       insert ai_message_citations
       insert ai_proposed_actions
       update ai_session_turns
       update ai_chat_sessions
     COMMIT
  -> async summary / memory candidate / diagnostics tail
```

### 8.2 Failed 路径

```text
TurnFailed
  -> derive safe user-visible error text
  -> BEGIN
       finalize assistant failure snapshot (optional)
       update ai_session_turns(status=failed,...)
       update ai_chat_sessions
     COMMIT
  -> diagnostics tail
```

### 8.3 RequiresConfirmation 路径

```text
NeedsConfirmation
  -> BEGIN
       persist confirmation task / proposed action
       update ai_session_turns(status=requires_confirmation)
       update ai_chat_sessions
     COMMIT
```

## 9. 持久化顺序

推荐顺序：

| 顺序 | 写入对象 | 原因 |
|---|---|---|
| 1 | assistant message final snapshot | 后续 citation/action 需要 message_id |
| 2 | citations | 属于 assistant message 附属物 |
| 3 | proposed actions / confirmation | 属于本轮产物 |
| 4 | turn row | 标记本轮终态 |
| 5 | session row | 刷新会话 header |
| 6 | async summary / memory candidate | 派生物，延后 |

## 10. Fail-open / Fail-closed 规则

### 10.1 必须 fail-closed

| 项 | 原因 |
|---|---|
| turn 终态更新失败 | 会让系统状态失真 |
| assistant message final snapshot 写失败 | 历史与返回不一致 |
| confirmation task 写失败 | 会让写入确认链断裂 |

### 10.2 可以 fail-open

| 项 | 原因 |
|---|---|
| summary 压缩失败 | 不影响当前用户看到结果 |
| memory candidate 抽取失败 | 只影响后续变聪明，不影响当前正确性 |
| 辅助 diagnostics 上报失败 | 主链路不该因此失败 |

## 11. 当前毛球代码应该如何收口

### 11.1 当前分散点

| 当前位置 | 当前承担的 finalizer 片段 |
|---|---|
| `runtime_stream_projector.rs` | 将 runtime 终态投影成 SSE 完成/错误/确认事件 |
| `runtime_stream_helpers.rs` | 完成时做 verification、citations、final text 补齐 |
| `non_stream_handler.rs` | 非流式路径拼 final_text、verification、message/citation 持久化 |
| `session_summary/mod.rs` | 异步历史压缩与摘要替代 |

### 11.2 推荐收口方向

| 方向 | 说明 |
|---|---|
| 新增 `Finalizer` application service | 统一接收 turn terminal input |
| Stream / Non-stream 都调同一个 Finalizer | 避免两条路径各自写一套收尾逻辑 |
| Projector 只做投影 | 不负责持久化 |
| SummaryCompressor 只做派生压缩 | 不承担主终态落库 |

## 12. 建议接口

建议新增一个 application 层收口接口：

```rust
pub struct TurnTerminalOutput {
    pub turn_id: Uuid,
    pub session_id: Uuid,
    pub actor_user_id: Uuid,
    pub assistant_message_id: Uuid,
    pub status: AgentTurnStatus,
    pub final_text: Option<String>,
    pub failure_code: Option<String>,
    pub retryable: Option<bool>,
    pub package: AiFactPackage,
    pub verification: Option<AiAnswerVerification>,
    pub citations: Vec<AiCitation>,
    pub proposed_actions: Vec<AiProposedAction>,
}
```

```rust
#[async_trait]
pub trait TurnFinalizer {
    async fn finalize(&self, output: TurnTerminalOutput) -> AiResult<FinalizationReceipt>;
}
```

## 13. 不变约束

| 约束 | 说明 |
|---|---|
| Finalizer 是 turn 终态唯一收口点 | 不允许继续散写 |
| Transcript 和 Event Log 分离 | message 是快照，event 是过程 |
| Summary 是派生物 | 不能反向定义 turn 真相 |
| Verification 在终态阶段执行 | 不在中途污染 loop |

## 14. 风险

| 风险 | 处理 |
|---|---|
| stream / non-stream 继续各自收尾 | 尽快统一到 shared finalizer service |
| 把 summary 压缩做成同步 | 会拖慢主响应 |
| assistant message 与 turn 状态分开失败 | 必须同事务收口关键字段 |
| confirmation 状态未单独收口 | 工具写入链会继续脆弱 |

