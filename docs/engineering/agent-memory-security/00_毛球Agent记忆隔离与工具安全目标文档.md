# 毛球 Agent 记忆隔离与工具安全目标文档

- 更新时间：2026-06-25
- Goal：定义毛球 Agent 的记忆系统、领域意图闸门、上下文沙箱、工具鉴权、缓存隔离、越权诱导防护、安全审计、风险评分和分级处置，让毛球只服务宠物照护、宠物记录、食品、健康风险、宠物相关陪伴和 App 帮助场景，并且让所有 Agent 读取、拒绝、写入、成本控制和处置都可追溯、可复核、可回滚。
- 执行方式：先目标文档后实现；后端按 TDD 小切片推进；iOS 只负责传递当前选中宠物和展示授权失败状态；Agent 调用链必须通过后端 Agent Gateway。
- 架构修订：`docs/engineering/ai-agent-runtime/02_毛球Agent能力工作台与Rig接入ADR.md` 已将入口 Gate 收敛为硬安全边界；本文中早期“非宠物请求不进入主 Agent”的表达，统一修订为“非私域请求不加载私域宠物事实，公共宠物能力、App 帮助和助手身份仍可进入 AgentSession Workbench”。

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 核心安全边界 | 毛球 Agent 没有直接数据库权限，所有私有数据读取都必须经过后端授权工具 |
| 宠物事实根 | 宠物事实、事件、异常、饮食、体重、疫苗驱虫都以 `pet_id` 为根，通过 `pet_guardians` 判断当前用户是否可访问 |
| 用户记忆根 | 用户偏好、毛球名字、回复风格、聊天习惯以 `user_id` 为根，默认私有 |
| 家庭共享根 | 多人共同照护、家庭储物柜、家庭级设置以 `household_id` 为根，只有家庭成员可见 |
| 聊天边界 | `chat_messages` 是真实聊天记录，不自动承载后台 hint、task 或候选事实 |
| 写入边界 | 聊天抽取、Agent 猜测、弱线索都不能直接写强事实；用户确认后才写 `pet_events` 或领域事实表 |
| 缓存边界 | 任何 Agent 上下文缓存 key 必须包含授权主体、scope、`pet_id` 和上下文版本 |
| 向量检索边界 | embedding 搜索必须带 metadata filter，禁止裸搜全库记忆 |
| 自定义毛球 | 毛球名字、语气、回复长度属于 `agent_preferences`，不是宠物事实 |
| 领域边界 | 毛球是宠物垂直领域 + 用户宠物私域 Agent；非私域请求不加载宠物事实和私有记忆，公共宠物能力、App 帮助和助手身份仍可进入 AgentSession Workbench |
| 成本控制 | 所有请求先过轻量意图闸门；只有宠物领域意图才读取 `pet_identity_context`、领域读模型和向量记忆 |
| 恶意尝试处置 | 审计先记录证据链，再做风险评分和分级处置；偶发越权问题以拒绝为主，持续探测和批量枚举进入安全事件流程 |
| 证据最小化 | 安全审计保留工具名、目标、授权结果、风险标签、请求 hash 和必要摘要，避免长期保存完整敏感 payload |
| 变聪明路径 | 毛球越用越聪明依赖结构化事实质量、基线建模、主动追问、用户确认回写和可审计检索 |

## 2. 目标边界

### 2.1 本目标期必须完成

| 范围 | 目标 |
|---|---|
| Agent Gateway | 新增或定义统一 Agent 工具入口，所有工具调用从登录态注入 `actor_user_id` |
| 工具授权 | 所有宠物私有事实工具调用前必须校验 `PetAccessPolicy` / `pet_guardians` |
| 记忆分区 | 定义 `agent_preferences`、`chat_sessions`、`chat_session_summaries`、`agent_memory_items` 或等价领域表的 scope 规则 |
| 上下文白名单 | Agent 只能接收后端拼装的授权事实包，不能自由拼 SQL、自由读取全表或自由检索全库 |
| 向量检索过滤 | 向量检索必须强制 `scope_type`、`scope_id`、`pet_id`、`visibility`、`memory_kind` metadata filter |
| 缓存隔离 | Agent 上下文缓存、摘要缓存、检索缓存 key 必须带 `actor_user_id` 或 `household_id`、`pet_id`、版本号 |
| 硬安全闸门 | 在上下文拼装和模型调用前完成硬安全判断，区分 prompt injection、越权诱导、危险写入、恶意成本滥用和普通可处理请求 |
| 非私域请求处理 | 公共宠物咨询、App 帮助和助手身份可进入 AgentSession Workbench；不查询宠物事实、不检索私有记忆；非宠物泛话题走轻量边界引导和成本控制 |
| 成本滥用识别 | 连续非宠物长问题、批量无关请求、反复要求通用创作等进入 `cost_abuse` 信号 |
| 越权诱导防护 | 用户诱导读取其他宠物、其他用户、管理员数据时，工具层拒绝并记录审计 |
| 审计日志 | 记录 Agent 每次工具读取的主体、目标、授权结果、引用事实和拒绝原因 |
| 风险识别 | 对越权读取、宠物枚举、管理员诱导、批量失败调用、脚本化模式生成 `agent_security_events` |
| 分级处置 | 定义低/中/高/严重/极高风险处置策略，包含拒绝、限速、重新验证、冻结 Agent 私有工具、人工审核和安全事故流程 |
| 写入确认 | Agent 抽取出的候选事实进入确认任务；用户确认后写回对应 `pet_id` / `user_id` / `household_id` |
| 代码备注 | 在 Agent Gateway、工具接口、记忆表、向量检索端口和缓存 key 处写清隔离边界，避免后续漂移 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 完整 LLM 编排平台 | 本期先定义安全边界和最小工具链，复杂工作流后续演进 |
| 医疗诊断模型 | HIS 和医疗诊断边界后续独立评审 |
| 跨用户匿名病例库 | 匿名统计和脱敏病例需要隐私、同意、脱敏和安全评审 |
| 商家 Agent 助手 | 商家管理和用户照护 Agent 权限边界不同，等商家模块进入实现再拆 |
| 家庭空间完整 UI | 本期定义 `household` scope，家庭成员邀请和权限 UI 后续独立设计 |
| 长期保存全部原始聊天 | 原始聊天保留策略需要隐私和成本策略，本期优先做摘要与确认事实 |
| 自动合并同名宠物记忆 | 同名、同芯片、同品种都不能自动合并，仍以 `pet_id` 和授权关系为准 |
| 公开风控阈值 | 风险分、限速阈值、冻结阈值不对用户公开，避免被绕过 |
| 自动永久封禁 | 本期只定义风险分和处置动作，永久封禁需要人工审核和申诉机制 |
| 长期明文保存敏感请求 | 安全审计采用 hash、摘要和风险标签；完整原文只允许短期、受控、可审计留存 |
| 泛通用知识问答 | 毛球不承接百科、作文、代码、泛娱乐等非宠物通用问答 |
| 非宠物长陪聊 | 非宠物闲聊只允许短回复和拉回宠物场景，不做长对话 |
| 为非宠物请求加载宠物上下文 | off-topic / app_support 不读取宠物事实包，避免 token 和隐私成本扩大 |

## 3. 依据

### 3.1 项目内依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| 产品策略 | `docs/product/strategy/04_宠物事实采集与毛球Agent记忆系统设计.md` | 毛球定位为结构化事实底座上的 Agent；工具读模型需要稳定、可解释、可审计 |
| Phase 1 | `docs/engineering/pet-identity/00_宠物唯一主体与归属关系Phase1目标文档.md` | 已定义 `pet_profiles.id` / `profile_number` 为终身身份，`pet_guardians` 表达授权关系，`pet_identity_context` 作为 Agent 身份事实包 |
| Phase 2 | `docs/engineering/pet-food-inventory/00_储物柜食品资产与宠物饮食配置Phase2目标文档.md` | 已定义储物柜是空间资产，宠物通过饮食配置消费资产，储物柜变化是弱线索 |
| Phase 3 | `docs/engineering/attention-hints-abnormal/00_AttentionHint与异常追踪闭环Phase3目标文档.md` | 已定义 `attention_hints`、`agent_confirmation_tasks`、`chat_messages`、`pet_events` 的边界 |
| 认证边界 | `docs/engineering/auth/03_认证边界与多设备安全整改设计.md` | 已要求业务接口移除对裸 user id 的信任，统一使用 `Authorization: Bearer <access_token>` |
| iOS 请求契约 | `docs/engineering/auth/06_iOS请求基础设施契约.md` | iOS Repository 通过 authenticated client 注入 Authorization，业务层不手动拼接登录身份 |
| 后端事件基线 | `maohuoban-rust/migrations/0005_pet_home_baseline.sql` | `pet_events` 已具备 `event_payload`、`visibility` 等基础字段，适合作为可追溯事实账本 |
| iOS AI 壳 | `maohuoban/maohuoban/Features/AI/Stores/AIAssistantStore.swift` | 当前 AI 对话仍是本地 mock 壳，不能作为后台 Agent 工具安全边界 |

### 3.2 产品上下文依据

| 用户确认点 | 对本目标的约束 |
|---|---|
| 宠物档案 ID 创建后永久不变 | Agent 记忆必须绑定不可变 `pet_id`，不能按名字或芯片号混合 |
| 多宠、共管、商家来源后续都会存在 | 访问授权必须独立于单一 owner 字段，必须走关系表和访问策略 |
| 毛球需要节约 token | 需要结构化读模型、会话摘要、短期缓存和按需检索，而不是塞入全量历史 |
| 用户可能诱导毛球读取其他宠物 | 工具层必须拒绝未授权目标，Prompt 只作为回复策略 |
| 首页 hint 和聊天有明确边界 | Agent 任务、轻提示、聊天消息、事实写入分别建模 |
| 自定义毛球名字可支持 | 自定义名字属于用户或家庭级 Agent 偏好，不进入宠物事实账本 |
| 恶意用户需要可处理 | 审计需要支持识别持续越权探测、枚举宠物、管理员诱导和脚本化读取尝试，并形成可复核证据 |
| 用户担心 token 成本失控 | 非宠物问题必须在入口被拦截或轻量处理，避免毛球变成通用助手 |

## 4. 推荐方案 / 数据流

### 4.1 Agent 私有数据读取链路

```text
用户消息
  -> 认证中间件解析 actor_user_id
  -> 解析当前 selected_pet_id / explicit_pet_ref
  -> Agent Gateway 接收工具调用申请
  -> PetAccessPolicy 校验 actor_user_id 是否可访问 pet_id
  -> 工具读取授权范围内的结构化读模型
  -> Agent Context Builder 只拼装白名单字段
  -> LLM 生成回答
  -> 引用事实写入审计日志
```

### 4.2 越权诱导处理链路

```text
用户要求读取未授权宠物或其他用户数据
  -> LLM 申请工具读取目标 pet_id / pet_ref
  -> Agent Gateway 从登录态注入 actor_user_id
  -> PetAccessPolicy 返回 denied
  -> 工具不返回私有事实
  -> 写 agent_tool_access_logs: allowed = false, denied_reason = unauthorized_pet
  -> 毛球回复固定拒绝话术
```

推荐拒绝话术：

```text
我只能查看你有权限管理的宠物记录。你可以切换到已授权的宠物，或让对方共享管理权限后再查看。
```

### 4.3 记忆写入链路

```text
聊天、快捷记录、储物柜变化、异常追踪、提醒反馈
  -> 结构化抽取候选事实
  -> 写 agent_confirmation_tasks 或领域待确认对象
  -> 用户确认
  -> 写 pet_events / pet_diet_assignments / abnormal_episodes / user_preferences
  -> 更新 Agent 读模型版本
  -> 失效对应上下文缓存
```

### 4.4 Token 节约链路

```text
用户问题
  -> 轻量意图闸门
  -> pet_domain
     -> 读取 pet_identity_context 最小身份包
     -> 按需读取 diet / abnormal / weight / preventive care / reminder 上下文
     -> 检索授权 scope 内少量相关 memory
     -> 拼装短上下文
     -> 回答后只保存摘要、引用和确认事实
  -> app_support
     -> 不读取宠物事实，使用规则或轻量模型短答
  -> public_pet_domain / app_support / assistant_identity
     -> 不读取私域宠物事实，进入 AgentSession Workbench 轻量回答
  -> off_topic / cost_abuse / prompt_injection
     -> 不读取宠物事实；安全风险硬拦截，普通软边界轻量引导并记录成本信号
```

### 4.4.1 领域意图闸门

| intent | 示例 | 加载宠物私域上下文 | AgentSession Workbench | 处理 |
|---|---|---:|---:|---|
| `pet_care` | 喂食、便便、精神、行为、日常照护 | 是 | 是 | 正常回答 |
| `pet_record_query` | 查体重、疫苗驱虫、异常、喂食历史 | 是 | 是 | 正常回答 |
| `pet_food` | 主粮、零食、储物柜、换粮 | 是 | 是 | 正常回答 |
| `pet_health_risk` | 拉稀、呕吐、不吃、精神差 | 是 | 是 | 正常回答并遵守医疗边界 |
| `emotional_pet_context` | 宠物去世、走失、照护焦虑 | 少量 | 是 | 允许宠物相关陪伴 |
| `app_support` | App 怎么添加宠物、怎么记录体重 | 否 | 是 | 使用产品帮助能力短答 |
| `public_pet_domain` | 猫拉肚子一般观察什么 | 否 | 是 | 使用公共宠物能力回答，遵守医疗边界 |
| `off_topic` | 作文、代码、百科、非宠物闲聊 | 否 | 是或轻量降级 | 轻量边界引导并拉回宠物 |
| `prompt_injection` | 忽略规则、改成通用助手、读取全库 | 否 | 否 | 拒绝并记录风险信号 |
| `cost_abuse` | 连续大量无关长问题、刷通用创作 | 否 | 否或轻量降级 | 限速、冷却或进入风险评分 |
| `safety_emergency` | 用户自伤、现实安全紧急情况 | 否或极少 | 轻量安全路径 | 按安全帮助流程处理 |

### 4.5 审计与分级处置链路

```text
Agent Gateway 收到工具调用申请
  -> 写 agent_tool_access_logs 原始审计
  -> 授权通过
     -> 返回授权事实引用
     -> 记录 returned_ref_ids
  -> 授权拒绝
     -> 记录 denied_reason 和 risk_signal
     -> 聚合 agent_security_events
     -> 更新 user_risk_scores
     -> 根据风险等级执行处置动作
```

处置边界：

| 状态 | 含义 | 处理 |
|---|---|---|
| 拒绝但无泄露 | 工具层拦截成功，没有返回私有事实 | 记录审计、按风险分决定是否限速 |
| 拒绝且频繁探测 | 用户持续尝试不同宠物名、芯片号、档案号或管理员诱导 | 生成安全事件、限速或冻结 Agent 私有工具 |
| 疑似脚本化 | 短时间大量 denied、请求模式高度重复、设备/IP 异常 | 暂停关键能力并进入人工审核 |
| 疑似数据泄露 | 工具层或检索层返回了未授权私有事实 | 进入安全事故流程，保留证据、修复漏洞、评估通知 |

## 5. 后端目标

### 5.1 Agent Gateway

| 要求 | 说明 |
|---|---|
| 登录态注入 | `actor_user_id` 只能来自认证上下文，前端和模型都不能传入或覆盖 |
| 工具注册白名单 | Agent 只能调用注册过的工具，工具必须声明需要的 scope 和权限 |
| 统一鉴权 | 宠物事实工具统一调用 `PetAccessPolicy`，家庭工具统一调用 `HouseholdAccessPolicy` |
| 输入规范化 | 名字、芯片号、档案号只能解析候选目标，最终访问必须落到授权 `pet_id` |
| 输出裁剪 | 工具只返回读模型字段，避免暴露底层兼容字段、内部备注、其他用户身份信息 |
| 拒绝一致性 | 未授权、目标不存在、已撤销授权的返回对外保持一致，避免枚举用户或宠物 |

### 5.2 推荐表 / 对象

#### `agent_preferences`

| 字段 | 要求 |
|---|---|
| `id` | UUID 主键 |
| `scope_type` | `user`、`household` |
| `scope_id` | 用户 ID 或家庭 ID |
| `agent_display_name` | 用户自定义毛球名称 |
| `tone` | 回复语气，例如 `warm`、`concise`、`professional` |
| `response_length` | 回复长度偏好，例如 `short`、`normal`、`detailed` |
| `enabled_capabilities` | 可用能力开关 |
| `created_at` / `updated_at` | 审计时间 |

规则：毛球名字和语气是 Agent 偏好，不能写入宠物事实；家庭级偏好只对家庭成员可见。

#### `chat_sessions`

| 字段 | 要求 |
|---|---|
| `id` | UUID 主键 |
| `actor_user_id` | 会话发起用户 |
| `primary_pet_id` | 当前会话主宠物，可空 |
| `household_id` | 家庭上下文，可空 |
| `source_hint_id` | 从首页轻提示进入时记录来源，可空 |
| `source_confirmation_task_id` | 从确认任务进入时记录来源，可空 |
| `created_at` / `last_message_at` | 会话时间 |

#### `chat_session_summaries`

| 字段 | 要求 |
|---|---|
| `id` | UUID 主键 |
| `chat_session_id` | 会话 ID |
| `scope_type` | `user`、`pet`、`household` |
| `scope_id` | 对应 scope ID |
| `summary_text` | 摘要文本 |
| `referenced_event_ids` | 摘要引用的事实事件 |
| `token_budget_hint` | 下次拼上下文预算 |
| `created_at` / `superseded_at` | 版本时间 |

规则：摘要是压缩上下文，不是强事实；摘要不能绕过事实账本直接参与医疗或饮食判断。

#### `agent_memory_items`

| 字段 | 要求 |
|---|---|
| `id` | UUID 主键 |
| `scope_type` | `user`、`pet`、`household` |
| `scope_id` | 对应 scope ID |
| `pet_id` | 宠物级记忆必须填写；用户级偏好可空 |
| `memory_kind` | `pet_fact`、`user_preference`、`household_setting`、`interaction_summary`、`pending_hypothesis` |
| `content` | 结构化 jsonb 或摘要文本 |
| `source_ref_type` / `source_ref_id` | 来源 chat、event、task、hint 等 |
| `confidence` | `low`、`medium`、`high` |
| `visibility` | `private`、`guardian_visible`、`household_visible` |
| `embedding_id` | 向量索引引用，可空 |
| `created_at` / `updated_at` / `expires_at` | 生命周期 |

规则：领域强事实优先写领域表和 `pet_events`；通用记忆只存偏好、摘要、低风险补充和待确认假设。

#### `agent_tool_access_logs`

| 字段 | 要求 |
|---|---|
| `id` | UUID 主键 |
| `actor_user_id` | 当前登录用户 |
| `chat_session_id` | 会话 ID，可空 |
| `tool_name` | 工具名 |
| `requested_scope_type` / `requested_scope_id` | 申请读取的 scope |
| `requested_pet_id` | 申请读取的宠物，可空 |
| `allowed` | 是否放行 |
| `denied_reason` | 拒绝原因 |
| `risk_signal` | 风险信号，例如 `prompt_injection`、`pet_enumeration`、`admin_mode_induction`、`cross_tenant_access` |
| `request_hash` | 用户请求文本 hash，用于去重和取证 |
| `request_excerpt` | 可选短摘要，需脱敏和长度限制 |
| `ip_prefix` / `device_id` | 风控辅助字段，按隐私最小化保存 |
| `returned_ref_ids` | 返回给模型的事实引用 ID |
| `created_at` | 审计时间 |

#### `agent_request_gate_logs`

| 字段 | 要求 |
|---|---|
| `id` | UUID 主键 |
| `actor_user_id` | 当前登录用户，可空用于未登录帮助场景 |
| `chat_session_id` | 会话 ID，可空 |
| `raw_intent` | 轻量分类器输出的原始意图 |
| `normalized_intent` | `pet_care`、`pet_record_query`、`pet_food`、`pet_health_risk`、`emotional_pet_context`、`app_support`、`off_topic`、`prompt_injection`、`cost_abuse`、`safety_emergency` |
| `gate_decision` | `allow_main_agent`、`allow_light_reply`、`deny_short_reply`、`rate_limited`、`safety_route` |
| `selected_pet_id` | 当前选中宠物，可空 |
| `context_loaded` | 是否加载宠物事实和私有记忆 |
| `model_tier` | `none`、`rules`、`light`、`main_agent` |
| `estimated_input_tokens` / `estimated_output_tokens` | 成本估算 |
| `risk_signal` | 可选：`off_topic`、`prompt_injection`、`cost_abuse` |
| `request_hash` | 用户请求文本 hash |
| `created_at` | 审计时间 |

规则：`agent_request_gate_logs` 用于成本观测和风控，不进入毛球回答上下文。

#### `agent_security_events`

| 字段 | 要求 |
|---|---|
| `id` | UUID 主键 |
| `actor_user_id` | 风险行为主体 |
| `event_kind` | `unauthorized_pet_access`、`pet_enumeration`、`admin_mode_induction`、`cross_tenant_probe`、`scripted_access_pattern`、`suspected_data_leak` |
| `severity` | `low`、`medium`、`high`、`severe`、`critical` |
| `status` | `open`、`reviewing`、`actioned`、`dismissed`、`resolved` |
| `first_seen_at` / `last_seen_at` | 首次和最近发生时间 |
| `attempt_count` | 聚合尝试次数 |
| `linked_access_log_ids` | 关联的原始工具访问日志 |
| `target_scope_summary` | 目标 scope 摘要，不能保存未授权私有明文详情 |
| `recommended_action` | `none`、`rate_limit`、`reauth_required`、`freeze_agent_private_tools`、`manual_review`、`incident_response` |
| `actioned_at` / `actioned_by` | 处置时间和处置人，可空 |
| `created_at` / `updated_at` | 审计时间 |

规则：`agent_security_events` 是风控聚合对象，不是聊天记录，不进入毛球上下文。

#### `user_risk_scores`

| 字段 | 要求 |
|---|---|
| `user_id` | 用户 ID |
| `risk_score` | 近期风险分 |
| `risk_level` | `normal`、`watch`、`limited`、`frozen`、`review_required` |
| `window_started_at` / `window_ends_at` | 评分窗口 |
| `signal_counts` | 各风险信号次数 |
| `active_restrictions` | 当前限制，例如限速、重新验证、冻结 Agent 私有工具 |
| `last_event_id` | 最近风险事件 |
| `updated_at` | 更新时间 |

规则：风险分只影响 Agent 私有工具、私有记忆检索和敏感写入确认；普通查看自己宠物、账号安全和申诉入口应保持可用。

### 5.3 风险信号与分级处置

| 风险等级 | 典型信号 | 处置 |
|---|---|---|
| 低 | 偶发询问能否查看朋友宠物 | 拒绝请求，记录 access log |
| 中 | 多次尝试不同宠物名、芯片号、档案号 | 限速 Agent 私有工具，必要时要求重新登录 |
| 高 | 明确要求忽略权限、管理员模式、读取全库 | 冻结 Agent 私有工具一段时间，生成安全告警 |
| 严重 | 批量枚举、脚本化请求、疑似撞库 | 暂停关键私有数据能力，进入人工审核 |
| 极高 | 成功越权返回或疑似数据泄露 | 启动安全事故流程，保留证据、修复漏洞、评估通知 |

用户侧话术：

| 场景 | 话术 |
|---|---|
| 普通越权请求 | 我只能查看你有权限管理的宠物记录。 |
| 多次高风险尝试 | 当前请求涉及未授权数据访问，相关能力已暂时受限。 |
| 需要重新验证 | 为保护宠物数据安全，请完成登录验证后继续使用。 |

### 5.4 意图闸门与成本控制

| 要求 | 说明 |
|---|---|
| 闸门前置 | 在读取宠物事实、私有记忆、向量检索和主模型调用前完成 |
| 轻量实现 | 优先使用规则、小模型或低成本分类器，输出标准化 intent 和置信度 |
| 工作台放行 | `pet_care`、`pet_record_query`、`pet_food`、`pet_health_risk`、`emotional_pet_context`、`app_support`、`off_topic` 在通过硬安全后进入 AgentSession Workbench |
| App 帮助轻量 | `app_support` 不读取宠物私有事实，可使用产品帮助能力或轻量回答 |
| 非私域轻量引导 | `off_topic` 不加载事实、不检索私有记忆，可进入 Workbench 生成轻量边界引导 |
| 成本滥用限速 | 连续 `off_topic` 长请求或批量无关请求触发 `cost_abuse`，进入限速/冷却 |
| 紧急安全独立 | `safety_emergency` 走安全帮助路径，不混入宠物事实和普通闲聊 |
| 观测记录 | 每次请求写 `agent_request_gate_logs`，记录 gate 决策和是否加载上下文 |

推荐拒答话术：

```text
我主要帮你处理宠物照护、记录和健康相关问题，也可以帮你回到毛伙伴里的相关操作。
```

### 5.5 工具权限矩阵

| 工具 | 读取对象 | 必要授权 | 输出原则 |
|---|---|---|---|
| `load_pet_identity_context` | 宠物身份事实包 | `actor_user_id` 对 `pet_id` 有 active guardian / owner / merchant 权限 | 只返回当前用户可见的身份、关系、生命周期摘要 |
| `load_pet_current_diet_context` | 饮食配置和喂食事实 | 可访问 `pet_id`，且食品资产 scope 对用户可见 | 返回强事实和弱线索标记 |
| `load_abnormal_episode_context` | 异常 episode | 可访问 `pet_id` 和 episode 所属宠物 | 返回用户主动记录和关联事件 |
| `load_weight_context` | 体重记录 | 可访问 `pet_id` | 返回趋势摘要和引用 ID |
| `load_preventive_care_context` | 疫苗驱虫 | 可访问 `pet_id` | 返回最近记录、到期提醒和引用 ID |
| `load_user_agent_preferences` | 毛球名字、语气偏好 | `actor_user_id` 匹配或 household 成员 | 返回偏好，不返回其他用户私有设置 |
| `search_agent_memory` | 记忆检索 | metadata filter 命中授权 scope | 返回少量相关记忆和来源引用 |
| `create_confirmation_task` | 待确认任务 | 可访问目标 scope | 不写强事实 |
| `commit_confirmed_fact` | 确认事实 | 用户显式确认，且可访问目标 scope | 写领域事实和审计引用 |

### 5.6 向量检索强制过滤

| metadata | 必填规则 |
|---|---|
| `scope_type` | 必填：`user`、`pet`、`household`、`public_knowledge` |
| `scope_id` | 私有记忆必填 |
| `pet_id` | 宠物级记忆必填 |
| `actor_visibility` | 标明 `private`、`guardian_visible`、`household_visible`、`public` |
| `memory_kind` | 标明事实、偏好、摘要、候选假设 |
| `source_ref_type` / `source_ref_id` | 支持追溯 |

硬规则：

| 规则 | 内容 |
|---|---|
| 禁止裸搜 | 所有私有向量检索必须带授权 metadata filter |
| 公共知识分库 | 养宠科普、疾病通用知识、食品通用知识进入 `public_knowledge` scope |
| 私有事实不进公共库 | 用户宠物事实、聊天摘要、图片备注、医疗记录不能进入公共知识索引 |
| 返回前二次鉴权 | 检索候选返回给模型前，再按 `actor_user_id` 做一次授权过滤 |

### 5.7 缓存 key 规则

| 缓存对象 | key 组成 |
|---|---|
| `pet_identity_context` | `agent:identity:{actor_user_id}:{pet_id}:{identity_context_version}` |
| `pet_current_diet_context` | `agent:diet:{actor_user_id}:{pet_id}:{diet_context_version}` |
| `abnormal_episode_context` | `agent:abnormal:{actor_user_id}:{pet_id}:{episode_id}:{episode_version}` |
| `user_agent_preferences` | `agent:prefs:user:{actor_user_id}:{preferences_version}` |
| `household_agent_preferences` | `agent:prefs:household:{household_id}:{actor_user_id}:{preferences_version}` |
| `memory_search_result` | `agent:memory-search:{actor_user_id}:{scope_type}:{scope_id}:{query_hash}:{memory_index_version}` |

缓存失效规则：

| 触发 | 失效目标 |
|---|---|
| 宠物关系变更 | 所有包含该 `pet_id` 的身份、饮食、异常、记忆检索缓存 |
| 用户被移除共管 | 该 `actor_user_id` 相关所有宠物上下文缓存 |
| 新增强事实 | 对应 `pet_id` 的领域上下文和检索缓存 |
| 用户修改毛球偏好 | `agent_preferences` 缓存 |
| 确认任务完成 | task、hint、相关领域上下文缓存 |

## 6. iOS 目标

| 任务 | 目标文件 / 模块 | 要求 |
|---|---|---|
| 当前宠物上下文 | Home、AI 入口、记录详情入口 | 发起毛球会话时只传当前选中 `pet_id` 和来源 ID，不传用户 ID |
| 登录态 | Authenticated HTTP client | 继续由请求基础设施注入 Authorization |
| 宠物切换 | 首页和记录页 | 切换宠物后新会话和工具请求绑定新的 `pet_id` |
| 授权失败展示 | AI / Home / Detail | 后端返回授权失败时展示可理解状态，不在前端补查其他宠物 |
| 毛球偏好 UI | 后续设置页 | 只编辑 `agent_preferences`，不写宠物事实 |
| 确认卡片 | AI 聊天或 hint 入口 | 用户确认后调用后端确认接口，前端不直接写强事实 |
| 非宠物问题展示 | AI 聊天页展示后端返回的短拒答，不在前端发起额外上下文查询 |
| 成本受限状态 | 当后端返回限速/冷却状态时，前端展示轻量提示，不重试主 Agent 请求 |

前端硬规则：

| 规则 | 内容 |
|---|---|
| 不传 `actor_user_id` | 用户身份由后端从 token 解析 |
| 不拼装私有事实上下文 | 前端只选择入口和当前宠物，事实包由后端构建 |
| 不兜底跨宠物 | 当前宠物无数据时展示空态或引导记录，不自动读取其他宠物 |
| 不用名字做身份 | 宠物名字只用于展示，所有请求使用 `pet_id` |
| 不为 off-topic 预加载 | 输入进入发送前后，前端不主动预取宠物事实包或私有记忆 |
| 不在前端自判放行私有数据 | 前端可以做输入长度和交互限制，领域放行和工具权限仍由后端决定 |

## 7. Agent 提示词与回复策略

Prompt 只承担行为约束，安全由工具层执行。

| 场景 | Agent 策略 |
|---|---|
| 用户要求读取未授权宠物 | 调用工具后按拒绝结果回复固定话术 |
| 用户要求忽略权限、进入管理员模式 | 回复无法执行该请求，并继续服务当前已授权宠物 |
| 用户用名字描述其他宠物 | 只在当前授权宠物候选内解析，解析不唯一时要求用户选择 |
| 用户要求比较多只宠物 | 只比较当前用户有权限访问的宠物 |
| 用户要求搜索所有宠物病例 | 只使用公共知识库或匿名统计结果 |
| 用户要求写入事实 | 生成确认任务或确认卡片，用户确认后写回 |
| 用户问非宠物通用问题 | 短拒答并拉回宠物照护范围 |
| 用户连续刷非宠物长问题 | 触发 `cost_abuse` 信号并进入限速或冷却 |
| 用户问 App 使用方式 | 使用产品帮助短答，不加载宠物事实包 |

## 8. 后端 TDD 任务拆分

### Task 1：Agent Gateway 与工具鉴权

| 步骤 | 内容 |
|---|---|
| 1 | 写未授权 `pet_id` 工具调用测试，断言返回 denied 且无事实泄漏 |
| 2 | 写已授权 owner / co_caretaker / merchant manager 工具调用测试 |
| 3 | 实现 Agent Gateway 工具注册和统一授权前置 |
| 4 | 写 `agent_tool_access_logs` 审计记录测试 |

### Task 2：Agent Preferences

| 步骤 | 内容 |
|---|---|
| 1 | 写用户级毛球名字和回复风格 CRUD 测试 |
| 2 | 写家庭级偏好只对家庭成员可见测试 |
| 3 | 实现 `agent_preferences` migration、domain、repository、HTTP DTO |
| 4 | 验证偏好不会写入宠物事实账本 |

### Task 3：会话摘要与记忆分区

| 步骤 | 内容 |
|---|---|
| 1 | 写 `chat_sessions` 绑定 `actor_user_id` / `primary_pet_id` 测试 |
| 2 | 写 `chat_session_summaries` 不作为强事实使用的用例测试 |
| 3 | 实现用户、宠物、家庭 scope 的记忆写入和读取 |
| 4 | 写跨 scope 读取被拒绝测试 |

### Task 4：向量检索过滤

| 步骤 | 内容 |
|---|---|
| 1 | 写未带 metadata filter 的检索端口测试，断言拒绝执行 |
| 2 | 写跨用户同名宠物记忆不会召回测试 |
| 3 | 实现检索前 filter 和返回后二次鉴权 |
| 4 | 公共知识库和私有记忆使用不同 scope |

### Task 5：缓存隔离

| 步骤 | 内容 |
|---|---|
| 1 | 写 cache key 包含 `actor_user_id`、scope、`pet_id`、版本号的单元测试 |
| 2 | 写宠物共管撤销后缓存失效测试 |
| 3 | 写新增事实后对应上下文缓存失效测试 |
| 4 | 实现上下文版本 bump 和缓存清理 |

### Task 6：用户诱导越权回归

| 步骤 | 内容 |
|---|---|
| 1 | 用自然语言输入模拟“读取其他用户宠物”请求 |
| 2 | 验证 LLM 产生工具调用时工具层拒绝 |
| 3 | 验证返回内容不包含未授权宠物是否存在的信息 |
| 4 | 验证审计日志记录拒绝原因 |

### Task 7：安全事件聚合与分级处置

| 步骤 | 内容 |
|---|---|
| 1 | 写连续未授权读取生成 `agent_security_events` 的测试 |
| 2 | 写宠物名/芯片号/档案号枚举触发风险分提升的测试 |
| 3 | 写高风险用户冻结 Agent 私有工具但保留账号安全入口的测试 |
| 4 | 写疑似数据泄露进入 `incident_response` 状态的测试 |

### Task 8：领域意图闸门与成本控制

| 步骤 | 内容 |
|---|---|
| 1 | 写 `off_topic` 请求不加载 `pet_identity_context`、不调用私有记忆检索的测试 |
| 2 | 写 `app_support` 使用轻量路径且不读取宠物事实的测试 |
| 3 | 写 `pet_health_risk` 正常进入主 Agent 并按需加载宠物上下文的测试 |
| 4 | 写连续非宠物长请求触发 `cost_abuse` 和限速/冷却的测试 |

## 9. 验收门禁

| 类型 | 命令 / 验收 |
|---|---|
| Rust 格式 | `cargo fmt --all --check` |
| Rust 编译 | `cargo check --workspace --all-targets` |
| Rust 测试 | `cargo test --workspace` |
| Rust lint | `cargo clippy --workspace --all-targets` |
| iOS Debug 构建 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build` |
| 授权验收 | 未授权 `pet_id` 的 Agent 工具调用返回 denied，不返回事实摘要、宠物姓名或存在性细节 |
| 多宠验收 | 同一用户多宠切换后，Agent 上下文只包含当前选中宠物和用户显式要求且有权限的宠物 |
| 共管验收 | 被授权共管者能读取共享宠物事实，撤销后无法读取且缓存失效 |
| 向量验收 | 私有记忆检索必须带 metadata filter，跨用户同名宠物不召回 |
| 缓存验收 | 不同用户访问同一只共管宠物时 cache key 隔离，权限撤销后旧缓存不可用 |
| 写入验收 | Agent 抽取事实只生成确认任务，用户确认后才写强事实 |
| 审计验收 | 每次 Agent 私有工具读取都有 access log，包含 allowed/denied 和引用 ID |
| 风控验收 | 连续未授权读取、宠物枚举和管理员诱导会生成 `agent_security_events` 并更新 `user_risk_scores` |
| 处置验收 | 高风险用户触发限速或冻结 Agent 私有工具后，普通账号安全和申诉入口仍可访问 |
| 意图验收 | `off_topic` / `app_support` 不加载宠物事实包，不检索私有记忆；可进入 AgentSession Workbench 做轻量边界引导或产品帮助 |
| 成本验收 | 连续非宠物长请求会记录 `agent_request_gate_logs` 并触发 `cost_abuse` 限速或冷却 |

## 10. 不变约束

| 约束 | 说明 |
|---|---|
| `pet_id` 是宠物事实根 | 名字、芯片号、档案号都不能替代 `pet_id` 做最终访问身份 |
| 登录态是唯一 actor 来源 | `actor_user_id` 只能由后端认证中间件注入 |
| 工具层是安全边界 | Prompt 不能承担越权防护的主要责任 |
| 读模型白名单 | Agent 只读取后端暴露的结构化读模型和授权记忆 |
| 弱线索不能变强事实 | 储物柜变化、聊天摘要、模型猜测都必须经确认才能写强事实 |
| 聊天摘要不是事实 | 摘要只服务 token 压缩，事实判断优先读领域事实表 |
| 私有记忆不进公共知识库 | 用户宠物事实和聊天摘要不能进入公共知识 scope |
| 审计必须可追溯 | Agent 回答引用的私有事实应能追到 `event_id`、`task_id`、`episode_id`、`memory_id` |
| 审计不进入上下文 | `agent_tool_access_logs`、`agent_security_events`、`user_risk_scores` 不进入普通毛球回答上下文 |
| 风控处置可复核 | 限制、冻结和人工审核必须能追溯到风险事件和原始 access log |
| 数据泄露单独处理 | 工具层成功拦截与疑似数据泄露分开标记和处理 |
| 毛球领域限定 | 毛球只承接宠物照护、宠物记录、宠物食品、宠物健康风险、宠物相关陪伴和 App 帮助 |
| 非宠物不加载上下文 | `off_topic`、`cost_abuse`、`prompt_injection` 不读取宠物事实、私有记忆和向量库 |
| App 帮助不读私有事实 | App 使用帮助只能读取公开产品帮助或规则，不读取用户宠物记录 |
| 前后端归属清晰 | 后端负责鉴权和事实拼装，iOS 负责当前宠物选择和结果展示 |

## 11. 风险

| 风险 | 处理 |
|---|---|
| 把安全寄托在 Prompt | 工具层鉴权、metadata filter、缓存 key 和审计日志作为强制门禁 |
| 向量库召回串用户 | 检索端口强制 filter，候选返回前二次鉴权 |
| 共管撤销后仍读到缓存 | 权限变更触发上下文版本 bump 和缓存失效 |
| 聊天摘要污染事实判断 | 摘要标记 `interaction_summary`，领域判断优先读强事实 |
| 自定义毛球名字混入宠物事实 | `agent_preferences` 独立建模，引用 user/household scope |
| 用户枚举宠物是否存在 | 未授权和不存在对外返回一致拒绝语义 |
| 多宠场景上下文过宽 | 默认只读当前 `selected_pet_id`；跨宠物比较必须显式选择并逐个鉴权 |
| 过度节约 token 丢关键事实 | 读模型按意图选择，引用 ID 可回查，重要事实用结构化摘要保留 |
| 审计成本过高 | access log 记录引用 ID 和摘要元数据，避免记录完整敏感 payload |
| 误伤正常用户 | 低风险只拒绝和记录，中高风险再限速或重新验证，严重处置需要人工复核 |
| 风控阈值被绕过 | 阈值和规则不对用户公开，结合行为频率、目标多样性、设备/IP 信号和请求 hash 聚合判断 |
| 审计泄露敏感信息 | 审计表保存 hash、摘要、标签和引用 ID，完整原文短期受控留存 |
| 内部人员滥用后台 | 后台查看、解封、降级风险分都写管理审计，保留处置 reason |
| 毛球被泛化成通用助手 | 入口意图闸门阻断 off-topic，并以验收测试保护不加载上下文 |
| 误判宠物相关问题为 off-topic | 低置信度意图走澄清问题，允许用户补充宠物对象和场景 |
| App 帮助消耗主模型 | App 帮助走规则或轻量模型，并独立统计 token |
| 成本滥用影响正常照护 | 限速优先作用于非宠物和主 Agent，紧急宠物健康风险保留安全通道 |
