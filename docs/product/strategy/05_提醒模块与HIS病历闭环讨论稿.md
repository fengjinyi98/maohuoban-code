# 提醒模块与 HIS 病历闭环讨论稿

- 更新时间：2026-07-05
- 文档性质：产品与工程边界讨论稿
- 适用范围：提醒模块、通知边界、异常追踪、诊前资料包、HIS 病历回流、App 病历展示
- 非目标：本文不是目标文档、实施计划或接口契约；不直接约束当前迭代排期。

---

## 1. 当前讨论结论

| 主题 | 结论 |
|---|---|
| 提醒模块 | 后端需要独立 Reminder 模块，提醒是业务计划，不等同通知。 |
| 通知模块 | Notification 负责触达执行，包括 APNs、站内通知、短信、邮件等投递状态。 |
| 系统日历 | 系统日历只作为用户主动开启的镜像能力，不作为提醒数据源。 |
| 提前提醒 | 宠物护理更适合“提前 1 天 / 3 天 / 7 天 / 当天”的护理节奏，会议式 10 分钟、1 小时价值较低。 |
| 病历来源 | App 病历记录主路径应来自医院 HIS 发布回流，不应以用户手动创建为主。 |
| 用户职责 | 用户记录异常、补充文字观察、上传就医资料照片、记录恢复和用药反馈。 |
| 医院职责 | 医生通过 HIS 产生原始病历、诊断、处方、检查报告和发布版健康档案。 |
| Agent 职责 | Agent 只基于宠物事实、结构化字段和用户文字追问、归纳、提醒、生成诊前摘要，不识别照片，不替代医生写病历或诊断。 |
| HIS 闭环 | 异常追踪积累事实，必要时生成诊前资料包给合作医院 HIS，医院诊疗后病历回流 App。 |
| 第一期能力约束 | 无 OCR、无多模态；照片只作为原始附件供医生查看，LLM 不解析图片内容。 |

---

## 2. 提醒与通知边界

### 2.1 核心定义

| 层 | 职责 | 示例 |
|---|---|---|
| Reminder 提醒 | 业务计划和待办本体 | 7 月 20 日给梅录做驱虫提醒 |
| Reminder Trigger | 具体触发点 | 提前 3 天、提前 1 天、当天 9:00 |
| Notification 通知 | 触达任务和投递状态 | APNs 已发送、失败、已读 |
| Calendar Mirror | 外部系统镜像 | 写入 Apple Calendar event |
| Attention Hint | 首页注意信号 | 异常需要更新、饮食变化需要确认 |

提醒是“应该在什么时候处理什么业务事项”。通知是“通过什么渠道把这件事送到用户面前”。二者状态不能混用。

### 2.2 状态边界

| 场景 | 正确归属 |
|---|---|
| 用户标记驱虫提醒已完成 | Reminder status |
| APNs 发送失败 | Notification delivery status |
| 用户关闭系统通知权限 | Notification channel unavailable |
| 用户删除提醒 | Reminder deleted，同时取消未来 triggers |
| 用户清空系统通知中心 | 只影响设备通知展示 |
| 用户在 App 内标记已读 | Notification read，不代表 Reminder 完成 |
| 用户在日历里删除事件 | Calendar mirror broken，不代表 App Reminder 删除 |

### 2.3 推荐后端边界

```text
reminder-domain
  -> Reminder
  -> ReminderKind
  -> ReminderStatus
  -> ReminderAdvancePolicy
  -> ReminderTrigger

reminder-application
  -> CreateReminder
  -> UpdateReminder
  -> CompleteReminder
  -> DeleteReminder
  -> GenerateReminderTriggers
  -> QueueDueReminderNotifications

notification-domain
  -> NotificationJob
  -> NotificationChannel
  -> NotificationDelivery
  -> NotificationStatus

notification-application
  -> CreateNotificationJob
  -> SendNotificationJob
  -> MarkNotificationRead
```

### 2.4 推荐数据流

```text
用户创建提醒
-> Reminder API 创建 reminder
-> Reminder 模块保存业务提醒
-> Reminder 模块根据策略生成 reminder_triggers
-> Scheduler 到点扫描 due triggers
-> 调用 Notification 模块创建 notification_job
-> Notification 模块发送 APNs / 站内通知
-> 回写 notification delivery 状态
```

### 2.5 系统日历同步

| 项 | 推荐 |
|---|---|
| 默认状态 | 默认关闭 |
| 入口 | 添加/编辑提醒 Sheet 增加“同步到系统日历” Switch |
| 授权时机 | 用户首次打开 Switch 时触发系统日历授权 |
| 写入内容 | 创建系统日历事件和 alert |
| 数据主源 | App 后端 Reminder |
| 编辑提醒 | App 更新成功后同步更新日历事件 |
| 删除提醒 | App 删除成功后删除日历事件 |
| 同步失败 | App 提醒保留，日历镜像显示失败或允许重试 |
| 多设备 | 每台设备各自同步自己的本地日历镜像 |

系统日历事件不能反向成为 App 提醒的数据源。用户在系统日历里修改或删除事件，只能影响日历镜像状态。

### 2.6 提前提醒策略讨论

当前“准时 / 提前 10 分钟 / 提前 1 小时 / 提前 1 天”更像会议提醒。宠物护理提醒的核心是提前安排时间。

推荐候选：

| 选项 | 适用场景 |
|---|---|
| 不提前 | 只想保留到期当天事项 |
| 当天提醒 | 普通事项 |
| 提前 1 天 | 驱虫、普通复诊、常规护理 |
| 提前 3 天 | 体检、需要预约医院的事项 |
| 提前 7 天 | 疫苗、年度体检、复杂安排 |

也可以抽象成策略：

| 策略 | 行为 |
|---|---|
| 轻提醒 | 当天一次 |
| 标准提醒 | 提前 1 天 + 当天 |
| 重要提醒 | 提前 7 天 + 提前 1 天 + 当天 |

待决策问题：提醒 Sheet 是直接展示单个提前时间，还是展示“轻提醒 / 标准提醒 / 重要提醒”这类策略。

---

## 3. 异常追踪、Agent 与提醒关系

### 3.1 异常追踪不应立即打扰

用户创建异常时，异常可能是偶发情况。系统不应在异常刚创建后立刻强提醒用户更新。

推荐机制是“规则调度 + Agent 解释和归纳”：

```text
用户创建异常
-> 创建 abnormal_episode
-> 根据严重程度生成 follow-up plan
-> 到达合适时间后生成 attention_hint 或 reminder_trigger
-> 用户更新异常情况
-> 写入 abnormal_followup 事实
-> 如果持续或加重，提示预约合作医院
```

### 3.2 异常追踪节奏建议

| 严重程度 | 初次更新提醒 | 后续提醒 | 升级条件 |
|---|---|---|---|
| 轻微 | 8-12 小时后 | 每 24 小时一次，最多 2 次 | 持续超过 24-48 小时 |
| 明显 | 4-6 小时后 | 每 12 小时一次 | 精神差、食欲差、频繁腹泻、带血 |
| 严重 | 立即建议就医 | 2-4 小时内确认是否已就医 | 拒食、脱水、血便、持续呕吐、幼宠/老年宠 |
| 已就医 | 不再催促异常更新 | 改为用药/复诊提醒 | 用药不良反应、复诊临近 |

### 3.3 异常更新入口

| 入口 | 适合场景 | 说明 |
|---|---|---|
| 异常更新 Sheet | 快速结构化更新 | 好转 / 无变化 / 加重，补充便便、精神、食欲、照片 |
| Agent 聊天 | 用户不知道如何描述 | Agent 追问并把自然语言整理成结构化事实 |

Agent 不替代业务入口。Agent 的价值是追问缺失信息、降低用户表达成本、把自然语言归纳成结构化事实，并在就医前生成医生能快速理解的摘要。

### 3.4 第一期 Agent 能力边界

第一期选择的 LLM 提供商不具备多模态能力，因此 Agent 只处理文本和结构化事实。

| Agent 可以做 | 示例 |
|---|---|
| 基于宠物事实提出观察建议 | 根据近期喂食、便便、精神、食欲、体重和异常记录，建议继续观察或考虑就医 |
| 主动追问异常变化 | “今天还有水样便吗？精神和食欲有没有变差？” |
| 引导用户补充文字事实 | 当前用药、既往病史、过敏/不良反应、异常开始时间 |
| 归纳用户文字 | 将“今天还是拉稀，没昨天活泼”整理为异常更新草稿 |
| 生成诊前文字摘要 | 只基于结构化字段和用户文字生成，标注供医生参考 |
| 标注附件存在 | “用户上传了 3 张资料照片，请医生查看原件” |

| Agent 不能做 | 原因 |
|---|---|
| 识别报告照片 | 第一期无 OCR、无多模态 |
| 提取化验指标 | 没有可靠文字输入 |
| 判断影像内容 | 医疗高风险且无视觉能力 |
| 根据照片诊断 | 越过医疗边界 |
| 把附件内容写入摘要 | 图片内容未被系统解析 |
| 猜测药品名称或报告结论 | 医疗场景不允许不确定推断 |

### 3.5 Attention Hint 与 Reminder 的区别

| 对象 | 作用 | 示例 |
|---|---|---|
| Attention Hint | 首页注意信号，强调“现在需要处理” | “梅录的拉肚子情况需要更新” |
| Reminder | 时间计划，强调“到点要做某件事” | “明天 9:00 复诊” |

异常追踪可以同时产生 Hint 和 Reminder，但二者不能互相替代。

---

## 4. HIS 病历闭环边界

### 4.1 病历不应由用户主创建

病历是医生诊疗后的医疗文书或发布版健康档案。普通用户不知道如何填写诊断、处置、用药和检查结论，也不应被要求手动创建医生职责字段。

App 用户能创建的是：

| 用户动作 | 命名建议 |
|---|---|
| 记录症状 | 异常记录 |
| 更新症状 | 异常更新 / 观察更新 |
| 上传报告、发票、药品、影像等照片 | 上传就医资料 |
| 就医后记录恢复、用药反馈 | 追加恢复 / 用药反馈 |
| 记录非合作医院就医经历 | 补充就医经历 |

App 里的“病历记录”主路径应来自：

| 来源 | 可信等级 | 展示文案 |
|---|---|---|
| 合作医院 HIS 发布 | 最高 | 由 XX 医院发布 |
| 用户上传照片资料 | 中低 | 用户上传资料 |
| Agent 根据文字整理 | 辅助 | 由毛球根据用户文字整理，需医生确认 |
| 用户补充说明 | 辅助 | 用户补充记录 |

第一期不假设宠物医院能稳定提供完整外院纸质病历、PDF 或结构化报告。用户侧只提供照片附件和手动文字说明；这些资料进入诊前包时必须保留来源和低可信标记。

### 4.2 核心链路

```text
用户正常记录喂食、便便、精神、食欲、体重等事件
-> 某天发现宠物拉肚子
-> 用户创建异常记录
-> abnormal_episode 打开
-> 系统延迟提醒用户更新异常
-> 用户更新后发现异常持续或加重
-> App 推荐预约合作医院
-> 后端生成诊前资料包
-> 预约单携带诊前资料包进入 HIS
-> 医生查看宠物资料、近期吃喝拉撒、异常时间线和照片
-> 医生接诊、诊断、开药、检查、收费
-> HIS 发布健康档案
-> App 收到医院病历回流
-> 用户在 App 查看病历、用药、复诊建议
-> 后续追踪用药反馈、恢复情况和复诊
```

### 4.3 对象边界

| 对象 | 谁创建 | 本质 |
|---|---|---|
| Pet Event | 用户 / 系统 / HIS | 宠物事实账本 |
| Abnormal Episode | 用户创建异常时系统生成 | 一次异常追踪链 |
| Abnormal Followup | 用户更新或 Agent 结构化后写入 | 异常进展事实 |
| Pre-visit Package | App 后端生成 | 就医前事实快照 |
| Hospital Appointment | 用户发起 | 合作医院接诊入口 |
| HIS Encounter | 医院 HIS 创建 | 医院内部就诊记录 |
| HIS Raw Medical Record | 医生创建 | 医院原始病历 |
| Health Record Publication | 医院发布 | 面向用户和授权协作的健康档案版本 |
| App Medical Record | HIS 回流 / 用户资料导入 | 用户可见病历聚合 |
| Medical Record User Update | 用户追加 | 恢复、用药反馈、补充资料 |

### 4.4 诊前资料包

诊前资料包不是病历。它是 App 根据宠物事实账本和异常追踪生成的一次性就医证据快照。

第一期诊前资料包只能使用三类输入：

| 输入 | 处理方式 |
|---|---|
| App 已有结构化事实 | 喂食、便便、精神、食欲、体重、疫苗、驱虫、异常记录 |
| 用户手动填写文字 | 主诉描述、既往病史、当前用药、过敏/不良反应 |
| 用户上传照片 | 原始附件和缩略图，供医生查看；系统不解析图片内容 |

建议包含：

| 内容 | 示例 |
|---|---|
| 宠物基本信息 | 名字、品种、性别、年龄、体重、绝育状态 |
| 当前问题 | 拉肚子、发生时间、严重程度、持续时间 |
| 异常时间线 | 首次发现、后续更新、照片、恢复/加重 |
| 近期饮食 | 主粮、换粮、喂食记录、食欲变化 |
| 近期排便 | 便便正常/异常记录、次数、性状 |
| 精神与食欲 | 快捷事实和异常更新 |
| 体重趋势 | 最近体重记录 |
| 疫苗驱虫 | 最近疫苗、驱虫记录 |
| 附件 | 便便照片、呕吐物照片、症状照片、报告照片、发票照片、药品照片 |
| 用户备注 | 用户主动补充的描述 |
| Agent 文字摘要 | 基于结构化字段和用户文字生成，明确“供医生参考” |

诊前资料包必须是快照。生成后不能因为后续事件静默改变历史包内容；需要更新时生成新版本。

照片附件在第一期只承担证据材料作用。诊前资料包中不能出现“系统识别出血常规某指标异常”这类基于图片推断的内容。

### 4.5 HIS 回流病历

HIS 端应保留双层模型：

| 层级 | 可见性 | 说明 |
|---|---|---|
| HIS 原始病历 | 医院内部授权员工 | 完整病历、内部备注、处方、收费、库存、治疗方案 |
| 发布版健康档案 | 宠物主 App、被授权机构 | 诊断摘要、报告、用药摘要、复诊建议 |

App 只展示发布版健康档案。医院内部备注、治疗方案、成本利润、经营数据不能默认回流给用户。

### 4.6 App 病历详情页方向

App 病历详情应展示“医院发布版健康档案”，而不是用户手写病历表单。

建议区块：

| 区块 | 内容 |
|---|---|
| 顶部状态 | 已发布、待复诊、用药中、已完成 |
| 发布来源 | 医院、医生、发布时间、来源可信标识 |
| 就诊摘要 | 就诊时间、主诉摘要、诊断摘要 |
| 诊前依据 | 关联异常 Episode、诊前资料包入口 |
| 医疗内容 | 诊断、检查报告、处方/用药、处置、费用摘要 |
| 复诊计划 | 复诊时间、注意事项、提醒入口 |
| 附件 | 报告、发票、检查单、照片 |
| 用户追加 | 用药反馈、恢复情况、补充文字和资料照片 |
| 审计来源 | HIS 发布、用户上传照片、Agent 文字整理、用户补充 |

### 4.7 当前 App 病历功能语义调整建议

| 当前概念 | 建议调整 |
|---|---|
| 新增病历 | 改为“上传就医资料”或后置 |
| 追加病历 | 改为“追加恢复 / 用药反馈 / 补充资料” |
| 手动填写诊断 | 不作为普通用户主入口 |
| 病历列表 | 展示 HIS 回流病历和用户上传的就医资料 |
| 病历详情 | 展示发布版病历来源和可信度 |

就医资料详情第一期只展示资料类型、用户备注、附件、关联就医状态和医生采纳状态。不得展示 OCR 识别结果或图片内容摘要。

---

## 5. 基础闭环流程图

本流程只覆盖一个简单场景：宠物原本健康，用户连续几天有正常记录，某天发现拉肚子，App 追踪异常，必要时预约合作医院，HIS 回流病历。慢性病、复杂既往史、非合作医院资料整理、OCR、多模态识别都不进入这个基础闭环。

### 5.1 主流程

```text
健康宠物日常记录
➡️ 连续几天记录便便正常 / 精神不错 / 食欲正常 / 喂食 / 体重等事实
➡️ 某天用户发现异常：拉肚子
➡️ 用户创建异常记录：选择便便异常、严重程度、发生时间、文字备注，可上传照片
➡️ 系统创建 abnormal_episode，并写入异常 pet_event
➡️ 系统不立即打扰，按严重程度生成后续追踪计划
➡️ 到达追踪时间后，首页/通知出现“更新异常情况”的提示
➡️ 用户进入异常更新入口
➡️ 用户通过结构化选项或文字更新：好转 / 无变化 / 加重，补充便便、精神、食欲、照片
➡️ 系统写入 abnormal_followup，并更新 abnormal_episode 状态
➡️ 系统和 Agent 基于宠物事实、异常更新和用户文字判断下一步
➡️ 分支 A：异常好转
   ➡️ 系统降低追踪频率或提示继续观察
   ➡️ 用户确认恢复
   ➡️ 系统关闭 abnormal_episode
   ➡️ 时间线保留异常发生、更新、恢复事实
   ➡️ 本次闭环结束
➡️ 分支 B：异常持续但未明显加重
   ➡️ 系统继续按节奏提醒更新
   ➡️ Agent 追问缺失事实：食欲、精神、饮水、次数、是否换粮、是否用药
   ➡️ 用户补充文字或结构化字段
   ➡️ 系统继续写入 abnormal_followup
   ➡️ 若超过观察窗口或出现风险信号，进入就医建议
➡️ 分支 C：异常加重或出现风险信号
   ➡️ 系统提示建议尽快就医
   ➡️ 用户选择预约合作医院
   ➡️ 后端生成 pre_visit_package 诊前资料包快照
   ➡️ 诊前资料包包含宠物基础信息、近期正常事实、异常时间线、用户文字、照片附件列表、Agent 文字摘要
   ➡️ 预约单携带 pre_visit_package_id 进入 HIS
   ➡️ HIS 医生工作台展示诊前资料包
   ➡️ 医生接诊、诊断、检查、开药、收费
   ➡️ HIS 发布健康档案版本
   ➡️ App 收到 HIS 回流的医院病历
   ➡️ 病历记录列表出现“由合作医院发布”的医院病历
   ➡️ 病历详情展示诊断摘要、处方/用药、检查报告、复诊建议、附件和来源
   ➡️ App 后续围绕用药反馈、恢复情况、复诊提醒继续追踪
```

### 5.2 节点能力清单

后续开发按这个表逐个节点补齐。每完成一个节点，就在“当前状态”里更新系统已具备的能力。

| 节点 | 当前状态 | 需要补齐 | 验证结论 |
|---|---|---|---|
| 1. 正常事实记录 | 便便正常、精神不错、食欲正常、喂食等记录已具备闭环 | 持续补充更多正常事实类型，例如体重、饮水、睡眠等 | 已验证能力具备 |
| 2. 创建异常记录 | 异常事件结构、照片附件、时间线、详情读取和 Agent 异常事实引用已具备闭环 | 后续扩展更完整的异常详情页和 episode 状态展示 | 已验证能力具备 |
| 3. abnormal_episode | episode 创建、状态更新、详情读取、事件关联和 Agent 只读事实工具已具备闭环 | 后续扩展 episode 状态页、追踪计划和分支策略展示 | 已验证能力具备 |
| 4. Agent 主动追踪计划 | 已具备初始 proactive followup 表、异常创建后默认追踪计划、due_at 到期投影、真实 scheduler 后台任务、追加后下一轮默认重规划、恢复/删除后的取消或 resolve 状态机；Agent workflow skill、runtime task type、同上下文 planning 注入、受控保存 tool 和 application service 保存计划闭环已具备 | 后续补齐后台自动模型 planning job 与首条主动追问自动发文 | 部分验证 |
| 5. 异常更新入口 | 已具备站内轻提醒 actions payload、`更新情况` 自动弹追加 Sheet、`问问毛球` 携带 abnormal episode 上下文并复用同一 Agent 会话和同一 Agent 上下文；Agent 聊天首屏异常卡片已具备；Agent 写回事件已在异常详情、首页时间线、全部时间线显示“毛球更新”标签 | 后续扩展首条主动追问文案和更多 episode 状态展示 | 部分验证 |
| 6. 异常更新落库 | 用户手动追加和 Agent 确认写回均可写入 `health/symptom_followup`，并更新 episode 状态；Agent 来源通过 `event_payload.source=agent_assisted_followup` 和首页 `source_label` 进入前端展示 | 后续补齐 Agent 追加后的动态重规划 | 部分验证 |
| 7. Agent 追问 | 异常事件/episode 事实读取已打通；异常轻提醒进入 Agent 会话的上下文、同 episode 会话复用和同 Agent 上下文复用已打通；用户确认写回 `symptom_followup` 已打通；异常追踪 workflow skill 已能进入模型上下文；模型规划结果保存和首条主动追问落库仍待实现 | 只能基于结构化事实和用户文字追问，不解析照片 | 部分验证 |
| 8. 好转分支 | 待实现 | 降低追踪频率、确认恢复、关闭 episode、保留时间线事实 | 未开始 |
| 9. 持续分支 | 待实现 | 按节奏继续提醒，追问缺失事实，超过窗口进入就医建议 | 未开始 |
| 10. 加重分支 | 待实现 | 风险条件、就医建议、预约合作医院入口 | 未开始 |
| 11. 诊前资料包 | 待设计/实现 | 生成快照，包含事实、文字、附件列表和 Agent 文字摘要 | 未开始 |
| 12. HIS 接收资料包 | HIS Web 目前是占位/Mock 阶段 | 医生工作台展示诊前资料包 | 未开始 |
| 13. HIS 诊疗与发布 | 待实现 | 接诊、诊断、处方、发布健康档案 | 未开始 |
| 14. App 病历回流 | 当前 App 病历仍是 mock 语义 | 接收 HIS 发布版病历，展示来源和详情 | 未开始 |
| 15. 病历后续追踪 | 待实现 | 用药反馈、恢复情况、复诊提醒进入后续闭环 | 未开始 |

### 5.2.1 节点 1：正常事实记录验证记录

当前节点已具备“正常事实进入时间线，并被 Agent 按工具读取为可回答事实”的能力。

| 能力 | 当前结论 | 证据 |
|---|---|---|
| 时间线事实落库 | 已具备 | 主开发库 `pet_events` 已存在 `daily/quick_fact` 与 `daily/feeding` 记录，`event_payload.source=direct_sql_agent_context_random_verification` 用于本轮验证追踪 |
| 健康 quick fact 读取 | 已具备 | Runtime 工具 `load_pet_recent_health_facts` 读取便便正常、精神不错、食欲正常，Tool Gateway 返回 `fact_count=3` |
| 喂食事实读取 | 已具备 | Runtime 工具 `load_pet_current_diet_context` 读取当前饮食与近期喂食，Tool Gateway 返回 `fact_count=5` |
| Agent 工具调用准确性 | 已具备 | 诊断包显示模型首轮同时调用 `load_pet_identity_context`、`load_pet_current_diet_context`、`load_pet_recent_health_facts`、`load_food_inventory_change_hints`，健康 quick fact 工具执行成功 |
| Agent 可读事实上下文 | 已具备 | 最终回答引用了“食欲正常、精神正常平稳、便便健康成型”，并输出“近期健康状况（7月2日记录）” |
| 引用与审计 | 已具备 | SSE citation 包含 `PetEvent` 引用；`answer_completed` 的 `verification_status=passed`，`citation_count=9` |

本节点当前覆盖范围是：便便正常、精神不错、食欲正常、喂食记录。后续扩展体重、饮水、睡眠、用药反馈等正常事实时，应沿用同一模式：`pet_events` 事实账本入库 -> domain/application 读模型 -> provider 事实包 -> Runtime Tool schema -> 合同测试和诊断验证。

### 5.2.2 节点 2：创建异常记录验证记录

当前节点已具备“用户创建异常记录后，异常事件进入事实账本、首页轻提示可打开对应异常详情、照片附件可随事件进入时间线，并可被 Agent 通过异常 episode 事实工具读取”的能力。

| 能力 | 当前结论 | 证据 |
|---|---|---|
| 异常事件落库 | 已具备 | 主开发库 `pet_events` 已存在 `health/abnormal_symptom` 记录：`0d1ea9c8-24b8-4e68-8fe2-8fb31a5418f4`，payload 含 `episode_id`、`symptom_kinds`、`severity`、`attachment_asset_ids` |
| episode 关联 | 已具备 | 主开发库 `abnormal_episodes` 已生成 `fcdd1ada-ac6e-461a-af37-fa4a7e2d640d`，`created_event_id` 指向对应异常事件 |
| 首页轻提示 | 已具备 | 主开发库 `attention_hints` 已生成 active `open_abnormal_episode`；本轮修复后 `route_payload` 同时携带 `episode_id` 和可读取的 `event_id` |
| 详情读取 | 已具备 | 诊断包显示创建后直接读取 `/api/v1/pet-events/0d1ea9c8-24b8-4e68-8fe2-8fb31a5418f4` 返回 200；原点击轻提示 404 的根因是把 `episode_id` 当作 `pet_event_id` 请求，已通过合同测试和客户端路由修复 |
| 照片附件 | 能力具备 | 合同测试 `abnormal_event_attachment_upload_enters_pet_timeline` 验证异常事件附件绑定后进入时间线和详情；本轮主库真实记录未上传照片，因此 `attachment_asset_ids=[]` |
| iOS 路由 | 已具备 | `AttentionHintRoutePayload` 解码 `event_id`，首页异常轻提示优先用 `event_id` 打开 `PetRecordDetailRoute.abnormal` |
| Agent 可读异常事实 | 已具备 | 诊断包显示模型按问题调用 `load_pet_abnormal_episode_facts`，后端通过 episode 聚合父异常事件、追加观察、恢复记录、附件存在性和最近追踪时间进入事实包 |

本节点当前覆盖范围是：异常记录创建、异常事件结构、episode 关联、首页轻提示、时间线/详情读取、照片附件字段闭环，以及 Agent 对异常事件事实的只读引用。异常 episode 的完整状态页、后续更新节奏、恢复/加重分支仍由后续节点继续收敛。

### 5.2.3 节点 3：abnormal_episode 验证记录

当前节点已具备“异常 episode 作为父追踪对象，聚合父异常、追加观察、恢复记录，并进入 Agent 可读事实工具”的能力。

| 能力 | 当前结论 | 证据 |
|---|---|---|
| episode 创建 | 已具备 | 创建 `health/abnormal_symptom` 时后端事务写入 `abnormal_episodes`，并把 `episode_id` 回写到父异常事件 payload |
| 状态更新 | 已具备 | 追加观察写入 `health/symptom_followup` 后更新 `last_observed_at/latest_event_id`；恢复写入 `health/abnormal_recovery` 后更新 `status=recovered/recovered_at/latest_event_id` |
| 事件关联 | 已具备 | 后端按 `event_payload.episode_id` 聚合同 episode 的追加观察、恢复和就诊关联；删除父异常时关闭 episode 并软删子事件，避免孤儿追加观察 |
| Agent 工具 schema | 已具备 | Runtime 注册 `load_pet_abnormal_episode_facts`，scope 为 `pet.abnormal_episode.read`，只读、无需确认，schema 只声明 `health.abnormal_episode.*` |
| Agent 事实读取 | 已具备 | 合同测试 `ai_chat_stream_loads_abnormal_episode_facts_without_quick_fact_payload` 验证 Agent 工具读取父异常、追加观察、恢复、附件存在性和最近追踪时间 |
| 诊断包验证 | 已具备 | 最新导出诊断包显示模型在异常相关私域问题中调用 `load_pet_abnormal_episode_facts`；该工具调用与 `load_pet_recent_health_facts` 分工明确，异常事实和近期 quick facts 分别进入 Agent 上下文 |
| 单一职责边界 | 已具备 | `load_pet_abnormal_episode_facts` 不返回便便、精神、食欲 quick facts；近期健康 quick facts 继续由 `load_pet_recent_health_facts` 提供，Runtime 按问题组合调用 |

本节点当前覆盖范围是：episode 父对象、状态、父子事件聚合、附件存在性、Agent 只读事实工具、合同测试和诊断包验证。后续延迟追踪计划、好转/持续/加重分支、诊前资料包仍在后续节点实现。

### 5.3 Agent 主动追踪与站内轻提醒目标文档

- 更新时间：2026-07-06
- Goal：用户创建或更新异常后，系统自动生成 Agent 主动追踪计划；到期后首页出现可操作的站内轻提醒；用户可直接更新异常或进入毛球会话；用户确认后的反馈写回异常进展事实。
- 执行方式：按后端契约、Agent skill、受控 tool、调度器、iOS UI 五个切片推进；每个切片先补合同测试或状态源测试，再接生产代码。

#### 5.3.0 当前结论

| 项 | 结论 |
|---|---|
| 主动追踪触发 | 异常创建、追加观察、恢复/关闭这些明确业务事件触发后台 planning。 |
| Agent 参与方式 | Agent 负责理解异常、生成追踪策略、组织追问文案和判断下一步追踪方向。 |
| Tool 参与方式 | Tool 负责受控读取事实、提交经校验/确认的写入意图，不承载隐藏业务策略。 |
| 调度方式 | 调度器只按 `agent_proactive_followups.due_at` 执行到期投影，生成站内 `attention_hints`。 |
| 首页交互 | 轻提醒展示 `更新情况`、`问问毛球` 两个文字按钮，通过 payload actions 驱动路由。 |
| 事实账本 | Agent 追问本身不进入病情事实；用户确认后的追加观察才写入 `pet_events.health/symptom_followup`。 |

#### 5.3.0.1 当前落地状态

| 能力 | 当前结论 | 证据 |
|---|---|---|
| 追踪计划模型 | 已具备 | 迁移 `0048_agent_proactive_followups.sql` 新增 `agent_proactive_followups`，并在 `abnormal_episodes` 上保存 `next_followup_due_at/last_followup_plan_id` |
| 异常创建触发计划 | 已具备默认计划 | 创建 `health/abnormal_symptom` 时事务写入初始 scheduled followup；合同测试 `abnormal_creation_creates_initial_agent_followup_plan` 已通过 |
| 到期站内轻提醒 | 已具备 | SQL 函数 `project_due_agent_proactive_followups(now_at)` 生成 `abnormal_followup_due`，payload 含 `更新情况/问问毛球` actions；合同测试 `due_agent_followup_creates_actionable_abnormal_followup_hint` 已通过 |
| 真实 scheduler 后台任务 | 已具备 | 后端启动入口启动 `agent_followup_scheduler` 周期任务，调用 `run_once` 执行 due plan 投影；合同测试 `scheduler_run_once_projects_due_agent_followup_hint` 已通过 |
| 未到期过滤 | 已具备 | dashboard 只读取 active 且 display window 生效的 hints；合同测试 `future_agent_followup_does_not_show_before_due_at` 已通过 |
| 用户追加后的 resolve | 已具备 | 写入 `symptom_followup` 后 proactive followup 变为 `answered`，对应 active hint 被 resolved；合同测试 `symptom_followup_resolves_due_agent_followup_hint` 已通过 |
| 用户追加后的重规划 | 已具备默认计划 | 写入 `symptom_followup` 后后端事务创建下一轮 scheduled followup，并回写 episode `next_followup_due_at/last_followup_plan_id`；合同测试 `symptom_followup_creates_next_agent_followup_plan` 已通过 |
| 首页 `更新情况` | 已具备 | iOS 解码 actions payload，push 异常详情并通过 `opensFollowupSheet` 自动弹追加观察 Sheet；真机构建和安装已通过 |
| 首页 `问问毛球` | 已具备上下文传递 | iOS 将 `abnormal_episode_id/source_hint_id/agent_followup_id` 传入 AI chat request；后端持久化到 `ai_chat_sessions` |
| 同 episode 会话复用 | 已具备 | `find_active_abnormal_episode_session` 让同一 abnormal episode 的第二轮轻提醒进入同一 AI session；session 冲突更新会刷新当前 `source_hint_id/agent_followup_id`，避免只复用聊天壳但恢复旧追踪轮次；合同测试 `abnormal_followup_entry_reuses_same_agent_session_and_context` 已通过 |
| 同 Agent 上下文复用 | 已具备 | 后端 `ChatTurnContext` 从已复用 session 合并 `chat_context_kind/abnormal_episode_id/source_hint_id/agent_followup_id`，并注入 Runtime `AiToolContext.observation_write_context`；合同测试 `abnormal_followup_second_turn_restores_agent_context_from_session` 验证第二轮只带 `chat_session_id` 时写入工具仍能拿到当前 episode/followup 上下文 |
| Agent workflow skill 动态 planning 入口 | 已具备 | 新增 `TaskType::AbnormalEpisodeFollowupPlanning`、`workflow.abnormal_episode_proactive_followup_planning`，Runtime 从恢复后的 `ObservationWriteContext` 派生该 task type；合同测试 `abnormal_episode_followup_planning_comes_from_runtime_context_not_user_text`、`builtin_runtime_matches_abnormal_episode_proactive_followup_planning_skill` 已通过 |
| Agent planning 上下文不丢 | 已具备 | 同一 abnormal episode 第二轮只带 `chat_session_id` 时，后端从 session 恢复异常追踪上下文并向 provider 请求注入“异常主动追踪 planning”workflow 指令；合同测试 `abnormal_followup_second_turn_restores_agent_context_from_session` 已加断言覆盖 |
| Agent planning 保存 tool | 已具备 | 新增 Runtime tool `save_abnormal_episode_followup_plan`，模型只提交 `due_at/message_title/message_body/rationale/recommended_actions`；`episode_id/agent_followup_id` 只能从后端恢复的 `ObservationWriteContext` 获取；合同测试 `abnormal_followup_agent_can_save_planned_followup_from_session_context` 已通过 |
| Agent planning 保存 service | 已具备 | `AbnormalFollowupPlanProvider` 调用 `PetService::save_agent_followup_plan`，application service 校验授权、文案长度和推荐动作，repository 更新 `agent_proactive_followups.status=scheduled` 并回写 `abnormal_episodes.next_followup_due_at/last_followup_plan_id` |
| 受控后台写入策略 | 已具备 | `PolicyGuard` 对 `save_abnormal_episode_followup_plan` 做精确放行，保持一般写工具仍需确认；合同测试 `policy_guard_allows_abnormal_followup_plan_tool_without_confirmation` 已通过 |
| Agent 聊天首屏异常卡片 | 已具备 | iOS `AIAssistantStore.abnormalEpisodeContextCard` 从 `AIAssistantEntryContext.abnormalEpisodeID` 派生首屏卡片，`AIAssistantMessageTimeline` 在消息前展示；测试 `testAbnormalEpisodeEntryExposesContextCard` 和 `testDefaultEntryDoesNotExposeAbnormalEpisodeContextCard` 覆盖入口差异 |
| Agent 确认写回 | 已具备 | `prepare_pet_observation_write` 在 `abnormal_episode_followup` 上下文中创建 `symptom_followup` 确认任务，用户确认后 `commit_pet_observation_write` 写入带 `episode_id/source/agent_followup_id` 的 `pet_events.health/symptom_followup`；合同测试 `abnormal_followup_agent_confirmed_write_keeps_episode_context` 已通过 |
| Agent 写回来源标签 | 已具备 | 后端首页摘要对 `event_payload.source=agent_assisted_followup` 输出 `source_label=毛球更新`；iOS 异常详情、首页时间线、全部时间线均展示“毛球更新”；合同测试 `home_dashboard_followup_timeline_routes_to_parent_abnormal_event` 和 iOS `HomeDashboardDecodingTests` 已通过 |

当前已具备 Agent workflow skill 的动态 planning 入口、同 Agent 上下文恢复、模型计划草稿受控保存 tool、application service 校验保存 `agent_proactive_followups`、episode 下一轮计划投影回写能力。后续切片聚焦后台自动模型 planning job、首条主动追问自动发文，以及用动态规划替换现有默认计划文案与节奏。

#### 5.3.1 目标边界

| 本目标期必须完成 | 验收结果 |
|---|---|
| `agent_proactive_followups` 追踪计划模型 | 能保存 planning/scheduled/due/answered/resolved/cancelled/expired 状态和审计字段 |
| 到期投影 | due plan 能生成 `attention_hints.kind=abnormal_followup_due`，并带 actions payload |
| 首页轻提醒 actions | `更新情况` push 异常详情并自动弹追加观察 Sheet；`问问毛球` push Agent 聊天并携带 episode 上下文 |
| 用户更新后的状态机 | 追加观察后 resolve 当前 hint/followup，并触发下一轮 planning 或结束追踪 |
| Agent 聊天写回 | Agent 根据用户自然语言生成待确认追加观察，用户确认后调用写入 tool |
| 标签展示 | Agent 聊天归纳并确认写回的追加观察，在异常详情、首页时间线、全部时间线显示“毛球更新” |

| 本目标期暂不做 | 原因 |
|---|---|
| 图片理解 / OCR / 多模态 | 第一期 Agent 只基于结构化事实和用户文字工作 |
| APNs 外部推送 | 先闭环站内轻提醒，后续 Notification 模块复用同一 due plan |
| 医疗诊断自动化 | Agent 只做观察建议、追问和诊前摘要，不替代医生诊断 |
| 完整 HIS 对接 | 本目标只产出异常追踪事实，HIS 资料包在后续节点实现 |

#### 5.3.2 主数据流

```text
用户创建异常
-> 写入 pet_events: health/abnormal_symptom
-> 创建 abnormal_episode
-> 投递 Agent 后台 planning job
-> Agent 读取异常、近期健康、饮食和储物柜弱线索
-> Agent 输出 due_at、追问文案、规划理由和推荐动作
-> 后端保存 agent_proactive_followup
-> 调度器到 due_at 生成/激活 abnormal_followup_due attention_hint
-> 首页展示毛球主动追问轻提醒
-> 用户选择“更新情况”或“问问毛球”
-> 用户在结构化入口提交，或在 Agent 会话中反馈并确认写回
-> 后端写入 symptom_followup 或关闭 episode
-> 后端 resolve 当前轻提醒并触发下一轮 planning 或归档
```

| 步骤 | 责任层 | 产物 |
|---|---|---|
| 异常事件落库 | Pet application / infrastructure | `pet_events.health/abnormal_symptom` |
| episode 创建 | Pet application / infrastructure | `abnormal_episodes.status=open` |
| Agent planning 触发 | Application job | `agent_proactive_followups.status=planning` 或后台任务 |
| 上下文读取 | Agent tools | `load_pet_abnormal_episode_facts`、`load_pet_recent_health_facts`、饮食/储物柜线索工具 |
| 追踪计划生成 | Agent skill | 已具备 workflow skill 入口；目标输出为 `due_at`、追问文案、规划理由、推荐动作 |
| 计划保存 | Tool + Application service | 已具备 `save_abnormal_episode_followup_plan` 受控保存 tool；application service 校验后写 `agent_proactive_followups.status=scheduled`，episode 写 `next_followup_due_at/last_followup_plan_id` |
| 到期触发 | Scheduler | `attention_hints.kind=abnormal_followup_due` |
| 用户响应 | iOS + Pet API / Agent chat | 追加观察、Agent 聊天反馈确认写回或关闭 episode |
| Agent 写回 | Runtime tool + Pet application service | `pet_events.health/symptom_followup`，payload 带 `episode_id/source=agent_assisted_followup/agent_followup_id` |
| 重规划/归档 | Application job + Agent skill | 下一次计划，或取消待办并终止追踪 |

#### 5.3.3 站内轻提醒 UI 目标

异常追踪轻提醒从“点击查看”升级为可操作的站内追问。UI 仍保持首页整体轻量风格，只使用文字按钮，不增加描边按钮或卡片内复杂控件。

| 区域 | 目标 |
|---|---|
| 标题 | 使用 Agent 追问语气，例如“毛球想确认一下” |
| 正文 | 使用 Agent 生成文案，例如“梅录早上记录了拉肚子，已经 6 小时了。现在便便、精神和食欲有好转吗？” |
| 主按钮 | `更新情况`，强调色文字，进入异常详情并自动弹出追加异常 Sheet |
| 次按钮 | `问问毛球`，次级文字色，进入 Agent 聊天页并携带 abnormal episode 上下文 |
| 样式边界 | 保持文字按钮；通过颜色区分主次；不做边框、不做额外卡片嵌套 |

轻提醒 payload 需要由后端提供动作语义，前端只做渲染和路由：

```json
{
  "episode_id": "...",
  "event_id": "...",
  "agent_followup_id": "...",
  "default_action": "update_observation",
  "actions": [
    {
      "id": "update_observation",
      "title": "更新情况",
      "route_kind": "abnormal_detail",
      "presentation": {
        "auto_open_sheet": "abnormal_followup"
      }
    },
    {
      "id": "chat_with_agent",
      "title": "问问毛球",
      "route_kind": "ai_chat",
      "chat_context": {
        "kind": "abnormal_episode_followup",
        "episode_id": "...",
        "source_hint_id": "...",
        "agent_followup_id": "..."
      }
    }
  ]
}
```

#### 5.3.4 `agent_proactive_followups` 目标模型

`attention_hints` 只承载首页当前可见待处理信号，不承载完整 Agent 追踪规划历史。Agent 主动追踪计划需要独立模型保存，便于重规划、取消、过期和审计。

| 字段 | 说明 |
|---|---|
| `id` | 追踪计划 ID |
| `pet_id` / `episode_id` | 绑定宠物和异常 episode |
| `trigger_event_id` | 触发本轮规划的异常/追加/恢复事件 |
| `source_turn_id` | 后台 Agent planning 会话或 turn |
| `status` | `planning/scheduled/due/answered/resolved/cancelled/expired` |
| `due_at` | 调度器生成站内轻提醒的时间 |
| `message_title` / `message_body` | 首页轻提醒展示文案 |
| `rationale` | Agent 给系统的规划理由，默认不直接展示 |
| `recommended_actions` | `update_observation/chat_with_agent/view_detail` 等动作 |
| `created_at/updated_at/resolved_at` | 审计字段 |

#### 5.3.5 Skill、Tool、Scheduler 与 Application 边界

Agent 能力拆分必须保持“skill 负责理解和流程策略，tool 负责受控读写，调度器负责时间执行”。不能把数据库写入、定时扫描或状态终止塞进 prompt，也不能把跨步推理写成单个工具的隐藏副作用。

| 类型 | 什么时候创建 | 职责 | 禁止承担 |
|---|---|---|---|
| Agent skill | 需要多步理解、追问策略、规划规则、跨 turn 一致行为、自然语言归纳时 | 异常追踪 planning、首条追问生成、根据用户反馈决定继续观察/建议就医/结束追踪、把自然语言整理成待确认追加观察 | 直接写数据库、定时调度、绕过工具读取事实、把未确认用户话术写成事实 |
| Agent tool | Agent 需要访问系统事实或执行受控副作用时 | 读取 episode facts、读取 quick facts、读取饮食/储物柜线索、提交经用户确认的追加观察、提交追踪计划结果 | 自行决定追踪节奏、隐藏多步业务策略、替代 skill 推理、返回和职责无关的综合摘要 |
| Scheduler | 需要按时间触发系统动作时 | 扫描 `agent_proactive_followups.due_at`，生成/激活站内 `attention_hints` | 生成医疗建议、理解异常内容、改写 Agent 文案 |
| Application service | 需要保证事务一致性和状态机时 | 创建 episode、保存计划、resolve hint、cancel plans、关闭/归档 episode | 把模型输出当作无校验事实直接入库 |

##### 5.3.5.1 什么时候给 Agent 创建 Skill

| 触发条件 | 说明 | 本目标例子 |
|---|---|---|
| 需要组合多个事实源形成判断 | 事实来自多个 tool，结论需要模型理解和权衡 | 根据异常、近期便便/精神/食欲、饮食和储物柜线索判断追问时间 |
| 需要多轮一致策略 | 同一 episode 的追问节奏需要跨创建、追加、关闭保持一致 | 第一次 6 小时追问，用户追加后决定 12 小时后追问或建议就医 |
| 需要自然语言生成 | 需要生成用户可读文案、追问语气或待确认草稿 | “毛球看到早上拉肚子已经 6 小时了，现在精神和食欲怎么样？” |
| 需要医疗边界判断 | 需要把建议限制在观察/就医建议范围 | 出现血便、拒食、精神明显变差时建议就医 |
| 需要把用户自由表达归纳成结构化草稿 | 用户在聊天中描述，系统需要生成待确认写入内容 | “还是拉稀，没昨天活泼”归纳成便便异常、精神下降、备注草稿 |

Skill 的输出必须是规划或草稿，不是最终事实。写入事实前必须经过 application service 校验；涉及用户新反馈时必须经过用户确认。

##### 5.3.5.2 什么时候给 Agent 创建 Tool

| 触发条件 | 说明 | 本目标例子 |
|---|---|---|
| 需要读取受权限约束的系统事实 | 返回结构化事实，schema 可审计 | `load_pet_abnormal_episode_facts`、`load_pet_recent_health_facts` |
| 需要执行受控写入 | 输入字段明确、权限明确、可验证、可回滚或可审计 | 提交用户确认后的 `symptom_followup` |
| 需要把模型输出交给后端校验入库 | Tool 只传递候选结果，后端负责约束和状态机 | 保存 `agent_proactive_followup` 的 `due_at/message/rationale/actions` |
| 需要对外暴露稳定能力给 Runtime | 工具 schema、scope、确认策略、失败语义稳定 | `pet.abnormal_episode.read`、`pet.health_fact.read`、`pet.abnormal_followup.write` |

Tool 输出应保持事实型和结构化。已有专门 tool 能返回近期便便、精神、食欲 quick facts 时，异常 episode tool 不重复返回 quick facts 摘要；planning skill 需要这些事实时，显式调用 `load_pet_recent_health_facts`。需要“摘要”时由 skill 基于多个 tool 的结果生成，避免把推理藏进读取 tool。

##### 5.3.5.3 边界判定表

| 能力 | 归属 |
|---|---|
| 判断“拉肚子明显，6 小时后询问便便/精神/食欲是否好转” | Agent skill |
| 读取该 episode 的父异常、追加观察、恢复、附件存在性 | Tool：`load_pet_abnormal_episode_facts` |
| 读取便便、精神、食欲近期 quick facts | Tool：`load_pet_recent_health_facts` |
| 读取当前饮食和储物柜弱线索 | Tool：饮食 / food inventory hint 工具 |
| 保存 Agent 规划结果 | Tool 提交候选计划，Application service 校验并入库 |
| 到 `due_at` 出现首页轻提醒 | Scheduler |
| 用户聊天反馈后写入 `symptom_followup` | Tool：需用户确认的写入工具，Application service 写事实账本 |
| 用户关闭异常后取消待提醒 | Application service 事务内完成 |
| 将 Agent 归纳后的追加观察打“毛球更新”标签 | Application service 写入来源字段，iOS 按来源渲染 |
| 第二轮轻提醒再次进入聊天 | 后端复用同一个 `ai_chat_sessions.id`，并从 session 恢复同一个 abnormal episode Agent 上下文 |

#### 5.3.6 用户响应后的状态处理

| 用户动作 | 后端处理 | Agent 后续 |
|---|---|---|
| 点击“更新情况”并提交追加观察 | 写 `health/symptom_followup`，更新 episode `last_observed_at/latest_event_id`，resolve 当前 hint/followup | 基于新事实重新 planning |
| 点击“问问毛球”并进入聊天 | 创建/打开 `abnormal_episode_followup` 会话，首屏展示异常卡片和 Agent 追问 | 用户反馈后，Agent 生成待确认追加观察；确认后写入 |
| 标记“已经好了” | 写 `health/abnormal_recovery`，episode `status=recovered` | 取消所有未到期/已到期追踪计划，保留历史供 HIS 参考 |
| 选择“不再追踪” | episode `status=closed_by_user`，写关闭原因 | 停止提醒；诊前资料包标记用户停止追踪 |
| 选择“误记/无效” | episode `status=voided/cancelled` | 停止提醒；诊前摘要默认低权重或排除 |

Agent 轻提醒本身不是病情事实，不进入异常进展时间线。只有用户反馈并确认后写入的 `symptom_followup` 才成为事实账本事件。经 Agent 聊天归纳并由用户确认写入的追加观察，在异常详情进展时间线、首页事件线和全部时间线中统一显示“毛球更新”标签。

同一个 abnormal episode 的 Agent 追踪上下文必须由后端 session 保持。验收标准不是只复用聊天会话 ID，而是同一 `ai_chat_sessions.id` 继续保留 `chat_context_kind=abnormal_episode_followup`、`abnormal_episode_id`，并在用户从新一轮轻提醒再次进入时刷新当前 `source_hint_id/agent_followup_id`。后续 turn 和 Runtime tool 执行都必须从该 session 恢复上下文：episode 级上下文保持同一个，当前追踪轮次上下文保持最新。前端可以携带入口上下文，但后端写入工具不能依赖模型或前端在每次工具调用中重新传 episode。

#### 5.3.7 TDD 任务拆分

| Task | 目标 | 先写失败测试 | 允许修改 | 最小绿灯命令 |
|---|---|---|---|---|
| Task 1：追踪计划模型和到期投影 | due plan 生成 actionable hint，追加/恢复/删除能 resolve 或 cancel | `maohuoban-rust/tests/pet_contract/agent_proactive_followup.rs` | pet infrastructure repository、migration、test support | `cargo test -p maohuoban_rust --test pet_contract agent_proactive_followup -- --nocapture` |
| Task 2：异常事件触发后台 planning | 创建/追加/关闭异常后产生 planning job 或计划意图 | pet application 合同测试 | pet application use case、job port、repository port | 对应 pet contract / application test |
| Task 3：Agent proactive followup skill | skill 能在异常追踪 runtime context 中注入 planning 指令，优先使用异常、quick facts、饮食/储物柜 tool，并保持同 session 同 Agent 上下文 | AI application/runtime 合同测试 | AI skill registry、runtime tool policy、planner prompt/contract | `cargo test -p maohuoban-ai-application --test planning_contract abnormal_episode_followup -- --nocapture` 和 `cargo test -p maohuoban-ai-application --test skill_runtime_contract builtin_runtime_matches_abnormal_episode_proactive_followup_planning_skill -- --nocapture` |
| Task 3.1：Agent planning 保存 tool | 模型输出计划草稿后，经受控 tool 和 application service 校验保存为 scheduled followup；第二轮只带 `chat_session_id` 时仍从同一 Agent 上下文恢复 episode/followup 归属 | AI contract + PolicyGuard 合同测试 | AI tool schema、planning save port、application service、repository、PolicyGuard 精确放行 | `cargo test --test ai_contract abnormal_followup_agent_can_save_planned_followup_from_session_context -- --nocapture --test-threads=1`；`cargo test -p maohuoban-ai-application --test policy_guard policy_guard_allows_abnormal_followup_plan_tool_without_confirmation -- --nocapture` |
| Task 4：调度器执行 | 到期计划被投影为 `abnormal_followup_due`，未到期计划不展示 | scheduler / repository 合同测试 | scheduler job、projection repository | scheduler 最小测试命令 |
| Task 5：首页 actions UI | 两个文字按钮按 payload 路由，旧 hint 仍可查看 | iOS 状态源或 ViewModel 测试 | Home dashboard models、attention hint section、route | iOS Debug 真机构建 |
| Task 6：Agent 聊天上下文和写回 | `问问毛球` 携带 episode context，复用同一 Agent 上下文；同 episode 第二轮轻提醒继续进入同一 session，同时刷新当前 `source_hint_id/agent_followup_id`；用户确认后写 `symptom_followup` 并显示“毛球更新” | AI chat contract + pet timeline 来源测试 | AI entry context、chat request DTO、write tool、timeline presentation | Rust contract + iOS Debug 真机构建 |

每个 Task 完成时必须记录三类证据：失败测试红灯、最小绿灯命令、必要的 Debug 构建或合同测试结果。测试未按预期失败、实现需要跨越目标边界、工具和 skill 职责混淆时停止并回到本文更新边界。

#### 5.3.8 验收门禁

| 类型 | 命令 / 验收 |
|---|---|
| Rust 格式 | `cargo fmt --all --check` |
| Rust 编译 | `cargo check --workspace --all-targets` |
| 后端主动追踪合同 | `cargo test -p maohuoban_rust --test pet_contract agent_proactive_followup -- --nocapture --test-threads=1` |
| Agent 会话上下文合同 | `cargo test -p maohuoban_rust --test ai_contract abnormal_followup_entry -- --nocapture --test-threads=1`；`cargo test -p maohuoban_rust --test ai_contract abnormal_followup_entry_reuses_same_agent_session_and_context -- --nocapture --test-threads=1` |
| Agent 上下文恢复合同 | `cargo test -p maohuoban_rust --test ai_contract abnormal_followup_second_turn_restores_agent_context_from_session -- --nocapture` |
| Agent 确认写回合同 | `cargo test -p maohuoban_rust --test ai_contract abnormal_followup_agent_confirmed_write_keeps_episode_context -- --nocapture --test-threads=1` |
| Agent skill 合同 | 覆盖 tool 调用组合、计划 JSON、医疗边界、无图片理解 |
| Agent planning skill 入口合同 | `cargo test -p maohuoban-ai-application --test planning_contract abnormal_episode_followup -- --nocapture`；`cargo test -p maohuoban-ai-application --test skill_runtime_contract builtin_runtime_matches_abnormal_episode_proactive_followup_planning_skill -- --nocapture` |
| 同 Agent 上下文注入合同 | `cargo test -p maohuoban_rust --test ai_contract abnormal_followup_second_turn_restores_agent_context_from_session -- --nocapture --test-threads=1`，provider 请求必须包含“异常主动追踪 planning”workflow 指令 |
| Agent planning 保存合同 | `cargo test -p maohuoban_rust --test ai_contract abnormal_followup_agent_can_save_planned_followup_from_session_context -- --nocapture --test-threads=1`，模型 tool call 不携带 episode/followup 归属，后端从 session context 保存 scheduled followup 并回写 episode |
| Agent planning tool 策略合同 | `cargo test -p maohuoban-ai-application --test policy_guard policy_guard_allows_abnormal_followup_plan_tool_without_confirmation -- --nocapture`，只放行 `save_abnormal_episode_followup_plan` 这类受控后台规划写入，一般写工具仍按确认策略 |
| iOS 构建 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'id=<当前连接真机设备ID>' -configuration Debug build` |
| iOS 安装 | `xcrun devicectl device install app --device <当前连接真机设备ID> ~/Library/Developer/Xcode/DerivedData/maohuoban-*/Build/Products/Debug-iphoneos/maohuoban.app` |
| 手动验收 | 创建异常 -> 到期轻提醒 -> `更新情况` 自动弹 Sheet -> 写入追加观察 -> hint 消失 -> 下一轮 planning 或归档 |
| 诊断包验收 | 异常相关 Agent 回答能调用 `load_pet_abnormal_episode_facts`；需要近期便便/精神/食欲时另行调用 `load_pet_recent_health_facts`；资料卡调用仍由模型选择和安全 gate 控制 |

#### 5.3.9 不变约束

| 约束 | 说明 |
|---|---|
| 单一事实源 | 病情事实只来自 `pet_events` 和 episode 聚合，轻提醒只是待处理信号 |
| Tool schema 收敛 | 读取工具只返回职责内事实；写入工具必须有权限、确认和后端校验 |
| Agent 上下文不丢 | 同 episode 后续轻提醒和确认写回必须复用同一 `ai_chat_sessions.id` 及其 abnormal episode context；新一轮轻提醒入口必须刷新 session 内当前 `source_hint_id/agent_followup_id`；Runtime planning 和 provider 请求也必须从该 context 注入异常追踪 workflow skill |
| Skill 不写库 | Skill 输出规划、建议、草稿；数据库状态由 application service 和 repository 负责 |
| Scheduler 不推理 | Scheduler 只看时间和状态，不生成医疗文案 |
| 照片只作附件 | 附件只作为原始材料和存在性事实，不参与 Agent 图片理解 |
| 删除父异常清理子关系 | 删除父异常时取消计划、resolve hint、软删或归档子观察，避免孤儿上下文 |

#### 5.3.10 本目标期验收场景

```text
08:10 用户创建“拉肚子，明显”异常
-> 后端写异常事件和 abnormal_episode
-> 后台 Agent planning 读取异常、近期健康、饮食和储物柜线索
-> Agent 计划 14:10 追问，并生成首页轻提醒文案
-> 14:10 调度器生成 abnormal_followup_due 站内轻提醒
-> 首页展示“更新情况”和“问问毛球”两个文字按钮
-> 用户点“更新情况”
-> App push 异常详情并自动弹追加异常 Sheet
-> 用户提交“便便仍稀，精神一般，食欲下降”
-> 后端写 symptom_followup，resolve 当前轻提醒
-> 后台 Agent 根据新事实决定下一次追踪时间或建议就医
```

本目标期不做图片理解，不做 APNs 外部推送，不让 Agent 根据照片生成病情判断。

### 5.4 第一轮验证场景

第一轮只跑一个最简单病例：

```text
第 1-3 天：用户记录便便正常、精神不错、食欲正常
➡️ 第 4 天：用户创建“拉肚子”异常，严重程度选择“明显”，填写文字备注并上传 1 张照片
➡️ 系统 4-6 小时后提醒用户更新异常情况
➡️ 用户更新：无变化，食欲下降，精神一般
➡️ Agent 基于事实追问：是否持续水样便、是否频繁、是否换粮、是否饮水减少
➡️ 用户补充文字：今天已经 3 次，没换粮
➡️ 系统判断异常持续且食欲/精神下降
➡️ App 提示预约合作医院
➡️ 用户预约
➡️ 系统生成诊前资料包
➡️ HIS mock 页面显示诊前资料包
➡️ HIS mock 发布医院病历
➡️ App 病历记录出现回流病历
```

第一轮不处理慢性病、不处理外院资料、不处理 OCR、不处理图片识别、不处理真实处方收费。

### 5.5 节点更新格式

每完成一个流程节点，在本文中按以下格式更新：

```text
节点 N：节点名称
当前状态：已完成 / 部分完成 / 未开始
已具备能力：...
缺失能力：...
下一步：...
验证方式：...
```

---

## 6. 推荐最小闭环

当前不建议同时做完整 HIS、提醒、异常、Agent 和病历回流。建议拆成可理解的链路：

```text
异常记录
-> 异常追踪
-> 生成诊前资料包
-> HIS 接收资料包
-> 医院病历回流 App
```

### 6.1 推荐先落地顺序

| 顺序 | 范围 | 原因 |
|---|---|---|
| 1 | 异常追踪详情和异常更新闭环 | 这是诊前包的数据源头 |
| 2 | App 病历语义调整 | 先移除“用户创建病历”的误导 |
| 3 | 诊前资料包模型和预览 | 让用户和医生看到同一份事实摘要 |
| 4 | HIS Web 接收诊前包 mock | 先跑通医生侧工作台入口 |
| 5 | HIS 发布病历回流 App | 完成医院病历闭环 |
| 6 | Reminder / Notification 独立模块 | 在提醒边界明确后独立建设 |

### 6.2 暂时不做

| 暂不做 | 原因 |
|---|---|
| 用户手动创建结构化病历 | 容易把医生职责转移给用户 |
| Agent 自动生成医生诊断 | 医疗边界错误 |
| OCR / 多模态识别报告照片 | 第一期 LLM 提供商不支持多模态，OCR 成本后置 |
| 从照片提取化验指标或药品名 | 输入不可靠，医疗风险高 |
| App 从日历反推提醒状态 | 数据源错误 |
| HIS 原始病历直接回流 App | 破坏医院数据与内部备注边界 |
| 一次性完成完整 HIS | 范围过大，容易失控 |

---

## 7. 待决策问题

| 问题 | 候选方向 |
|---|---|
| App 病历入口名称 | “医院病历” / “就医记录” / “健康档案” |
| 非合作医院资料入口 | “上传就医资料”是否放在病历列表底部 CTA |
| 异常更新默认入口 | 先进入结构化 Sheet，还是先进入 Agent 聊天 |
| Agent 提醒节奏 | 按严重程度固定规则，还是规则 + Agent 动态调整 |
| 诊前资料包触发 | 用户点击预约时生成，还是异常升级时提前生成草稿 |
| HIS 回流范围 | 第一版只回流诊断摘要、处方、复诊建议，还是包含检查报告附件 |
| 提醒提前策略 | 单个提前时间，还是轻提醒/标准提醒/重要提醒策略 |

---

## 8. 当前推荐一句话

用户记录异常和文字观察，上传相关照片作为原始附件；Agent 基于宠物事实和用户文字主动追问、建议观察或就医，并生成仅供医生参考的诊前文字摘要；医院诊疗后把发布版病历回流到 App；提醒是业务计划，通知是触达执行，系统日历只是用户主动开启的镜像。
