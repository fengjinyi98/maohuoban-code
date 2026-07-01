# 毛球Agent领域事实协议目标文档

- 更新时间：2026-06-30
- Goal：定义毛球 Agent 的领域事实协议，明确哪些是强事实、哪些是弱线索、哪些是待确认事实、这些事实如何通过工具返回给 Agent、如何被引用、何时能写回产品事实账本
- 执行方式：先目标文档后实现；依托当前 `AiFactPackage / AiFactEntry / AiFactStrength / ToolFactSchema` 与现有产品事实设计，不引入兼容旧模式

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 领域事实是什么 | 毛球可查询、可解释、可追踪的结构化宠物事实单元 |
| 为什么要单独立协议 | 没有事实协议，工具返回、模型解释、确认写回、弱线索治理都会混乱 |
| 事实必须分层 | 至少要区分 `强事实 / 待确认事实 / 弱线索` |
| 工具协议和事实协议的关系 | 工具协议定义“怎么返回”；事实协议定义“返回的是什么” |
| 当前毛球现状 | 已经有 `AiFactEntry / AiFactPackage / AiFactStrength / ToolFactSchema`，并在运行时工具里开始返回 `pet_identity / current_diet / inventory_change_hint / diet_confirmation_candidate` |
| 当前核心缺口 | 缺少正式文档把“哪些事实能直接进入回答、哪些只能当线索、哪些必须确认后才能写回”固定下来 |

## 2. 目标边界

### 2.1 本目标期必须明确

| 范围 | 目标 |
|---|---|
| 事实类型 | 明确强事实、待确认事实、弱线索、计算事实的定义 |
| 事实来源 | 明确用户记录、聊天抽取、工具读模型、库存变化、episode/thread 等来源差异 |
| 事实写回规则 | 明确哪些能直接写入事实账本，哪些必须通过确认任务 |
| 事实引用规则 | 明确回答如何引用事实，如何关联 `citations / source_id / event_id` |
| 工具事实输出规则 | 明确 `ToolFactSchema` 和 `AiFactPackage` 的边界 |
| 毛球领域映射 | 明确当前宠物档案、饮食、库存线索、异常追踪等事实类别 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 全量营养知识图谱 | 当前先把核心宠物事实和线索分层立住 |
| 完整医疗事实本体 | 这是更后面的 HIS/医疗边界问题 |
| 商业推荐事实协议 | 当前先聚焦宠物照护、记录和帮助 |

## 3. 依据

### 3.1 项目内依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| 事实包模型 | `maohuoban-ai-domain/src/ai/model/fact_package.rs` | 当前已定义 `AiFactPackage`、`AiFactEntry`、`AiFactStrength` |
| 工具事实 schema | `maohuoban-ai-domain/src/ai/workbench/tool_fact_schema.rs` | 当前已定义工具可返回事实 schema |
| 工具事实投影 | `maohuoban-ai-domain/src/ai/workbench/tool_fact_projection.rs` | 当前已开始把事实投影成模型/前端可见结构 |
| Runtime 工具事实 | `maohuoban-ai-http/src/Infrastructure/ai/router/chat/runtime_tools.rs` | 当前工具已返回 `pet_identity/current_diet/inventory_change_hint/diet_confirmation_candidate` |
| 产品事实底座 | `docs/product/strategy/04_宠物事实采集与毛球Agent记忆系统设计.md` | 当前已明确宠物事实账本、食品库、症状追踪链和事件类型 |
| Phase 3 | `docs/engineering/attention-hints-abnormal/00_AttentionHint与异常追踪闭环Phase3目标文档.md` | 当前已明确异常 episode、confirmation task、hint 和 event 边界 |

### 3.2 当前已存在的事实强度

从现有代码可见：

| 强度 | 当前含义 |
|---|---|
| `Strong` | 已确认事实，可直接用于回答和引用 |
| `PendingConfirmation` | 待确认事实，不能当成确定真相 |
| `Weak` | 弱线索，只能辅助判断，不可当权威事实 |

## 4. 事实分层协议

### 4.1 四类事实

| 类型 | 定义 | 可否直接回答 | 可否直接写回账本 |
|---|---|---|---|
| 强事实 | 已确认、可追溯、当前有效的结构化事实 | 可以 | 可以 |
| 待确认事实 | 已抽取但未确认的候选事实 | 只能以“待确认/可能”表述 | 不可以 |
| 弱线索 | 只能暗示某种可能性的信息 | 只能辅助推理 | 不可以 |
| 计算事实 | 基于强事实派生的计算结果 | 可以，但要保留来源链 | 不直接写回原始账本 |

### 4.2 当前毛球上的映射

| 类型 | 毛球例子 |
|---|---|
| 强事实 | `pet_identity.name`、当前主粮、已确认体重、已确认症状事件 |
| 待确认事实 | `diet_confirmation_candidate`、聊天抽取的换粮候选 |
| 弱线索 | `inventory_change_hint`、储物柜变化、订单导入但未确认消费 |
| 计算事实 | `world_days`、`companionship_days`、近期异常趋势 |

## 5. 事实来源协议

### 5.1 来源种类

| 来源 | 特性 |
|---|---|
| 用户显式记录 | 高可信，通常直接形成强事实 |
| 聊天抽取 | 需确认后升级 |
| 后端结构化读模型 | 已是系统确认视图，可作为强事实读取面 |
| 库存/订单变化 | 只能作为弱线索 |
| 就诊/异常 thread 事件 | 取决于是否已确认/已写账本 |

### 5.2 来源到强度的推荐映射

| 来源 | 推荐强度 |
|---|---|
| 用户快捷记录 / 表单提交 | `Strong` |
| 已落 `pet_events` / 读模型投影 | `Strong` |
| 聊天抽取未确认 | `PendingConfirmation` |
| 储物柜变化 / 食品库存变化 | `Weak` |
| 规则计算出的趋势 | `Strong` 或 `Weak`，取决于输入事实是否全是强事实 |

## 6. 事实键协议

### 6.1 事实键必须稳定

推荐保持：

| 规则 | 说明 |
|---|---|
| 使用稳定 `fact_key` | 例如 `pet_identity.name`、`pet_identity.world_days` |
| 不把 UI 文案当 key | key 只做协议，不做展示 |
| key 归属于领域 namespace | 避免散乱命名 |

### 6.2 当前可见事实键族

| 领域 | 当前事实键示例 |
|---|---|
| 宠物身份 | `pet_identity.name/species/sex/breed/birthday/arrival_date/world_days/companionship_days` |
| 当前饮食 | `current_staple`, `diet_status` |
| 库存线索 | `inventory_change_hint` |
| 饮食确认 | `diet_confirmation_candidate` |

## 7. ToolFactSchema 协议

### 7.1 它解决什么问题

`ToolFactSchema` 用来告诉系统：

| 作用 | 说明 |
|---|---|
| 这个工具会返回哪类事实 | `fact_keys` |
| 这些事实能回答什么问题 | `natural_language_summary` |
| 每个字段是什么意思 | `fields[].meaning` |
| 用户会怎么问 | `fields[].example_queries` |

### 7.2 为什么需要它

| 原因 | 说明 |
|---|---|
| 帮助 `EvidencePlanner` 预取 | 当前已经这么做了 |
| 帮助工具说明自然语言投影 | 当前 `AgentRuntimeRequestPolicy` 已使用 |
| 帮助前端/调试知道工具返回的事实边界 | 降低协议漂移 |

## 8. AiFactPackage 协议

### 8.1 建议定位

| 字段 | 定位 |
|---|---|
| `facts` | 强事实主集合 |
| `computed` | 基于强事实派生的计算结果 |
| `weak_hints` | 弱线索集合 |

### 8.2 使用规则

| 集合 | 使用规则 |
|---|---|
| `facts` | 可直接回答、可引用 |
| `computed` | 可回答，但必须可追溯到强事实 |
| `weak_hints` | 不可直接当结论，只能触发追问或候选确认 |

## 9. 引用协议

### 9.1 回答为什么必须带引用

| 原因 | 说明 |
|---|---|
| 便于审计 | 知道答案依据哪些事实 |
| 便于用户解释 | 后续可在 UI 中解释“为什么这么说” |
| 便于回放和评测 | 可以判断模型有没有离开事实边界 |

### 9.2 引用来源

| 引用类型 | 来源 |
|---|---|
| `event citation` | 来自 `pet_events` 或 episode/thread event |
| `fact citation` | 来自结构化读模型的 source_ref/source_id |
| `confirmation citation` | 来自 `agent_confirmation_tasks` 的确认结果 |

## 10. 事实写回协议

### 10.1 哪些能直接写回

| 类型 | 规则 |
|---|---|
| 用户显式记录的事实 | 直接写回 |
| 用户在确认任务中确认的事实 | 写回 |
| 系统内部纯计算事实 | 不直接写原始账本，只作为派生视图 |

### 10.2 哪些不能直接写回

| 类型 | 原因 |
|---|---|
| 弱线索 | 不足以构成事实 |
| 未确认聊天抽取 | 不能直接篡改宠物事实 |
| 模型猜测 | 绝不能直接写回 |

## 11. 事实在毛球上的典型路径

### 11.1 宠物档案

```text
pet profile / pet identity read model
  -> strong facts
  -> tool returns AiFactPackage.facts
  -> model can answer directly
```

### 11.2 当前饮食

```text
diet assignments / feeding facts
  -> current_staple / diet_status
  -> strong facts
  -> model can answer directly
```

### 11.3 库存变化

```text
food inventory item changes
  -> inventory_change_hint
  -> weak hint
  -> model不能直接下结论
  -> 应改成提示或确认任务
```

### 11.4 聊天抽取换粮

```text
user says "最近换粮了"
  -> candidate fact
  -> PendingConfirmation
  -> create confirmation task
  -> confirmed
  -> write pet_events(diet_change)
  -> become strong fact
```

## 12. 当前毛球实现应如何收紧

### 12.1 当前方向正确的部分

| 当前实现 | 价值 |
|---|---|
| `AiFactStrength` | 已经表达事实强度分层 |
| `ToolFactSchema` | 已经开始定义工具返回事实边界 |
| `inventory_change_hint` | 已经没有被误当成强事实 |
| `diet_confirmation_candidate` | 已经体现待确认事实的方向 |

### 12.2 推荐下一步

| 步骤 | 说明 |
|---|---|
| 1 | 把 `AiFactEntry` 的来源语义文档化并继续完善 source_ref/source_id |
| 2 | 对每个 Runtime 工具补齐 fact schema 和强度说明 |
| 3 | 在 finalizer / confirmation pipeline 中固定“弱线索 -> 候选 -> 确认 -> 强事实”的升级路径 |
| 4 | 为异常 episode/thread 补事实键与引用规则 |

## 13. 与前面文档的关系

| 文档 | 本文依赖方式 |
|---|---|
| `05 Tool Contract` | 工具协议定义“怎么返回”，本文定义“返回什么” |
| `08 Memory & Retrieval Contract` | 长期记忆召回依赖事实强度和来源分层 |
| `09 Planning & Execution Contract` | planner 需要区分强事实和弱线索来决定是否追问 |
| `10 Intent Gate Contract` | gate 决定是否值得加载私域事实 |
| `11 Skill Runtime Contract` | domain/workflow skill 会规定遇到弱线索如何处理 |

## 14. 不变约束

| 约束 | 说明 |
|---|---|
| 弱线索不直接当结论 | 必须保持 |
| 未确认事实不直接写账本 | 必须保持 |
| 计算事实不替代原始事实 | 必须保持 |
| 工具必须声明返回事实边界 | 继续推进 |

## 15. 风险

| 风险 | 处理 |
|---|---|
| 把弱线索混进强事实集合 | 会直接污染回答正确性 |
| 不给工具定义事实 schema | 证据规划和解释边界会失控 |
| 聊天抽取直接落强事实 | 会带来高风险事实污染 |
| 事实键不稳定 | 后续引用、评测、回放都会崩 |

