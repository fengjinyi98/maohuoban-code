# 毛球 Agent 后端 LLM 接入与前端流式聊天目标文档

- 更新时间：2026-06-26
- Goal：新增毛球 Agent 后端 AI 编排层，使用通用 OpenAI 兼容格式接入可替换 LLM Provider，并接入 iOS 现有毛球聊天 UI、流式输出、对话记录和宠物头像/名称展示，让用户可以咨询宠物垂直公共问题，并在授权范围内围绕自己的宠物进行私域 AI 对话；宠物数据的唯一权威来源仍是后端现有宠物事实、身份、饮食、异常和事件读模型，不能在 AI 模块或前端新增第二套宠物数据源。
- 执行方式：先目标文档后实现；后端和 iOS 按 TDD / 最小切片推进；首版完成宠物垂直公共能力、用户宠物私域助手、OpenAI 兼容非流式 Provider、后端 SSE 流式转发、iOS 流式消费、历史记录列表；所有私有事实读取必须经过 Agent Gateway、业务工具和权限校验；完成后执行 Rust 质量门和 iOS Debug 构建。
- 架构修订：`docs/engineering/ai-agent-runtime/02_毛球Agent能力工作台与Rig接入ADR.md` 已将毛球定位扩展为“宠物垂直领域 Agent + 用户宠物私域 Agent”，并将入口 Gate 收敛为硬安全边界。
- 关联文档：
  - `docs/design/01_毛伙伴AI入口与后端架构方案.md`
  - `docs/product/strategy/04_宠物事实采集与毛球Agent记忆系统设计.md`
  - `docs/engineering/agent-memory-security/00_毛球Agent记忆隔离与工具安全目标文档.md`
  - `docs/engineering/pet-identity/00_宠物唯一主体与归属关系Phase1目标文档.md`
  - `docs/engineering/pet-food-inventory/00_储物柜食品资产与宠物饮食配置Phase2目标文档.md`
  - `docs/engineering/attention-hints-abnormal/00_AttentionHint与异常追踪闭环Phase3目标文档.md`

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 产品目标 | 毛球是宠物垂直领域 Agent + 用户宠物私域 Agent；首版支持公共宠物咨询、用户有权限的宠物事实问答、饮食/异常追问和建议动作确认 |
| 实现方向 | 新增独立 `maohuoban-ai-*` 后端分层 crate，并接入现有 iOS `Features/AI` 聊天页面 |
| LLM 协议 | 使用 OpenAI 兼容 Chat Completions / SSE 格式，Provider 通过 `base_url`、`api_key`、`model` 配置，不绑定厂商 SDK |
| LLM 角色 | LLM 负责理解自然语言、在授权事实包内组织回答、必要时提出工具调用或追问；事实读取、宠物解析、健康分级、写入动作和权限判断由后端完成 |
| 宠物选择 | 用户可以在问题中使用宠物名字；后端基于当前用户授权宠物列表、当前入口 `selectedPetID` 和用户消息解析目标宠物；解析结果必须落到唯一授权 `pet_id` |
| 唯一数据源 | 宠物身份、头像、名字、物种、饮食、异常、事件、提醒、历史事实都来自后端已有宠物体系和读模型；AI 不新建宠物镜像表，前端不维护第二套宠物事实 |
| 前端现状 | `AIAssistantScreen` 已有消息流、输入栏、建议问题、pending action、历史入口和 mock 流式输出 |
| 流式现状 | `AIAssistantStreamingEngine` 已支持 delta 合并、flush、complete 和单条消息增量更新 |
| 历史现状 | `AIAssistantHistoryScreen` 已有历史列表 UI，每条记录展示宠物头像、名字、标题、时间和最近消息摘要 |
| 当前后端基础 | pet 后端已有饮食上下文、储物柜弱线索、饮食确认候选、`agent_confirmation_tasks`、异常 episode 和 `attention_hints` |
| 当前缺口 | workspace 暂无 `maohuoban-ai-domain`、`maohuoban-ai-application`、`maohuoban-ai-infrastructure`、`maohuoban-ai-http`、`LlmProvider`、`/ai/chat`、`/ai/chat/stream`、AI 会话表、AI 审计表 |
| 安全边界 | Agent 没有数据库权限，不能 SQL 查询，不能绕过业务服务，不能自由检索全库记忆 |
| 写入边界 | LLM 不能直接写 `pet_events`、提醒、饮食配置；只能生成 `AiProposedAction` 或复用 `agent_confirmation_tasks`，用户确认后执行 |
| 回答边界 | 所有 LLM 输出返回用户前必须经过事实来源、工具完整性、隐私、医疗和写入边界校验 |

## 2. 目标边界

### 2.1 本目标期必须完成

| 范围 | 目标 |
|---|---|
| AI 后端分层 | 新增 `maohuoban-ai-domain`、`maohuoban-ai-application`、`maohuoban-ai-infrastructure`、`maohuoban-ai-http`，接入 workspace 和根服务装配 |
| LLM Provider 分层 | 新增 `LlmProvider` 端口、厂商 Provider factory、`DeepSeekLlmProvider` 和 OpenAI 兼容协议客户端，支持普通响应和 SSE 流式响应 |
| Provider 配置 | 从环境变量读取 `AI_LLM_PROVIDER_KIND`、`AI_LLM_BASE_URL`、`AI_LLM_API_KEY`、`AI_LLM_MODEL`、`AI_LLM_TIMEOUT_SECS`、`AI_LLM_TEMPERATURE`，日志不输出密钥 |
| 私域聊天接口 | 新增 `POST /api/v1/ai/chat` 用于非流式调试和测试；新增 `POST /api/v1/ai/chat/stream` 用于 iOS 流式聊天 |
| 会话历史接口 | 新增 `GET /api/v1/ai/chat-sessions`、`GET /api/v1/ai/chat-sessions/{id}/messages`，支撑现有历史页真实数据源 |
| 会话与消息表 | 新增 AI 会话、消息、引用、建议动作、审计表；会话只保存宠物展示快照，不作为宠物事实权威来源 |
| 宠物解析 | 新增 `AiPetResolver`，结合当前入口 pet、用户消息中的宠物名、授权宠物列表解析唯一目标宠物；歧义时追问选择 |
| 宠物候选工具 | 新增或复用后端宠物列表/身份读模型，向 Agent 提供“当前用户有权限的宠物候选摘要”，字段来自 pet 后端 |
| Agent Gateway | 新增统一工具注册和调用入口，所有私有工具从认证上下文注入 `actor_user_id` 并执行权限校验 |
| 硬安全闸门 | AgentSession Workbench 前置 `HardSafetyGate`，只处理 prompt injection、越权诱导、危险写入和恶意成本滥用；非私域请求不加载宠物事实 |
| 首批工具 | 接入 `load_pet_identity_context`、授权宠物候选、`load_pet_current_diet_context`、`load_food_inventory_change_hints`、`load_pet_diet_confirmation_candidates` |
| 事实包 | 新增 `AiFactPackage`，包含目标宠物、事实、弱线索、引用、缺失信息和事实强度 |
| Prompt 构建 | 新增 `AiPromptBuilder`，把系统规则、用户问题、宠物候选、目标宠物事实包和输出格式拼成 LLM messages |
| 回答校验 | 新增 `AiAnswerVerifier`，拦截无来源事实、弱线索误用、越权内容、医疗诊断、未确认写操作 |
| SSE 事件协议 | 后端定义稳定流式事件：`message_started`、`delta`、`tool_call`、`citation`、`proposed_action`、`message_completed`、`error` |
| iOS 真实接入 | `AIAssistantStore` 从 mock 响应切换到 Repository；保留现有流式引擎作为 UI 增量渲染层 |
| iOS 历史接入 | `AIAssistantHistoryScreen` 使用后端会话列表；每条记录继续展示宠物头像和名字 |
| 建议动作 | 后端返回 `proposed_actions` / `confirmation_tasks`；iOS pending action 卡片点击后调用后端确认接口 |
| 测试与构建 | 后端使用 fake provider / mock HTTP server 测试；iOS 用 Repository/Store 测试验证流式事件累积和历史映射；完成后执行真实 iOS Debug 构建 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| UGC @AI 自动评论回复 | 公开评论涉及审核、私域 handoff 和可见性策略，后续独立目标 |
| UGC 到私域助手完整 handoff | 需要 UGC 内容快照、图片 OCR、商品/成分摘要和路由联动，首版先完成私域聊天 |
| 向量记忆和 embedding | 当前重点是结构化事实、权限、流式聊天和历史；向量检索必须等 metadata filter 和二次鉴权准备好后接入 |
| 完整医疗分诊规则库 | 首版健康风险只做保守边界和缺失信息提示；红旗规则库后续独立评审 |
| 多 Provider 灰度平台 | 首版只做单 Provider 配置和可替换端口；灰度、A/B 和回滚后续扩展 |
| 后台运营审核台 | 本期写审计与风险数据，不做管理 UI |
| 前端复杂多宠选择器 | 歧义时后端返回选择需求，首版 iOS 可展示轻量系统消息或建议动作；完整选择 UI 后续独立切片 |
| 长期保存完整原始聊天 | 隐私策略未定；首版保存必要消息、摘要、引用、宠物展示快照和审计元数据 |
| 公共知识库 | App 帮助和公开养宠知识库后续建设；首版允许宠物垂直公共咨询进入 AgentSession Workbench，但不把模型当泛百科知识源 |

## 3. 依据

### 3.1 项目内依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| AI 架构 | `docs/design/01_毛伙伴AI入口与后端架构方案.md` | 已定义 AI 编排层、受控业务工具、安全策略、审计、LLM Provider 和回答校验 |
| LLM 质量门 | `docs/design/01_毛伙伴AI入口与后端架构方案.md` 第 11 节 | 明确结构化事实包输入、私域事实类问题强制工具链、回答前事实校验 |
| 产品定位 | `docs/product/strategy/04_宠物事实采集与毛球Agent记忆系统设计.md` | 毛球定位为结构化宠物事实底座上的 Agent |
| 工具边界 | `docs/product/strategy/04_宠物事实采集与毛球Agent记忆系统设计.md` 第 7 节 | 已定义毛球不直接扫描全部原始事件，后端提供稳定工具读模型 |
| 安全目标 | `docs/engineering/agent-memory-security/00_毛球Agent记忆隔离与工具安全目标文档.md` | 明确 Agent Gateway、工具鉴权、意图闸门、审计、风险评分和非宠物成本控制 |
| 宠物身份 | `docs/engineering/pet-identity/00_宠物唯一主体与归属关系Phase1目标文档.md` | 明确 `pet_id` 是系统内唯一身份，Agent 只能围绕同一个 `pet_id` 建立事实上下文 |
| 饮食事实 | `docs/engineering/pet-food-inventory/00_储物柜食品资产与宠物饮食配置Phase2目标文档.md` | 明确储物柜资产是弱线索，当前主粮、喂食事件、用户确认事实才是强事实 |
| 异常追踪 | `docs/engineering/attention-hints-abnormal/00_AttentionHint与异常追踪闭环Phase3目标文档.md` | 明确 `agent_confirmation_tasks` 是结构化任务，不自动写聊天消息，用户确认后才写事实 |
| iOS 聊天页 | `maohuoban/maohuoban/Features/AI/Presentation/AIAssistantScreen.swift` | 已有消息流、输入栏、建议问题、pending action、历史入口、mock 流式测试按钮 |
| iOS Store | `maohuoban/maohuoban/Features/AI/Stores/AIAssistantStore.swift` | 当前是本地 mock 状态容器，已管理消息、草稿、pending action、附件和流式引擎 |
| iOS 流式引擎 | `maohuoban/maohuoban/Features/AI/Stores/AIAssistantStreamingEngine.swift` | 已支持 delta 合并、flush、complete 和取消 |
| iOS 历史页 | `maohuoban/maohuoban/Features/AI/Presentation/AIAssistantHistoryScreen.swift` | 历史记录 UI 每行展示宠物头像、宠物名字、标题、时间和最近消息 |
| iOS 入口上下文 | `maohuoban/maohuoban/Features/AI/Domain/AIAssistantEntryContext.swift` | 当前入口携带 `selectedPetID`、`selectedPetName`、头像 URL、物种和 UGC 标题；后续仍只能作为入口上下文，不能成为事实来源 |
| 当前后端工具 | `maohuoban-rust/crates/maohuoban-pet-http/src/pet/router/agent_diet.rs` | 已有饮食上下文、储物柜变化线索、饮食确认候选、确认接口 |
| 当前确认任务 | `maohuoban-rust/crates/maohuoban-pet-domain/src/pet/model/agent_confirmation_task.rs` 和 `maohuoban-rust/migrations/0025_agent_confirmation_tasks.sql` | 已有 Agent 结构化确认任务模型和表 |
| 当前 workspace | 根 `Cargo.toml` | 目前没有 `maohuoban-ai-*` crate 和 `reqwest` 等 HTTP client |

### 3.2 OpenAI 兼容协议依据

| 来源 | 公开事实 | 对本项目的启发 |
|---|---|---|
| OpenAI 兼容 Chat Completions 生态 | 主流模型服务支持 `POST /v1/chat/completions`、`model`、`messages`、`tools`、`tool_choice`、`stream`、`usage` 等字段 | 内部定义稳定 `LlmChatRequest/Response`，Provider 单独做 OpenAI 兼容适配 |
| OpenAI-style tool calling | 模型可返回工具调用意图，工具 schema 由调用方声明，真实执行由应用侧完成 | 毛伙伴只允许模型申请工具，执行必须走 Agent Gateway 和业务服务 |
| SSE 流式 | 兼容流式通常以 SSE chunk 形式返回增量内容 | 后端把 Provider chunk 转换为毛伙伴稳定 SSE 事件，iOS 只消费自家事件协议 |
| Bearer Key | 兼容 Provider 通常使用 `Authorization: Bearer <api_key>` | 密钥只在 infrastructure Provider 内使用，不进入 domain、application、日志、HTTP 响应 |

## 4. 推荐方案 / 数据流

### 4.1 私域流式聊天主链路

```text
iOS AIAssistantStore.submitDraft
  -> AIAssistantRepository.openChatStream
  -> POST /api/v1/ai/chat/stream
  -> Auth 解析 actor_user_id
  -> AiIntentGate 轻量分类
  -> AiPetResolver 解析目标宠物
  -> Agent Gateway 强制工具链
  -> 业务工具读取授权事实包
  -> Provider factory 选择 DeepSeekLlmProvider
  -> DeepSeekLlmProvider 复用 OpenAI-compatible 协议客户端
  -> AiAnswerVerifier 增量缓冲 / 完成校验
  -> 后端 SSE 输出 message_started / delta / citation / proposed_action / completed
  -> iOS AIAssistantStreamingEngine 增量渲染
  -> 完成后刷新引用、pending action、历史记录摘要
```

### 4.2 宠物解析链路

```text
用户消息：“毛球今天拉肚子，是不是换粮了？”
  -> 读取当前用户授权宠物候选摘要
  -> 候选包含 pet_id、name、avatar、species、profile_number
  -> 若 selectedPetID 命中且消息没有明显切换宠物
     -> 使用 selectedPetID
  -> 若消息中出现唯一授权宠物名“毛球”
     -> 使用对应 pet_id
  -> 若同名或多宠歧义
     -> 返回 needs_pet_selection，不加载具体宠物事实
  -> 若目标宠物未授权或不存在
     -> 返回统一拒绝，不透露存在性
```

硬规则：LLM 可以参与自然语言理解，但最终 `target_pet_id` 必须由后端 `AiPetResolver` 在授权宠物集合内确定。前端传入的宠物名、头像、物种只作为展示上下文或乐观 UI，不能作为事实来源。

### 4.3 对话历史链路

```text
GET /api/v1/ai/chat-sessions
  -> 按 actor_user_id 查询 AI 会话
  -> 每条会话返回 pet_display_snapshot
       pet_id / pet_name / pet_avatar_url / pet_species
  -> pet_display_snapshot 来源于会话创建或最后一次后端宠物读模型投影
  -> iOS AIAssistantHistoryScreen 渲染头像、名字、标题、时间、最近消息

GET /api/v1/ai/chat-sessions/{id}/messages
  -> 鉴权 session actor_user_id
  -> 返回消息、引用、建议动作状态
  -> iOS 选中历史后回填聊天页
```

`pet_display_snapshot` 是历史展示快照，用于保证历史记录在宠物改名后仍可解释；它不是宠物事实权威来源。任何新的事实判断都必须重新从 `pet_id` 读取当前后端读模型。

### 4.4 饮食弱线索追问链路

```text
用户问：毛球拉稀，是不是换粮导致？
  -> target_pet_id = 毛球对应 pet_id
  -> load_pet_identity_context
  -> load_pet_current_diet_context
  -> 强事实中没有近期 current_staple / feeding 变化
  -> load_food_inventory_change_hints
  -> 发现近期新增主粮但未配置给该宠物
  -> 回答只能表达“需要确认”
  -> 返回 confirmation task / proposed action
  -> 用户确认后写 agent_confirmed_fact / diet_change / feeding_correction
```

### 4.5 Provider 分层与 OpenAI 兼容协议数据流

```text
AiPromptBuilder
  -> LlmChatRequest {
       model,
       messages,
       tools,
       tool_choice,
       temperature,
       stream,
       response_format
     }
  -> LlmProviderRegistryConfig.active_runtime_provider_config
  -> provider factory
  -> DeepSeekLlmProvider / future GlmLlmProvider / future KimiLlmProvider
  -> OpenAiCompatibleLlmProvider 协议客户端
  -> POST {base_url}/chat/completions 或 {base_url}/v1/chat/completions
  -> LlmStreamEvent / LlmChatResponse
  -> JSON Output answer_text 兼容解析
  -> AiAnswerVerifier
  -> Maohuoban SSE Event
```

## 5. 后端目标

### 5.1 新增 crate

| crate | 职责 |
|---|---|
| `maohuoban-ai-domain` | AI 会话、消息、intent、surface、LLM 请求响应、流式事件、工具调用、事实包、引用、建议动作、回答校验结果、错误 |
| `maohuoban-ai-application` | `AiGatewayService`、`AiIntentGate`、`AiPetResolver`、工具注册、工具编排、事实包构建、Prompt 构建、回答校验、聊天和历史用例 |
| `maohuoban-ai-infrastructure` | 厂商 Provider factory、`DeepSeekLlmProvider`、`OpenAiCompatibleLlmProvider` 协议客户端、PostgreSQL AI 仓储、审计仓储、Provider 配置、HTTP client、SSE 解析、错误映射 |
| `maohuoban-ai-http` | `/api/v1/ai/chat`、`/api/v1/ai/chat/stream`、历史接口、确认动作接口、反馈接口的 HTTP DTO 和路由 |

依赖方向：

```text
maohuoban-ai-http
  -> maohuoban-ai-application
  -> maohuoban-ai-domain

maohuoban-ai-infrastructure
  -> maohuoban-ai-application
  -> maohuoban-ai-domain

maohuoban_rust 根 crate
  -> 装配 auth / pet / ai / provider / repositories
```

AI application 可以依赖 pet application 端口或服务对象，不能直接依赖 pet infrastructure 或 SQL。

### 5.2 Domain 模型

| 模型 | 要求 |
|---|---|
| `AiChatSession` | 记录会话 ID、actor user、primary pet、surface、source hint、source task、标题、状态和时间 |
| `AiPetDisplaySnapshot` | 历史展示快照：`pet_id`、`pet_name`、`pet_avatar_url`、`pet_species`、`profile_number`；只用于展示，不作为事实源 |
| `AiMessage` | 记录用户消息、助手消息、系统边界提示、流式状态、引用、usage、provider、finish reason |
| `AiConversationSurface` | 首批支持 `home_private`、`pet_profile`、`abnormal_detail`、`confirmation_task`；预留 `ugc_comment` |
| `AiIntent` | 支持 `pet_care`、`pet_record_query`、`pet_food`、`pet_health_risk`、`emotional_pet_context`、`app_support`、`off_topic`、`prompt_injection`、`cost_abuse` |
| `AiPetResolution` | 表达 `resolved`、`needs_selection`、`unauthorized_or_not_found`、`no_pet_context` |
| `AiFactPackage` | 包含目标宠物、事实、computed、弱线索、引用、缺失信息和事实强度 |
| `AiCitation` | 引用 pet event、diet assignment、food inventory hint、attention hint、confirmation task、abnormal episode |
| `AiProposedAction` | 表达建议写操作，包含 action kind、目标 pet、payload、确认文案和风险等级 |
| `LlmChatRequest` | OpenAI 兼容请求的内部稳定模型 |
| `LlmChatResponse` | OpenAI 兼容响应的内部稳定模型 |
| `LlmStreamEvent` | Provider 流式事件内部模型，屏蔽厂商 chunk 差异 |
| `AiStreamEvent` | 毛伙伴对 iOS 输出的稳定 SSE 事件模型 |
| `AiAnswerVerification` | 校验状态、阻断原因、重试建议和安全回退文案 |

### 5.3 Provider 配置

| 配置 | 默认 / 要求 |
|---|---|
| `AI_LLM_PROVIDER_ID` | 默认 `env-openai-compatible`；运营配置中的 Provider 稳定标识 |
| `AI_LLM_PROVIDER_KIND` | 默认按 `provider_id` 推断，当前支持 `openai_compatible`、`deepseek`；运行时按 kind 装配厂商 Provider |
| `AI_LLM_PROVIDER_DISPLAY_NAME` | 默认 `OpenAI Compatible`；管理后台展示名称 |
| `AI_LLM_PROVIDER_ENABLED` | 默认 true；关闭后运行时降级为未配置 Provider |
| `AI_LLM_PROVIDER_IS_DEFAULT` | 默认 true；运行时只选择启用且默认的 Provider |
| `AI_LLM_BASE_URL` | 必填；OpenAI 格式 base URL，支持以 `/v1` 结尾或不以 `/v1` 结尾，Provider 内归一化到 `/v1/chat/completions` |
| `AI_LLM_API_KEY` | 必填；传入真实 key，Base64 等外部传输格式必须在进入后端配置前解码 |
| `AI_LLM_MODEL` | 必填；不在代码里硬编码厂商模型 |
| `AI_LLM_TIMEOUT_SECS` | 默认 30 秒 |
| `AI_LLM_TEMPERATURE` | 默认 0.2，事实问答保持低随机性 |
| `AI_LLM_MAX_OUTPUT_TOKENS` | 可选；缺省按 Provider 默认或应用层策略 |
| `AI_LLM_RESPONSE_FORMAT` | 可选；`json_object` 时按 OpenAI 兼容格式发送 `{"type":"json_object"}`，用于 DeepSeek JSON Output |

本地开发当前使用 DeepSeek OpenAI 兼容接口：

```bash
AI_LLM_PROVIDER_ID=deepseek
AI_LLM_PROVIDER_KIND=deepseek
AI_LLM_PROVIDER_DISPLAY_NAME="DeepSeek"
AI_LLM_PROVIDER_ENABLED=true
AI_LLM_PROVIDER_IS_DEFAULT=true
AI_LLM_BASE_URL=https://api.deepseek.com
AI_LLM_API_KEY=<真实 sk-... key>
AI_LLM_MODEL=deepseek-v4-flash
AI_LLM_TIMEOUT_SECS=90
AI_LLM_TEMPERATURE=0.2
AI_LLM_MAX_OUTPUT_TOKENS=4096
AI_LLM_RESPONSE_FORMAT=json_object
```

配置规则：

| 规则 | 内容 |
|---|---|
| 启动不泄密 | 日志不能输出完整 API key、Authorization header 或原始请求体敏感字段 |
| 缺配置可降级 | 本地缺少 `AI_LLM_API_KEY` 时服务可启动，AI 接口返回 provider_not_configured |
| 测试不打外网 | 单元测试和契约测试默认使用 fake provider 或 mock HTTP server |
| Provider 可替换 | application 只依赖 trait，不感知 base URL、header 和 HTTP client |
| 厂商差异隔离 | DeepSeek 独立在 `provider/deepseek.rs`，OpenAI 兼容协议客户端只负责通用 HTTP 序列化；后续 GLM/Kimi 新增各自 Provider 文件和 kind |
| 管理后台投影 | 后端只对管理后台暴露 Provider 元数据和 `api_key_configured`，不返回密钥明文 |

### 5.4 HTTP 接口

#### `POST /api/v1/ai/chat/stream`

请求：

| 字段 | 要求 |
|---|---|
| `message` | 必填，用户本轮输入，限制最大长度 |
| `selected_pet_id` | 可空；前端当前宠物上下文 |
| `surface` | 必填，入口类型 |
| `chat_session_id` | 可空；为空则创建新会话 |
| `source_hint_id` | 可空；从首页 hint 进入时传 |
| `confirmation_task_id` | 可空；从确认任务进入时传 |
| `client_message_id` | 可空，用于幂等和前端重试 |

SSE 事件：

| event | data 要求 |
|---|---|
| `message_started` | `chat_session_id`、`message_id`、`target_pet`、`title` |
| `pet_resolution` | `status`、候选宠物摘要或 resolved pet |
| `tool_call` | 工具名、状态、引用数量；不返回完整私有 payload |
| `delta` | 本次文本增量 |
| `citation` | 引用 chip / source id / source kind |
| `proposed_action` | 待确认动作 |
| `confirmation_task` | 结构化确认任务 |
| `message_completed` | final message、usage、finish reason |
| `error` | 稳定错误码、可展示文案、是否可重试 |

#### `POST /api/v1/ai/chat`

用于非流式调试、契约测试和降级。响应字段与流式完成后的聚合结果一致。

#### `GET /api/v1/ai/chat-sessions`

返回会话列表：

| 字段 | 要求 |
|---|---|
| `id` | 会话 ID |
| `title` | 会话标题 |
| `subtitle` | 展示时间，如今天/昨天/日期 |
| `pet_display_snapshot` | 宠物头像、名字、物种、`pet_id` |
| `last_message_preview` | 最近消息摘要 |
| `last_message_at` | 排序时间 |

#### `GET /api/v1/ai/chat-sessions/{id}/messages`

返回会话消息、引用、建议动作状态和当前宠物展示快照。必须校验 session 属于当前 actor。

### 5.5 数据库目标

| 表 | 目标 |
|---|---|
| `ai_chat_sessions` | 持久化会话、actor user、primary pet、surface、source hint、source task、标题、宠物展示快照和状态 |
| `ai_messages` | 持久化用户/助手/系统消息、模型、provider、finish reason、usage、回答校验状态 |
| `ai_message_citations` | 持久化回答引用的事实 ID 和类型 |
| `ai_tool_access_logs` | 记录工具调用、授权结果、目标 scope、returned ref IDs、拒绝原因和风险信号 |
| `ai_request_gate_logs` | 记录 intent、gate decision、是否加载上下文、成本估算和风险信号 |
| `ai_proposed_actions` | 持久化待确认动作；用户确认后绑定执行结果 |

数据源规则：

| 规则 | 内容 |
|---|---|
| 会话可存展示快照 | 快照只服务历史列表展示，不能作为新的宠物事实来源 |
| 事实判断重新读取 | 每轮回答都以 `pet_id` 调用后端 pet 读模型，不能用会话快照判断年龄、饮食、异常或提醒 |
| 前端只渲染快照 | iOS 历史页使用后端返回的 `pet_display_snapshot`，不能从本地 mock 或缓存推断宠物事实 |

### 5.6 首批工具

| 工具 | 来源 | 输入 | 输出原则 |
|---|---|---|---|
| `list_authorized_pet_candidates` | pet application | `actor_user_id` | 返回当前用户有权限宠物的最小摘要，用于解析和选择 |
| `load_pet_identity_context` | pet application | `actor_user_id`、`pet_id` | 返回当前授权宠物身份、生命周期和当前关系摘要 |
| `load_pet_current_diet_context` | pet application | `actor_user_id`、`pet_id` | 返回当前主粮、尝试中、常用零食/营养品、最近喂食和引用 ID |
| `load_food_inventory_change_hints` | pet application | `actor_user_id`、scope、since | 返回近期储物柜变化弱线索，标注不能当摄入事实 |
| `load_pet_diet_confirmation_candidates` | pet application | `actor_user_id`、`pet_id` | 返回待确认饮食候选和追问文案 |
| `create_diet_confirmation_task` | pet / ai application | `actor_user_id`、`pet_id`、candidate | 创建或复用 `agent_confirmation_tasks`，不写强事实 |

工具硬规则：

| 规则 | 内容 |
|---|---|
| 所有私有工具必须鉴权 | 未授权 pet 返回 denied，不透露宠物是否存在 |
| 工具输出必须裁剪 | 不返回底层兼容字段、其他用户身份、内部备注、完整审计数据 |
| 弱线索不能进入 computed 结论 | 只能进入 missing information 或 confirmation candidate |
| 工具失败不编造 | 工具失败时回答“暂时无法读取记录”，不让模型补全事实 |

## 6. iOS / 前端目标

| 任务 | 目标文件 / 模块 | 要求 |
|---|---|---|
| Repository | `maohuoban/maohuoban/Features/AI/Data` | 新增 `AIAssistantRepository`，负责 stream chat、非流式 fallback、历史列表、消息详情、确认动作 |
| DTO | `Features/AI/Data` | 定义 `AIChatStreamRequest`、`AIStreamEventDTO`、`AIChatSessionDTO`、`AIMessageDTO`、mapper |
| Store 接入 | `Features/AI/Stores/AIAssistantStore.swift` | 从 mock `responseContent` 切换到 Repository；保留 `AIAssistantStreamingEngine` 做 UI 增量合并 |
| 流式消费 | `AIAssistantStore` | 收到 `message_started` 创建 assistant 占位消息；`delta` append；`citation/proposed_action` 更新 message / pending action；`completed` 结束 streaming |
| 取消与重试 | `AIAssistantStore` | 新消息发送前取消旧 stream；网络错误后关闭 streaming 状态并展示可重试系统消息 |
| 历史列表 | `AIAssistantHistoryScreen.swift` | 使用后端会话列表；每行继续展示宠物头像、名字、标题、时间和最近消息 |
| 历史详情 | `AIAssistantStore.selectConversationHistory` | 选择历史后调用消息详情接口回填聊天页 |
| 入口上下文 | `AIAssistantEntryContext.swift` | 继续只承载 `selectedPetID` 等路由上下文；不能成为事实来源 |
| 宠物展示 | `AIAssistantConversationHistory.swift` | 增加/映射后端 `petDisplaySnapshot`；历史展示使用后端快照 |
| 确认卡 | `AIAssistantProposedAction.swift` | 对齐后端 `proposed_actions` / `confirmation_tasks`，点击确认后调用后端确认接口 |
| 临时按钮清理 | `AIAssistantScreen.swift` | 后端接入完成后移除或仅 Debug 编译保留 mock 流式测试按钮和 FPS 临时入口 |
| 测试 | `maohuoban/maohuobanTests/Features/AI` | 增加 Store 流式事件累积、历史 DTO mapping、确认动作测试 |

前端硬规则：

| 规则 | 内容 |
|---|---|
| 不传 `actor_user_id` | 用户身份只来自后端 token |
| 不拼装事实包 | 宠物事实、饮食上下文、弱线索和记忆检索都由后端构建 |
| 不直接写强事实 | 点击确认卡后调用后端确认/动作接口 |
| 不新增宠物数据源 | 前端 AI 模块不能维护独立宠物列表或事实缓存；只消费入口上下文和后端返回快照 |
| 不用快照做事实判断 | 历史 pet snapshot 只展示，不参与下一轮事实判断 |
| 不兜底跨宠物 | 当前宠物无数据或名称歧义时展示后端返回的选择/缺失信息 |
| 不为 off-topic 预加载 | 聊天输入前后不主动预取宠物事实 |
| SwiftUI 渲染无副作用 | View body、formatter、computed view 不发请求、不写状态、不写缓存 |

## 7. 观测目标

| 事件 / 信号 | 触发层 | 必备字段 |
|---|---|---|
| `ai.request.gated` | application | actor user、intent、gate decision、selected pet、resolved pet、context_loaded、risk_signal、request_hash |
| `ai.pet.resolved` | application | selected_pet_id、resolved_pet_id、resolution_status、candidate_count、ambiguous |
| `ai.tool.called` | Agent Gateway | tool name、requested scope、pet id、allowed、denied_reason、returned_ref_ids、duration_ms |
| `ai.llm.requested` | infrastructure | provider、model、stream、timeout、message_count、tool_count、request_id、estimated_input_tokens |
| `ai.llm.failed` | infrastructure | provider、model、error_kind、http_status、timeout、retryable |
| `ai.stream.completed` | http / application | chat_session_id、message_id、delta_count、duration_ms、finish_reason |
| `ai.answer.verified` | application | verification_status、blocked_reason、unsupported_fact_count、medical_blocked、privacy_blocked |
| `ai.action.proposed` | application | action kind、pet id、requires_confirmation、source_message_id |
| `ai.history.loaded` | http | actor user、session_count、page_cursor |
| `ai.cost.estimated` | application | input_tokens、output_tokens、total_tokens、model、surface |

日志规则：

| 规则 | 内容 |
|---|---|
| 密钥不入日志 | API key、Authorization、完整 Provider 请求头禁止记录 |
| 私有事实最小化 | 日志记录引用 ID 和摘要，不记录完整医疗/交易/聊天 payload |
| 开发可定位 | 本地开发环境可返回 `debug_ref`，生产环境默认不返回 |
| 临时日志纪律 | 若为真机或线上问题加入临时日志，必须在用户确认问题解决后清理并扫描残留 |

## 8. TDD 任务拆分

### Task 1：AI 后端 crate 与基础 domain

| 项 | 内容 |
|---|---|
| 目标 | workspace 出现可编译的 AI 分层 crate，并有稳定 domain 模型承载会话、消息、intent、宠物解析、LLM 请求响应和流式事件 |
| 前置依赖 | 无 |
| 验收项映射 | A1、A2、A3 |
| 回归验证 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo check --workspace --all-targets` |

#### Slice 1.1：workspace crate 骨架

| 项 | 要求 |
|---|---|
| 行为目标 | 新增 `maohuoban-ai-domain`、`maohuoban-ai-application`、`maohuoban-ai-infrastructure`、`maohuoban-ai-http` 并加入 workspace |
| 先写失败测试 | 在 `maohuoban-rust/tests/ai_contract.rs` 增加 smoke test 或编译引用，先验证缺 crate 时无法编译 |
| 允许修改 | 根 `Cargo.toml`、各新 crate `Cargo.toml`、`src/lib.rs`、`maohuoban-rust/tests/ai_contract.rs` |
| 最小绿灯命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo check -p maohuoban-ai-domain -p maohuoban-ai-application -p maohuoban-ai-infrastructure -p maohuoban-ai-http` |
| 回归命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo check --workspace --all-targets` |
| 完成证据 | 记录 failing-test 编译失败原因、green-test 编译通过输出、workspace check 摘要 |
| 停止条件 | 新 crate 需要引入无关业务依赖，或 workspace 现有 crate 出现无关编译错误 |

#### Slice 1.2：AI domain 序列化

| 项 | 要求 |
|---|---|
| 行为目标 | `AiIntent`、`AiGateDecision`、`AiConversationSurface`、`AiPetResolution`、`AiStreamEvent` 可稳定序列化/反序列化 |
| 先写失败测试 | `maohuoban-ai-domain` 内新增 enum roundtrip tests，断言 snake_case 和未知值拒绝 |
| 允许修改 | `maohuoban-ai-domain/src` |
| 最小绿灯命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-domain` |
| 回归命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo check --workspace --all-targets` |
| 完成证据 | 记录 enum roundtrip 红绿结果和编译验证 |
| 停止条件 | domain 模型需要引用 axum、sqlx、reqwest 或其他 infrastructure 依赖 |

### Task 2：Provider 分层、OpenAI 兼容协议与 SSE 解析

| 项 | 内容 |
|---|---|
| 目标 | application 通过 `LlmProvider` trait 调用 fake provider；infrastructure 通过厂商 Provider factory 装配 DeepSeek，并把内部请求转换成 OpenAI 兼容 HTTP/SSE 请求 |
| 前置依赖 | Task 1 |
| 验收项映射 | A4、A5、A6、A7 |
| 回归验证 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-application -p maohuoban-ai-infrastructure` |

#### Slice 2.1：`LlmProvider` 端口与 fake provider

| 项 | 要求 |
|---|---|
| 行为目标 | `AiGatewayService` 能依赖 trait 获取 fake assistant response 和 fake stream events |
| 先写失败测试 | `maohuoban-ai-application` 新增测试：fake provider 返回固定回答和 delta 序列，application 不依赖 concrete provider |
| 允许修改 | `maohuoban-ai-application/src`、`maohuoban-ai-domain/src` |
| 最小绿灯命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-application llm_provider` |
| 回归命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-domain -p maohuoban-ai-application` |
| 完成证据 | 记录 trait 测试从 unresolved trait 红到 fake provider 绿 |
| 停止条件 | application 直接引用 reqwest、Provider URL 或 API key |

#### Slice 2.2：Provider factory、DeepSeek Provider 与 OpenAI 兼容请求序列化

| 项 | 要求 |
|---|---|
| 行为目标 | `DeepSeekLlmProvider` 独立封装 DeepSeek 默认行为，内部复用 `OpenAiCompatibleLlmProvider` 将请求序列化为 OpenAI 兼容 JSON，Authorization 使用 Bearer |
| 先写失败测试 | `maohuoban-ai-infrastructure` 新增 HTTP mock 测试，断言 provider kind、path、headers、model、messages、tools、temperature、stream、response_format 字段 |
| 允许修改 | `maohuoban-ai-infrastructure/src`、根 `Cargo.toml` workspace dependencies |
| 最小绿灯命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-infrastructure openai_compatible` |
| 回归命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo check --workspace --all-targets` |
| 完成证据 | 记录 mock server 断言失败与通过结果；确认日志不包含 API key |
| 停止条件 | 测试需要真实外网或真实 API key |

#### Slice 2.3：SSE chunk 解析

| 项 | 要求 |
|---|---|
| 行为目标 | Provider SSE chunk 能解析为 `LlmStreamEvent`，支持 delta、finish、usage、error |
| 先写失败测试 | 用本地 fixture 模拟 OpenAI 兼容 SSE，断言 delta 顺序和 `[DONE]` 处理 |
| 允许修改 | `maohuoban-ai-infrastructure/src/provider`、`maohuoban-ai-domain/src/stream.rs` |
| 最小绿灯命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-infrastructure sse_stream_parser` |
| 回归命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-infrastructure` |
| 完成证据 | 记录 chunk fixture 数量、delta 合并顺序、finish 断言 |
| 停止条件 | 解析逻辑依赖真实外部 Provider 才能验证 |

### Task 3：宠物解析与唯一数据源

| 项 | 内容 |
|---|---|
| 目标 | 用户可用宠物名字提问，后端在授权宠物集合内解析唯一 `pet_id`；宠物数据来自 pet 后端读模型 |
| 前置依赖 | Task 1 |
| 验收项映射 | A8、A9、A10、A11 |
| 回归验证 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-application pet_resolver` |

#### Slice 3.1：授权宠物候选端口

| 项 | 要求 |
|---|---|
| 行为目标 | AI application 能通过端口获取当前用户授权宠物最小摘要 |
| 先写失败测试 | fake pet catalog 返回多宠列表，断言候选只含 `pet_id/name/avatar/species/profile_number` |
| 允许修改 | `maohuoban-ai-application/src/pets`、必要的 pet application 端口 |
| 最小绿灯命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-application authorized_pet_candidates` |
| 回归命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-pet-application` |
| 完成证据 | 记录候选字段断言，确认无饮食/异常/事件事实泄漏 |
| 停止条件 | 需要在 AI 模块复制宠物表或新增宠物事实缓存 |

#### Slice 3.2：名字解析唯一宠物

| 项 | 要求 |
|---|---|
| 行为目标 | 消息中出现唯一授权宠物名时解析到对应 `pet_id`；未提名时使用 selected pet；歧义时返回 needs_selection |
| 先写失败测试 | table tests 覆盖 selected pet、唯一名字、同名多宠、未授权名字、无宠物上下文 |
| 允许修改 | `maohuoban-ai-application/src/pet_resolver`、`maohuoban-ai-domain/src/pet_resolution.rs` |
| 最小绿灯命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-application pet_resolver` |
| 回归命令 | 无 |
| 完成证据 | 记录解析状态和目标 `pet_id` 断言 |
| 停止条件 | 解析结果依赖前端传来的宠物名字作为权威值 |

### Task 4：意图闸门与 Agent Gateway 工具链

| 项 | 内容 |
|---|---|
| 目标 | off-topic 不加载上下文；宠物领域问题按 intent 强制调用工具并生成事实包 |
| 前置依赖 | Task 1、Task 3 |
| 验收项映射 | A12、A13、A14、A15 |
| 回归验证 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-application` |

#### Slice 4.1：规则版 `AiIntentGate`

| 项 | 要求 |
|---|---|
| 行为目标 | 规则分类器识别宠物照护、食品、健康风险、App 帮助、off-topic、prompt injection |
| 先写失败测试 | `maohuoban-ai-application` 新增 table tests，覆盖典型中文输入和 expected decision |
| 允许修改 | `maohuoban-ai-application/src/intent`、`maohuoban-ai-domain/src/intent.rs` |
| 最小绿灯命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-application intent_gate` |
| 回归命令 | 无 |
| 完成证据 | 记录分类用例数量、红绿结果和低置信度处理 |
| 停止条件 | 分类需要调用主 LLM 或读取宠物上下文 |

#### Slice 4.2：工具白名单与鉴权

| 项 | 要求 |
|---|---|
| 行为目标 | 未注册工具调用被拒绝；已注册 pet tool 通过 pet application 完成权限校验 |
| 先写失败测试 | `tool_registry_rejects_unknown_tool` 和 `pet_tool_authorization`，断言未授权无宠物名/食品名泄漏 |
| 允许修改 | `maohuoban-ai-application/src/tools`、必要的 pet application 适配 |
| 最小绿灯命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-application tool_registry pet_tool_authorization` |
| 回归命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-pet-application` |
| 完成证据 | 记录 unknown tool 拒绝、授权成功、未授权无泄漏 |
| 停止条件 | 需要直接依赖 `maohuoban-pet-infrastructure` 或 SQL 查询 |

#### Slice 4.3：饮食事实包强弱分离

| 项 | 要求 |
|---|---|
| 行为目标 | 当前主粮/喂食/确认事实进入 strong facts，储物柜变化只进入 hints / confirmation candidates |
| 先写失败测试 | 构造有 food hint 但无喂食/配置的 fixture，断言 hint 不进入 strong facts |
| 允许修改 | `maohuoban-ai-application/src/context`、`maohuoban-ai-domain/src/fact_package.rs` |
| 最小绿灯命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-application fact_package_diet_hints` |
| 回归命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-application` |
| 完成证据 | 记录强事实/弱线索断言结果 |
| 停止条件 | 事实包需要塞入全量 pet_events 或完整聊天历史 |

### Task 5：Prompt、回答校验与流式输出边界

| 项 | 内容 |
|---|---|
| 目标 | LLM 只基于事实包回答；流式输出在后端完成缓冲校验后结束，边界违规可回退为安全消息 |
| 前置依赖 | Task 2、Task 4 |
| 验收项映射 | A16、A17、A18、A19 |
| 回归验证 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-application answer_verifier stream_pipeline` |

#### Slice 5.1：Prompt Builder 不含越权字段

| 项 | 要求 |
|---|---|
| 行为目标 | Prompt messages 只包含系统规则、用户问题、宠物候选、授权事实包和输出格式；不包含 API key、actor token、审计表原文 |
| 先写失败测试 | 构造事实包和敏感字段，断言生成 messages 不包含 token/api key/unauthorized payload |
| 允许修改 | `maohuoban-ai-application/src/prompt` |
| 最小绿灯命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-application prompt_builder` |
| 回归命令 | 无 |
| 完成证据 | 记录敏感字段扫描断言结果 |
| 停止条件 | 需要把完整数据库行或审计日志塞进 prompt |

#### Slice 5.2：无来源事实与弱线索误用拦截

| 项 | 要求 |
|---|---|
| 行为目标 | 回答中出现事实包外食品/日期/医院/药物，或把 weak hint 表达为已吃过，必须被阻断 |
| 先写失败测试 | 构造 facts 只含弱线索“新增主粮”，回答却说“毛球已经换粮”，断言 blocked_reason |
| 允许修改 | `maohuoban-ai-application/src/verifier`、`maohuoban-ai-domain/src/verification.rs` |
| 最小绿灯命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-application answer_verifier` |
| 回归命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-application` |
| 完成证据 | 记录 unsupported fact 和 weak hint misuse 拦截 |
| 停止条件 | 校验器只能靠 LLM 自我审查才能通过 |

#### Slice 5.3：后端稳定 SSE 事件

| 项 | 要求 |
|---|---|
| 行为目标 | fake provider delta 序列被转换为毛伙伴稳定 SSE 事件，事件顺序固定 |
| 先写失败测试 | `stream_pipeline_emits_stable_events` 断言 `message_started -> delta* -> message_completed` |
| 允许修改 | `maohuoban-ai-application/src/stream`、`maohuoban-ai-domain/src/stream.rs` |
| 最小绿灯命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-application stream_pipeline` |
| 回归命令 | 无 |
| 完成证据 | 记录事件顺序和 final text 断言 |
| 停止条件 | iOS 需要直接解析 OpenAI 原始 chunk |

### Task 6：AI HTTP 接口、会话持久化与审计

| 项 | 内容 |
|---|---|
| 目标 | 根服务装配 AI router；聊天、流式、历史列表、消息详情和审计持久化可用 |
| 前置依赖 | Task 1-5 |
| 验收项映射 | A20、A21、A22、A23、A24 |
| 回归验证 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban_rust ai_contract` |

#### Slice 6.1：HTTP 认证与 stream route

| 项 | 要求 |
|---|---|
| 行为目标 | 未登录 `/ai/chat/stream` 返回 unauthorized；已登录进入 stream，前端不能传 actor user |
| 先写失败测试 | `maohuoban-rust/tests/ai_contract/chat_stream.rs` 新增 unauthorized 和 authenticated smoke tests |
| 允许修改 | `maohuoban-ai-http/src`、根服务装配、根 `Cargo.toml` |
| 最小绿灯命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban_rust ai_chat_stream_auth` |
| 回归命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo check --workspace --all-targets` |
| 完成证据 | 记录 401 和认证通过测试结果 |
| 停止条件 | HTTP handler 接收或信任 `actor_user_id` 字段 |

#### Slice 6.2：会话和消息持久化

| 项 | 要求 |
|---|---|
| 行为目标 | AI chat 成功后 DB 中有 session、user message、assistant message 和 pet display snapshot |
| 先写失败测试 | contract test 查询 `ai_chat_sessions`、`ai_messages`，断言 actor user、primary pet、message role、pet snapshot |
| 允许修改 | `maohuoban-rust/migrations`、`maohuoban-ai-*` |
| 最小绿灯命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban_rust ai_chat_persistence` |
| 回归命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban_rust ai_chat_stream_auth ai_chat_persistence` |
| 完成证据 | 记录 DB 断言行数和关键字段 |
| 停止条件 | 需要保存完整敏感 Provider 原始请求才能通过 |

#### Slice 6.3：历史接口

| 项 | 要求 |
|---|---|
| 行为目标 | `GET /ai/chat-sessions` 返回带宠物头像/名字快照的会话列表；`GET /messages` 返回消息 |
| 先写失败测试 | contract test 创建两条会话，断言排序、pet display snapshot、最近消息摘要和鉴权 |
| 允许修改 | `maohuoban-ai-http/src`、`maohuoban-ai-application/src/history`、`maohuoban-ai-infrastructure/src/postgres` |
| 最小绿灯命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban_rust ai_chat_history` |
| 回归命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban_rust ai_contract` |
| 完成证据 | 记录历史响应 JSON 和鉴权拒绝测试 |
| 停止条件 | 历史接口读取前端本地 mock 或新增宠物事实源 |

#### Slice 6.4：审计日志

| 项 | 要求 |
|---|---|
| 行为目标 | 每次工具调用和每次 gate decision 都写审计日志；off-topic 日志显示 context_loaded = false |
| 先写失败测试 | contract test 调用宠物问题和 off-topic，查询 `ai_tool_access_logs`、`ai_request_gate_logs` |
| 允许修改 | `maohuoban-rust/migrations`、`maohuoban-ai-application`、`maohuoban-ai-infrastructure` |
| 最小绿灯命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban_rust ai_audit_logs` |
| 回归命令 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban_rust ai_contract` |
| 完成证据 | 记录 allowed/denied、returned_ref_ids、context_loaded 断言 |
| 停止条件 | 审计日志必须保存完整聊天原文或完整私有事实 payload |

### Task 7：iOS Repository、Store 流式接入与历史页真实数据

| 项 | 内容 |
|---|---|
| 目标 | iOS AI 聊天页使用后端 stream，历史页使用后端会话列表，现有 UI 交互和流式渲染保持稳定 |
| 前置依赖 | Task 6 的接口契约 |
| 验收项映射 | A25、A26、A27、A28 |
| 回归验证 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build` |

#### Slice 7.1：AI DTO 和 Repository

| 项 | 要求 |
|---|---|
| 行为目标 | iOS 有独立 Repository 解析 stream event、历史 session 和 messages DTO |
| 先写失败测试 | `maohuobanTests/Features/AI` 新增 DTO decoding tests，覆盖 `delta`、`citation`、`proposed_action`、history row |
| 允许修改 | `Features/AI/Data`、`Features/AI/Domain`、`maohuobanTests/Features/AI` |
| 最小绿灯命令 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -only-testing:maohuobanTests/AIAssistantDTOTests test` |
| 回归命令 | 无 |
| 完成证据 | 记录 DTO 解码测试通过 |
| 停止条件 | Repository 需要直接访问宠物 Store 作为事实源 |

#### Slice 7.2：Store 消费流式事件

| 项 | 要求 |
|---|---|
| 行为目标 | `AIAssistantStore` 收到后端 delta 后用现有 `AIAssistantStreamingEngine` 增量更新 assistant 消息 |
| 先写失败测试 | Store 测试模拟 stream event 序列，断言消息创建、文本累积、`isStreaming` 关闭、citation 更新、pending action 更新 |
| 允许修改 | `AIAssistantStore.swift`、`AIAssistantStreamingEngine.swift` 必要边界、AI Repository protocol |
| 最小绿灯命令 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -only-testing:maohuobanTests/AIAssistantStoreStreamingTests test` |
| 回归命令 | 无 |
| 完成证据 | 记录 Store 流式累积测试通过 |
| 停止条件 | View body 里直接发网络请求或写持久化状态 |

#### Slice 7.3：历史页真实数据

| 项 | 要求 |
|---|---|
| 行为目标 | `AIAssistantHistoryScreen` 渲染后端 session 列表，每条记录显示后端返回的宠物头像和名字 |
| 先写失败测试 | Store/mapper 测试断言 `petDisplaySnapshot -> AIAssistantConversationHistory` 映射 |
| 允许修改 | `AIAssistantStore.swift`、`AIAssistantConversationHistory.swift`、`AIAssistantHistoryScreen.swift` 必要接入点 |
| 最小绿灯命令 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -only-testing:maohuobanTests/AIAssistantHistoryTests test` |
| 回归命令 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build` |
| 完成证据 | 记录历史映射测试和 Debug build 结果 |
| 停止条件 | 历史页继续依赖 mock 列表作为真实路径 |

## 9. 验收门禁

| ID | 类型 | 命令 / 验收 |
|---|---|---|
| A1 | workspace | 根 `Cargo.toml` 包含 `maohuoban-ai-domain/application/infrastructure/http` workspace members 和 dependencies |
| A2 | domain 编译 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test -p maohuoban-ai-domain` 通过 |
| A3 | workspace 编译 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo check --workspace --all-targets` 通过 |
| A4 | Provider 端口 | application 测试证明只依赖 `LlmProvider` trait |
| A5 | Provider 分层与 OpenAI 兼容序列化 | mock HTTP 测试断言 DeepSeek kind、factory 装配、path、headers、model、messages、tools、temperature、stream、response_format 正确 |
| A6 | Provider 错误 | 401、429、5xx、timeout、invalid JSON 映射为稳定错误 |
| A7 | SSE 解析 | Provider SSE chunk 解析为稳定 `LlmStreamEvent` |
| A8 | 宠物候选 | AI 只能读取当前 actor 授权宠物候选摘要 |
| A9 | 宠物解析 | selected pet、宠物名、同名歧义、未授权目标都有测试 |
| A10 | 唯一数据源 | AI 不新增宠物事实表；宠物展示快照仅用于历史展示 |
| A11 | 未授权拒绝 | 未授权 pet 不返回宠物姓名、头像、食品名或存在性细节 |
| A12 | 意图闸门 | off-topic / app_support 不加载宠物事实、不调用主 Agent |
| A13 | prompt injection | “忽略权限/管理员模式/读取全库”等请求被拒绝并记录风险信号 |
| A14 | 工具白名单 | 未注册工具调用被拒绝 |
| A15 | 饮食事实包 | 强事实和弱线索分离，储物柜新增不进入强事实 |
| A16 | Prompt 安全 | Prompt 不包含 API key、Authorization、未授权 payload、完整审计原文 |
| A17 | 回答校验 | Verifier 拦截无来源事实、弱线索误用、医疗诊断和未确认写入 |
| A18 | 后端 SSE | `/api/v1/ai/chat/stream` 输出稳定毛伙伴 SSE 事件协议 |
| A19 | 流式完成 | `message_completed` 后会话消息持久化，错误时关闭流式状态 |
| A20 | HTTP 认证 | 未登录 AI 接口返回 unauthorized；已登录从 token 注入 actor |
| A21 | 会话持久化 | AI chat 成功后写入 session、messages、pet display snapshot |
| A22 | 历史接口 | 会话列表和消息详情按 actor 鉴权并返回宠物展示快照 |
| A23 | 审计日志 | 每次工具读取有 access log；每次请求有 gate log |
| A24 | 写入边界 | proposed action / confirmation task 不直接写 `pet_events` 强事实 |
| A25 | iOS DTO | AI stream / history DTO 解码测试通过 |
| A26 | iOS Store | Store 流式事件累积、完成、错误、pending action 测试通过 |
| A27 | iOS 历史 | 历史记录使用后端返回宠物头像和名字映射 |
| A28 | iOS 构建 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build` 以 `** BUILD SUCCEEDED **` 结束 |
| A29 | Rust 格式 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo fmt --all --check` 通过 |
| A30 | Rust 测试 | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo test --workspace` 通过 |
| A31 | Rust lint | `cd /Users/fengjinyi/Developer/maohuoban-code && cargo clippy --workspace --all-targets` 无新增 warning |

## 10. 不变约束

| 约束 | 说明 |
|---|---|
| `pet_id` 是唯一事实根 | 名字、芯片号、档案号只能解析候选，最终访问必须落到授权 `pet_id` |
| 宠物数据唯一来源 | 宠物身份、头像、名字、物种、饮食、异常、事件和提醒来自后端宠物体系；AI 不维护第二套宠物事实 |
| 前端只传上下文 | iOS 传 `selectedPetID`、source hint、task、surface；不传 actor user，不拼事实包 |
| 历史快照非事实 | `pet_display_snapshot` 只服务历史展示，不能用于新一轮事实判断 |
| 登录态是唯一 actor 来源 | `actor_user_id` 只能由认证中间件注入 |
| Agent Gateway 是工具入口 | LLM、HTTP handler、前端都不能直接调用业务仓储或 SQL |
| Prompt 不是安全边界 | 权限、检索过滤、写入确认、医疗边界必须由后端代码和测试保护 |
| 结构化事实优先 | 私域事实类问题先查业务读模型，再调用 LLM 表达 |
| 弱线索不能变强事实 | 储物柜变化、聊天摘要、模型推断都必须经用户确认 |
| 写操作必须确认 | 提醒、事件、饮食配置、症状记录都必须先生成待确认动作 |
| 聊天和任务分离 | `agent_confirmation_tasks`、`attention_hints` 不自动写入 AI 聊天消息，只有用户进入聊天并真实交互才写消息 |
| Off-topic 不加载上下文 | 非宠物问题、prompt injection、cost abuse 不读取宠物事实或私有记忆 |
| Provider 可替换 | application 不绑定 OpenAI、DeepSeek、reqwest 或任何具体模型 slug |
| API key 不泄漏 | 配置、日志、错误、审计和响应都不能包含完整密钥 |
| 测试不依赖外网 | 单元和契约测试使用 fake provider 或 mock HTTP server |
| 医疗安全优先 | 毛球不能诊断、开药、给剂量或替代兽医 |
| SwiftUI 渲染路径无副作用 | View body、formatter、computed view 不发请求、不写状态、不写缓存 |
| 新增代码无 warning | Rust 和 iOS 新增代码不引入新增 warning |

## 11. 风险

| 风险 | 处理 |
|---|---|
| LLM 编造宠物事实 | 强制工具链 + 事实包 + `AiAnswerVerifier`，无来源事实直接拦截 |
| 宠物名字解析错宠 | `AiPetResolver` 只在授权候选内解析；同名或歧义返回选择需求 |
| AI 模块变成第二套宠物数据源 | 目标文档和测试限制 AI 只存展示快照和引用 ID；事实判断重新读 pet 后端 |
| 前端使用入口宠物名做事实 | iOS 只把入口上下文传给后端；后端返回 resolved pet 和事实结果 |
| 模型把弱线索当换粮事实 | 事实包标注 fact strength，Verifier 禁止把 hint 表达为 confirmed fact |
| 越权读取其他宠物 | Agent Gateway 注入 actor，工具层鉴权，未授权和不存在统一拒绝 |
| Prompt injection 绕过工具 | prompt injection 在意图闸门和工具层记录风险；工具层拒绝未授权目标 |
| Provider 不稳定 | timeout、retryable error、保守回退文案和 provider_not_configured 状态 |
| 流式半截输出违规 | 后端保留最终校验；必要时以安全消息收束并记录 verifier block |
| iOS 流式状态卡住 | Store 测试覆盖 error/completed/cancel，确保 `isStreaming` 最终关闭 |
| 历史记录宠物改名后展示混乱 | 会话保存展示快照，同时新一轮回答重新读取当前 pet 事实 |
| 成本失控 | 意图闸门前置；off-topic 不调用主 Agent；记录 token usage 和 gate logs |
| API key 泄漏 | 配置读取集中在 infrastructure；日志扫描测试覆盖敏感字段 |
| Provider 格式差异 | 内部稳定 `LlmChatRequest/Response/StreamEvent`，Provider 单独做兼容适配 |
| 审计保存过多敏感数据 | 保存 hash、引用 ID、短摘要和风险标签；完整 payload 默认不保存 |
| 健康问题过度保守影响体验 | 回答提供观察要点、缺失信息和就医边界，避免诊断和处方 |
| 范围膨胀 | 本目标期只做私域聊天、流式、历史、首批工具；UGC、向量记忆、医疗规则库独立目标文档 |
