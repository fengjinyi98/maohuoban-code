# 毛球Agent意图规划Skill记忆上下文与工具系统目标文档

- 更新时间：2026-06-30
- Goal：回答毛球 Agent 在意图理解、任务拆解、skill 分层、长短期记忆、动态上下文、压缩阈值、检索系统、工具调用系统和核心模块拆分上的底层设计问题，并给出毛球对应模块边界
- 执行方式：问题驱动的底层协议文档；先收敛模型与系统职责，再进入后续实现

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 当前文档角色 | 这是 `01` 主链路文档的下钻文档，回答“链路内部怎么工作” |
| 任务理解本质 | Agent 不应该直接从用户一句话跳到执行；中间必须经过意图判定、上下文装配、能力筛选、计划推进 |
| Skill 本质 | skill 不是工具本身，而是“可复用的高层执行模板 / 领域操作剧本 / 规则包” |
| 记忆本质 | 记忆不是“什么都存”，而是“只把未来有复用价值、可验证、可隔离的信息进入对应层级” |
| Prompt 本质 | 静态 prompt 定义长期不变规则；动态 prompt 负责把本轮用户、宠物、会话、记忆、工具边界拼进去 |
| 压缩本质 | 压缩不是为了省一点 token，而是为了保持上下文质量，避免历史把当前轮污染掉 |
| 检索本质 | 检索系统必须是“先过滤 scope，再决定召回，再裁剪注入”，而不是一股脑语义搜全库 |
| 毛球当前现状 | 已经有 `AiIntentGate`、`TurnContextBuilder`、`MemoryRetriever`、`ToolRegistry`、`PolicyGuard`、`EvidencePlanner`、`ContextBudgetPolicy` 等雏形 |
| 现阶段重点 | 先把这些雏形提升成正式协议层，不引入兜底兼容 |

## 2. 目标边界

### 2.1 本目标期必须回答

| 范围 | 目标 |
|---|---|
| 意图理解 | 用户输入进来后，Agent 如何理解目标、归类意图、决定是否进入主流程 |
| 任务拆解 | Agent 如何把用户需求拆成步骤，并决定先后顺序 |
| 模型 vs 工具 | 什么时候该继续问模型，什么时候该调用工具 |
| Skill 匹配与分层 | skill 如何匹配、为什么要分层、各层职责是什么 |
| Skill 沉淀机制 | 哪些能系统自动沉淀，哪些必须人工确认或后续扩展 |
| 长短期记忆 | 各保存什么，为什么要分层 |
| 长期记忆膨胀治理 | 怎样防止越存越多、越存越脏 |
| 记忆召回 | 怎样决定召回哪些记忆，以及怎样避免上下文污染 |
| 动态上下文 | 静态 prompt、动态 prompt、上下文组件如何组装 |
| 上下文预算与压缩 | 多大触发压缩，如何裁剪，谁负责 |
| 核心模块拆分 | Agent 系统应该拆成哪些模块，各管什么 |
| 检索与工具系统 | 检索系统、工具注册与调用系统应该怎样设计，并对应到毛球当前架构 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 用户自定义 skill 平台 | 这是后续能力开放问题，不是当前底层协议问题 |
| 自动让用户编排毛球推送 skill | 属于后续产品化扩展，不进入本期底层实现 |
| 完整多 agent 编排器 | 当前先把单 agent runtime 的协议层稳定住 |
| 向量数据库最终选型细节 | 本文只定义检索设计原则，具体实现以后续 `pgvector` 合同文档为准 |

## 3. 问题与答案

### 3.1 用户输入一个需求以后，Agent 如何理解用户意图并进行任务拆解

| 问题 | 结论 |
|---|---|
| 怎么理解用户意图 | 先做轻量意图分类，决定是否进入主 Agent、是否加载私域上下文、是否只走轻量回复 |
| 怎么拆解任务 | 不是所有请求都需要显式 planner。只有跨多步、跨工具、跨状态变更的任务才进入任务拆解 |
| 毛球当前对应 | `AiIntentGate` 已经承担入口意图闸门；后续需要独立出 `Task Planner Contract` |

推荐链路：

```text
用户输入
  -> Intent Gate
  -> 判断领域 / 风险 / 私域上下文需求
  -> 若是简单问答，直接进入 Runtime
  -> 若是多步任务，生成 Task Plan
  -> Task Plan 分解为若干 Step
```

毛球上的意图层级：

| 层级 | 说明 | 毛球示例 |
|---|---|---|
| `direct_answer` | 仅靠当前上下文即可回答 | “猫拉肚子一般要观察什么” |
| `context_answer` | 需要私域上下文或最近历史 | “豆包最近是不是换粮了” |
| `tool_read_task` | 需要读工具取证 | “查一下最近 7 天体重和便便” |
| `tool_write_task` | 需要确认后写入 | “帮我把这个症状记下来” |
| `followup_task` | 需要补信息或追问 | “它今天不舒服” |
| `reject_or_redirect` | 不进入主执行链路 | prompt injection / cost abuse / 非宠物泛请求 |

### 3.2 任务拆解以后，Agent 如何先做什么后做什么，什么时候调用模型什么时候调用工具

| 问题 | 结论 |
|---|---|
| 先后顺序怎么决定 | 按依赖推进：先补上下文，再取证，再判断，再生成回答，再决定是否写入或追踪 |
| 什么时候调用模型 | 需要理解语义、做解释、组织语言、整合证据、决定下一步时 |
| 什么时候调用工具 | 需要访问外部事实、执行副作用、读取数据库读模型、触发确认任务时 |
| 毛球当前对应 | `EvidencePlanner` 已经在做“回答前先预取必要事实”的雏形；后续要扩成更完整的 step planner |

推荐规则：

| 场景 | 优先动作 |
|---|---|
| 用户问的是公开知识 | 先模型，尽量不读私域工具 |
| 用户问的是私域事实 | 先工具取证，再模型总结 |
| 用户表达模糊 | 先模型判断缺什么，再追问或工具取证 |
| 用户要执行写入 | 先模型澄清，再工具申请确认，再执行写入 |
| 当前证据不足 | 不让模型瞎答，先补工具或追问 |

### 3.3 用户输入进来以后，系统如果匹配相关的 skill

| 问题 | 结论 |
|---|---|
| skill 如何匹配 | 先看显式触发，再看当前任务类型，再看当前可用能力 |
| skill 与 tool 的关系 | skill 决定“怎么做”；tool 决定“能做什么” |
| 毛球当前对应 | 当前毛球还没有正式 skill runtime，只有 `capability_catalog + ToolRegistry + Workbench Prompt` 的轻量能力描述层 |

推荐匹配链路：

```text
用户输入
  -> Intent Gate
  -> Task Type 判断
  -> Skill Matcher
  -> 选出 0..N 个 Skill
  -> Skill 为 Runtime 提供执行策略 / prompt 模板 / 工具组
```

### 3.4 Skill 分层体系怎么设计，为什么这样分层，不同层级职责边界是什么

建议 skill 分 4 层：

| 层级 | 名称 | 职责 | 例子 |
|---|---|---|---|
| L0 | System Skill | 平台级硬规则、流程纪律、安全规则 | 不越权、不诊断、写入需确认 |
| L1 | Domain Skill | 领域能力模板 | 宠物异常追踪、饮食分析、App 帮助 |
| L2 | Workflow Skill | 多步任务剧本 | “先查近期饮食，再查症状，再给建议，再安排追踪” |
| L3 | Personalization Skill | 用户/家庭偏好层 | 回复风格、称呼、偏好提醒方式 |

为什么要这样分层：

| 原因 | 说明 |
|---|---|
| 避免所有规则都堆进一个 prompt | 不然很快失控，难以治理 |
| 把稳定规则和可变规则分开 | 系统规则长久稳定，领域流程可迭代，个性化最易变化 |
| 利于权限治理 | 不是所有 skill 都能影响工具集和写入能力 |
| 利于测试 | 每层都能单测边界与注入行为 |

### 3.5 有没有 skill 沉淀机制

| 问题 | 结论 |
|---|---|
| 能不能自动沉淀 | 可以，但只限于低风险、可验证、非副作用的层 |
| 当前毛球该不该做 | 这期不做完整自动沉淀平台 |
| 本期建议 | 先支持系统内置 skill + 工程侧显式注册，不让模型自己随意写 skill |

建议分法：

| 类型 | 是否可自动沉淀 | 原因 |
|---|---|---|
| System Skill | 否 | 这是平台契约，必须人工维护 |
| Domain Skill | 部分可 | 可由工程/运营从高频成功案例提炼 |
| Workflow Skill | 部分可 | 可从常见成功路径沉淀，但要人工审核 |
| Personalization Skill | 暂不做 | 会牵涉用户配置面和权限模型 |

### 3.6 长短期记忆怎么设计，分别保存什么

| 记忆类型 | 保存内容 | 生命周期 |
|---|---|---|
| 短期记忆 | 当前会话最近消息、当前任务状态、当前轮证据、临时澄清信息 | 当前 session / 当前 task |
| 长期静态记忆 | 低频变化但长期稳定的信息 | 长期保留 |
| 长期动态记忆 | 高频变化、可被新事实替换的弱记忆或摘要 | 长期保留但可失效 / supersede |

毛球上的建议：

| 类型 | 毛球具体内容 |
|---|---|
| 短期记忆 | 最近几轮对话、当前 selected pet、当前问题补充、当前 tool result |
| 长期静态记忆 | 用户偏好、家庭设置、毛球名字、固定照护偏好 |
| 长期动态记忆 | 会话摘要、弱偏好趋势、待确认事实线索、历史症状线程摘要 |

### 3.7 为什么要把长期记忆分层为静态长期记忆和动态长期记忆

| 原因 | 说明 |
|---|---|
| 稳定度不同 | 有些信息几乎不变，有些信息会被持续刷新 |
| 失效策略不同 | 静态记忆少失效，动态记忆必须支持 stale/superseded |
| 检索权重不同 | 静态偏好更稳定，动态摘要更接近近期任务 |
| 审计方式不同 | 静态记忆更像配置，动态记忆更像可回溯观察结论 |

### 3.8 每一轮都触发长期记忆存储，会不会快速膨胀，膨胀以后怎么处理

会。

解决方式不是“不存”，而是“分级写入”：

| 策略 | 说明 |
|---|---|
| 候选池 | 每轮先写 `memory candidate`，不直接升为长期记忆 |
| 去重 | 同一含义、同一 scope、同一 pet 的候选要合并 |
| 升级门槛 | 只有高置信、用户确认、多次重复出现的信息才升级 |
| 生命周期 | 动态记忆支持 `active/stale/superseded/retracted` |
| 周期压缩 | 旧的动态记忆和摘要合并为更粗粒度摘要 |

毛球当前已有对应基础：

| 当前基础 | 证据 |
|---|---|
| `agent_memory_candidates` | `docs/engineering/ai-agent-runtime/TODO_毛球Agent用户Workspace记忆与首轮上下文组装清单.md` |
| `session_summary` | `maohuoban-ai-application/src/ai/session_summary/*` |
| `MemoryRetriever` | `maohuoban-ai-application/src/ai/memory/retriever.rs` |

### 3.9 大模型如何判断哪些长期记忆需要召回，如何避免召回太多导致上下文污染

结论：不应该把“召回哪些记忆”的决定完全交给模型。

推荐链路：

```text
用户问题
  -> scope filter
  -> memory kind filter
  -> relevance retrieval
  -> top-k candidate
  -> budget trim
  -> 注入模型
```

避免污染的关键规则：

| 规则 | 说明 |
|---|---|
| 先过滤 scope | 未授权 pet / household 记忆不进入候选 |
| 再过滤类型 | 当前问饮食，就不要召回无关人格偏好 |
| top-k 限制 | 不是“能召回多少就塞多少” |
| 预算裁剪 | 按字节/token 上限硬裁剪 |
| 低置信降权 | 弱猜测不能压过明确事实 |
| 近期优先 | 动态记忆按 recency 排序 |

毛球当前已经有：

| 当前模块 | 作用 |
|---|---|
| `MemoryRetriever` | 先做 scope 过滤 |
| `MemoryPack.filter_for_*` | 保证 public/pet/household 隔离 |
| `ContextBudgetPolicy` | 预算裁剪思路已经存在 |

### 3.10 动态 prompt 和静态 prompt 有什么区别，上下文如何动态组装

| 类型 | 定义 | 毛球例子 |
|---|---|---|
| 静态 prompt | 长期不变的系统规则 | 平台边界、医疗边界、工具执行规则 |
| 动态 prompt | 本轮才注入的上下文 | selected pet（选定的宠物）、session summary（会话摘要）、memory pack（记忆包）、visible tools（可见工具） |

毛球当前对应：

| 当前实现 | 说明 |
|---|---|
| `workbench_prompt_projection.rs` | 动态把 workbench 投影成模型可见 prompt |
| `TurnContextBuilder` | 负责组装动态上下文组件 |
| `AiIntentGate` | 决定是否加载私域上下文 |

推荐组装顺序：

```text
System Base Rules
  + Capability Boundary
  + Surface / Locale / Timezone
  + Selected Pet / Authorized Pets
  + Session Summary
  + Memory Pack
  + Visible Tools
  + Recent Conversation
  + Current User Message
```

### 3.11 上下文窗口总 token 是多少，触发压缩的上限阈值如何规定

结论：不应写死成一个全局常数，必须是 provider/model capability 的一部分。

建议：

| 层级 | 规则 |
|---|---|
| Provider Capability | 声明每个模型的总 context、建议输入预算、输出预算 |
| Runtime Budget | 给当前 turn 划定 `history / memory / tools / output` 子预算 |
| Compression Trigger | 当 projected input 达到预算阈值时，先压缩历史，再裁剪弱记忆 |

当前毛球已有：

| 当前实现 | 说明 |
|---|---|
| `ContextBudgetPolicy::default_for_deepseek_1m()` | 已经有按模型设默认预算的雏形 |
| `SessionSummaryCompressor` | 已有会话摘要压缩机制 |

建议阈值原则：

| 指标 | 建议 |
|---|---|
| 触发压缩 | projected input 超过模型安全输入预算的 70%-80% |
| 硬上限 | 超过 85%-90% 直接禁止继续堆上下文 |
| 优先裁剪顺序 | 早期闲聊 > 低置信动态记忆 > 旧摘要 > 强事实最后裁剪 |

### 3.12 一个 agent 系统应该拆分哪些核心模块，每个模块分别负责什么

建议毛球拆成下面这些模块：

| 模块 | 职责 | 毛球对应方向 |
|---|---|---|
| Intent Gate | 判定意图、风险、是否加载私域上下文 | `AiIntentGate` |
| Session Runtime | 管 session / history / resume / transcript | 当前缺正式 `Session Contract` |
| Turn Context Builder | 组装 workbench/context/memory/tools | `TurnContextBuilder` |
| Skill Runtime | 匹配和注入 system/domain/workflow/personalization skill | 当前缺正式 `Skill Contract` |
| Planner | 生成 step 序列、决定先后顺序 | 当前只有 `EvidencePlanner` 雏形 |
| Model Runtime | 负责采样、delta、tool-call、finish | `AgentRuntimeLoopEngine` |
| Tool Registry | 工具声明与发现 | `ToolRegistry` |
| Policy Guard | 审批、风险、确认、目标鉴权 | `PolicyGuard` |
| Tool Gateway | 执行工具并产生标准结果 | `tool_executor.rs` + HTTP runtime tools |
| Memory System | 长短期记忆、候选、检索、失效 | `MemoryRetriever` + session summary + candidate repo |
| Context Retriever | 最近历史、摘要、记忆、事实查询的统一入口 | 当前散在 loaders，需要收口 |
| Finalizer | summary、memory upgrade、cleanup、delivery 前终态收尾 | 当前缺独立 `Finalizer Contract` |
| Diagnostics / Eval | 每层事件、链路追踪、合同测试、评测 | 现有 diagnostics 基础较好 |

### 3.13 Agent 在执行任务过程中如何判断当前步骤是否成功，失败后如何重试回滚或重新规划

成功判定要分层：

| 层 | 成功信号 |
|---|---|
| Tool Step | 工具返回标准成功结果，且未被 PolicyGuard 拒绝 |
| Evidence Step | 已拿到与当前问题匹配的事实 |
| Answer Step | 生成了非空、符合边界的最终文本 |
| Write Step | 用户已确认，写入成功并有 transcript/audit |
| Turn | 命中明确 `Completed / Failed / Interrupted / RequiresConfirmation` 终态 |

失败后的处理：

| 失败类型 | 处理 |
|---|---|
| 工具参数错 | 小范围重试或改参 |
| 工具目标未授权 | 不重试，直接拒绝 |
| provider 超时 | provider 级重试或切换 profile |
| 证据不足 | 重新规划为追问 / 追加读工具 |
| 写入失败 | 不伪装成功，保留待确认或失败状态 |
| 上下文超限 | 先压缩再重试 |

回滚原则：

| 原则 | 说明 |
|---|---|
| 读操作无回滚 | 只记录失败即可 |
| 写操作必须显式确认 | 未确认就不执行，自然避免回滚 |
| 多步写入要么有补偿动作，要么拆成确认型任务 | 毛球不应直接做隐式复合写操作 |

### 3.14 上下文检索系统应该怎么设计，如何结合向量检索、关键词检索、AST 分析和调用链分析

这里要先区分：`代码 agent` 和 `毛球 agent` 不一样。

| 检索能力 | 代码 Agent 需要 | 毛球 Agent 需要 |
|---|---|---|
| 向量检索 | 是 | 是 |
| 关键词检索 | 是 | 是 |
| AST 分析 | 是 | 否 |
| 调用链分析 | 是 | 否 |
| 结构化读模型查询 | 可选 | 是核心 |

毛球的检索系统建议是：

```text
Query
  -> Scope Filter
  -> Structured Read Model Lookup
  -> Keyword Recall
  -> Vector Recall
  -> Merge / Rank
  -> Budget Trim
  -> Context Projection
```

也就是说，毛球不需要 AST 和调用链分析，毛球真正对应的是：

| 在代码 Agent 里的东西 | 在毛球里的对应物 |
|---|---|
| AST 分析 | 结构化事实 schema |
| 调用链分析 | 宠物事实引用链 / 症状线程 / reminder thread / event lineage |

### 3.15 Agent 工具调用系统应该怎么设计，工具如何注册调用，这些对应在我们的毛球 Agent 上应该是什么

推荐设计：

| 环节 | 要求 |
|---|---|
| 注册 | 工具必须注册到 `ToolRegistry`，声明 name/schema/scope/read_only/risk/toolset/fact_schema |
| 发现 | 默认只给模型看当前可见工具摘要，按需展开 schema |
| 调用 | 所有调用都通过 `Tool Gateway`，禁止模型直接访问后端服务 |
| 审批 | `PolicyGuard` 决定 allow/deny/transform/confirm/terminate |
| 返回 | 返回统一 `AiToolResult`，支持 success/denied/failed/requires_confirmation |

毛球当前已具备的对应物：

| 当前代码 | 角色 |
|---|---|
| `ToolRegistry` | 工具白名单与发现 |
| `runtime_tools.rs` | HTTP 层装配本轮工具集 |
| `PolicyGuard` | 工具级风险和 pet 授权校验 |
| `tool_executor.rs` | runtime 执行工具 |
| `EvidencePlanner` | 当前的“先取证再回答”雏形 |
| `workbench_prompt_projection.rs` | 把本轮可见工具告诉模型 |

## 4. 毛球应当对应成什么

### 4.1 模块映射

| 设计问题 | 毛球应该新增或收紧的模块 |
|---|---|
| 意图理解 | `Intent Contract`，从 `AiIntentGate` 升级为正式协议 |
| 任务拆解 | `Planner Contract`，从 `EvidencePlanner` 扩成 step planner |
| Skill 体系 | `Skill Contract`，新增 `system/domain/workflow/personalization` 四层注入协议 |
| 长短期记忆 | `Memory Contract`，明确 `short/static_long/dynamic_long/candidate` |
| 动态上下文 | `Context Assembly Contract`，由 `TurnContextBuilder` 统一收口 |
| 压缩阈值 | `Budget & Compression Contract`，基于 provider capability 配置 |
| 检索系统 | `Retriever Contract`，统一 structured/keyword/vector recall |
| 工具系统 | `Tool Contract + Tool Gateway Contract + Policy Contract` |
| 终态处理 | `Finalizer Contract` |

### 4.2 推荐实现顺序

| 顺序 | 文档 / 协议 | 原因 |
|---|---|---|
| 1 | `03_Session Contract` | session 是一切恢复和隔离的根 |
| 2 | `04_Turn Contract` | turn 决定状态机的边界 |
| 3 | `05_Tool Contract` | tool 是 agent 差异化能力的核心 |
| 4 | `06_Memory & Context Contract` | 解决记忆和上下文污染问题 |
| 5 | `07_Skill & Planner Contract` | 在 session/turn/tool/memory 稳定后再做高层编排 |

## 5. 不变约束

| 约束 | 说明 |
|---|---|
| 禁止兼容旧模式 | 不写 dual path / legacy adapter / fallback 掩盖协议缺口 |
| 模型不直接拥有业务权限 | 只能通过 Tool Gateway 申请能力 |
| 私域记忆先过滤 scope | 未授权上下文不能进入 recall |
| 写入必须显式确认 | 聊天抽取不能直接改强事实 |
| 上下文组装和模型循环解耦 | 组装归 `TurnContextBuilder`，循环归 Runtime |

## 6. 风险

| 风险 | 处理 |
|---|---|
| 文档一次塞太多概念，后续实现漂移 | 每一组问题继续拆成独立协议文档，不直接跨层写代码 |
| 过早引入 skill 自动沉淀导致复杂度爆炸 | 本期只做手工/系统内置 skill 体系，不做开放式自动沉淀 |
| 记忆系统过度设计 | 先把候选、隔离、召回、压缩四件事做稳 |
| provider 差异继续污染业务层 | 后续单独写 `Provider Capability Contract`，禁止现场分支蔓延 |

