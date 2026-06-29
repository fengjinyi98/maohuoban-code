# TODO：毛球 Agent 解耦与 Hermes 借鉴落地清单

- 创建时间：2026-06-29
- 文档类型：TODO
- 关联参考：`references/agent/hermes-agent`
- 关联文档：`docs/engineering/ai-agent-runtime/02_毛球Agent能力工作台与Rig接入ADR.md`

## 0. 文档边界

| 项 | 说明 |
|---|---|
| 本文是什么 | 待办清单，用于拆分下一阶段工程动作 |
| 本文不是什么 | 不是目标文档、不是 ADR、不是最终架构规范 |
| 使用方式 | 逐项勾选；每项完成后补充 PR / commit / 测试证据 |

## P0：先解决用户可见输出边界

- [x] 定义 `InternalTurnEvent` 与 `UserVisibleTurnEvent` 的最小事件枚举。
  - 交付物：domain/application 层事件类型草案。
  - 验证：内部模型 delta、工具规划、JSON 输出不能直接成为 SSE `delta`。
  - 完成证据：`maohuoban-ai-domain/src/ai/model/runtime.rs` 已新增内部事件与用户可见事件；`runtime_event_roundtrip` 覆盖两类事件 roundtrip 和事件名。

- [x] 拆分后端 SSE 投影层，只允许 `UserVisibleTurnEvent` 进入 iOS 协议。
  - 交付物：SSE projector 只消费用户可见事件。
  - 验证：工具执行态、正文、确认卡片、错误分别进入独立事件。
  - 完成证据：`runtime_stream.rs` 先把 `AgentEvent` 投影为 `UserVisibleTurnEvent`，再映射为 SSE；iOS decoder 支持 `execution_trace_*`、`answer_*` 新事件名。

- [x] 增加后端流式思考清理器。
  - 借鉴：Hermes `StreamingThinkScrubber`。
  - 交付物：跨 chunk 过滤 `<think>`、`<thinking>`、`<reasoning>`、`<REASONING_SCRATCHPAD>`。
  - 验证：模型思考过程不会以正文流式渲染给用户。
  - 完成证据：`visible_text_prefix_from_model_output` 增加思考标签清理；`projector_scrubs_cross_chunk_thinking_and_internal_context_before_sse_delta` 覆盖跨 chunk 场景。

- [x] 增加内部上下文 / JSON 输出清理器。
  - 借鉴：Hermes `StreamingContextScrubber`。
  - 交付物：过滤内部事实包、memory context、JSON Output 草稿、provider 原始结构。
  - 验证：流式过程中不会展示内部字段，完成后也不依赖前端覆盖隐藏。
  - 完成证据：输出解析层保留 `answer_text` 提取并过滤 `memory_context`、`provider_raw` 等内部片段；completion 仍走后端校验与引用投影。

- [x] 固化“工具执行态在正文之前展示”的事件顺序。
  - 交付物：`execution_trace_started -> execution_trace_completed -> answer_delta -> answer_completed` 合同。
  - 验证：后端工具已完成时，前端不会继续展示“正在执行”。
  - 完成证据：`projector_emits_execution_trace_completed_before_answer_delta` 固化事件顺序；stream handler 已在 `answer_completed` 持久化助手消息。

### P0 完成验证

| 验证项 | 命令 / 结果 |
|---|---|
| Domain 事件边界 | `cargo test -p maohuoban-ai-domain turn_event_boundary_separates_internal_and_user_visible_events` 通过 |
| Runtime SSE projector | `cargo test -p maohuoban-ai-http runtime_stream` 通过 |
| 受影响 Rust crates | `cargo test -p maohuoban-ai-domain -p maohuoban-ai-application -p maohuoban-ai-http` 通过 |
| Rust 格式 | `cargo fmt --all --check` 通过 |
| Rust lint | `cargo clippy --workspace --all-targets` 通过，无新增 warning |
| Rust 编译 | `cargo check -p maohuoban-ai-domain -p maohuoban-ai-application -p maohuoban-ai-http` 通过 |
| iOS 真机 Debug 构建 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'id=00008120-0016704C0E9B401E' -configuration Debug build` 通过，`** BUILD SUCCEEDED **` |
| iOS DTO 最小测试 | `xcodebuild test ... -only-testing:maohuobanTests/AIAssistantDTOTests/testDecodeAnswerDeltaEvent -only-testing:maohuobanTests/AIAssistantDTOTests/testDecodeAnswerCompletedEvent -only-testing:maohuobanTests/AIAssistantDTOTests/testDecodeExecutionTraceEvents` 通过，`** TEST SUCCEEDED **` |

## P1：拆 Agent Turn 前置上下文

- [x] 新增 `TurnContextBuilder` 或等价 builder。
  - 借鉴：Hermes `TurnContext`。
  - 交付物：把安全裁决、会话摘要、宠物上下文、工具目录、记忆包从 LoopEngine 中拆出。
  - 验证：LoopEngine 只负责模型循环和工具回灌。
  - 完成证据：`maohuoban-ai-application/src/ai/turn_context/mod.rs` 新增 `TurnContextBuilder`，HTTP 层 `workbench_builder.rs` 透传 `session_summary`/`memory_entries` 并委托调用（`stream_handler.rs`/`non_stream_handler.rs` 已适配）；`turn_context_builder.rs` 9 个测试覆盖无宠物/有宠物/会话摘要/记忆按 pet_id 过滤场景。
  - 已知边界：HTTP 生产路径当前传入 `session_summary=None`、`memory_entries=Vec::new()`，会话历史加载和记忆包组装属于 P2 交付范围。

- [x] 定义 `ContextPack`。
  - 交付物：只包含模型允许看到的上下文字段。
  - 验证：不包含数据库字段、权限字段、UI 展示字段、内部状态字段。
  - 完成证据：`context_pack.rs` 新增 `has_private_context()`；`context_pack_boundary.rs` 4 个测试覆盖私域判断、禁止字段断言（database/permission/display/internal/profile_number/avatar_url/status）、roundtrip。

- [x] 定义 `MemoryPack`。
  - 交付物：按 `user_id`、`pet_id`、`household_id` 区分记忆来源。
  - 验证：无宠物公共问答不加载私域宠物记忆。
  - 完成证据：`memory_pack.rs` 新增 `filter_for_public_context()` 移除 Pet/Household scope；`filter_for_pet_context(pet_id)` 仅按 pet_id 过滤 Pet scope，无 household_id 时全部移除 Household scope（subject_id 是 household_id 而非 pet_id）；`memory_pack_isolation.rs` 8 个测试覆盖混合 scope 过滤、纯 Pet scope 过滤、按 pet_id 过滤其他宠物、Household 无 household_id 全移除、空包、User/Session 保留。后续 P2 接入 household_id 后扩展 `filter_for_private_context(pet_id, household_id)`。

- [x] 定义 `CapabilityCatalog`。
  - 交付物：告诉模型当前 turn 可用能力域和使用边界。
  - 验证：无宠物用户仍可进入公共宠物能力；私域工具按授权宠物启用。
  - 完成证据：`capability_catalog.rs` 新增 `has_private_capabilities()`；`capability_catalog_boundary.rs` 4 个测试覆盖纯公共目录、含私域目录、空目录、公共能力不要求私域上下文；`turn_context_builder.rs` 验证无宠物不含 PrivatePetContext、有宠物追加 PrivatePetContext。

## P1：工具能力与进度文案标准化

- [x] 扩展工具 metadata。
  - 字段：`toolset`、`domain`、`scope`、`risk_level`、`progress_started_text`、`progress_completed_text`、`result_fact_schema`。
  - 验证：前端不需要根据工具名映射文案。
  - 完成证据：`AiToolMetadata` 新增 `toolset: Toolset`、`progress_text: ToolProgressText`、`result_fact_schema: Option<ToolFactSchema>`；`ToolDefinitionInfo` 透传三个新字段；`ToolRegistry::list_definitions` 填充新字段；HTTP 层 `RuntimePetContextToolKind` 按 kind 提供进度文案和事实 schema；`toolset_metadata_boundary.rs` 10 个测试 + `tool_metadata_standardization.rs` 7 个测试覆盖全部边界。

- [x] 建立工具 toolset 分组。
  - 借鉴：Hermes toolsets。
  - 初始分组：`public_pet_domain`、`private_pet_context`、`app_support`、`memory`、`confirmation`。
  - 验证：每个 turn 的模型工具清单由 toolset + 权限 + selected pet 共同决定。
  - 完成证据：Domain 层新增 `Toolset` 枚举（5 个 variants，snake_case 序列化，Ord/Hash 可做 BTreeMap key）；`ToolRegistry` 新增 `list_by_toolset(toolset)` 按分组过滤和 `list_toolset_groups()` 按分组汇总；`ToolsetGroupSummary` 类型暴露分组摘要；`AgentRuntimeRequestPolicy` 新增 `is_private_toolset` 判断，`toolset=PrivatePetContext` 的工具在无已选宠物时被隐藏，优先于旧 `scope`/`domain_tags` 规则；`runtime_tool_visibility.rs` 新增 `SneakyPrivateTool` 测试验证 `scope`/`domain_tags` 不命中旧规则但 `toolset` 命中时仍被隐藏。

- [x] 工具结果统一进入事实投影。
  - 交付物：工具原始结果与模型可见事实包分离。
  - 验证：模型看不到业务内部字段，只看到裁剪后的事实和引用 ID。
  - 完成证据：Domain 层新增 `ToolFactProjector` 投影器、`ModelVisibleToolResult` 和 `ModelVisibleFact` 类型；`ModelVisibleFact` 只有 `certainty` 和 `text` 两个字段，`citation_id` 已从结构体移除（编译期保证）；`project_facts` 过滤内部状态 key（status/life_status 等）、保留 `reference_ids` 列表、映射 `strength` 为确定性标签；`project_denied`/`project_failed` 只返回通用安全文案不暴露原始原因；`tool_fact_projection_boundary.rs` 8 个测试覆盖内部字段过滤、`citation_id` 字段不存在断言、JSON 不含 `citation_id`、安全文案、确定性标签、空包。

- [x] 工具执行审计与用户可见轨迹分离。
  - 交付物：审计记录保留工具参数 hash、授权结果、风险标签；用户轨迹只保留展示文案和状态。
  - 验证：用户可见事件不携带敏感参数。
  - 完成证据：Domain 层新增 `ToolExecutionAudit`（tool_name + tool_call_id + args_hash + allowed + risk_level + toolset）和 `ToolExecutionTrace`（display_text + status + citation_count）；`ToolExecutionTrace` 不携带 `tool_call_id`，JSON 序列化验证轨迹不含 `tool_call_id`/`args`/`hash`/`risk`/`toolset`/`allowed` 字段；`tool_audit_trace_separation.rs` 7 个测试覆盖审计字段完整性、轨迹字段最小化（无 `tool_call_id`）、JSON roundtrip、两者可从同一执行构建但携带不同信息。

## P2：同会话上下文连续性

### P2 边界修正

| 项 | 本阶段口径 |
|---|---|
| 先解决的问题 | 同一个 `chat_session_id` 内的连续追问、代词承接、上一轮主题承接 |
| 参考 Hermes | `SessionStore.load_transcript -> _build_gateway_agent_history -> run_conversation(conversation_history=...) -> build_turn_context` |
| DeepSeek 1M 的影响 | 可以放宽最近历史预算和推迟压缩触发；仍需要后端受控投影历史 |
| 历史输入原则 | 只把模型允许看到的会话内容投影进 messages；内部事件、执行轨迹、provider raw、reasoning、JSON 草稿不进入普通历史 |
| 与长期记忆关系 | 同会话历史解决当前聊天连续性；跨会话记忆、用户偏好、用户画像走独立 MemoryPack / Workspace 机制 |

- [ ] 新增 `RecentConversationLoader`。
  - 借鉴：Hermes `SessionStore.load_transcript()`。
  - 输入：`actor_user_id`、`chat_session_id`、provider context length、当前 turn token 预算。
  - 输出：当前会话内按时间升序排列的最近消息窗口。
  - 验证：新聊天第一轮历史为空；同一聊天第二轮能加载上一轮 user / assistant 正文。

- [ ] 新增 `ConversationHistoryProjector`。
  - 借鉴：Hermes `_build_gateway_agent_history()`。
  - 交付物：把持久化消息投影成模型可见历史。
  - 允许角色：`user` 最终输入、`assistant` 最终可见正文、必要的已完成工具协议消息。
  - 过滤内容：`execution_trace_*`、`tool progress UI`、`provider_raw`、`reasoning_content`、`JSON Output` 草稿、内部 fact package、错误堆栈、权限字段。
  - 验证：历史投影测试断言上述内部字段不会出现在 `LlmChatRequest.messages`。

- [ ] 扩展 `TurnContextBuilder` 接收同会话最近历史。
  - 交付物：新增 `RecentConversationPack` 或等价字段，和 `ContextPack`、`MemoryPack` 分层保存。
  - 验证：`TurnContextBuilder` 只接收已投影历史，不直接读数据库，不直接拼 provider raw。

- [ ] 改造 `AgentRuntimeLoopEngine::build_messages`。
  - 当前差距：`build_messages` 只读取 `state.user_inputs.last()`，`AiPromptBuilder::build_messages(..., &[], ...)` 传入空历史。
  - 交付物：请求 messages 顺序固定为 `system/workbench context -> recent conversation history -> current user message -> 本轮 assistant tool call/result 回灌`。
  - 验证：连续追问 case 中第二轮请求包含上一轮主体和回答正文。

- [ ] 新增 `ContextBudgetPolicy`。
  - 策略：按 provider `context_length` 推导历史预算；DeepSeek 1M 初期可使用较大最近窗口，保留 turn 数、token、字节数硬上限。
  - 裁剪顺序：优先保留当前用户消息、最近轮次、当前选中宠物相关轮次、已引用事实；较早普通闲聊先裁剪。
  - 验证：超预算时请求仍可构造，且不会把全量历史无界塞给模型。

- [ ] 新增同会话连续性回归 case。
  - case：用户第一轮问“豆包今天拉肚子怎么办”，第二轮追问“那要不要停罐头？”。
  - 验证：第二轮能识别“它 / 豆包 / 拉肚子 / 罐头”来自同一会话历史，并按需要申请饮食或异常工具。

## P2：会话摘要与上下文压缩兜底

- [ ] 新增会话摘要更新策略。
  - 借鉴：Hermes `context_compressor.py` 和 `conversation_compression.py`。
  - 触发：请求接近预算阈值、同会话历史超过配置上限、用户主动继续很长旧会话。
  - 交付物：长会话超过阈值后生成结构化摘要，作为 `session_summary` 注入 `ContextPack`。
  - 验证：摘要保留宠物主体、事实引用、用户偏好、未完成确认动作。

- [ ] 新增摘要安全边界。
  - 交付物：摘要标记为“历史参考”，只辅助理解当前问题。
  - 验证：摘要不会把旧任务、旧工具调用、旧确认动作重新激活为当前任务。

- [ ] 新增压缩后历史重写策略。
  - 交付物：压缩后的会话保留最近尾部消息和结构化摘要，写入 `chat_session_summaries` 或等价表。
  - 验证：压缩后继续追问仍能识别当前主体，旧内部事件不会被压缩摘要带回模型。

## P2：跨会话记忆与候选写入

- [ ] 新增记忆候选写入流程。
  - 交付物：把“可记忆信息”先写候选，再由校验或用户确认升级。
  - 验证：宠物健康、饮食、档案事实必须经过用户确认或业务工具确认。

- [ ] 新增私域记忆检索过滤。
  - 交付物：检索条件必须带 `scope_type`、`scope_id`、`actor_user_id`、可选 `pet_id` / `household_id`。
  - 验证：公共问答不加载 pet 私域记忆；未授权 pet 记忆不可检索。

## P2：工具循环与失败恢复

- [ ] 增加 per-turn 工具循环 guardrail。
  - 借鉴：Hermes `ToolCallGuardrailController`。
  - 交付物：检测重复失败、同参重复、只读工具无进展。
  - 验证：模型不会反复调用同一个失败工具直到超时。

- [ ] 区分软提醒和硬停止。
  - 交付物：普通无进展先给模型内部提醒；安全越界、重复危险写入进入硬停止。
  - 验证：普通失败不会直接变成用户硬拒答。

- [ ] 工具失败结构化返回。
  - 交付物：工具统一返回 `error_code`、`recoverable`、`safe_user_message`、`internal_reason`。
  - 验证：前端只展示安全文案，模型可根据 recoverable 决定追问或换工具。

## P3：能力扩展机制

- [ ] 评估渐进工具披露。
  - 借鉴：Hermes `tool_search`、`tool_describe`、`tool_call`。
  - 触发条件：工具 schema 明显膨胀，影响模型选择和 token 成本。
  - 验证：核心工具常驻，长尾工具按需描述。

- [ ] 建立 Agent runtime 回归 case。
  - case：无宠物公共问答、私域工具调用、工具进度、思考过滤、JSON 过滤、连续追问、越权拒绝、工具重复失败。
  - 验证：同一组 case 可覆盖自有 engine 和 Rig adapter。

## P3：Rig 接入 POC

- [ ] 明确 Rig 接入边界。
  - 决策：Rig 只作为 `LoopEngine` adapter POC。
  - 保留自研主权：`AgentSession Workbench`、`Tool Gateway`、`Policy Guard`、`UserVisibleTurnEvent`、`SSE Adapter`、`SessionEventStore`。
  - 验证：Rig 不能直接访问业务服务、数据库、宠物事实源和 HTTP handler。

- [ ] 新增 `RigLoopEngineAdapter` 骨架。
  - 交付物：实现现有 `LoopEngine` trait。
  - 输入：`TurnContext`、`CapabilityCatalog`、模型配置、工具目录。
  - 输出：统一转换为自有 `InternalTurnEvent` / `LoopStep`。
  - 验证：fake Rig state 可产出 model call、tool request、tool result、done。

- [ ] 建立 Rig 与自研 engine 的合同测试。
  - case：直接回答、单工具调用、工具失败、工具后 followup、需要确认、流式正文、思考过滤。
  - 验证：同一输入下，两种 engine 产出相同用户可见事件顺序。

- [ ] 增加 engine 选择配置。
  - 交付物：运行时可配置 `self_hosted` / `rig_poc`。
  - 验证：切换 engine 不影响 HTTP、SSE、iOS DTO、Tool Gateway、Policy Guard。

- [ ] 验证 Rig tool calling 与 DeepSeek provider 的兼容性。
  - 交付物：记录 Rig 对 OpenAI compatible tools、streaming、JSON output 的实际支持差异。
  - 验证：DeepSeek 工具调用失败时可回落到自研 engine，错误分类可观测。

- [ ] 验证 Rig 流式事件清洗位置。
  - 交付物：Rig raw delta 必须先进入内部事件层，再由自有 Projector 清洗。
  - 验证：Rig 输出的 reasoning、tool planning、JSON draft 不会进入 iOS 正文流。

- [ ] 设定 Rig POC 停止条件。
  - 条件：需要让 Rig 直接管理宠物权限、事实裁剪、SSE 协议、会话存储或工具真实执行时暂停接入。
  - 处理：保留自研 engine，重新评审接入边界。

## 参考点

| 参考项目文件 | 可借鉴内容 |
|---|---|
| `references/agent/hermes-agent/AGENTS.md` | core narrow waist、能力放边缘、prompt caching 稳定 |
| `references/agent/hermes-agent/agent/turn_context.py` | turn 前置上下文 builder |
| `references/agent/hermes-agent/gateway/session.py` | session key、transcript 加载、会话生命周期 |
| `references/agent/hermes-agent/gateway/run.py` | transcript -> agent history 投影、缓存 agent history 保护 |
| `references/agent/hermes-agent/agent/conversation_loop.py` | conversation_history 进入模型请求前的最终清洗和临时上下文注入 |
| `references/agent/hermes-agent/agent/context_compressor.py` | 长会话摘要压缩、历史参考边界、头尾保护 |
| `references/agent/hermes-agent/tools/registry.py` | 工具注册、toolset、可用性检查 |
| `references/agent/hermes-agent/tools/tool_search.py` | 渐进工具披露 |
| `references/agent/hermes-agent/agent/think_scrubber.py` | 流式思考清理 |
| `references/agent/hermes-agent/agent/memory_manager.py` | memory context 清理与 provider 编排 |
| `references/agent/hermes-agent/agent/tool_guardrails.py` | 工具循环 guardrail |
| `references/agent/hermes-agent/agent/context_engine.py` | 可替换上下文引擎 |
