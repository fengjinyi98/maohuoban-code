# 毛球Agent记忆与上下文检索协议目标文档

- 更新时间：2026-06-30
- Goal：定义毛球 Agent 的记忆分层、上下文检索、召回裁剪、摘要边界与预算策略，明确哪些信息进入短期记忆、长期记忆、候选池和摘要，以及这些内容如何进入本轮上下文
- 执行方式：先目标文档后实现；在现有 `MemoryRetriever / MemoryPack / ContextPack / SessionSummary / ContextBudgetPolicy` 基础上收敛协议，不引入兼容旧模式

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 记忆系统的目标 | 不是“什么都存”，而是“只把未来有复用价值、可验证、可隔离的信息进入对应层级” |
| 检索系统的目标 | 不是“语义搜全库”，而是“先过滤 scope，再召回，再裁剪，再投影” |
| 短期记忆和长期记忆必须分层 | 因为生命周期、稳定度、失效规则、检索权重都不同 |
| 长期记忆还要再分 | 应拆成 `静态长期记忆` 和 `动态长期记忆` |
| 会话摘要不是记忆替代物 | 它是历史压缩层，不是事实权威层 |
| 当前毛球现状 | 已经有 `MemoryPack`、`MemoryRetriever`、`ContextPack`、`RecentConversationPack`、`SessionSummary`、`CompressionThreshold`、`ContextBudgetPolicy` 等基础能力 |
| 当前核心缺口 | 这些基础能力还没被正式收敛成统一协议，导致“什么进上下文、什么不进”仍靠散点逻辑 |

## 2. 目标边界

### 2.1 本目标期必须明确

| 范围 | 目标 |
|---|---|
| 记忆分层 | 明确短期、静态长期、动态长期、候选池、摘要层分别保存什么 |
| 召回链路 | 明确 scope filter、类型过滤、相关性检索、预算裁剪的先后顺序 |
| 上下文注入 | 明确什么进入 `ContextPack`、`MemoryPack`、`RecentConversationPack` |
| 膨胀治理 | 明确每轮写候选、升级门槛、stale/superseded 规则 |
| 压缩边界 | 明确什么情况下触发 summary，summary 如何与 recent history 配合 |
| 毛球映射 | 明确这些能力在毛球上对应哪些现有模块与下一步协议 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 最终向量数据库实现细节 | 本文只定义检索协议与分层原则 |
| 用户自定义长期记忆界面 | 当前先定义底层协议 |
| 自动知识蒸馏平台 | 当前先把候选池、升级、裁剪规则立住 |

## 3. 依据

### 3.1 项目内依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| 记忆包 | `maohuoban-ai-domain/src/ai/workbench/memory_pack.rs` | 当前已按 `public / pet / household` 场景过滤记忆 |
| 上下文包 | `maohuoban-ai-domain/src/ai/workbench/context_pack.rs` | 当前 `ContextPack` 只承载可投影上下文 |
| 会话摘要 | `maohuoban-ai-domain/src/ai/workbench/session_summary.rs` | 当前摘要已明确是“历史参考”，并具备 `compressed_until_message_id` |
| 最近历史 | `maohuoban-ai-domain/src/ai/workbench/recent_conversation.rs` | 当前历史窗口已是模型可见投影层 |
| 记忆检索 | `maohuoban-ai-application/src/ai/memory/retriever.rs` | 当前检索已先做 scope 校验与过滤 |
| 历史投影 | `maohuoban-ai-application/src/ai/conversation_history/mod.rs` | 当前恢复上下文会先读 summary，再读压缩边界之后的消息 |
| 会话摘要压缩 | `maohuoban-ai-application/src/ai/session_summary/mod.rs` | 当前已具备压缩触发、尾部保留、旧摘要替代 |
| 上下文预算 | `maohuoban-ai-application/src/ai/turn_context/context_budget.rs` | 当前已具备按 turn 数和字节数裁剪最近历史窗口 |
| 记忆与安全边界文档 | `docs/engineering/agent-memory-security/00_毛球Agent记忆隔离与工具安全目标文档.md` | 当前已明确 scope、记忆根、候选池、安全边界 |
| 首轮记忆 TODO | `docs/engineering/ai-agent-runtime/TODO_毛球Agent用户Workspace记忆与首轮上下文组装清单.md` | 当前已提出 `agent_preferences / agent_profile_items / agent_memory_items / agent_memory_candidates / chat_session_summaries` 分层方向 |

### 3.2 参考实现依据

| 参考项目 | 启发 |
|---|---|
| `pi` | transcript 持久化与 compaction 分离，资源加载和会话壳分离 |
| `hermes-agent` | 系统提示分层缓存，外部记忆与会话压缩分离 |
| `package` | transcript recovery 优先，session memory 作为后处理抽取层 |
| `openclaw` | session memory/hook/summary 作为独立运行时层 |

## 4. 记忆分层协议

### 4.1 建议分层

| 层 | 名称 | 作用 | 生命周期 |
|---|---|---|---|
| L1 | 短期记忆 | 当前会话和当前任务的直接上下文 | 本 session / 本 turn |
| L2 | 静态长期记忆 | 低频变化、长期稳定、明确确认过的信息 | 长期 |
| L3 | 动态长期记忆 | 会变化、会被新事实替代的趋势、弱结论和历史摘要 | 长期但可失效 |
| L4 | 候选池 | 每轮抽取后待确认、待升级的信息 | 短到中期 |
| L5 | 会话摘要 | 历史压缩层，用于恢复，不直接当事实权威 | 可替代 |

### 4.2 毛球上的具体映射

| 层 | 毛球内容 |
|---|---|
| 短期记忆 | 当前 selected pet、最近几轮问答、当前 tool result、当前澄清信息 |
| 静态长期记忆 | 用户回复风格偏好、毛球名字、固定照护偏好、家庭固定设置 |
| 动态长期记忆 | 近期关注点、会话摘要、历史症状线程摘要、弱偏好趋势 |
| 候选池 | 聊天抽取的待确认事实、潜在偏好、待升级 profile item |
| 会话摘要 | 该 session 历史压缩结果与 `compressed_until_message_id` |

## 5. 为什么长期记忆必须分成静态和动态

| 原因 | 说明 |
|---|---|
| 稳定度不同 | 用户明确偏好通常稳定；历史趋势和弱结论会变化 |
| 升级门槛不同 | 静态长期记忆必须更高置信；动态长期记忆可以先弱保存 |
| 失效策略不同 | 动态长期记忆必须支持 `stale / superseded / retracted` |
| 注入优先级不同 | 静态偏好优先级高，动态记忆更容易被裁掉 |

## 6. 短期记忆协议

### 6.1 定义

| 类型 | 当前毛球对象 |
|---|---|
| 当前会话最近历史 | `RecentConversationPack` |
| 当前轮上下文 | `ContextPack` |
| 当前轮可见记忆包 | `MemoryPack` |

### 6.2 规则

| 规则 | 说明 |
|---|---|
| 短期记忆优先来自当前 session | 不跨 session 直接混入 |
| 最近历史必须是投影后的纯净消息 | 不把 provider/model/verification 等内部字段塞回模型 |
| 当前轮上下文只保留白名单字段 | `selected_pet / authorized_pets / session_summary / locale / timezone` |

## 7. 长期记忆膨胀治理

### 7.1 每轮都直接写长期记忆会出什么问题

| 问题 | 后果 |
|---|---|
| 膨胀过快 | 很快失去检索质量 |
| 低价值垃圾记忆堆积 | 上下文污染 |
| 弱结论压过强事实 | 产生错误回答 |
| 重复内容太多 | 浪费存储与预算 |

### 7.2 推荐治理方式

| 策略 | 说明 |
|---|---|
| 每轮先写候选池 | 不直接升级成长期记忆 |
| 去重与合并 | 同义、同 scope、同 subject 的候选要合并 |
| 升级门槛 | 需要高置信、重复出现或用户确认 |
| 生命周期状态 | `active / stale / superseded / retracted / deleted` |
| 周期压缩 | 旧动态记忆合并成更粗粒度摘要 |

## 8. 召回协议

### 8.1 推荐链路

```text
用户问题
  -> Scope Filter
  -> Memory Kind Filter
  -> Structured Read Model Lookup
  -> Keyword Recall
  -> Vector Recall
  -> Merge & Rank
  -> Budget Trim
  -> MemoryPack / ContextPack Injection
```

### 8.2 为什么不能直接把召回决策全交给模型

| 原因 | 说明 |
|---|---|
| 模型不掌握授权边界 | 先做 scope filter 是硬约束 |
| 模型倾向多拿上下文 | 容易污染 |
| 模型很难稳定做预算裁剪 | 这应该是系统职责 |

### 8.3 毛球当前基础

| 当前模块 | 作用 |
|---|---|
| `MemoryRetriever` | 检索前先做 scope 校验 |
| `MemoryPack.filter_for_public_context` | 公共问答过滤私域记忆 |
| `MemoryPack.filter_for_pet_context` | 私域宠物问答只保留当前 pet 记忆 |
| `MemoryPack.filter_for_household_context` | 家庭上下文只保留当前 household 记忆 |

## 9. 召回排序与裁剪协议

### 9.1 排序原则

| 维度 | 优先级 |
|---|---|
| scope 精确匹配 | 最高 |
| 明确确认过的静态偏好 | 高 |
| 与当前问题类型匹配的动态记忆 | 高 |
| 较新的动态记忆 | 中 |
| 低置信弱结论 | 低 |

### 9.2 裁剪原则

| 顺序 | 优先裁掉什么 |
|---|---|
| 1 | 最旧、最低置信的动态记忆 |
| 2 | 与当前问题类型无关的动态记忆 |
| 3 | 较老的会话摘要片段 |
| 4 | 强事实最后裁剪 |

## 10. 上下文注入协议

### 10.1 注入顺序

```text
Static System Prompt
  -> Capability Boundary
  -> ContextPack
  -> Session Summary
  -> RecentConversationPack
  -> MemoryPack
  -> Visible Tools
  -> Current User Message
```

### 10.2 注入边界

| 包 | 应承载什么 | 不应承载什么 |
|---|---|---|
| `ContextPack` | 当前 surface、locale、timezone、selected pet、authorized pets、session summary | 数据库字段、内部状态、provider 细节 |
| `RecentConversationPack` | 投影后的 role/content/tool_call_id/tool_calls | verification/provider/model/raw payload |
| `MemoryPack` | 已经通过 scope 和预算过滤的摘要条目 | 未确认原文、私有原始 payload |

## 11. 会话摘要协议

### 11.1 摘要的定位

| 问题 | 结论 |
|---|---|
| summary 是不是长期记忆 | 不是，它是历史压缩层 |
| summary 能不能替代事实 | 不能 |
| summary 的作用 | 让长会话在预算内恢复上下文 |

### 11.2 当前毛球实现已经正确的点

| 当前实现 | 价值 |
|---|---|
| `to_context_summary()` 添加“历史参考”前缀 | 防止旧任务被重新激活 |
| `compressed_until_message_id` | 明确压缩边界 |
| `superseded_at` | 明确旧摘要替代关系 |
| `CompressionThreshold::should_compress` | 已有消息数、字节数、旧会话恢复三种触发因子 |

## 12. 上下文预算协议

### 12.1 当前基础

| 当前模块 | 作用 |
|---|---|
| `ContextBudgetPolicy` | 按 turn 数和字节数裁掉最近历史 |
| `CompressionThreshold` | 决定何时要压缩 summary |

### 12.2 推荐规则

| 规则 | 说明 |
|---|---|
| 历史窗口预算 | 由 `RecentConversationPack` 先按 turn/bytes 硬裁剪 |
| 摘要触发预算 | 达到 provider profile 预算阈值前先压缩旧历史 |
| 记忆预算 | `MemoryPack` 独立有 top-k 和 bytes/token 上限 |
| 不同 provider 可有不同默认值 | 预算策略应受 `Provider Capability Contract` 管理 |

## 13. 检索系统在毛球上不需要什么

| 不需要 | 原因 |
|---|---|
| AST 分析 | 这是代码 Agent 的能力，不适合宠物垂直 Agent |
| 调用链分析 | 毛球需要的是事实引用链，而不是代码调用链 |

### 13.1 对应替代物

| 代码 Agent 能力 | 毛球对应能力 |
|---|---|
| AST | 结构化事实 schema |
| 调用链 | 事实引用链 / 症状线程 / 事件 lineage |

## 14. 对毛球当前实现的直接要求

| 要求 | 说明 |
|---|---|
| 明确 `static long` 与 `dynamic long` 的领域模型 | 当前只有总的 MemoryPack 语义，还未正式拆层 |
| 候选池先于长期记忆升级 | 当前文档和 migration 方向已对，后续实现要坚持 |
| 召回流程必须先 scope filter | 不能让模型决定先搜什么 scope |
| summary 必须继续是派生层 | 不允许把摘要当事实权威 |
| 预算策略纳入 provider profile | 与 `07` 文档打通 |

## 15. 不变约束

| 约束 | 说明 |
|---|---|
| 私域记忆必须先做 scope 过滤 | 绝不把未授权 pet/household 记忆放进候选 |
| 短期、长期、摘要、候选池不能混成一层 | 每层职责不同 |
| 检索系统不让模型裸搜全库 | 检索由系统决定，模型只消费结果 |
| Summary 不激活旧任务 | 保持当前安全语义不变 |

## 16. 风险

| 风险 | 处理 |
|---|---|
| 继续把所有记忆都丢进一个包 | 后续一定会污染上下文 |
| 跳过候选池直接升级长期记忆 | 记忆膨胀和漂移会很快出现 |
| 只做语义召回不做 scope filter | 会直接破坏隐私隔离 |
| 让 summary 参与事实判断 | 会造成历史幻觉和错误推理 |

