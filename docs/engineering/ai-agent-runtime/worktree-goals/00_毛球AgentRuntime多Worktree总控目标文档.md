# 毛球 Agent Runtime 多 Worktree 总控目标文档

- 更新时间：2026-06-28
- Goal：将毛球 Agent 最终架构定稿为自有 `maohuoban-agent-runtime` SDK 化分层形态，并拆成 6 个可并行 worktree 目标；每个 worktree 只负责一个独立边界，能独立测试、独立验证、独立合并。
- 执行方式：先目标文档后实现；每个 worktree 必须 TDD；所有 worktree 以本文档冻结的契约名称、事件名称、文件边界和验收门禁为准。
- 关联文档：
  - `docs/engineering/ai-agent-runtime/00_毛球AgentRuntime架构讨论记录.md`
  - `docs/engineering/ai-llm-integration/00_毛球Agent后端LLM接入与前端流式聊天目标文档.md`
  - `docs/engineering/agent-memory-security/00_毛球Agent记忆隔离与工具安全目标文档.md`
  - `references/agent/rig`
  - `references/agent/adk-rust`
  - `references/agent/anda`
  - `references/agent/pi`

---

## 1. 当前定稿结论

| 项 | 结论 |
|---|---|
| 最终形态 | 自有 Agent Runtime SDK + 可插拔 Loop Engine + 领域安全能力层 + 多端 Adapter + Eval / Replay 基础设施 |
| 首期 Agent 形态 | 单主 Agent + 工具池 + Tool Discovery；预留多 Agent 接口，首期只注册 `main_pet_care_agent` |
| 框架策略 | Rig 用于 Loop Engine POC；ADK-Rust 借鉴工具元数据；Anda 借鉴工具发现、模型路由、上下文压缩；Pi 借鉴 SDK / Adapter 分层 |
| 主权边界 | Tool Gateway、Policy Guard、Domain Memory、Provider Error Taxonomy、SSE Protocol、Persistence Policy 全部由毛球自有代码掌握 |
| 并行策略 | 契约、工具、Provider、Session Store、Adapter、Eval 六个 worktree 并行；每个 worktree 只改自己的文件族 |
| 合并策略 | 优先合并 WT-01 契约；其他 worktree 通过独立测试证明局部正确，合并时只解决 additive export / mod 声明冲突 |

## 2. 多 Worktree 切分

| Worktree | 目标文档 | 独立结果 | 主要文件边界 |
|---|---|---|---|
| WT-01 | `01_WT01_Runtime契约与LoopEngine目标文档.md` | Runtime 核心契约、事件、LoopEngine trait、AgentSession 骨架 | `maohuoban-ai-domain/src/ai/model/runtime*`、`maohuoban-ai-application/src/ai/runtime*` |
| WT-02 | `02_WT02_ToolGateway与PolicyGuard目标文档.md` | 工具元数据、工具发现、策略裁决、确认事件 | `maohuoban-ai-application/src/ai/tools*`、`maohuoban-ai-application/src/ai/policy*` |
| WT-03 | `03_WT03_Provider错误分类与ModelRouter目标文档.md` | Provider 错误分类、模型 label 路由、重试 / fallback 契约 | `maohuoban-ai-domain/src/ai/model/provider*`、`maohuoban-ai-infrastructure/src/Infrastructure/provider*` |
| WT-04 | `04_WT04_SessionEventStore与Replay目标文档.md` | 结构化 session event store、turn replay、历史写入策略 | `maohuoban-ai-domain/src/ai/model/session_event*`、`maohuoban-ai-infrastructure/src/repository*`、`migrations/*ai*` |
| WT-05 | `05_WT05_HTTP_SSE_iOS协议Adapter目标文档.md` | 后端 SSE adapter 和 iOS 消费协议稳定化 | `maohuoban-ai-http/src/Infrastructure/ai*`、`maohuoban/maohuoban/Features/AI*` |
| WT-06 | `06_WT06_Eval与Diagnostics目标文档.md` | Eval harness、诊断事件、replay 验证样例 | `maohuoban-rust/tests/ai_eval*`、`.maohuoban-diagnostics` 读取辅助、AI diagnostics 文件 |

## 3. 总体架构边界

```text
iOS / History / IM / Replay / CLI
  -> HTTP-SSE Adapter / RPC Adapter
  -> maohuoban-agent-runtime SDK
  -> AgentSession / AgentSessionRuntime
  -> LoopEngine Adapter
  -> Tool Gateway / Policy Guard / Domain Memory / Model Router / Provider Adapter
  -> Session Event Store + Telemetry + Eval
```

## 4. 冻结契约命名

| 契约 | 首期名称 |
|---|---|
| 主 Agent | `main_pet_care_agent` |
| Runtime 会话 | `AgentSession` |
| Runtime 外层 | `AgentSessionRuntime` |
| Loop 引擎 trait | `LoopEngine` |
| Loop step | `CallModel`、`CallTools`、`Done` |
| 模型标签 | `lite`、`primary`、`pro`、`memory` |
| 工具策略结果 | `Allow`、`Deny`、`Transform`、`RequireConfirmation`、`Terminate` |
| Provider 错误大类 | `not_configured`、`timeout`、`rate_limited`、`upstream`、`stream_interrupted`、`invalid_response` |
| 用户可见失败文案 | `暂时无法获取回答，请稍后重试。` |

## 5. 冻结事件名称

| 事件 | 触发点 | 必备字段 |
|---|---|---|
| `turn_started` | 收到用户输入并创建 turn | `turn_id`、`chat_session_id`、`agent_id`、`surface` |
| `policy_checked` | 策略裁决完成 | `turn_id`、`decision`、`risk_level` |
| `model_call_started` | 发起 Provider 请求前 | `turn_id`、`model_label`、`tool_count` |
| `model_call_finished` | Provider 请求完成 | `turn_id`、`finish_reason`、`usage` |
| `tool_started` | 工具执行前 | `turn_id`、`tool_call_id`、`tool_name` |
| `tool_finished` | 工具执行后 | `turn_id`、`tool_call_id`、`status`、`citation_count` |
| `needs_confirmation` | 写入或高风险动作需用户确认 | `turn_id`、`confirmation_task_id`、`question_text` |
| `needs_clarification` | 缺宠物、缺事实或问题歧义 | `turn_id`、`reason`、`suggested_actions` |
| `message_delta` | 输出用户可见文本增量 | `turn_id`、`text` |
| `provider_error` | Provider 失败 | `turn_id`、`category`、`retryable` |
| `turn_finished` | 本轮完成 | `turn_id`、`message_id`、`final_text`、`status` |
| `turn_failed` | 本轮失败 | `turn_id`、`error_code`、`retryable` |

## 6. Worktree 隔离规则

| 规则 | 要求 |
|---|---|
| 文件边界 | 每个 worktree 只修改自己目标文档列出的文件族；跨界必须停止并记录原因 |
| 契约改动 | `AgentEvent`、`LoopEngine`、错误分类、SSE 事件名属于共享契约，只能 WT-01 或对应目标修改 |
| Cargo 改动 | 不新增 crate；使用现有 `maohuoban-ai-*` crate，避免多个 worktree 同时改根 `Cargo.toml` |
| migration 改动 | 只有 WT-04 可以新增 AI session event 相关 migration |
| iOS 改动 | 只有 WT-05 可以修改 `maohuoban/maohuoban/Features/AI` |
| 诊断改动 | 只有 WT-06 可以新增 Eval / Diagnostics 专用测试和诊断读取辅助 |
| 共享 `mod.rs` 冲突 | 允许 additive export；合并时按模块名保留所有新增声明 |
| 临时日志 | 只允许 WT-06 增加诊断事件；其他 worktree 不保留临时打印 |

## 7. 全局验收门禁

| 类型 | 命令 / 验收 |
|---|---|
| Rust 基础构建 | `cargo check -p maohuoban-ai-domain -p maohuoban-ai-application -p maohuoban-ai-infrastructure -p maohuoban-ai-http` |
| AI crate 测试 | `cargo test -p maohuoban-ai-domain -p maohuoban-ai-application -p maohuoban-ai-infrastructure -p maohuoban-ai-http` |
| AI 合同测试 | `cargo test -p maohuoban_rust --test ai_contract` |
| iOS scheme 检查 | `xcodebuild -list -project maohuoban/maohuoban.xcodeproj` |
| iOS Debug 构建 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build` |
| 文档复查 | 每个 worktree 最终回复必须列出红灯测试、绿灯测试、回归命令和未覆盖风险 |

## 8. 不变约束

| 约束 | 说明 |
|---|---|
| 宠物事实权威 | 宠物事实仍来自后端业务读模型和 `pet_id`，Agent 不创建第二套宠物事实源 |
| 工具执行 | LLM 只能申请工具，真实执行必须通过 Tool Gateway |
| 写入动作 | 提醒创建、事实回写、饮食修改等写操作必须用户确认 |
| 前端职责 | iOS 只消费后端稳定事件，不直接理解 Provider chunk |
| 错误边界 | Provider 错误不伪装成正常助手回答 |
| 多 Agent | 首期不实现多 Agent 调度，只预留 `agent_id` / `AgentDefinition` |

## 9. 风险

| 风险 | 处理 |
|---|---|
| 多 worktree 同时改共享契约 | 契约类变更收敛到 WT-01；其他 worktree 只消费已冻结名称 |
| Runtime 抽象过大 | 每个 worktree 只实现一个 observable behavior，禁止一次性重写聊天链路 |
| Rig 接入引入依赖复杂度 | WT-01 先写 `LoopEngine` trait 和 fake engine；Rig adapter 作为 POC，保持可替换 |
| iOS 与后端事件不一致 | WT-05 以冻结事件表和合同测试为准，iOS DTO 不直接跟随 Provider 格式 |
| Eval 缺失导致“聪明”不可验证 | WT-06 必须在首期建立固定样例，作为后续所有 worktree 的回归门禁 |
