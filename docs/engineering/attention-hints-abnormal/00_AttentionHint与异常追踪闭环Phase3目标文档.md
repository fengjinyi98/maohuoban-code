# Attention Hint 与异常追踪闭环 Phase 3 目标文档

- 更新时间：2026-06-25
- Goal：建立通用 `attention_hints` 首页轻提示读模型、`abnormal_episodes` 异常追踪链和 `agent_confirmation_tasks` 结构化确认任务，让异常记录、异常后续反馈、饮食确认、疫苗驱虫提醒和用户提醒等信号统一进入首页待处理提示，同时保证毛球 Agent 的追问任务、聊天消息和宠物事实账本边界清晰。
- 执行方式：先目标文档后实现；后端恢复 TDD 小切片推进；iOS 先迁移 mock/快速 UI 兜底到结构化契约，完成后执行真实 Debug 构建。

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| Phase 3 定位 | Phase 3 先做通用轻提示系统和异常 episode 追踪闭环，异常是第一个落地来源 |
| 首页轻提示 | 首页轻提示升级为 `attention_hints` 通用读模型 |
| 异常追踪 | 异常记录创建 `abnormal_episode`，后续观察、就诊、恢复挂到同一个 episode / thread |
| Agent 追问 | 毛球 Agent 产生 `agent_confirmation_task`，可被首页轻提示、通知、聊天入口复用 |
| 聊天边界 | `attention_hint` 和 `agent_confirmation_task` 默认不写入 `chat_messages`；用户进入聊天并发生真实交互后才写聊天记录 |
| 事实边界 | 用户确认后才写 `pet_events`，例如 `symptom_followup`、`agent_confirmed_fact`、`diet_change` |
| 提醒边界 | Reminder 是时间/到期事项；Attention Hint 是首页待处理注意信号；二者可以互相引用 |
| Agent 上下文 | 毛球以 `pet_id` 为根读取异常 episode、饮食强事实、储物柜弱线索、提醒和确认任务 |

## 2. 目标边界

### 2.1 本目标期必须完成

| 范围 | 目标 |
|---|---|
| 通用轻提示模型 | 新增或定义 `attention_hints`，承载首页轻提示、点击路由、优先级、状态和来源引用 |
| 异常 episode | 新增或定义 `abnormal_episodes`，把异常记录、追加观察、就诊、恢复串成一个闭环 |
| Agent 确认任务 | 新增或定义 `agent_confirmation_tasks`，承载饮食变化确认、症状追问、风险上下文确认 |
| 异常记录写入 | 异常提交时创建 episode，写入 `pet_events` 异常事实，并生成 `open_abnormal_episode` 轻提示 |
| 异常详情读取 | 异常详情从 episode 读取 header、症状、观察、证据、进展时间线和可执行动作 |
| 异常闭环动作 | 支持追加观察、关联就诊、标记恢复；恢复后 resolve 对应 hint 和 episode |
| 首页读模型 | `HomeDashboardSnapshot` 新增 `attention_hints`，首页时间线上方按优先级展示轻提示 |
| Phase 2 串联 | 异常分析时读取 `pet_current_diet_context`，强事实不足且存在储物柜变化时生成饮食确认任务 |
| Agent / Chat 边界 | 结构化确认任务和聊天消息分离；从 hint 进入聊天时只记录来源引用 |
| 代码备注 | 在关键 DTO、Store、投影或页面入口写清 `attention_hints`、`Reminder`、`chat_messages`、`pet_events` 的边界，避免后续漂移 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 医疗诊断结论 | 异常详情只展示用户主动记录和关联记录 |
| LLM 自动建议直接展示到异常详情 | 用户已明确异常详情不应混入后续观察建议 |
| HIS 完整就诊病历 | HIS 医疗链路后续独立做，本期只允许关联就诊记录引用 |
| 后台自动写聊天记录 | 首页 hint 和 Agent confirmation task 是待处理信号 |
| 全量提醒系统重构 | Reminder 继续保持通用提醒系统，本期只定义与 hint 的引用关系 |
| 复杂通知调度中心 | 本期定义状态和来源，通知调度后续单独设计 |
| 徽章/经验激励 | 异常追踪完成可作为后续徽章信号，本期不接激励系统 |
| 自动把储物柜变化当成换粮事实 | 储物柜变化仍是弱线索，必须经用户确认或真实喂食/饮食配置事件转成强事实 |

## 3. 依据

### 3.1 项目内依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| 产品策略 | `docs/product/strategy/04_宠物事实采集与毛球Agent记忆系统设计.md` | 文档明确“宠物事实采集系统 + 毛球 Agent 的结构化记忆底座”，并要求症状记录形成追踪链 |
| Phase 1 | `docs/engineering/pet-identity/00_宠物唯一主体与归属关系Phase1目标文档.md` | Phase 1 已定义所有事实和 Agent 上下文以不可变 `pet_id` 为根 |
| Phase 2 | `docs/engineering/pet-food-inventory/00_储物柜食品资产与宠物饮食配置Phase2目标文档.md` | Phase 2 已定义储物柜变化是弱线索，宠物饮食配置和喂食事件是强事实 |
| iOS 首页 hint | `maohuoban/maohuoban/Features/Home/Presentation/Sections/HomeOpenAbnormalEpisodeHintSection.swift` | 当前首页轻提示是异常专属组件，并通过时间线文本兜底识别“异常/恢复” |
| iOS 首页模型 | `maohuoban/maohuoban/Features/Home/Domain/Models/HomeDashboardSnapshot.swift` | 当前首页快照没有 `attentionHints` 字段，只有 `reminders`、`recentTimeline` 等 |
| iOS Reminder | `maohuoban/maohuoban/Features/Home/Domain/Models/HomeDashboardSections.swift` | Reminder 已有 `sourceRef`，定位为近期待处理提醒 |
| iOS 首页组合 | `maohuoban/maohuoban/Features/Home/Presentation/Sections/HomeDashboardContentSections.swift` | 当前异常轻提示放在时间线上方，Phase 3 可沿用位置并替换为通用 section |
| iOS 异常记录 | `maohuoban/maohuoban/Features/Pet/Presentation/Abnormal/PetAbnormalRecordScreen.swift` | 当前异常提交写 `PetEventDraft(kind: .health, subkind: "quick_abnormal")`，没有 episode、thread 和结构化 payload |
| iOS 异常模型 | `maohuoban/maohuoban/Features/Pet/Presentation/Abnormal/PetAbnormalRecordModels.swift` | 异常页已有症状类型和严重程度枚举，可直接映射后端结构化字段 |
| iOS 异常详情 | `maohuoban/maohuoban/Features/Pet/Presentation/Abnormal/PetAbnormalRecordDetailPresentation.swift` | 当前详情是 mock，已预留 `episodeID`，并注明只聚合用户主动记录和关联记录 |
| iOS 异常动作 | `maohuoban/maohuoban/Features/Pet/Presentation/Abnormal/PetAbnormalRecordDetailTimelineSections.swift` | 已定义追加观察、关联就诊、标记恢复三个动作，适合作为 episode 闭环入口 |
| iOS AI | `maohuoban/maohuoban/Features/AI/Stores/AIAssistantStore.swift` | 当前 AI 是本地 mock 对话壳，`pendingAction` 确认会追加聊天消息，不能直接复用为后台确认任务写入路径 |
| iOS AI Context | `maohuoban/maohuoban/Features/AI/Domain/AIAssistantEntryContext.swift` | 当前 AI 入口只有宠物和 UGC 上下文，后续需要扩展 `sourceHintID`、`confirmationTaskID` |
| iOS 添加提醒 | `maohuoban/maohuoban/Features/Home/Presentation/Reminders/HomeAddReminderSheet.swift` | 添加提醒 sheet 注释已明确“创建无 sourceRef 的提醒本体”，业务记录关联提醒由对应业务流程生成 |
| 后端 Home Domain | `maohuoban-rust/crates/maohuoban-home-domain/src/home/model/activity.rs` | 后端首页模型只有 `HomeReminder` 和 `HomeTimelineEvent`，没有 attention hint |
| 后端首页投影 | `maohuoban-rust/src/home_event_projection.rs` | 当前首页提醒从 `PetEvent` 派生 vaccine/deworming/follow_up，时间线从事件摘要投影，没有异常 episode 投影 |
| 后端事件表 | `maohuoban-rust/migrations/0005_pet_home_baseline.sql` | `pet_events` 已有 `event_payload jsonb`、`event_kind`、`event_subkind`、`occurred_at`，适合承载异常事实，但缺少 episode/thread 层 |

### 3.2 产品上下文依据

| 用户已确认决策 | 对 Phase 3 的约束 |
|---|---|
| 首页轻提示后续要统一为通用轻提示系统 | 异常轻提示组件不能成为长期架构 |
| 轻提示只在有信号时显示，放在时间线 section 上方 | `attention_hints` 首页展示位置沿用当前异常轻提示位置 |
| 轻提示不使用背景，只能通过图标颜色提醒 | iOS 组件设计继续保持非卡片、非背景式提示 |
| 异常记录详情只是用户主动记录详情 | 异常详情不能展示 LLM 后续观察建议 |
| 异常后续需要追加观察、就诊、恢复串成时间线 | `abnormal_episode` 必须是可追加、可关联、可关闭的对象 |
| 毛球追问或提示也可能显示在首页轻提示 | Agent 确认任务要能生成 hint，但 hint 不能自动变成聊天消息 |
| 饮食资产和宠物消费关系已进入 Phase 2 | Phase 3 的异常判断需要读取饮食强事实和储物柜弱线索 |

## 4. 推荐方案 / 数据流

### 4.1 核心对象关系

```text
pet_id
  -> pet_events
     -> abnormal symptom / observation / recovery / agent_confirmed_fact
  -> abnormal_episodes
     -> episode 状态、主症状、严重程度、开始/最后观察/恢复时间
  -> attention_hints
     -> 首页待处理提示、点击路由、优先级、来源引用
  -> agent_confirmation_tasks
     -> 毛球结构化追问、候选事实、用户确认结果
  -> chat_messages
     -> 只有用户进入聊天并真实交互后写入
```

### 4.2 异常创建流程

```text
用户点击首页「异常」
  -> 进入异常记录页
  -> 选择症状、程度、时间、备注、照片
  -> create_abnormal_episode
  -> 写 pet_events: event_kind = health, event_subkind = abnormal_symptom
  -> 写 abnormal_episodes: status = open
  -> 写 attention_hints: kind = open_abnormal_episode
  -> 首页时间线上方展示 hint
  -> 点击 hint 进入异常详情
```

### 4.3 异常追踪闭环

```text
异常详情
  -> 追加观察
     -> 写 pet_events: symptom_followup
     -> 更新 abnormal_episodes.last_observed_at / status
  -> 关联就诊
     -> 写或关联 clinic_visit 事件
     -> 更新 abnormal_episodes.latest_event_id
  -> 标记恢复
     -> 写 pet_events: abnormal_recovery
     -> 更新 abnormal_episodes.status = recovered
     -> resolve attention_hints(open_abnormal_episode / abnormal_followup_due)
```

### 4.4 Agent 追问与首页轻提示

```text
异常 episode 打开
  -> Agent 读取 pet_current_diet_context
  -> 强饮食事实不足
  -> Agent 读取 food_inventory_change_hints
  -> 发现近期新增主粮但无喂食/配置确认
  -> 创建 agent_confirmation_tasks(diet_change_confirmation)
  -> 创建 attention_hints(diet_change_confirmation)
  -> 用户点击 hint
     -> 进入确认任务或带 source_hint_id 的毛球聊天
  -> 用户确认
     -> 写 pet_events(agent_confirmed_fact / diet_change)
     -> resolve confirmation task
     -> resolve 或更新 hint
```

## 5. 后端目标

### 5.1 新增 `abnormal_episodes`

| 字段 | 要求 |
|---|---|
| `id` | UUID 主键 |
| `pet_id` | 引用 `pet_profiles(id)`，所有异常追踪以宠物为根 |
| `status` | `open`、`watching`、`recovering`、`recovered`、`escalated`、`closed` |
| `primary_symptom_kind` | 主症状，例如 `appetite`、`energy`、`stool`、`vomit` |
| `symptom_kinds` | 症状数组，可用 jsonb 或关联表表达 |
| `severity` | `mild`、`obvious`、`severe` |
| `started_at` | 用户记录的异常开始或发生时间 |
| `last_observed_at` | 最近一次观察、就诊或恢复反馈时间 |
| `recovered_at` | 标记恢复时间，可空 |
| `created_by_user_id` | 创建人 |
| `created_event_id` | 首条异常事实事件 |
| `latest_event_id` | 最近关联事件 |
| `created_at` / `updated_at` | 审计时间 |

约束：关闭或恢复 episode 不能删除历史事件；后续观察、就诊、恢复都必须可追溯到同一 `episode_id`。

### 5.2 新增 `attention_hints`

| 字段 | 要求 |
|---|---|
| `id` | UUID 主键 |
| `pet_id` | 引用 `pet_profiles(id)`；必要时可扩展到 user/household scope |
| `kind` | `open_abnormal_episode`、`abnormal_followup_due`、`diet_change_confirmation`、`preventive_care_due`、`reminder_due`、`weight_stale`、`feeding_pattern_changed` |
| `title` | 首页轻提示标题 |
| `subtitle` | 首页轻提示副标题 |
| `icon` | 客户端可映射 SF Symbol 的语义值 |
| `tone` | `info`、`notice`、`warning`、`critical` |
| `priority` | 数字优先级，首页按优先级和时间排序 |
| `status` | `active`、`dismissed`、`resolved`、`expired` |
| `source_ref_type` | `abnormal_episode`、`agent_confirmation_task`、`reminder`、`preventive_care_record`、`pet_event` |
| `source_ref_id` | 来源对象 ID |
| `route_kind` | `abnormal_detail`、`confirmation_task`、`reminder_detail`、`preventive_care_detail`、`weight_record`、`ai_chat` |
| `route_payload` | jsonb，存放 `episode_id`、`record_id`、`task_id`、`source_hint_id` 等路由参数 |
| `display_from` / `display_until` | 展示窗口 |
| `created_by` | `system`、`agent`、`user`、`business_rule` |
| `created_at` / `updated_at` / `resolved_at` | 审计时间 |

展示规则：同一宠物首页默认只展示最高优先级的少量 active hint；后端返回排序后的轻量读模型，前端不再从时间线文本猜测异常状态。

### 5.3 新增 `agent_confirmation_tasks`

| 字段 | 要求 |
|---|---|
| `id` | UUID 主键 |
| `pet_id` | 引用 `pet_profiles(id)` |
| `task_kind` | `diet_change_confirmation`、`symptom_followup`、`risk_context_confirmation` |
| `question_text` | 给用户的结构化追问文案 |
| `candidate_payload` | jsonb，候选事实或需要确认的上下文 |
| `source_hint_id` | 关联 hint，可空 |
| `source_ref_type` / `source_ref_id` | 关联 abnormal episode、food inventory hint、pet event 等 |
| `status` | `pending`、`answered`、`dismissed`、`expired` |
| `answer_payload` | 用户回答后的结构化结果 |
| `resolved_event_id` | 确认后写入的事实事件 |
| `created_at` / `resolved_at` | 创建和解决时间 |

硬规则：`agent_confirmation_tasks` 是结构化任务；任何 task 只有在用户确认后才写入 `pet_events`。

### 5.4 `pet_events` 异常 payload 补齐

| 事件 | 必备字段 |
|---|---|
| `abnormal_symptom` | `episode_id`、`symptom_kinds`、`symptom_details`、`severity`、`note`、`attachment_asset_ids` |
| `symptom_followup` | `episode_id`、`condition_change`、`symptom_kinds`、`note`、`attachment_asset_ids` |
| `clinic_visit_linked` | `episode_id`、`clinic_visit_event_id`、`linked_by_user_id` |
| `abnormal_recovery` | `episode_id`、`recovered_at`、`recovery_note` |
| `agent_confirmed_fact` | `confirmation_task_id`、`confirmed_fact_kind`、`confidence`、`linked_event_ids` |

Phase 1 已建议补齐 `source_kind`、`source_ref_type`、`source_ref_id`、`parent_event_id`、`thread_id`、`confidence`；Phase 3 的异常 episode 可以先用 `episode_id` 明确链路，再逐步收敛到统一 thread 字段。

### 5.5 首页聚合接口目标

| 输出字段 | 目标 |
|---|---|
| `attention_hints` | 返回当前选中宠物或首页上下文可见的 active hints |
| `recent_timeline` | 继续返回最近事实事件，不承担轻提示显隐判断 |
| `reminders` | 继续返回疫苗、驱虫、复诊、用户自定义提醒等时间事项 |
| `open_abnormal_episode_count` | 可作为兼容或统计字段，首页展示以 `attention_hints` 为主 |
| `latest_open_abnormal_episode_id` | 可进入 `attention_hints.route_payload`，避免前端单独猜 latest |

## 6. iOS 目标

| 任务 | 目标文件 / 模块 | 要求 |
|---|---|---|
| 首页模型 | `Features/Home/Domain/Models/HomeDashboardSnapshot.swift` | 新增 `attentionHints: [AttentionHint]`，字段映射后端 `attention_hints` |
| Hint Domain | `Features/Home/Domain/Models/HomeDashboardSections.swift` | 新增 `AttentionHint` 类型，含 kind、tone、priority、sourceRef、route |
| 首页组件 | `Features/Home/Presentation/Sections` | 将 `HomeOpenAbnormalEpisodeHintSection` 迁移为 `HomeAttentionHintSection`，保留时间线上方位置和无背景轻提示样式 |
| 首页组合 | `HomeDashboardContentSections.swift` | 从 `snapshot.homeLatestOpenAbnormalHintEvent` 切换为 `snapshot.attentionHints` |
| 临时兜底清理 | `HomeOpenAbnormalEpisodeHintSection.swift` | 后端接入后移除“从 recentTimeline 文本识别异常/恢复”的逻辑 |
| 异常记录 | `PetAbnormalRecordScreen.swift` | 提交结构化 abnormal payload，接后端 episode 创建接口 |
| 异常详情 Store | `Features/Pet/Presentation/Abnormal` | 从 mock presentation 迁移到 Store / Repository，按 `episode_id` 拉取详情 |
| 异常动作 | `PetAbnormalRecordDetailAction` | 追加观察、关联就诊、标记恢复接真实命令，并更新 episode / hints |
| AI 入口 | `AIAssistantEntryContext.swift` | 扩展 `sourceHintID`、`confirmationTaskID`、`initialIntent`，用于从 hint 进入聊天 |
| AI 建议动作 | `AIAssistantProposedAction.swift` / `AIAssistantStore.swift` | 聊天内 `pendingAction` 对齐 `agent_confirmation_tasks`，保持用户显式确认后写事实 |
| Reminder 保持独立 | `HomeAddReminderSheet.swift` / `HomeDashboardSections.Reminder` | 继续作为提醒系统，不用 Reminder 替代 Attention Hint |

### 6.1 前端不合理点与迁移要求

| 当前实现 | 问题 | Phase 3 迁移要求 |
|---|---|---|
| 从时间线标题/副标题包含“异常”识别轻提示 | 文本展示变化会影响业务状态 | 改为后端返回 `attention_hints` |
| 发现“恢复”文本就隐藏异常轻提示 | 恢复状态应由 episode.status 或 hint.status 决定 | 由后端 `abnormal_episodes.status` 和 `attention_hints.status` 控制 |
| 异常记录只写 `quick_abnormal` 事件摘要 | 缺少症状结构、episode 和追踪链 | 写结构化 payload 并创建 episode |
| 异常详情是 mock presentation | 无法展示真实追加观察、就诊、恢复链 | 引入 Store / Repository 按 episode 读取 |
| AI `pendingAction` 确认直接追加聊天消息 | 这是聊天内 mock 行为，不能代表后台任务流 | 后台 task 不自动写聊天；聊天入口只记录 source 引用 |
| 后端 HomeReminder 字段旧于 iOS Reminder | Reminder 和 Attention Hint 边界不同 | 不继续往 Reminder 塞 hint 语义 |

## 7. Agent / Chat 边界

| 规则 | 内容 |
|---|---|
| Hint 不是聊天 | `attention_hints` 不自动写入 `chat_messages` |
| Task 不是聊天 | `agent_confirmation_tasks` 不自动写入 `chat_messages` |
| 用户进入聊天才成消息 | 只有用户点击进入聊天或在聊天页发起交互，Agent 追问才写入 `chat_messages` |
| 确认任务独立存在 | Agent 的结构化追问先存在 `agent_confirmation_tasks`，可被首页、通知、聊天复用 |
| 事实写入独立于聊天 | 用户确认后写 `pet_events`，聊天只是其中一种交互入口 |
| 聊天可引用 hint | 若从 hint 进入聊天，chat session 记录 `source_hint_id` 和 `source_confirmation_task_id` |
| 回答可追溯 | 毛球引用异常、饮食、提醒时，应能追溯到 `episode_id`、`event_id`、`task_id` 或 `hint_id` |

### 7.1 聊天表建议扩展

| 字段 | 目标 |
|---|---|
| `chat_session_id` | 标识一次会话 |
| `source_hint_id` | 从首页 hint 进入聊天时记录来源 |
| `source_confirmation_task_id` | 从确认任务进入聊天时记录来源 |
| `linked_pet_id` | 当前聊天绑定宠物 |
| `linked_event_ids` | 本轮回答引用或生成的事实事件 |

## 8. Attention Hint 类型首批定义

| kind | 来源 | 点击行为 | 解决条件 |
|---|---|---|---|
| `open_abnormal_episode` | 未关闭异常 episode | 进入异常详情 | episode 标记恢复或关闭 |
| `abnormal_followup_due` | 异常追踪到期 | 进入追加观察或异常详情 | 用户反馈、延期、关闭 |
| `diet_change_confirmation` | 储物柜变化 + 缺少强饮食事实 | 进入确认任务或毛球 | 用户确认或否认 |
| `preventive_care_due` | 疫苗/驱虫临近或到期 | 进入疫苗/驱虫详情 | 完成记录或忽略 |
| `reminder_due` | 用户手动提醒 | 进入提醒详情 | 完成、延期、删除 |
| `weight_stale` | 长期未记录体重 | 进入体重记录 | 新增体重记录 |
| `feeding_pattern_changed` | 喂食节奏变化 | 进入饮食记录或毛球确认 | 用户确认或系统恢复正常 |

## 9. 后端 TDD 任务拆分

### Task 1：Attention Hint Domain 与首页读模型

| 步骤 | 内容 |
|---|---|
| 1 | 写 domain enum 和序列化测试，覆盖 kind、tone、status、route_kind |
| 2 | 新增 `attention_hints` migration |
| 3 | 实现 repository create/list/resolve/dismiss/expire |
| 4 | 首页聚合接口返回 `attention_hints`，并保持 `reminders` 独立 |
| 5 | 验证 `cargo test --workspace` 和 `cargo clippy --workspace --all-targets` |

### Task 2：Abnormal Episode

| 步骤 | 内容 |
|---|---|
| 1 | 写创建异常 episode 的 application 测试 |
| 2 | 新增 `abnormal_episodes` migration、domain model、repository |
| 3 | 创建异常时写 episode + pet event + open hint |
| 4 | 查询异常详情时返回 episode header、首条事件、关联事件 |

### Task 3：异常追加与恢复闭环

| 步骤 | 内容 |
|---|---|
| 1 | 写追加观察、关联就诊、标记恢复测试 |
| 2 | 追加观察更新 `last_observed_at` 和 `latest_event_id` |
| 3 | 关联就诊只挂引用，不复制就诊详情 |
| 4 | 标记恢复写恢复事件，并 resolve open/followup hints |

### Task 4：Agent Confirmation Task

| 步骤 | 内容 |
|---|---|
| 1 | 写 `diet_change_confirmation` 创建和回答测试 |
| 2 | 新增 `agent_confirmation_tasks` migration、domain model、repository |
| 3 | 回答确认后写 `agent_confirmed_fact` 或派生 `diet_change` |
| 4 | 验证 task 不自动写入聊天消息 |

### Task 5：iOS 首页轻提示与异常详情真实接入

| 步骤 | 内容 |
|---|---|
| 1 | 新增 iOS `AttentionHint` 解码测试或 Store 行为测试 |
| 2 | 首页从 `attentionHints` 渲染通用轻提示 |
| 3 | 异常记录提交结构化 payload |
| 4 | 异常详情按 `episode_id` 读取真实数据 |
| 5 | 执行 iOS Debug 构建 |

## 10. 验收门禁

| 类型 | 命令 / 验收 |
|---|---|
| Rust 格式 | `cargo fmt --all --check` |
| Rust 编译 | `cargo check --workspace --all-targets` |
| Rust 测试 | `cargo test --workspace` |
| Rust lint | `cargo clippy --workspace --all-targets` |
| iOS Debug 构建 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build` |
| 首页验收 | 有 active `attention_hints` 时，时间线上方显示通用轻提示；无 active hint 时不显示 |
| 异常验收 | 创建异常后首页出现 open abnormal hint；标记恢复后 hint 消失 |
| Agent 验收 | 储物柜弱线索只能生成确认任务；用户确认后才写事实事件 |
| 聊天验收 | 未进入聊天时不产生 `chat_messages`；从 hint 进入聊天时记录 source 引用 |

## 11. 不变约束

| 约束 | 说明 |
|---|---|
| `pet_id` 单根身份 | 所有 hint、episode、task、event 都必须绑定或可追溯到同一个 `pet_id` |
| 事件追加优先 | 异常、观察、恢复、确认都以追加事件保存，不能覆盖历史事实 |
| Reminder 保持独立 | Reminder 继续表达时间/到期事项，不承担首页注意信号所有语义 |
| 异常详情不显示 LLM 建议 | 异常详情只展示用户主动记录、关联记录和动作入口 |
| Hint 非强事实 | `attention_hints` 是待处理信号，不是事实账本 |
| Task 非聊天 | `agent_confirmation_tasks` 是结构化任务，不是聊天记录 |
| 储物柜变化是弱线索 | 不能把新增食品资产自动推断为宠物已食用 |
| iOS 渲染路径无副作用 | 轻提示排序、路由解析、展示 formatter 保持纯读取 |
| 快速 UI mock 可保留但需隔离 | mock 只用于预览和开发，不进入真实数据路径 |

## 12. 风险

| 风险 | 处理 |
|---|---|
| Hint、Reminder、Notification 概念混淆 | 文档和代码注释明确三者职责，首页聚合接口分字段返回 |
| 异常详情变成 AI 建议页 | 异常详情只接 episode 和 pet_events；Agent 提示通过 confirmation task / hint 独立展示 |
| 聊天记录被后台任务污染 | 后端写测试保证 task 创建/resolve 不写 chat；聊天入口显式携带 source |
| 前端继续从时间线文本猜业务状态 | 接入 `attention_hints` 后删除文本兜底，并用解码/展示测试保护 |
| 异常 episode 与 pet_events 双写不一致 | 用 application service 统一事务写入 episode、event、hint |
| 多宠首页 hint 串宠 | 所有 query 必须按 `pet_id` 和访问权限过滤；iOS 路由 payload 必须携带目标 pet |
| 储物柜弱线索被 Agent 当强事实 | Agent 读模型标注 fact strength，确认后才写 `agent_confirmed_fact` |
| Phase 3 范围过大 | 按 Attention Hint、Abnormal Episode、Confirmation Task、iOS 接入四个切片推进，每个切片独立验收 |
