# 毛球Agent意图闸门协议目标文档

- 更新时间：2026-06-30
- Goal：定义毛球 Agent 的 `Intent Gate Contract`，明确用户输入进入系统后的第一层判断边界：哪些请求进入主 Agent、哪些只走轻量回复、哪些必须被硬拦截
- 执行方式：先目标文档后实现；以现有 `AiIntentGate`、`AiIntent`、`AiGateDecision`、`gated_stream_response` 为基础收敛协议，不引入兼容旧模式

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 意图闸门是什么 | Agent 链路的第一层入口协议 |
| 它的作用 | 决定当前请求是否进入主 Agent、是否加载私域上下文、是否直接走轻量响应、是否硬拦截 |
| 为什么必须先有它 | 因为后面的 planner、tool、memory、provider 都建立在入口边界之上 |
| 当前毛球现状 | 已经有 `AiIntentGate` 规则分类器，并已将 `PromptInjection / CostAbuse` 硬拦截、`AppSupport / OffTopic` 轻量化 |
| 当前核心缺口 | 还没有正式文档把“分类、边界、输出路径、风险信号、诊断字段”固定下来 |
| 直接结论 | 意图闸门不是“附属判断”，而是整个 Agent 主链路的前置协议与成本/安全/上下文边界控制面 |

## 2. 目标边界

### 2.1 本目标期必须明确

| 范围 | 目标 |
|---|---|
| 分类目标 | 明确有哪些意图类型 |
| 边界目标 | 明确哪些进入主 Agent，哪些跳过 Provider，哪些硬拦截 |
| 上下文目标 | 明确哪些意图允许加载私域宠物上下文 |
| 风险目标 | 明确哪些意图携带风险信号 |
| 输出目标 | 明确 gate 分支的稳定输出语义 |
| 诊断目标 | 明确 gate 日志和观测点必备字段 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 大模型分类器替代规则分类器 | 当前先固化协议边界，分类实现以后再升级 |
| 复杂多标签混合意图系统 | 当前先以单主意图驱动主链路 |
| 个性化 gate | 当前先做平台统一边界，不做用户级差异化 |

## 3. 依据

### 3.1 项目内依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| 意图枚举 | `maohuoban-ai-domain/src/ai/model/intent.rs` | 已有 `AiIntent` 与 `AiGateDecision` |
| 规则分类器 | `maohuoban-ai-application/src/ai/intent/mod.rs` | 已有 `AiIntentGate::classify()` |
| 行为判断 | `AiGateDecision::allow_processing / enters_workbench / requires_context_load` | 已有入口行为语义基础 |
| 入口使用 | `maohuoban-ai-http/.../chat/turn_preparation.rs` | 当前请求入口已经先走 gate 分类 |
| 轻量绕过路径 | `gated_stream_response.rs` | 当前 `AppSupport / PromptInjection / CostAbuse` 已有独立响应路径 |
| 测试覆盖 | `maohuoban-ai-application/tests/intent_gate.rs` | 已覆盖典型中文输入和 workbench 进入条件 |

### 3.2 当前已有意图类型

| 意图 | 当前含义 |
|---|---|
| `PetCare` | 宠物一般照护问题 |
| `PetRecordQuery` | 宠物记录查询 |
| `PetFood` | 饮食、主粮、储物柜、换粮 |
| `PetHealthRisk` | 异常、症状、风险场景 |
| `EmotionalPetContext` | 宠物相关情感表达 |
| `AppSupport` | 毛伙伴 App 使用帮助 |
| `OffTopic` | 非宠物泛话题 |
| `PromptInjection` | 越权、绕过、读库等危险诱导 |
| `CostAbuse` | 长文本创作、代码、批量生成等成本滥用 |

## 4. 意图闸门在链路中的位置

```text
用户输入
  -> Intent Gate
     -> hard block
     -> light response
     -> enters workbench
  -> (if enters workbench)
     TurnContextBuilder
     -> Planner / Runtime / Tool / Finalizer
```

关系：

| 层 | gate 决定什么 |
|---|---|
| Session | 是否值得新建本轮执行 |
| Turn | 本轮的主意图和风险标签 |
| Planner | 是否继续进入 step 规划 |
| Tool | 是否允许私域工具进入候选 |
| Memory | 是否允许加载私域记忆 |
| Provider | 是否值得消耗上游模型调用 |

## 5. Intent Gate 的目标

### 5.1 它必须回答的三个问题

| 问题 | 说明 |
|---|---|
| `这个请求是不是毛球该处理的` | 决定是否进入主链路 |
| `这个请求需不需要私域上下文` | 决定是否加载 pet/private memory/tool |
| `这个请求是不是风险请求` | 决定是否硬拦截或降级 |

### 5.2 它不负责什么

| 不负责 | 原因 |
|---|---|
| 完整任务规划 | 这是 planner 的职责 |
| 工具参数构造 | 这是 runtime/tool 层职责 |
| 实际工具执行 | 这是 tool gateway 职责 |
| 最终回答生成 | 这是 runtime/model/finalizer 职责 |

## 6. 分类协议

### 6.1 建议意图层次

| 层次 | 含义 | 当前毛球是否已有 |
|---|---|---|
| `pet_domain_private` | 需要私域上下文的宠物请求 | 已由 `PetCare/PetRecordQuery/PetFood/PetHealthRisk/EmotionalPetContext` 覆盖 |
| `pet_domain_public` | 宠物相关但不需要私域数据 | 当前主要落在 `PetCare`，后续可细分 |
| `app_support` | 产品帮助 | 已有 |
| `off_topic_soft` | 可轻量回复再拉回 | 已有 `OffTopic` |
| `hard_block_security` | 安全硬拦截 | 已有 `PromptInjection` |
| `hard_block_cost` | 成本硬拦截 | 已有 `CostAbuse` |

### 6.2 当前规则实现已经表达出的优先级

当前顺序是：

```text
prompt injection
  -> cost abuse
  -> pet health risk
  -> pet food
  -> pet record query
  -> emotional pet context
  -> app support
  -> pet care
  -> off topic
```

这条优先级是合理的：

| 规则 | 原因 |
|---|---|
| 安全类最高优先 | 先阻断危险路径 |
| 成本类次高 | 先挡住明显滥用 |
| 高风险症状高于普通宠物问题 | 优先进入健康风险路径 |
| App 支持高于 OffTopic | 避免把产品问题误杀成闲聊 |

## 7. Gate 决策协议

### 7.1 决策对象

当前 `AiGateDecision` 已经基本正确：

| 字段 | 作用 |
|---|---|
| `intent` | 主意图 |
| `context_loaded` | 是否加载私域上下文 |
| `risk_signal` | 风险标签 |
| `reason` | 可读解释 |

### 7.2 建议固定三个方法语义

| 方法 | 语义 |
|---|---|
| `requires_context_load()` | 决定是否加载私域 pet/context/memory/tool |
| `allow_processing()` | 决定是否允许进入主 Agent 编排 |
| `enters_workbench()` | 决定是否进入 `AgentSessionWorkbench` |

### 7.3 当前边界

当前 `enters_workbench()` 的语义是：

| 意图 | 是否进入 Workbench |
|---|---|
| `PromptInjection` | 否 |
| `CostAbuse` | 否 |
| 其他 | 是 |

这是正确的，因为：
- `AppSupport` 和 `OffTopic` 仍可能需要受控轻量回复
- 只有硬安全阻断才真正不进入主执行面

## 8. 上下文加载协议

### 8.1 私域上下文何时加载

| 意图 | 当前规则 |
|---|---|
| `PetCare` | 加载 |
| `PetRecordQuery` | 加载 |
| `PetFood` | 加载 |
| `PetHealthRisk` | 加载 |
| `EmotionalPetContext` | 加载 |
| `AppSupport` | 不加载 |
| `OffTopic` | 不加载 |
| `PromptInjection` | 不加载 |
| `CostAbuse` | 不加载 |

### 8.2 为什么 `AppSupport` 不加载

| 原因 | 说明 |
|---|---|
| 产品问题不需要宠物事实 | 避免浪费 token |
| 降低隐私风险 | 帮助类问题不应顺手带出宠物私域数据 |

### 8.3 为什么 `OffTopic` 也不加载

| 原因 | 说明 |
|---|---|
| 非宠物话题本来就不需要私域事实 | 保持成本和隐私边界 |
| 后续如要轻量拉回，也不需要 pet context | 只需边界话术 |

## 9. 输出路径协议

### 9.1 三种路径

| 路径 | 条件 | 后续动作 |
|---|---|---|
| `hard_block` | `PromptInjection / CostAbuse` | 不进 workbench，不调 provider，直接安全回复 |
| `light_response` | `AppSupport / OffTopic` | 可进入 workbench，但默认不加载私域上下文；必要时走轻量固定/模板化回复 |
| `full_agent` | 宠物相关主意图 | 进入完整 runtime |

### 9.2 当前 gated response 语义

| 意图 | 当前回复语义 |
|---|---|
| `AppSupport` | 说明这是 App 帮助，不读取宠物事实 |
| `PromptInjection / CostAbuse` | 说明超出安全边界，不能处理 |
| 其他 gate 跳过情况 | 说明只能处理宠物照护、记录和 App 相关问题 |

## 10. 风险信号协议

### 10.1 哪些意图必须打风险标签

| 意图 | 风险标签 |
|---|---|
| `PromptInjection` | `prompt_injection` |
| `CostAbuse` | `cost_abuse` |

### 10.2 后续建议扩展

| 建议信号 | 用途 |
|---|---|
| `admin_impersonation` | 更细粒度的安全诊断 |
| `data_exfiltration_attempt` | 读库/读全量隐私数据 |
| `creative_bulk_generation` | 区分长文本创作型滥用 |

但这些扩展应该是**风险标签**扩展，不应先拆成更多入口意图枚举。

## 11. 诊断与审计协议

### 11.1 Gate 必须打哪些点

| 事件 | 必备字段 |
|---|---|
| request classified | `intent`, `gate_decision`, `context_loaded`, `risk_signal`, `estimated_input_tokens` |
| gate skipped main agent | `session_id`, `message_id`, `intent` |
| workbench entered | `intent`, `context_loaded`, `resolved_pet_id?` |

### 11.2 当前毛球基础

| 当前实现 | 作用 |
|---|---|
| `ai_request_gate_logs` | 已有 DB 审计表 |
| `diagnostics_common.rs` | 已有诊断投影字段 |
| `intent_gate.rs` 测试 | 已覆盖典型样例 |

## 12. 实现要求

### 12.1 规则分类器保持轻量

| 原则 | 说明 |
|---|---|
| 轻量、稳定、可测试 | 当前阶段先保持规则可控 |
| 不追求一次性识别所有复杂语义 | 真正复杂推进交给 planner/runtime |

### 12.2 后续演进方向

| 阶段 | 方向 |
|---|---|
| 当前 | 规则分类器 + 明确边界 |
| 下一阶段 | 可引入轻量模型分类器，但输出仍必须落到 `AiGateDecision` 协议 |
| 更后阶段 | 可做 hybrid gate，但 Runtime 行为仍只认统一 gate 协议 |

## 13. 和前面文档的关系

| 文档 | 本文依赖方式 |
|---|---|
| `03 Session Contract` | gate 决定是否值得创建和推进 turn |
| `04 Turn Contract` | gate 决定 turn 的 `intent/gate_decision` 字段 |
| `05 Tool Contract` | gate 决定哪些工具可见 |
| `07 Provider Capability Contract` | gate 决定是否值得消耗 provider token |
| `08 Memory & Retrieval Contract` | gate 决定是否加载私域记忆 |
| `09 Planning & Execution Contract` | gate 决定是否进入 planner/runtime |

## 14. 不变约束

| 约束 | 说明 |
|---|---|
| 只有硬安全请求不进入 workbench | 避免把轻量回复路径做得过死 |
| 非私域请求不加载私域上下文 | 严格控制 token 和隐私边界 |
| gate 负责边界，不负责回答内容生成 | 保持职责单一 |
| 风险信号要稳定可审计 | 便于回放和安全治理 |

## 15. 风险

| 风险 | 处理 |
|---|---|
| gate 做得过重，变成第二个 planner | 保持只做入口边界判断 |
| gate 做得过轻，导致私域上下文乱加载 | 用 `requires_context_load` 继续强约束 |
| 分类规则散落多处 | 后续继续集中在 `AiIntentGate` 和契约测试中 |
| 安全标签和意图枚举混在一起失控 | 风险信号扩展与意图扩展分开治理 |

