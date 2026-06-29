# TODO：毛球 Agent 用户 Workspace 记忆与首轮上下文组装清单

- 创建时间：2026-06-29
- 文档类型：TODO
- 关联文档：
  - `docs/engineering/agent-memory-security/00_毛球Agent记忆隔离与工具安全目标文档.md`
  - `docs/product/strategy/04_宠物事实采集与毛球Agent记忆系统设计.md`
  - `docs/engineering/ai-agent-runtime/TODO_毛球Agent解耦与Hermes借鉴落地清单.md`

## 0. 文档边界

| 项 | 说明 |
|---|---|
| 本文是什么 | 用户个性化、记忆、会话上下文、首轮 ContextPack 组装的待办清单 |
| 本文不是什么 | 不是目标文档、不是 ADR、不是数据库最终设计 |
| 核心判断 | 生产记忆以数据库结构化存储为权威，Markdown 只作为调试导出和人工查看视图 |

## P0：Workspace Scope 与隔离底座

- [ ] 定义 `AgentWorkspaceScope`。
  - 交付物：能表达 `user`、`household`、`pet`、`session` 四类 scope。
  - 验证：任何 ContextPack、MemoryPack、缓存 key、检索请求都必须携带 scope。

- [ ] 新增 `WorkspaceResolver`。
  - 输入：`actor_user_id`、登录态、入口 `selected_pet_id`、会话 ID、用户消息。
  - 输出：当前 turn 可访问的 user scope、household scope、授权 pet scope、session scope。
  - 验证：模型不能传入或覆盖 `actor_user_id`、`pet_id` 授权结果。

- [ ] 定义 scope 权限规则。
  - 交付物：`user` 私有、`household` 家庭成员可见、`pet` 由 `pet_guardians` 授权、`session` 归属发起用户。
  - 验证：未授权 pet 不进入候选摘要、记忆检索、工具目录和 ContextPack。

- [ ] 定义上下文缓存 key 规则。
  - 字段：`actor_user_id`、`scope_type`、`scope_id`、`pet_id`、`fact_projection_version`、`memory_version`、`preference_version`。
  - 验证：同名宠物、共管宠物、不同用户之间不会复用上下文缓存。

## P0：数据库记忆对象拆分

- [ ] 定义 `agent_preferences`。
  - 用途：保存用户明确偏好，例如回复长度、语气、称呼、禁忌表达、毛球自定义名称。
  - 验证：偏好可查看、可修改、可删除，有 `source` 和 `updated_at`。

- [ ] 定义 `agent_profile_items`。
  - 用途：保存系统归纳的用户画像，例如记录时间习惯、照护关注点、表达偏好趋势。
  - 验证：画像带 `confidence`，只作为辅助上下文，不能覆盖用户明确偏好。

- [ ] 定义 `agent_memory_items`。
  - 用途：保存跨会话弱记忆和长期线索。
  - 必备字段：`scope_type`、`scope_id`、`pet_id`、`memory_kind`、`content`、`confidence`、`source_ref`、`status`。
  - 验证：检索必须按 scope metadata 过滤。

- [ ] 定义 `agent_memory_candidates`。
  - 用途：保存从会话、工具结果、用户确认动作中抽取出的候选记忆。
  - 验证：候选通过校验或确认后才能升级为偏好、画像、记忆或宠物事实。

- [ ] 定义 `chat_session_summaries`。
  - 用途：保存当前会话摘要、未完成事项、宠物主体、事实引用、确认动作。
  - 验证：继续旧会话时注入摘要，新会话默认不加载旧会话摘要。

- [ ] 明确宠物强事实存储位置。
  - 交付物：宠物年龄、主粮、症状、用药、异常、健康时间线仍以宠物领域表和 `pet_events` 为权威。
  - 验证：`agent_memory_items` 不复制会频繁变化的宠物强事实，只保存引用或弱线索。

## P0：首轮 ContextPack 组装链路

- [ ] 新增 `ContextBuilder` 首轮组装入口。
  - 输入：`actor_user_id`、`session_id`、`user_message`、`entry_context`、`WorkspaceScope`。
  - 输出：模型可见 `ContextPack`，不暴露数据库行、权限字段、内部展示字段。
  - 验证：LLM 只看到白名单投影。

- [ ] 首轮加载用户偏好。
  - 内容：少量高优先级偏好，例如回答长度、语气、称呼。
  - 验证：偏好注入有 token 上限，冲突时以最近明确偏好为准。

- [ ] 首轮判断是否需要私域宠物上下文。
  - 场景：用户说“我家”“它”“豆包”或入口带 selected pet 时才加载宠物候选摘要。
  - 验证：公共宠物问题不读取私域宠物事实和私有记忆。

- [ ] 首轮加载授权宠物候选摘要。
  - 内容：`pet_id`、名字、物种、必要消歧字段。
  - 验证：候选摘要不包含内部状态、权限细节、敏感家庭信息。

- [ ] 首轮避免全量宠物事实注入。
  - 做法：优先给模型工具目录，让模型按需申请 `load_pet_identity_context`、`load_pet_current_diet_context`、`load_pet_recent_observations`。
  - 验证：私域事实来自 Tool Gateway 的最新事实投影。

- [ ] 首轮按 scope 检索相关跨会话记忆。
  - 做法：只检索当前 user / household / pet scope 下与问题相关的少量记忆。
  - 验证：无 pet 场景不检索 pet 私域记忆。

- [ ] 定义 ContextPack 预算和裁剪顺序。
  - 优先级：安全边界 > 明确偏好 > 当前会话摘要 > 最近消息 > 当前 pet 候选 > 相关记忆 > 弱画像。
  - 验证：超预算时优先裁剪弱画像和低置信记忆。

## P1：会话上下文与跨会话记忆

- [ ] 新增同会话最近消息加载策略。
  - 交付物：继续当前 session 时加载最近 N 轮或最近 token 预算内消息。
  - 验证：连续追问能识别上一轮 pet、话题、工具结果引用。

- [ ] 新增会话摘要更新流程。
  - 触发：turn 完成、上下文接近阈值、会话结束、用户切换主题。
  - 摘要内容：用户意图、宠物主体、已用事实、未完成确认、风险边界。
  - 验证：摘要不保存工具原始敏感参数。

- [ ] 新增跨会话记忆检索器。
  - 输入：用户问题、WorkspaceScope、目标 pet、memory_kind。
  - 输出：少量可注入 memory snippets。
  - 验证：检索结果必须带来源、置信度和状态。

- [ ] 新增记忆注入格式。
  - 交付物：`MemoryPack` 明确区分 preference、profile、memory、session_summary、fact_reference。
  - 验证：模型能区分“明确偏好”和“系统推断画像”。

## P1：自进化流水线

- [ ] 新增 `TurnFinalizer` 记忆入口。
  - 输入：用户消息、最终回答、工具结果、引用、确认动作、错误。
  - 输出：候选摘要、候选偏好、候选画像、候选事实。
  - 验证：主回答完成后异步执行，不阻塞 SSE 完成。

- [ ] 新增 `MemoryCandidateExtractor`。
  - 分类：`preference_candidate`、`profile_candidate`、`pet_fact_candidate`、`session_summary_candidate`、`risk_signal`。
  - 验证：分类结果必须带来源引用和置信度。

- [ ] 新增 `MemoryVerifier`。
  - 校验：权限、冲突、来源可靠性、是否需要用户确认、是否属于宠物强事实。
  - 验证：未确认宠物强事实不能直接写入宠物事实表。

- [ ] 新增偏好更新策略。
  - 规则：用户明确表达的偏好可高置信更新；模型推断不能直接改偏好。
  - 验证：“以后回答短一点”能更新 `agent_preferences`；“用户可能喜欢短答”只能进入画像候选。

- [ ] 新增用户画像更新策略。
  - 规则：多次行为一致才提高置信度；单次行为只生成低置信画像。
  - 验证：画像过期、降权、删除都有机制。

- [ ] 新增宠物事实候选写入策略。
  - 规则：聊天抽取出的饮食、症状、用药、档案变化进入确认任务或领域待确认对象。
  - 验证：用户确认后写 `pet_events` 或对应领域表。

## P1：事实更新与记忆失效

- [ ] 定义事实版本号。
  - 对象：pet identity、diet projection、symptom thread、health timeline、memory pack、preference pack。
  - 验证：事实变化后相关 ContextPack 缓存失效。

- [ ] 定义记忆 stale 状态。
  - 状态：`active`、`stale`、`superseded`、`retracted`、`deleted`。
  - 验证：回答时不注入 stale / deleted 记忆。

- [ ] 新增事实引用型记忆。
  - 做法：可变宠物强事实用 `ref_type` + `ref_id` 指向事实投影，回答时重新读取最新事实。
  - 验证：宠物主粮更新后，旧主粮不会通过长期记忆再次注入。

- [ ] 新增冲突处理。
  - 场景：用户新说法与旧记忆冲突、宠物事实与画像冲突、家庭成员记录冲突。
  - 验证：冲突进入候选或确认任务，不自动覆盖强事实。

## P2：多用户与共管安全

- [ ] 定义家庭共管记忆边界。
  - 交付物：家庭共享偏好和家庭共享宠物事实与个人偏好分离。
  - 验证：A 用户个人偏好不会影响 B 用户私聊体验。

- [ ] 定义共管宠物事实读取边界。
  - 交付物：pet scope 由 `pet_guardians` 和家庭关系共同决定。
  - 验证：撤销授权后，相关 pet 记忆和缓存立即不可读。

- [ ] 定义审计日志。
  - 内容：ContextBuilder 加载了哪些 scope、哪些记忆、哪些事实引用、哪些工具能力。
  - 验证：排查越权问题时能还原本轮上下文来源。

- [ ] 定义用户删除与隐私权利。
  - 操作：删除偏好、删除画像、删除跨会话记忆、清空会话、撤销家庭共享。
  - 验证：删除后 ContextBuilder 不再注入对应内容。

## P2：观测与调试视图

- [ ] 新增 MemoryPack 诊断输出。
  - 内容：scope、加载数量、裁剪原因、版本号、引用 ID。
  - 验证：诊断不输出敏感原文和密钥。

- [ ] 新增 Markdown 导出视图。
  - 用途：人工 review 用户偏好、画像摘要、记忆状态。
  - 验证：导出视图不是权威存储，修改导出文件不影响数据库。

- [ ] 新增管理后台预留接口。
  - 能力：查看偏好、画像、记忆候选、确认状态、事实引用。
  - 验证：后台接口仍走权限和审计。

## P3：回归测试与安全 Case

- [ ] 首轮公共问答 case。
  - 输入：“猫拉肚子怎么办？”
  - 验证：不加载私域宠物事实、不检索 pet 私域记忆。

- [ ] 首轮私域问答 case。
  - 输入：“豆包今天拉肚子，是不是换粮了？”
  - 验证：加载授权宠物候选，模型通过工具读取饮食和异常事实。

- [ ] 偏好更新 case。
  - 输入：“以后回答短一点。”
  - 验证：更新 `agent_preferences`，下一轮 ContextPack 注入短答偏好。

- [ ] 用户画像 case。
  - 输入：多次晚上记录喂食。
  - 验证：生成低/中置信画像，不作为强规则。

- [ ] 宠物事实更新 case。
  - 输入：“豆包现在不吃旧主粮了，换成 X。”
  - 验证：进入确认任务；确认后写宠物事实并让旧记忆 stale。

- [ ] 多用户隔离 case。
  - 输入：用户 A 和用户 B 共同管理同一宠物，但偏好不同。
  - 验证：宠物事实共享，个人偏好隔离。

- [ ] 越权诱导 case。
  - 输入：用户要求查看未授权宠物历史。
  - 验证：ContextBuilder 不加载该 pet，Tool Gateway 拒绝，审计记录风险。

## 参考点

| 参考项目文件 | 可借鉴内容 |
|---|---|
| `references/agent/hermes-agent/agent/turn_context.py` | turn 前置上下文 builder |
| `references/agent/hermes-agent/agent/memory_manager.py` | memory provider 编排和上下文清洗 |
| `references/agent/hermes-agent/agent/context_engine.py` | 可替换上下文引擎 |
| `references/agent/hermes-agent/website/docs/developer-guide/memory-provider-plugin.md` | memory provider 生命周期 |
| `docs/engineering/agent-memory-security/00_毛球Agent记忆隔离与工具安全目标文档.md` | scope、权限、候选事实、安全审计 |
| `docs/product/strategy/04_宠物事实采集与毛球Agent记忆系统设计.md` | 宠物事实账本和 Agent 事实工具边界 |

