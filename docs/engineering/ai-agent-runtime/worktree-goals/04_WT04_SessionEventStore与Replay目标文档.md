# WT-04 Session Event Store 与 Replay 目标文档

- 更新时间：2026-06-28
- Goal：建立结构化 Agent session event store，把 turn、tool、policy、provider、retry、用户可见消息关联起来，并支持基于 session / turn 的 replay 测试。
- 执行方式：TDD；只改 session event domain、repository、migration、AI persistence 合同测试，不改 Provider、Tool、iOS。

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 历史策略 | 用户可见聊天消息和 runtime event 分开存储，通过 `session_id` / `turn_id` 关联 |
| Replay 目标 | 诊断和回归能重放一次 turn 的关键事件顺序 |
| 存储形态 | 数据库表使用 append-only event entry，保留 JSON payload 和稳定 event_name |
| 会话分叉 | 首期只预留 parent_event_id，不做 UI 分叉 |

## 2. 目标边界

### 2.1 本目标期必须完成

| 范围 | 目标 |
|---|---|
| Domain | 定义 `AgentSessionEventEntry`、`turn_id`、`event_name`、`payload` |
| Migration | 新增 `ai_session_events` 或等价表 |
| Repository | append / list_by_session / list_by_turn |
| Replay | 将 event entries 读回并校验顺序 |
| 测试 | 覆盖 migration、append-only、按 turn 查询、历史消息关联 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 分叉 UI | 后续目标 |
| 完整 JSONL 导出 | 可在 Replay 基础上后续实现 |
| 复杂压缩 | Runtime compaction 后续独立 |
| iOS 历史 UI | WT-05 负责 |

## 3. 依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| 当前仓储 | `maohuoban-rust/crates/maohuoban-ai-infrastructure/src/repository/session.rs` | 已有 AI 会话仓储 |
| 当前 rows | `maohuoban-rust/crates/maohuoban-ai-infrastructure/src/repository/session_rows.rs` | 可扩展 session event row |
| 当前合同测试 | `maohuoban-rust/tests/ai_contract/persistence.rs`、`history.rs` | 可加入 runtime event store 验证 |
| Pi 参考 | `references/agent/pi/packages/coding-agent/docs/session-format.md` | JSONL entry + id / parentId 的会话事件思想 |

## 4. 推荐数据流

```text
AgentSession emits AgentEvent
  -> SessionEventRepository.append(entry)
  -> user-visible message persistence
  -> diagnostics / replay reads list_by_turn(turn_id)
  -> assert event sequence and payload
```

## 5. 允许修改

| 文件 / 模块 | 要求 |
|---|---|
| `maohuoban-rust/crates/maohuoban-ai-domain/src/ai/model/session_event.rs` | 新增 session event entry 类型 |
| `maohuoban-rust/crates/maohuoban-ai-application/src/ai/ports/session_event_repository.rs` | 新增端口 |
| `maohuoban-rust/crates/maohuoban-ai-infrastructure/src/repository/session_event.rs` | 新增仓储 |
| `maohuoban-rust/migrations/*ai_session_events*.sql` | 新增表 |
| `maohuoban-rust/tests/ai_contract/persistence.rs` | 扩展合同测试 |
| `maohuoban-rust/tests/ai_contract/replay.rs` | 可新增 replay 合同测试 |

## 6. 禁止修改

| 文件 / 模块 | 原因 |
|---|---|
| Provider | WT-03 负责 |
| Tool / Policy | WT-02 负责 |
| iOS | WT-05 负责 |
| HTTP SSE format | WT-05 负责 |

## 7. TDD 任务拆分

### Task 1：Session event domain

| 项 | 内容 |
|---|---|
| 目标 | 事件 entry 可序列化并带 turn/session 关联 |
| 前置依赖 | WT-01 事件名称，可先使用冻结字符串 |
| 回归验证 | `cargo test -p maohuoban-ai-domain session_event` |

#### Slice 1.1：entry roundtrip

| 项 | 要求 |
|---|---|
| 行为目标 | `AgentSessionEventEntry` serde roundtrip，保留 `event_name` 和 `payload` |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-domain/tests/session_event_roundtrip.rs` |
| 允许修改 | `maohuoban-ai-domain/src/ai/model/session_event.rs` 和 additive export |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-domain session_event_roundtrip` |
| 回归命令 | `cargo test -p maohuoban-ai-domain session_event` |
| 完成证据 | 记录 roundtrip payload 断言 |
| 停止条件 | 需要改 WT-01 runtime event 类型时停止并对齐契约 |

### Task 2：Repository append / query

| 项 | 内容 |
|---|---|
| 目标 | 事件可 append-only 保存和按 turn 查询 |
| 前置依赖 | Task 1 |
| 回归验证 | `cargo test -p maohuoban_rust --test ai_contract ai_session_event` |

#### Slice 2.1：migration + append

| 项 | 要求 |
|---|---|
| 行为目标 | 写入两条 event 后按 turn 读回顺序一致 |
| 先写失败测试 | `maohuoban-rust/tests/ai_contract/persistence.rs` |
| 允许修改 | `migrations/*ai_session_events*.sql`、`maohuoban-ai-infrastructure/src/repository/session_event.rs` |
| 最小绿灯命令 | `cargo test -p maohuoban_rust --test ai_contract ai_session_event_store_appends_and_lists_turn_events` |
| 回归命令 | `cargo test -p maohuoban_rust --test ai_contract persistence` |
| 完成证据 | 记录数据库 count 和 event order 断言 |
| 停止条件 | 需要修改现有聊天消息表结构时停止 |

### Task 3：Replay helper

| 项 | 内容 |
|---|---|
| 目标 | 测试可读取 turn event sequence 做 replay 断言 |
| 前置依赖 | Task 2 |
| 回归验证 | `cargo test -p maohuoban_rust --test ai_contract ai_turn_replay` |

#### Slice 3.1：replay 顺序断言

| 项 | 要求 |
|---|---|
| 行为目标 | 给定 turn_id 能得到 `turn_started -> model_call_started -> provider_error -> turn_failed` |
| 先写失败测试 | `maohuoban-rust/tests/ai_contract/replay.rs` |
| 允许修改 | `maohuoban-ai-infrastructure/src/repository/session_event.rs`、测试辅助 |
| 最小绿灯命令 | `cargo test -p maohuoban_rust --test ai_contract ai_turn_replay_reads_event_sequence` |
| 回归命令 | `cargo test -p maohuoban_rust --test ai_contract ai_session_event` |
| 完成证据 | 记录 event sequence |
| 停止条件 | 需要接真实 Runtime 时停止，首期可直接写 repository fixture |

## 8. 验收门禁

| 类型 | 命令 / 验收 |
|---|---|
| Domain | `cargo test -p maohuoban-ai-domain session_event` |
| Infrastructure | `cargo test -p maohuoban-ai-infrastructure session_event` |
| 合同测试 | `cargo test -p maohuoban_rust --test ai_contract ai_session_event` |
| 构建 | `cargo check -p maohuoban-ai-domain -p maohuoban-ai-application -p maohuoban-ai-infrastructure` |

## 9. 不变约束

| 约束 | 说明 |
|---|---|
| append-only | runtime event 不做覆盖更新 |
| 隐私最小化 | payload 不保存完整用户敏感原文，必要时保存 hash / 摘要 |
| 聊天消息独立 | 用户可见 messages 表仍负责历史显示 |

## 10. 风险

| 风险 | 处理 |
|---|---|
| event payload 过大 | 存摘要和引用 id，完整诊断由 diagnostics SDK 控制 |
| migration 冲突 | WT-04 独占 AI session event migration |
