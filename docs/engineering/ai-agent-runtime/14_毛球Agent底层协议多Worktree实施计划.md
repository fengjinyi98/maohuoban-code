# 毛球Agent底层协议多Worktree实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 以多 worktree 方式，按正确前置依赖、并行边界和观测前置顺序，完成 `01-13` 底层协议文档对应的实际代码落地，并避免后期再次因目录混乱、缺少观测或跨层耦合而返工。

**Architecture:** 采用一条集成主线 + 多个短生命周期 worktree。先做结构和观测基线，再依次完成 `session -> turn -> tool -> provider -> facts -> memory/context -> finalizer -> planner -> skill -> eval`。所有 worktree 都只拥有明确的写入边界，合并顺序遵守依赖图，不直接从旧基线并行修改共享文件。

**Tech Stack:** Git worktree、Rust workspace、axum、sqlx、PostgreSQL、SwiftUI、MaohuobanDiagnostics、正式 diagnostics 链路。

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| worktree 目录 | 仓库已有 `.worktrees/`，且已在 `.gitignore` 中忽略，可直接作为标准位置 |
| 当前最正确的落地顺序 | `结构与观测基线 -> session/turn -> tool -> provider/facts -> memory/context -> finalizer -> planning -> skill -> eval` |
| 必须最先完成的不是业务能力 | 而是 `目录治理 + 全链路观测 + 核心持久化主键` |
| 评测 worktree 不应最后一次性做 | 应作为滚动 worktree 从第一阶段开始持续补门禁 |
| 共享高冲突文件不允许跨 worktree 同时改 | 例如 `runtime/session`, `runtime/loop`, `router/chat/*`, `provider/*`, `docs/engineering/ai-agent-runtime/*` |

## 2. worktree 总策略

### 2.1 总体规则

| 规则 | 要求 |
|---|---|
| 一条集成主线 | 所有 worktree 都合并到同一集成分支，再由集成分支推进 |
| 一棵 worktree 一组职责 | 每个 worktree 只负责一层或一组紧耦合协议 |
| 严格写入边界 | 不允许两个 worktree 同时改同一核心文件族 |
| 先基线后并行 | 只有在前置基线合并后才能切后续并行枝 |
| 评测滚动更新 | 测试 worktree 持续 rebase 到最新集成分支，补门禁而不重写业务逻辑 |

### 2.2 推荐分支和目录命名

| worktree | 路径 | 分支 |
|---|---|---|
| WT00 | `.worktrees/ai-rt-00-structure-observability` | `codex/ai-rt-00-structure-observability` |
| WT01 | `.worktrees/ai-rt-01-session-turn` | `codex/ai-rt-01-session-turn` |
| WT02 | `.worktrees/ai-rt-02-tool-gateway` | `codex/ai-rt-02-tool-gateway` |
| WT03 | `.worktrees/ai-rt-03-intent-gate` | `codex/ai-rt-03-intent-gate` |
| WT04 | `.worktrees/ai-rt-04-provider-profiles` | `codex/ai-rt-04-provider-profiles` |
| WT05 | `.worktrees/ai-rt-05-domain-facts` | `codex/ai-rt-05-domain-facts` |
| WT06 | `.worktrees/ai-rt-06-memory-context` | `codex/ai-rt-06-memory-context` |
| WT07 | `.worktrees/ai-rt-07-finalizer` | `codex/ai-rt-07-finalizer` |
| WT08 | `.worktrees/ai-rt-08-planner-execution` | `codex/ai-rt-08-planner-execution` |
| WT09 | `.worktrees/ai-rt-09-skill-runtime` | `codex/ai-rt-09-skill-runtime` |
| WT10 | `.worktrees/ai-rt-10-eval-regression` | `codex/ai-rt-10-eval-regression` |

### 2.3 集成分支

| 分支 | 用途 |
|---|---|
| `codex/ai-runtime-integration` | 所有短生命周期 worktree 的统一合并主线 |
| `main` | 只在阶段性绿灯后由集成分支推进 |

## 3. 为什么这个顺序不能乱

| 层 | 为什么必须前置 |
|---|---|
| `WT00 结构与观测` | 后续所有工作都要落到稳定目录和正式 diagnostics 上 |
| `WT01 session/turn` | 后续 tool、provider、finalizer、replay 都要挂在 `session_id/turn_id` 上 |
| `WT02 tool` | provider 请求、planner、facts、confirmation 都依赖工具协议 |
| `WT04 provider` | memory/context/finalizer 的预算和错误策略依赖 provider profile |
| `WT05 facts` | memory/context/planner 需要知道哪些是强事实、弱线索、待确认事实 |
| `WT06 memory/context` | planner 和 finalizer 的摘要/候选/召回都依赖这层 |
| `WT07 finalizer` | planner 完成后需要有唯一收口点，不能继续散写 |
| `WT08 planning` | 只有前面的 session/turn/tool/provider/facts/memory/finalizer 稳住后，planner 才不会变成空转抽象 |
| `WT09 skill` | skill runtime 依赖 intent/planner/toolset/workbench 稳定边界 |

## 4. 分阶段执行顺序

### 4.1 Wave 0：基线

| wave | worktree | 必须前置 | 可并行 | 目标 |
|---|---|---|---|---|
| 0 | WT00 | 无 | 否 | 完成目录治理基线、全链路观测基线、测试脚手架基线 |

### 4.2 Wave 1：持久化主键骨架

| wave | worktree | 必须前置 | 可并行 | 目标 |
|---|---|---|---|---|
| 1 | WT01 | WT00 | 否 | 完成 `session + turn` 落库和读取主链 |

### 4.3 Wave 2：入口与工具面

| wave | worktree | 必须前置 | 可并行 | 目标 |
|---|---|---|---|---|
| 2A | WT02 | WT01 | 可与 WT03 并行 | 完成 `Tool Contract` 和 Tool Gateway 正式实现 |
| 2B | WT03 | WT01 | 可与 WT02 并行 | 完成 `Intent Gate Contract` 实现化 |

### 4.4 Wave 3：Provider 与事实

| wave | worktree | 必须前置 | 可并行 | 目标 |
|---|---|---|---|---|
| 3A | WT04 | WT02 | 可与 WT05 并行 | 完成 `Provider Capability Contract` 和 `DeepSeek/OpenAI-compatible` profile |
| 3B | WT05 | WT02 | 可与 WT04 并行 | 完成 `领域事实协议` 与工具返回事实分层 |

### 4.5 Wave 4：上下文与收尾

| wave | worktree | 必须前置 | 可并行 | 目标 |
|---|---|---|---|---|
| 4A | WT06 | WT01 + WT04 + WT05 | 可与 WT07 部分并行，但建议先合并 WT06 | 完成 `Memory & Context` 召回、摘要、预算协议实现 |
| 4B | WT07 | WT01 + WT02 + WT05 | 在 WT06 合并后再收尾最稳 | 完成 `Finalizer Contract` 实现 |

### 4.6 Wave 5：行为层

| wave | worktree | 必须前置 | 可并行 | 目标 |
|---|---|---|---|---|
| 5A | WT08 | WT02 + WT03 + WT04 + WT06 + WT07 | 可与 WT09 局部并行，但建议先合并 WT08 | 完成 `Planning & Execution` 轻规划协议实现 |
| 5B | WT09 | WT03 + WT08 | 可少量并行，但依赖 WT08 的 planner 输出结构 | 完成 `Skill Runtime` 实现 |

### 4.7 Wave 6：滚动门禁

| wave | worktree | 必须前置 | 可并行 | 目标 |
|---|---|---|---|---|
| 6 | WT10 | WT00 起即可启动，之后持续 rebase | 是，贯穿所有阶段 | 扩展 `13_评测与回归协议` 到完整门禁与 fixture |

## 5. 全链路观测必须前置

### 5.1 原则

| 原则 | 说明 |
|---|---|
| 不等出问题再加日志 | 观测点必须和协议同时落地 |
| 不留临时写盘日志 | 只保留正式 diagnostics 链路 |
| 开发阶段允许正文进入 diagnostics | 但必须继续脱敏 `Authorization / api_key / Bearer / Cookie` |
| 每层固定 correlation key | 至少要有 `session_id / turn_id / message_id / tool_call_id / provider / model` |

### 5.2 必备观测点

| 层 | 必备观测 |
|---|---|
| Ingress | 原始用户输入、session_id、message_id、gate decision、selected_pet_id、resolved_pet_id |
| Workbench | capability catalog、visible tool names、context summary、memory entry count、recent conversation count |
| Planner | task type、step list、step transitions、replan reason |
| Tool Gateway | tool schema name、args、policy decision、duration、fact count、citation ids、failure code |
| Provider Request | 发给上游的完整请求体正文、model route、response_format、tool count |
| Provider Response | 上游返回 body、stream chunk、tool_call delta、reasoning delta、finish_reason、usage |
| Finalizer | final_text、verification、citations、proposed_actions、summary triggered、turn terminal status |
| Persistence | 哪些表写成功/失败、行主键、时序 |

### 5.3 观测 ownership

| worktree | 观测 ownership |
|---|---|
| WT00 | 定义字段规范、红线脱敏规则、共用 diagnostics helper |
| WT01 | session/turn/persistence 观测 |
| WT02 | tool/policy/result 观测 |
| WT03 | gate 分类与 light-path 观测 |
| WT04 | provider request/response/stream/error 观测 |
| WT06 | recall/summary/budget 观测 |
| WT07 | finalizer terminal output 观测 |
| WT08 | planner step/replan 观测 |
| WT10 | 为以上观测加门禁测试 |

## 6. 目录与文件规则前置治理

### 6.1 必须在 WT00 先完成的目录基线

| crate | 目标目录 |
|---|---|
| `maohuoban-ai-domain` | `src/ai/model/`, `src/ai/workbench/` |
| `maohuoban-ai-application` | `src/ai/intent/`, `src/ai/turn_context/`, `src/ai/runtime/`, `src/ai/tools/`, `src/ai/memory/`, `src/ai/session_summary/`, `src/ai/planning/`, `src/ai/finalizer/`, `src/ai/provider_capability/`, `src/ai/skill/` |
| `maohuoban-ai-infrastructure` | `src/Infrastructure/provider/`, `src/repository/` |
| `maohuoban-ai-http` | `src/Infrastructure/ai/router/chat/composition/`, `loaders/`, `persistence/`, `responses/`, `runtime/` |

### 6.2 文件规则

| 规则 | 实施要求 |
|---|---|
| 一个类型优先一个文件 | 新增 `SessionTurn`, `ProviderProfile`, `SkillDefinition`, `TaskType` 等都单文件 |
| 一个文件只一个主要职责 | 不再制造新的 god file |
| Rust 文件尽量 <= 300 行 | 超过 500 行视为必须拆分 |
| 共享协议类型先落 domain/application | 避免 HTTP/infra 先定义出隐式协议 |

### 6.3 哪些文件必须禁止多人并行改

| 文件族 | 原因 |
|---|---|
| `runtime/session.rs` | turn 事件映射高冲突 |
| `runtime/agent_runtime_loop_engine.rs` | 核心闭环高冲突 |
| `runtime_request.rs` / `agent_runtime_request_policy.rs` | tool/provider/skill 多层都会碰 |
| `chat/turn_preparation.rs` | gate/session/turn 交汇点 |
| `provider/openai_compatible.rs` / `sse.rs` | provider 能力层高冲突 |

## 7. 每个 worktree 的明确 ownership

| worktree | 允许写入 |
|---|---|
| WT00 | 共用 diagnostics、目录结构、`mod.rs` 装配、测试脚手架 |
| WT01 | session/turn 领域模型、迁移、repository、history loader |
| WT02 | tools/*、runtime_tools、policy guard、tool audit |
| WT03 | intent/*、turn_preparation gate 路径、gated responses |
| WT04 | provider/*、provider tests、config/profile |
| WT05 | fact_package、tool_fact_schema/projection、runtime_tools fact mapping |
| WT06 | memory/*、session_summary/*、conversation_history/*、context_budget/* |
| WT07 | finalizer 新目录、assistant message finalize、citation/action write orchestration |
| WT08 | planning/*、runtime_phase / execution policy / replan policy |
| WT09 | skill/*、capability/toolset -> skill runtime 映射 |
| WT10 | tests/*、fixtures/*、eval cases、diagnostics assertions |

## 8. 集成顺序

### 8.1 合并规则

| 规则 | 说明 |
|---|---|
| 所有 worktree 先 merge 到 `codex/ai-runtime-integration` | 不直接打到 `main` |
| 有前置依赖的 worktree 必须在依赖 merge 后 rebase | 降低冲突和语义漂移 |
| WT10 持续 rebase 最新 integration | 让门禁始终反映当前真相 |

### 8.2 推荐合并顺序

1. WT00  
2. WT01  
3. WT02 和 WT03  
4. WT04 和 WT05  
5. WT06  
6. WT07  
7. WT08  
8. WT09  
9. WT10 最终门禁补齐  
10. `codex/ai-runtime-integration` -> `main`

## 9. 工作方式

### Task 1: WT00 结构与观测基线

**Files:**
- Modify: `maohuoban-rust/crates/maohuoban-ai-*/**/mod.rs`
- Modify: `maohuoban-rust/crates/maohuoban-ai-http/src/Infrastructure/ai/router/diagnostics*.rs`
- Modify: `maohuoban-rust/tests/ai_contract.rs`
- Create: 目录骨架与共用 diagnostics helper

- [ ] 固定目录落点和文件 ownership。
- [ ] 固定 correlation id 字段。
- [ ] 固定“开发阶段可记录正文、认证字段必须脱敏”的 diagnostics 规则。
- [ ] 给 diagnostics 增加 contract tests。
- [ ] merge 到 integration。

### Task 2: WT01 Session + Turn

**Files:**
- Create: `maohuoban-ai-domain/src/ai/model/session_turn.rs`
- Create: `maohuoban-ai-application/src/ai/ports/session_turn_repository.rs`
- Create: `maohuoban-ai-infrastructure/src/repository/session_turn.rs`
- Modify: `migrations/*`
- Modify: `history loader / session repository / runtime session`

- [ ] 先补 `ai_session_turns` 和 `turn_id` 绑定。
- [ ] 跑 session/turn/domain roundtrip 和 history/replay 测试。
- [ ] merge 到 integration。

### Task 3: WT02 Tool Gateway 与 WT03 Intent Gate 并行

**Files:**
- WT02 只改 `tools/*`, `runtime_tools.rs`, `policy/*`
- WT03 只改 `intent/*`, `turn_preparation.rs`, `gated responses`

- [ ] WT02 固化模型侧工具协议 + 运行时元数据 + turn_id 工具审计。
- [ ] WT03 固化分类边界、light path 和 risk signal。
- [ ] 各自 green 后 merge。

### Task 4: WT04 Provider Profiles 与 WT05 Domain Facts 并行

**Files:**
- WT04 只改 `provider/*`, provider tests
- WT05 只改 `fact_package`, `tool_fact_*`, runtime tool fact mapping

- [ ] WT04 固化 `OpenAI-compatible` 与 `DeepSeek` profile。
- [ ] WT05 固化强事实/弱线索/待确认事实协议。
- [ ] 各自 green 后 merge。

### Task 5: WT06 Memory & Context

**Files:**
- Modify: `memory/*`, `session_summary/*`, `conversation_history/*`, `turn_context/context_budget.rs`

- [ ] 固化 recall pipeline、summary boundary、budget trim。
- [ ] 先跑 memory/history/summary tests。
- [ ] merge 到 integration。

### Task 6: WT07 Finalizer

**Files:**
- Create: `maohuoban-ai-application/src/ai/finalizer/*`
- Modify: `non_stream_handler.rs`, `runtime_stream_helpers.rs`, persistence helpers

- [ ] 统一 terminal output 收口。
- [ ] 同步/异步收尾边界固定。
- [ ] 跑 persistence/history/replay/diagnostics tests。
- [ ] merge 到 integration。

### Task 7: WT08 Planning & Execution

**Files:**
- Create: `maohuoban-ai-application/src/ai/planning/*`
- Modify: `runtime_phase.rs`, `loop engine`, `evidence_planner.rs`

- [ ] 将轻规划协议实体化。
- [ ] 区分 retry 与 replan。
- [ ] 跑 runtime loop / regression / eval_case tests。
- [ ] merge 到 integration。

### Task 8: WT09 Skill Runtime

**Files:**
- Create: `maohuoban-ai-application/src/ai/skill/*`
- Modify: `turn_context`, `workbench prompt projection`, capability/toolset mapping

- [ ] 实现内置 skill runtime，不开放用户自定义。
- [ ] 跑 workbench/toolset/skill prompt 投影测试。
- [ ] merge 到 integration。

### Task 9: WT10 Eval & Regression 持续门禁

**Files:**
- Modify: `tests/ai_contract/*`
- Modify: `runtime_* tests`
- Create: `fixtures/eval_cases/*`

- [ ] 从 WT00 开始滚动补门禁。
- [ ] 每个阶段 merge 前补对应 contract tests。
- [ ] 最后跑全量 AI 核心回归。

## 10. 验证门禁

| 阶段 | 最小命令 |
|---|---|
| 每个 worktree 完成 | `cargo fmt --all --check` + 对应最小测试命令 |
| 每个 wave 完成 | `cargo check --workspace --all-targets` |
| integration 合并前 | `cargo test -p maohuoban-ai-domain -p maohuoban-ai-application -p maohuoban-ai-infrastructure -p maohuoban-ai-http --all-targets` |
| 最终推进 main 前 | `cargo test --workspace` |

## 11. 风险

| 风险 | 处理 |
|---|---|
| worktree 并行改共享核心文件 | 用明确 ownership 和 merge 顺序避免 |
| 先写功能后补观测 | 规定 WT00 必须最先完成，后续每枝自带层级观测 |
| 先写业务后补目录治理 | 规定 WT00 先固定目录和模块落点 |
| WT10 只在最后补门禁 | 改成滚动 worktree，从第一阶段开始跟进 |

