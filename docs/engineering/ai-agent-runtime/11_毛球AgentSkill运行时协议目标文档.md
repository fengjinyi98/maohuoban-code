# 毛球AgentSkill运行时协议目标文档

- 更新时间：2026-06-30
- Goal：定义毛球 Agent 的 `Skill Runtime Contract`，明确 skill 不是工具、skill 如何分层、如何匹配、如何注入本轮执行，以及 skill 与 tool / planner / memory / system prompt 的边界
- 执行方式：先目标文档后实现；以毛球当前 `AgentDefinition / CapabilityCatalog / Toolset / Workbench Prompt Projection` 为基础收敛，不先做用户开放式 skill 平台

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| skill 是什么 | skill 是高层执行模板 / 规则包 / 领域操作剧本，不是具体工具 |
| skill 和 tool 的关系 | skill 决定“怎么做”；tool 决定“能做什么” |
| 为什么必须单独做运行时协议 | 否则能力说明、prompt 规则、流程模板、用户偏好会散落在 system prompt、工具描述和 planner 里 |
| 当前毛球现状 | 已经有 `AgentDefinition`、`CapabilityCatalog`、`Toolset`、`Workbench Prompt Projection` 这些 skill 雏形，但还不是正式 skill runtime |
| 当前核心缺口 | 缺少 skill 层次、匹配规则、注入顺序、优先级和治理边界 |
| 直接结论 | 当前阶段毛球应该先做“内置 skill 运行时协议”，不做开放式用户 skill 平台 |

## 2. 目标边界

### 2.1 本目标期必须明确

| 范围 | 目标 |
|---|---|
| skill 定义 | 明确 skill 和 tool / prompt / planner 的区别 |
| skill 分层 | 明确 system/domain/workflow/personalization 四层 |
| skill 匹配 | 明确一轮请求如何选中 0..N 个 skill |
| skill 注入 | 明确 skill 以什么形式进入本轮 runtime |
| skill 优先级 | 明确多 skill 并存时谁覆盖谁 |
| skill 边界 | 明确哪些 skill 能影响工具集，哪些只能影响话术或流程 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 用户自定义 skill 平台 | 当前先收敛底层运行时协议 |
| 模型自动生成并热安装 skill | 当前风险太高，先不进入实现面 |
| 第三方 marketplace / hub | 与本期底层重构目标无关 |

## 3. 依据

### 3.1 项目内依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| Agent 身份 | `maohuoban-ai-domain/src/ai/workbench/agent_definition.rs` | 当前已具备 `agent_id / name / purpose / capability_domains` |
| 能力目录 | `maohuoban-ai-domain/src/ai/workbench/capability_catalog.rs` | 当前已具备本轮可投影能力说明 |
| 工具分组 | `maohuoban-ai-domain/src/ai/workbench/toolset.rs` | 当前已具备 `PublicPetDomain / PrivatePetContext / AppSupport / Memory / Confirmation` |
| Prompt 投影 | `maohuoban-ai-application/src/ai/runtime/workbench_prompt_projection.rs` | 当前已经把能力边界、本轮工具、上下文和记忆拼成模型可见 prompt |
| TurnContextBuilder | `maohuoban-ai-application/src/ai/turn_context/mod.rs` | 当前工作台上下文已经按能力域和 selected pet 生成不同能力目录 |
| 意图闸门 | `10_毛球Agent意图闸门协议目标文档.md` | 当前 gate 决定哪些请求值得进入 skill/runtime 面 |

### 3.2 参考实现依据

| 参考项目 | 启发 |
|---|---|
| `hermes-agent` | skill 会在运行时加载进 prompt，并有 usage bump、bundle、平台过滤等机制 |
| `pi` | skill 通过 `ResourceLoader` 进入 system prompt 和 slash command runtime |
| `package` | skill 更像可运行指令/规则资产，和工具、system prompt 分离 |

## 4. Skill 的定义

### 4.1 skill 不是工具

| 对象 | 作用 |
|---|---|
| tool | 执行一个具体操作，如查宠物档案、读取饮食上下文、创建确认任务 |
| skill | 告诉 Agent 遇到某类问题时该按什么规则、顺序、风格和边界来做 |

### 4.2 skill 也不是普通 prompt

| 对象 | 差异 |
|---|---|
| system prompt | 平台长期稳定总规则 |
| skill | 针对特定任务或领域动态注入的可复用策略单元 |

### 4.3 skill 也不是 planner

| 对象 | 差异 |
|---|---|
| planner | 负责当前 turn 实际 step 推进 |
| skill | 负责给 planner 和模型提供“这类事情应该怎么做”的策略模板 |

## 5. Skill 分层协议

### 5.1 四层建议

| 层级 | 名称 | 职责 | 毛球例子 |
|---|---|---|---|
| L0 | System Skill | 平台硬边界、长期稳定规则 | 医疗边界、写入需确认、隐私边界 |
| L1 | Domain Skill | 领域级能力模板 | 宠物健康风险应答、饮食分析、App 帮助 |
| L2 | Workflow Skill | 多步任务剧本 | “先查饮食，再查症状，再给建议，再决定是否追踪” |
| L3 | Personalization Skill | 用户/家庭级偏好层 | 回复风格、称呼、表达偏好 |

### 5.2 为什么要这样分层

| 原因 | 说明 |
|---|---|
| 规则稳定度不同 | 系统边界最稳定，个性化变化最大 |
| 权限等级不同 | 不是所有 skill 都能影响工具集 |
| 调试难度不同 | 分层后可分别定位问题在规则、领域、流程还是个性化 |
| 测试粒度更清晰 | 可以按层做契约测试 |

## 6. 技能匹配协议

### 6.1 匹配链路

```text
用户输入
  -> Intent Gate
  -> TaskType
  -> Skill Matcher
     -> choose 0..N skills
  -> TurnContextBuilder / Planner / Prompt Projection
```

### 6.2 匹配依据

| 依据 | 说明 |
|---|---|
| 意图 | `PetHealthRisk / PetFood / AppSupport / OffTopic` 等 |
| 任务类型 | `direct_answer / evidence_read / write_task / clarification_task` |
| 当前 surface | 首页私域、宠物档案、确认任务、异常详情等 |
| 当前可见工具集 | 某类 skill 只有在相关 toolset 可见时才生效 |
| 当前 selected pet / private context | 决定是否能注入私域领域 skill |

### 6.3 不同 skill 的匹配场景

| Skill 层 | 匹配方式 |
|---|---|
| System Skill | 永远注入 |
| Domain Skill | 按 intent/capability_domain 匹配 |
| Workflow Skill | 按 task type / execution path 匹配 |
| Personalization Skill | 按 actor_user_id / household_id 匹配 |

## 7. Skill 注入协议

### 7.1 注入顺序

```text
System Base Prompt
  -> System Skill
  -> Domain Skill
  -> Workflow Skill
  -> Personalization Skill
  -> ContextPack / MemoryPack / RecentConversationPack
  -> Visible Tools
  -> Current User Message
```

### 7.2 注入形式

建议 skill 不直接“改模型协议”，而是通过这几种运行时输入形式进入：

| 形式 | 用途 |
|---|---|
| `skill instructions` | 注入到系统提示词 |
| `workflow hints` | 注入给 planner / runtime policy |
| `toolset visibility hint` | 决定本轮工具可见性或优先级 |
| `response style hint` | 影响最终回答风格 |

## 8. Skill 与当前毛球工作台的映射

### 8.1 当前已有的 skill 雏形

| 当前对象 | 实际扮演的 skill 角色 |
|---|---|
| `AgentDefinition.purpose` | L0/L1 边界性 skill 描述 |
| `CapabilityCatalog.capabilities` | L1 领域能力摘要 |
| `Toolset` | L1/L2 可用能力域的控制开关 |
| `workbench_prompt_projection` | skill 注入投影器 |

### 8.2 当前还缺的正式协议

| 缺口 | 说明 |
|---|---|
| `SkillDefinition` | 缺少明确 skill 数据结构 |
| `SkillMatcher` | 缺少运行时匹配器 |
| `SkillBundle` | 缺少多 skill 合并与优先级规则 |
| `SkillRuntime` | 缺少将 skill 转成 prompt/runtime policy 的正式层 |

## 9. Skill 边界协议

### 9.1 哪些 skill 可以影响工具

| Skill 层 | 能否影响工具可见性 | 说明 |
|---|---|---|
| System Skill | 可以 | 平台级边界可隐藏高风险工具 |
| Domain Skill | 可以 | 某类问题只应暴露相关 toolset |
| Workflow Skill | 可以，但应受限 | 只能缩小或排序，不应随意新增未授权工具 |
| Personalization Skill | 不应影响授权工具集 | 只能影响风格和偏好，不应越权 |

### 9.2 哪些 skill 只能影响表达

| Skill 层 | 只影响表达的场景 |
|---|---|
| Personalization Skill | 称呼、长度、口吻、偏好 |
| 部分 Domain Skill | 领域术语说明方式、提示方式 |

## 10. Skill 与 Tool 的关系协议

### 10.1 关系图

```text
Skill
  -> 告诉 Agent 这类问题的处理规则
Tool
  -> 给 Agent 提供可执行动作
Planner
  -> 在 skill 规则下实际决定当前 step
```

### 10.2 毛球上的典型例子

| 场景 | Skill | Tool |
|---|---|---|
| “豆包是不是换粮了” | 饮食分析 skill | `load_pet_current_diet_context`, `load_food_inventory_change_hints` |
| “它今天不舒服” | 健康风险应答 skill | 读档案、读饮食、读症状、必要时追问 |
| “怎么改宠物资料” | AppSupport skill | 不一定需要工具，只需产品帮助说明 |

## 11. Skill 运行时协议建议

### 11.1 建议定义

| 字段 | 作用 |
|---|---|
| `skill_id` | 稳定身份 |
| `layer` | system/domain/workflow/personalization |
| `title` | 人类可读名称 |
| `match_conditions` | 哪些意图/task/surface 命中 |
| `instruction_block` | 注入的规则文本 |
| `toolset_hints` | 影响哪些 toolset 可见或优先 |
| `priority` | 多 skill 冲突时排序 |
| `mutable` | 是否允许后续动态升级/替换 |

### 11.2 建议输出

`SkillMatcher` 输出：

| 输出 | 说明 |
|---|---|
| `active_skills` | 本轮命中的 skill 列表 |
| `merged_instruction` | 供 prompt 注入的合并文本 |
| `toolset_policy` | 对本轮工具集的影响 |
| `workflow_policy` | 对 planner 的提示 |

## 12. Skill 优先级协议

建议固定为：

```text
System Skill
  > Domain Skill
    > Workflow Skill
      > Personalization Skill
```

解释：

| 原因 | 说明 |
|---|---|
| 安全边界不能被覆盖 | System 永远最高 |
| 领域边界高于具体流程 | 先知道能干什么，再决定怎么干 |
| 个性化不能破坏平台规则 | Personalization 永远最低 |

## 13. 当前毛球下一步应怎么做

| 步骤 | 说明 |
|---|---|
| 1 | 新增 `SkillDefinition` 领域模型 |
| 2 | 新增 `SkillLayer` 枚举 |
| 3 | 新增 `SkillMatcher` application 层 |
| 4 | 将 `CapabilityCatalog` 从纯展示对象升级为 `Domain Skill` 输入之一 |
| 5 | 将 `Toolset` 与 skill runtime 关联，而不是直接散在 request policy 里 |

## 14. 不变约束

| 约束 | 说明 |
|---|---|
| skill 不是 tool | 两者永远分层 |
| skill 不直接执行副作用 | 副作用只能通过 tool gateway |
| personalization 不得影响授权边界 | 只能改风格，不能改权限 |
| system skill 永远优先 | 不允许下层覆盖硬边界 |

## 15. 风险

| 风险 | 处理 |
|---|---|
| 把 skill 和 tool 混成一层 | 会导致协议失控 |
| 太早开放用户自定义 skill | 当前先收敛内置运行时协议 |
| 多 skill 注入顺序不稳定 | 必须固定优先级和合并规则 |
| skill 直接改写工具授权 | 只能影响可见性/优先级，不能绕过 PolicyGuard |

