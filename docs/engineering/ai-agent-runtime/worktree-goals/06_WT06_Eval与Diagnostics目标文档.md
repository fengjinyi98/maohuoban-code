# WT-06 Eval 与 Diagnostics 目标文档

- 更新时间：2026-06-28
- Goal：建立毛球 Agent Runtime 的 eval harness 和诊断观测基线，让寒暄、疫苗、饮食、异常、模糊表达、越权、Provider 失败、工具失败都能独立回归验证。
- 执行方式：TDD；只新增 eval / diagnostics 测试和事件断言，不改核心业务实现。

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 聪明度验证 | 不能靠主观体验，需要固定样例和可重复断言 |
| 诊断目标 | 每次 turn 能看到 gate、policy、provider、tool、event emission 的链路 |
| Replay | Eval 和 diagnostics 要能读取 WT-04 的 session events；WT-04 未合并前使用 fixture |
| 覆盖范围 | 首期覆盖边界和退化，不追求大规模 benchmark |

## 2. 目标边界

### 2.1 本目标期必须完成

| 范围 | 目标 |
|---|---|
| Eval case | 建立 YAML / JSON / Rust fixture 样例 |
| Eval runner | 用 fake provider / fake tools 驱动 runtime 或合同链路 |
| Diagnostics 断言 | 验证关键事件不含敏感原文和密钥 |
| 回归样例 | 覆盖 public_pet_domain、private_pet_context、app_support、off_topic、provider_error、unauthorized_pet 和内部字段泄露 |
| 输出 | 每个 eval case 有通过 / 失败原因 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 线上评测平台 | 后续目标 |
| 大模型自动打分 | 首期用确定性断言 |
| 多 Agent 评测 | 首期只有主 Agent |
| 真实 Provider 成本测试 | 使用 fake / mock provider |

## 3. 依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| 当前诊断测试 | `maohuoban-rust/tests/ai_contract/chat_stream.rs` | 已断言 `ai.chat.stream.request.received`、`ai.chat.gate.decided`、provider started/error 等事件 |
| 诊断 SDK | `.maohuoban-diagnostics` 和 `maohuoban-diagnostics-sdk` | 可读取本地诊断事件 |
| 当前 intent 测试 | `maohuoban-rust/crates/maohuoban-ai-application/tests/intent_gate.rs` | 可沉淀 eval case |
| Pi SDK | `references/agent/pi/packages/coding-agent/docs/sdk.md` | SDK programmatic testing 是 runtime 独立验证方向 |
| ADK-Rust eval | `references/agent/adk-rust` | 平台化 eval 作为长期参考 |

## 4. 推荐数据流

```text
eval case
  -> fake auth / pet / provider / tools
  -> runtime or HTTP contract path
  -> collect AgentEvent + Diagnostics
  -> assert expected outcome, forbidden leakage, event sequence
```

## 5. 允许修改

| 文件 / 模块 | 要求 |
|---|---|
| `maohuoban-rust/tests/ai_eval.rs` 或 `maohuoban-rust/tests/ai_eval/*` | 新增 eval 合同测试 |
| `maohuoban-rust/tests/ai_contract/chat_stream.rs` | 只允许新增 diagnostics 断言 |
| `maohuoban-rust/crates/maohuoban-ai-application/tests/*eval*` | 应用层 fake eval |
| `docs/engineering/ai-agent-runtime/worktree-goals/eval-cases/` | 可新增样例文件 |

## 6. 禁止修改

| 文件 / 模块 | 原因 |
|---|---|
| Runtime 实现 | WT-01 负责 |
| Tool / Policy 实现 | WT-02 负责 |
| Provider 实现 | WT-03 负责 |
| Session repository | WT-04 负责 |
| iOS | WT-05 负责 |

## 7. TDD 任务拆分

### Task 1：Eval case schema

| 项 | 内容 |
|---|---|
| 目标 | 定义最小 eval case：输入、上下文、期望事件、禁止输出 |
| 前置依赖 | 无 |
| 回归验证 | `cargo test -p maohuoban-ai-application eval_case` |

#### Slice 1.1：case 解析和确定性断言

| 项 | 要求 |
|---|---|
| 行为目标 | eval case 可解析并断言 expected intent / forbidden_text |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-application/tests/eval_case.rs` |
| 允许修改 | 测试文件和 eval case fixture |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-application eval_case_parses_fixture` |
| 回归命令 | `cargo test -p maohuoban-ai-application eval_case` |
| 完成证据 | 记录至少 5 个 case 名称 |
| 停止条件 | 需要改业务 intent gate 才能通过时停止，当前只做 schema |

### Task 2：HTTP 诊断链路断言

| 项 | 内容 |
|---|---|
| 目标 | 关键 AI 请求写入完整诊断链路且不含敏感原文 |
| 前置依赖 | 当前 diagnostics SDK |
| 回归验证 | `cargo test -p maohuoban_rust --test ai_contract ai_chat_stream_records_backend_diagnostics_chain` |

#### Slice 2.1：诊断事件字段完整性

| 项 | 要求 |
|---|---|
| 行为目标 | 诊断事件包含 gate、provider、stream event，不包含完整 message 和 api_key |
| 先写失败测试 | `maohuoban-rust/tests/ai_contract/chat_stream.rs` |
| 允许修改 | 测试断言；只有缺观测点时才允许最小新增 diagnostics event |
| 最小绿灯命令 | `cargo test -p maohuoban_rust --test ai_contract ai_chat_stream_records_backend_diagnostics_chain` |
| 回归命令 | `cargo test -p maohuoban_rust --test ai_contract ai_chat_stream` |
| 完成证据 | 记录事件 message 列表 |
| 停止条件 | 需要改变 Provider 或 HTTP 行为时停止并交给对应 worktree |

### Task 3：边界 eval

| 项 | 内容 |
|---|---|
| 目标 | 固定样例覆盖 off_topic 进入 workbench、provider_error、unauthorized_pet 和输出泄露 |
| 前置依赖 | Task 1 |
| 回归验证 | `cargo test -p maohuoban_rust --test ai_eval` |

#### Slice 3.1：provider 未配置 eval

| 项 | 要求 |
|---|---|
| 行为目标 | provider 未配置样例得到 retryable=false、用户文案统一、无正常 assistant final；off_topic / app_support 不再断言 `skip_main_agent` |
| 先写失败测试 | `maohuoban-rust/tests/ai_eval/provider_error.rs` |
| 允许修改 | eval 测试和 fixture；必要时只新增 diagnostics 断言 |
| 最小绿灯命令 | `cargo test -p maohuoban_rust --test ai_eval provider_not_configured_eval` |
| 回归命令 | `cargo test -p maohuoban_rust --test ai_eval` |
| 完成证据 | 记录 event sequence 和 expected outcome |
| 停止条件 | 需要修复业务逻辑时停止并把失败交给对应 worktree |

## 8. 验收门禁

| 类型 | 命令 / 验收 |
|---|---|
| Eval schema | `cargo test -p maohuoban-ai-application eval_case` |
| Diagnostics | `cargo test -p maohuoban_rust --test ai_contract ai_chat_stream_records_backend_diagnostics_chain` |
| Eval 合同 | `cargo test -p maohuoban_rust --test ai_eval` |
| 构建 | `cargo check -p maohuoban-ai-application` |

## 9. 不变约束

| 约束 | 说明 |
|---|---|
| 不改业务通过测试 | Eval worktree 发现失败时记录证据，交给对应 worktree 修 |
| 隐私 | Eval / diagnostics 不保存完整敏感消息、API key、用户 token |
| 可重复 | 所有 eval 使用 fake / mock provider |

## 10. 风险

| 风险 | 处理 |
|---|---|
| Eval 变成实现补丁 | 严格禁止改核心业务；只写测试和最小诊断观测 |
| 断言过脆 | 断言事件名、分类、禁止文本，不断言模型自然语言细节 |
