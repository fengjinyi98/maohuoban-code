# ADR：毛球 Agent 能力工作台与 Rig 接入架构决策

- 创建时间：2026-06-28
- 最近更新：2026-06-30
- 文档类型：ADR / 架构决策记录
- 当前状态：草案，待评审
- 替代说明：已替代过时的 TurnPlan ADR，旧 ADR 文件已清理
- 决策范围：Rust AI Agent Runtime、AgentSession、LoopEngine、Tool Gateway、Context / Memory、Provider Adapter、SSE Adapter、Diagnostics / Eval
- 关联 Issue：`docs/agent/Issue/2026-06-28_毛球Agent入口路由与硬软边界混淆Issue.md`
- 关联文档：
  - `docs/engineering/ai-agent-runtime/00_毛球AgentRuntime架构讨论记录.md`
  - `docs/engineering/agent-memory-security/00_毛球Agent记忆隔离与工具安全目标文档.md`
  - `docs/product/strategy/04_宠物事实采集与毛球Agent记忆系统设计.md`
  - `docs/agent/articles/31-rig-rs-rig-build-powerful-llm-applications-in-rust.md`
  - `docs/agent/articles/32-adk-rust-com-adk-rust-用-rust-构建强大的-ai-代理.md`
  - `docs/agent/articles/34-github-com-ldclabs-anda-an-ai-agent-framework-built-with-rust.md`
  - `docs/agent/articles/38-github-com-zavora-ai-adk-rust-rust-agent-development-kit-adk-rust-build-ai-agents-in-ru.md`

---

## 1. 决策结论

| 项 | 决策 |
|---|---|
| 毛球定位 | 毛球是宠物垂直领域 Agent + 用户宠物私域 Agent；用户没有宠物时仍可咨询宠物垂直公共问题和 App 使用问题 |
| 核心形态 | 引入 `AgentSession Workbench`，把 prompt、tools、context、memory、provider、policy 和事件流组织为同一个受控工作台 |
| Gate 职责 | 入口 Gate 收敛为 `HardSafetyGate`，只处理安全硬边界、越权诱导、危险写入、恶意成本滥用等硬裁决 |
| 智能来源 | 智能来自 prompt + 工具能力说明 + 上下文投影 + 记忆包 + 安全策略 + LoopEngine，而不是后端关键词路由 |
| 工具主权 | LLM 只能申请工具；工具真实执行必须经过毛伙伴自有 `Tool Gateway`、`Policy Guard`、事实裁剪和审计 |
| 事实主权 | 模型只能看到后端投影后的事实和工具结果，不能看到内部字段、表结构、展示字段、权限字段或架构细节 |
| Rig 接入 | Rig 作为 `LoopEngine` adapter POC 接入；自有 `AgentSession`、Tool Gateway、SSE、Policy、Provider、Session Store 继续由毛伙伴掌握 |
| 前端职责 | iOS 只消费后端稳定 SSE 事件；工具执行进度文案、活动状态、完成状态和错误状态都由后端提供 |
| 旧 ADR 处理 | `AgentTurnPlan` 不再作为核心执行计划；其可保留的思想下沉为 runtime 事件、事实投影和诊断字段 |

## 2. 背景与问题

### 2.1 用户纠偏

| 用户纠偏点 | 架构含义 |
|---|---|
| 用户没有宠物也应该能问宠物问题 | 宠物垂直公共能力必须独立于用户私域宠物事实 |
| 毛球是宠物垂直领域 + 用户宠物私域 Agent | 架构需要同时支持公共宠物知识、私域事实、App 帮助和助手身份 |
| Gate 只处理安全边界拦截 | 产品软边界、身份回答、App 帮助、普通宠物咨询不应由入口 gate 固定回复 |
| 模型能力靠工具、上下文、记忆和 prompt 发挥 | 后端应提供受控工作台，让模型在能力目录中判断工具使用和追问 |
| 不能让模型看到内部展示字段 | 安全不能依赖 prompt，需要后端事实投影和输出校验兜底 |
| 工具进度文案由后端提供 | SSE 事件必须包含可直接展示的活动文案和真实完成状态 |

### 2.2 当前代码事实

| 层 | 文件 / 事实 | 结论 |
|---|---|---|
| Runtime Domain | `maohuoban-rust/crates/maohuoban-ai-domain/src/ai/model/runtime.rs` | 已有 `AgentSessionState`、`LoopStep`、`AgentEvent`、`ModelLabel` 等 runtime 契约 |
| LoopEngine | `maohuoban-rust/crates/maohuoban-ai-application/src/ai/runtime/engine.rs` | 已有 `LoopEngine` trait，可承接自有实现和 Rig adapter |
| AgentSession | `maohuoban-rust/crates/maohuoban-ai-application/src/ai/runtime/session.rs` | 已能把 LoopStep 映射为 `turn_started`、`model_call_started`、`tool_started`、`turn_finished` 等事件 |
| Runtime Loop | `maohuoban-rust/crates/maohuoban-ai-application/src/ai/runtime/agent_runtime_loop_engine.rs` | 已能执行模型调用、工具执行、工具结果回灌和二次模型调用 |
| Tool Gateway | `maohuoban-rust/crates/maohuoban-ai-application/src/ai/tools/registry.rs` | 工具注册、工具 metadata、工具发现、执行前 `PolicyGuard` 已出现 |
| Policy Guard | `maohuoban-rust/crates/maohuoban-ai-application/src/ai/policy/guard.rs` | 已能基于 `authorized_pet_id` 校验工具参数，写入和高风险工具要求确认 |
| SSE Adapter | `maohuoban-rust/crates/maohuoban-ai-http/src/Infrastructure/ai/router/chat/runtime_stream.rs` | 已能把工具开始 / 完成、模型 delta、完成和错误映射为稳定事件，并缓冲未完整 JSON delta |
| HTTP Gate | `maohuoban-rust/crates/maohuoban-ai-http/src/Infrastructure/ai/router/chat/stream_handler.rs`、`non_stream_handler.rs` | 主链路按 `enters_workbench()` 处理硬安全阻断；`context_loaded` 仅表达是否加载私域事实和审计状态 |
| 无宠物路径 | `maohuoban-rust/crates/maohuoban-ai-http/src/Infrastructure/ai/router/chat/stream_handler.rs` | `target_pet=None` 仍进入 `AgentSession Workbench`；公共能力可用，私域宠物工具被隐藏 |
| LLM request | `maohuoban-rust/crates/maohuoban-ai-application/src/ai/runtime/agent_runtime_loop_engine.rs` | Runtime 根据 Workbench 和 `ToolRegistry` 构造模型可见工具目录，初次和工具回灌后的模型调用都走流式 provider |

### 2.3 旧 `AgentTurnPlan` ADR 的问题

| 问题 | 说明 |
|---|---|
| 过度后端路由 | `AnswerRoute` 容易继续演化成“后端判断用户说什么，然后固定回答什么”的规则机 |
| 软边界仍被分类主导 | `SoftBoundary`、`AppSupport`、`AssistantIdentity` 仍在入口计划里被预判，模型的工具选择和表达能力受限 |
| 私域上下文被误作能力边界 | `NoPetFacts` 虽然表达不加载私域事实，但旧讨论仍偏向“不进入主 Agent” |
| `ProviderUnavailable` 混入 route | Provider 错误属于运行时失败态，不应成为业务回答路线 |
| 实施切片偏补丁 | 旧 ADR 更像修 `context_loaded` 的执行分支，未完成 Agent 能力工作台的边界设计 |

## 3. 新架构目标

| 目标 | 可验证结果 |
|---|---|
| 建立能力工作台 | 一次用户 turn 进入 `AgentSession Workbench` 后，模型能基于能力目录直接回答、调用工具、追问或安全降级 |
| 支持无宠物用户 | 没有 selected pet 或没有授权宠物时，公共宠物咨询、App 帮助和助手身份仍能自然回答 |
| 私域事实按需读取 | 用户涉及自己宠物事实时，模型申请私域工具，Tool Gateway 鉴权后返回裁剪事实 |
| 工具进度真实可消费 | 后端输出 started / completed / failed 活动事件，iOS 不需要根据工具名自行映射文案 |
| 安全边界代码兜底 | Prompt injection、越权、医疗、写入、成本滥用由后端策略裁决和输出校验处理 |
| Provider 可替换 | DeepSeek、OpenAI compatible、后续 GLM / Kimi 通过 provider adapter 和 model label 接入 |
| LoopEngine 可替换 | 自有 LoopEngine 和 Rig adapter 都实现同一 `LoopEngine` trait，HTTP / SSE / Tool Gateway 不绑定具体框架 |
| Eval 可回归 | 通过固定 case 验证无宠物公共问答、私域工具调用、越权拒绝、工具进度、provider 错误和输出泄露 |

## 4. 核心概念

### 4.1 能力域

| 能力域 | 含义 | 是否需要宠物私域事实 |
|---|---|---:|
| `PublicPetDomain` | 宠物照护、饮食、行为、常见症状、通用风险提醒等公共垂直知识 | 否 |
| `PrivatePetContext` | 用户授权宠物的档案、饮食、异常、提醒、记录、家庭上下文 | 是 |
| `AppProductSupport` | 毛伙伴 App 使用帮助、添加宠物、记录、历史、提醒等产品问题 | 否 |
| `AssistantIdentity` | 用户询问毛球是谁、能做什么、边界是什么 | 否 |
| `HardSafety` | prompt injection、越权诱导、危险写入、成本滥用、安全事件 | 否 |

### 4.2 Runtime 组件

| 组件 | 职责 | 边界 |
|---|---|---|
| `HardSafetyGate` | 入口硬安全裁决 | 不负责普通产品边界话术 |
| `AgentDefinition` | 定义主 Agent 身份、系统规则、可用能力域和默认模型标签 | 首期只注册 `main_pet_care_agent` |
| `CapabilityCatalog` | 给模型说明有哪些能力、何时使用、需要哪些信息 | 不直接执行工具 |
| `ToolCapabilityCatalog` | 工具摘要、风险、参数 schema、progress 文案、domain tags | schema 由后端生成 |
| `ContextPack` | 当前 surface、selected pet 摘要、授权宠物候选、会话摘要 | 只包含可给模型看的字段 |
| `MemoryPack` | 用户偏好、宠物记忆、家庭记忆、会话摘要 | 按 user / pet / household scope 隔离 |
| `Tool Gateway` | 工具白名单、参数校验、鉴权、事实裁剪、审计 | LLM 不能绕过 |
| `Policy Guard` | 允许、拒绝、改参、确认、终止 | 代码裁决优先 |
| `Output Guard` | 回答事实校验、内部字段泄露校验、医疗和引用校验 | 返回用户前执行 |
| `LoopEngine` | 模型调用、工具调用、工具结果回灌、终止条件 | 可用自有实现或 Rig adapter |
| `SessionEventStore` | append-only 记录 turn、tool、policy、provider、runtime event | 用户可见消息和 runtime event 分离 |
| `SSE Adapter` | 把 runtime event 投影为 iOS 稳定事件 | iOS 不消费 provider chunk |

## 5. 决策边界

### 5.1 Gate 边界

| 输入类型 | Gate 行为 | 后续路径 |
|---|---|---|
| 宠物公共咨询 | 通过 | 进入 AgentSession，允许公共知识回答或工具选择 |
| 用户私域宠物问题 | 通过 | 进入 AgentSession，按需申请私域工具 |
| App 使用帮助 | 通过 | 进入 AgentSession，可使用 App 帮助能力 |
| 助手身份问题 | 通过 | 进入 AgentSession，由身份 prompt 和能力目录回答 |
| 非宠物泛话题 | 通过或轻限制 | 进入 AgentSession，由产品边界能力轻量引导 |
| prompt injection | 阻断 | 直接安全响应，记录风险 |
| 越权读取诱导 | 阻断或进入工具层拒绝 | 不返回私域事实 |
| 危险医疗 / 写入动作 | 阻断或要求确认 | 不执行危险动作 |
| 恶意成本滥用 | 限制或阻断 | 限速、冷却、短答或安全响应 |

### 5.2 宠物上下文边界

| 场景 | 处理 |
|---|---|
| 无 selected pet，用户问通用养宠知识 | 进入 `PublicPetDomain`，不加载私域事实 |
| 无授权宠物，用户问“猫拉肚子怎么办” | 进入 `PublicPetDomain`，给通用观察建议和就医边界 |
| 有 selected pet，用户问“几岁了” | 工作台带入当前 pet 上下文，模型可申请 `load_pet_identity_context` |
| 用户提到授权宠物名 | 后端解析到授权 `pet_id`，私域工具只返回该 `pet_id` 的裁剪事实 |
| 用户提到未授权宠物 | Tool Gateway / Policy Guard 拒绝，不透露存在性 |
| 用户要求读取全部宠物或管理员数据 | `HardSafetyGate` 或 Tool Gateway 拒绝并记录安全事件 |

### 5.3 Rig 接入边界

| 项 | 决策 |
|---|---|
| 接入位置 | `LoopEngine` trait 后面新增 `RigLoopEngineAdapter` |
| 保留主权 | `AgentSession`、`Tool Gateway`、`Policy Guard`、`Provider Adapter`、`SSE Adapter`、`SessionEventStore` 仍在毛伙伴自有代码 |
| POC 目标 | 验证 Rig 的 sans-IO step、工具调用状态、暂停恢复、审批流程是否适配毛球 |
| 不接入范围 | 不让 Rig 直接访问业务服务，不让 Rig 替代 HTTP handler，不让 Rig 管理宠物事实权限 |
| 成功标准 | 同一组 runtime contract case 在自有 engine 和 Rig adapter 下都能通过 |

### 5.4 Rig POC 当前落地状态

| 项 | 当前状态 |
|---|---|
| Adapter | `RigLoopEngineAdapter` 保留为 fake step adapter 合同测试；`RigAgentRunLoopEngine` 已接入真实 `rig-core::agent::run::AgentRun` |
| Step source | `AgentRun` 作为 sans-IO state machine 决定 `CallModel / CallTools / Done`，真实 IO 由自有 driver 完成 |
| 统一输出 | Rig model/tool/done 步骤统一映射为自有 `LoopStep`，再由 `AgentSession` 投影为 `AgentEvent` |
| 合同测试 | `rig_agent_run_engine.rs` 验证 provider -> tool -> followup 闭环；`runtime_engine_selector.rs` 验证 engine 选择链路 |
| 运行时选择 | `AgentRuntimeEngineFactory` 支持 `self_hosted` / `rig_poc`，HTTP 流式和非流式入口通过 factory 构造 engine |
| 配置入口 | `MAOHUOBAN_AI_RUNTIME_ENGINE=self_hosted|rig_poc`，未知值回退 `self_hosted` |
| POC 限制 | `rig_poc` 当前使用 Rig `AgentRun` 管状态机，provider、Tool Gateway、Policy Guard、context 组装仍由毛伙伴自有代码掌握 |

### 5.5 Rig 与 DeepSeek provider 兼容性记录

| 能力 | 当前结论 | 验证状态 |
|---|---|---|
| OpenAI compatible tools | `RigAgentRunLoopEngine` 复用自有 `LlmChatRequest.tools` 和 `LlmProvider`，工具执行继续走 `ToolRegistry` | fake provider + fake tool 已覆盖；DeepSeek provider SSE tool-call delta 已用 httpmock 覆盖 |
| Streaming | Rig driver 先消费自有 provider stream，`Delta` 转 `LoopStep::MessageDelta`，stream 完成后把累计内容 / tool call 喂回 `AgentRun` | `rig_agent_run_engine.rs` 已覆盖 streaming + tool + followup |
| JSON output | `visible_text_from_model_output` 已过滤 JSON `answer_text` 和 `<think>` 内容；Rig delta 同样先进入内部事件层 | Rig followup 测试覆盖 `<think>` + JSON draft + `answer_text` 提取 |
| Tool failure fallback | DeepSeek 工具调用失败属于 provider/runtime 错误分类；当前 `self_hosted` 是默认生产路径，`rig_poc` 可通过 `MAOHUOBAN_AI_RUNTIME_ENGINE` 显式开启或关闭 | provider error 诊断保留 stable code、retryable、safe fallback 和 engine mode |
| 观测字段 | runtime 事件和 HTTP provider error 诊断可区分 `self_hosted` / `rig_poc` | `runtime_engine_selector.rs`、`rig_agent_run_engine.rs`、`chat_stream::ai_chat_stream_records_backend_diagnostics_chain` 覆盖 |

### 5.6 Codex 上下文压缩参考结论

| Codex 机制 | 参考文件 | 毛球落点 |
|---|---|---|
| history 与当前上下文分离 | `references/agent/codex/codex-rs/core/src/context_manager/history.rs` | `RecentConversationPack`、`SessionSummary`、`AgentSessionWorkbench` 分层管理 |
| compact lifecycle | `references/agent/codex/codex-rs/core/src/compact.rs` | 压缩应是显式生命周期，后续补 pre/post compact 诊断事件 |
| replacement history | `compact.rs` 中 `replacement_history` | 压缩后应替换历史窗口，保留摘要 + tail，避免每轮重复旧前缀 |
| initial context reinjection | `InitialContextInjection` | 摘要只作为历史参考；当前宠物、能力目录、memory、policy 每轮由 builder 重新注入 |
| context diff update | `context_manager/updates.rs` | 后续可对 pet/context/memory 做差量注入，当前先保持每轮构建稳定 Workbench |
| token-budget compact | `compact_token_budget.rs` | DeepSeek 1M 先用 `ContextBudgetPolicy` 控制 recent window，再由 `SessionSummaryCompressor` 写压缩边界 |

### 5.7 上下文组装底层原则

| 层 | 原则 |
|---|---|
| HTTP handler | 只负责认证、请求 DTO、SSE/JSON 响应和持久化编排 |
| Turn preparation | 只生成 session、message id、gate、pet resolution、审计前置信息 |
| Context manager | 后续下沉 `load_history_and_summary`，统一加载 recent history、active summary、压缩结果 |
| TurnContextBuilder | 每轮重新组装 `AgentSessionWorkbench`，摘要是参考材料，当前轮能力和宠物上下文由代码决定 |
| LoopEngine | 只消费 Workbench，不加载历史、不读数据库、不访问业务服务 |
| Projector | Rig raw delta、provider delta、JSON draft、reasoning 都先转内部事件，再投影为 iOS 可见事件 |

## 6. 推荐数据流

### 6.1 总体链路

```text
用户消息
  -> HTTP / Auth 解析 actor_user_id
  -> HardSafetyGate 只做硬安全裁决
  -> AgentSession Workbench
       -> AgentDefinition
       -> CapabilityCatalog
       -> ContextPack
       -> MemoryPack
       -> ToolCapabilityCatalog
       -> LoopEngine
  -> 模型判断直接回答 / 调用工具 / 追问 / 轻量引导
  -> Tool Gateway 鉴权执行并裁剪事实
  -> 工具结果回灌模型
  -> Output Guard 校验
  -> AgentEvent
  -> SSE Adapter
  -> iOS 展示工具进度、文本增量、完成、错误或确认
```

### 6.2 无宠物公共咨询链路

```text
用户：“猫拉肚子一般要观察什么？”
  -> HardSafetyGate: allowed
  -> ContextPack: no selected_pet, no private facts
  -> CapabilityCatalog: PublicPetDomain 可用
  -> LoopEngine: 模型直接回答通用观察要点
  -> Output Guard: 医疗边界校验
  -> SSE: delta + message_completed
```

### 6.3 私域工具链路

```text
用户：“我家豆包今天拉肚子，是不是换粮了？”
  -> HardSafetyGate: allowed
  -> ContextPack: selected pet / 授权宠物候选
  -> 模型申请 load_pet_current_diet_context / load_food_inventory_change_hints
  -> Tool Gateway 校验 actor_user_id + pet_id
  -> 工具返回裁剪事实和 citation refs
  -> SSE 输出 AgentActivity / ToolCall started / completed
  -> 工具结果回灌模型
  -> Output Guard 校验弱线索表达和引用
  -> message_completed
```

### 6.4 写入确认链路

```text
用户：“帮我把这次拉肚子记下来”
  -> 模型申请 create_pet_symptom_event
  -> Tool Gateway 识别写入工具
  -> Policy Guard 返回 RequireConfirmation
  -> AgentEvent::NeedsConfirmation
  -> SSE confirmation_task
  -> iOS 展示确认卡
  -> 用户确认后由后端确认接口执行真实写入
```

## 7. 后续 TDD 任务拆分

### Task 1：AgentSession Workbench 契约

| 项 | 内容 |
|---|---|
| 目标 | Runtime 输入从单一 user input 扩展为 workbench context，能表达能力目录、上下文包和记忆包 |
| 前置依赖 | 当前 `AgentSession` / `LoopEngine` 已存在 |
| 回归验证 | `cargo test -p maohuoban-ai-domain runtime_event_roundtrip && cargo test -p maohuoban-ai-application runtime_contract` |

#### Slice 1.1：ContextPack / CapabilityCatalog domain roundtrip

| 项 | 要求 |
|---|---|
| 行为目标 | `ContextPack`、`CapabilityCatalog`、`AgentDefinition` 可 serde roundtrip，且不包含内部字段 |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-domain/tests/workbench_contract.rs` |
| 允许修改 | `maohuoban-ai-domain/src/ai/model/runtime*`、additive export |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-domain workbench_contract` |
| 回归命令 | `cargo test -p maohuoban-ai-domain runtime_event_roundtrip` |
| 完成证据 | 记录 roundtrip payload、禁止字段断言 |
| 停止条件 | 需要改 HTTP 或 Provider 才能通过时停止 |

#### Slice 1.2：AgentSession 接收 Workbench 输入

| 项 | 要求 |
|---|---|
| 行为目标 | `AgentSession` prompt 时携带 workbench context，fake engine 能读取能力数量并产出事件 |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-application/tests/runtime_contract.rs` |
| 允许修改 | `maohuoban-ai-application/src/ai/runtime/*` |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-application agent_session_uses_workbench_context` |
| 回归命令 | `cargo test -p maohuoban-ai-application runtime_contract` |
| 完成证据 | 记录 fake engine 读取 capability count 的断言 |
| 停止条件 | 需要真实工具或真实 Provider 时停止 |

### Task 2：HardSafetyGate 收敛

| 项 | 内容 |
|---|---|
| 目标 | 入口 Gate 只输出硬安全裁决，不再用 `context_loaded=false` 决定是否进入 AgentSession |
| 前置依赖 | Task 1 |
| 回归验证 | `cargo test -p maohuoban-ai-application intent_gate && cargo test -p maohuoban_rust --test ai_contract ai_chat_stream` |

#### Slice 2.1：Gate contract 去掉软路由早退语义

| 项 | 要求 |
|---|---|
| 行为目标 | 公共宠物咨询、助手身份、App 帮助、普通非宠物输入均为 `Allowed` 或轻限制，不返回 `skip_main_agent` |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-application/tests/intent_gate.rs` 或新增 `safety_gate.rs` |
| 允许修改 | `maohuoban-ai-application/src/ai/intent/*` 或新增 `ai/safety/*` |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-application safety_gate_allows_non_private_turns` |
| 回归命令 | `cargo test -p maohuoban-ai-application intent_gate` |
| 完成证据 | 记录旧 `off_topic=skip_main_agent` case 改为允许进入 workbench 的断言 |
| 停止条件 | 需要调整 HTTP SSE 协议时停止并拆到 WT-05 |

#### Slice 2.2：HTTP handler 不再用 context_loaded 早退

| 项 | 要求 |
|---|---|
| 行为目标 | `stream_handler` 不再通过 `if !context_loaded` 返回 `gated_stream_response`；硬安全单独响应 |
| 先写失败测试 | `maohuoban-rust/tests/ai_contract/chat_stream.rs` 新增身份 / 无宠物公共咨询 case |
| 允许修改 | `maohuoban-ai-http/src/Infrastructure/ai/router/chat/*` |
| 最小绿灯命令 | `cargo test -p maohuoban_rust --test ai_contract ai_chat_stream_identity_enters_workbench` |
| 回归命令 | `cargo test -p maohuoban_rust --test ai_contract ai_chat_stream` |
| 完成证据 | 记录 Provider 或 fake workbench 被调用、SSE 事件顺序 |
| 停止条件 | 需要重写 iOS Store 时停止并拆到 WT-05 |

### Task 3：公共宠物能力和私域工具能力分层

| 项 | 内容 |
|---|---|
| 目标 | 无 pet 时进入公共宠物能力；有授权 pet 时私域工具可用；两者共用 AgentSession |
| 前置依赖 | Task 1、Task 2 |
| 回归验证 | `cargo test -p maohuoban-ai-application runtime_loop_engine && cargo test -p maohuoban_rust --test ai_eval` |

#### Slice 3.1：无宠物公共咨询不加载私域工具

| 项 | 要求 |
|---|---|
| 行为目标 | 无 selected pet 的公共宠物问题进入 workbench，工具目录不包含私域宠物读取工具 |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-application/tests/runtime_loop_engine.rs` |
| 允许修改 | `maohuoban-ai-application/src/ai/runtime/*`、`ai/tools/*` |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-application public_pet_domain_without_private_tools` |
| 回归命令 | `cargo test -p maohuoban-ai-application runtime_loop_engine` |
| 完成证据 | 记录工具 count 和私域工具缺席断言 |
| 停止条件 | 需要引入公共知识库时停止，首期可用 prompt + fake provider |

#### Slice 3.2：授权宠物问题按需调用私域工具

| 项 | 要求 |
|---|---|
| 行为目标 | 目标 pet 已授权时，模型工具调用必须经过 Tool Gateway，工具结果回灌后再生成回答 |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-application/tests/runtime_loop_engine.rs` |
| 允许修改 | `maohuoban-ai-application/src/ai/runtime/*`、`maohuoban-ai-http/src/Infrastructure/ai/router/chat/runtime_tools.rs` |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-application agent_runtime_executes_private_tool_through_gateway` |
| 回归命令 | `cargo test -p maohuoban-ai-application runtime_loop_engine` |
| 完成证据 | 记录 tool_started、tool_finished、followup model 请求断言 |
| 停止条件 | 工具需要访问未授权业务域时停止 |

### Task 4：RigLoopEngineAdapter POC

| 项 | 内容 |
|---|---|
| 目标 | 在自有 `LoopEngine` trait 后面增加 Rig adapter POC，验证可替换性 |
| 前置依赖 | Task 1 的 Workbench 契约 |
| 回归验证 | `cargo test -p maohuoban-ai-application rig_loop_engine` |

#### Slice 4.1：Rig adapter 编译级契约

| 项 | 要求 |
|---|---|
| 行为目标 | `RigLoopEngineAdapter` 实现 `LoopEngine`，fake Rig state 可产出 `CallModel / CallTools / Done` |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-application/tests/rig_loop_engine.rs` |
| 允许修改 | `maohuoban-ai-application/src/ai/runtime/rig_adapter/*`、必要 additive export |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-application rig_loop_engine_contract` |
| 回归命令 | `cargo check -p maohuoban-ai-application` |
| 完成证据 | 记录同一 fake case 可由 adapter 输出相同 `AgentEvent` 顺序 |
| 停止条件 | 需要让 Rig 直接访问 Tool Gateway 或 Provider 时停止并重新评审 |

## 8. 验收门禁

| 类型 | 命令 / 验收 |
|---|---|
| Domain 契约 | `cargo test -p maohuoban-ai-domain runtime_event_roundtrip workbench_contract` |
| Runtime 契约 | `cargo test -p maohuoban-ai-application runtime_contract runtime_loop_engine` |
| Tool Gateway | `cargo test -p maohuoban-ai-application tool_registry tool_discovery policy_guard` |
| HTTP 合同 | `cargo test -p maohuoban_rust --test ai_contract ai_chat_stream` |
| Eval | `cargo test -p maohuoban_rust --test ai_eval` |
| Rust 构建 | `cargo check -p maohuoban-ai-domain -p maohuoban-ai-application -p maohuoban-ai-infrastructure -p maohuoban-ai-http` |
| iOS 构建 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'id=<当前连接真机设备ID>' -configuration Debug build` |

## 9. 不变约束

| 约束 | 说明 |
|---|---|
| 宠物事实权威 | 宠物事实仍来自后端业务读模型和 `pet_id`，Agent 不创建第二套宠物事实源 |
| 工具执行 | LLM 只能申请工具，真实执行必须通过 Tool Gateway |
| 前端职责 | iOS 只消费后端稳定事件，不理解 provider chunk，不自行映射工具文案 |
| 模型可见内容 | 模型只能看到后端投影字段，不能看到内部 key、表结构、展示状态字段、安全字段 |
| 写入动作 | 提醒创建、事实回写、饮食修改、症状记录等写操作必须用户确认 |
| 医疗边界 | 模型可提供观察建议和就医提醒，不能给诊断、开药、剂量 |
| 引用 | 引用只绑定回答实际使用的事实，由后端事件提供 |
| Provider 错误 | Provider 未配置、超时、限流、上游失败属于系统失败态，不伪装成普通助手拒答 |
| Rig 主权 | Rig adapter 不接管业务权限、事实源、HTTP、SSE、审计和持久化 |

## 10. 风险

| 风险 | 处理 |
|---|---|
| Workbench 抽象过大 | 先按 ContextPack、CapabilityCatalog、Tool Gateway、SSE 事件四个可测切片推进 |
| Gate 收敛后成本上升 | 用 `lite` 模型、短上下文、公共能力 prompt 和限速策略控制成本 |
| 模型乱用私域工具 | Tool Gateway 校验 `actor_user_id`、`authorized_pet_id`、scope、risk_level，拒绝返回私域事实 |
| 工具过多导致 token 膨胀 | 借鉴 Anda，先暴露工具组摘要，再按需展开 schema |
| Rig 依赖牵动过大 | Rig 只做 adapter POC，保持自有 `LoopEngine` 可随时回退 |
| 结构化输出不稳定 | `visible_text_from_model_output` 保持兼容；结构化 blocks 后续通过 Output Guard 和合同测试升级 |
| 旧测试锁住错误行为 | Eval 和合同测试中 `off_topic=skip_main_agent` 旧断言必须迁移为安全边界和能力域断言 |
| 诊断缺证据 | 每个 turn 记录 hard safety、capability set、tool request、policy decision、provider category、output guard 结果摘要 |
