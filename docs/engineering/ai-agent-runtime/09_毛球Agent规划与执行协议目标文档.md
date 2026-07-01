# 毛球Agent规划与执行协议目标文档

- 更新时间：2026-06-30
- Goal：定义毛球 Agent 的 `Planning & Execution Contract`，明确用户需求如何被理解为任务、任务如何拆成 step、step 如何推进、何时调用模型、何时调用工具、失败后如何重规划
- 执行方式：先目标文档后实现；在现有 `AiIntentGate / EvidencePlanner / RuntimePhase / LoopStep / PolicyGuard` 基础上收敛协议，不引入兼容旧模式

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 规划不是总要显式存在 | 不是所有请求都需要一个重型 planner |
| 毛球当前最需要的规划 | 先有“轻规划协议”，再决定以后是否引入复杂 planner |
| 当前最佳实践 | `Intent Gate -> Task Type -> Step Plan -> Runtime Execution -> Finalizer -> Optional Replan` |
| 模型和工具的分工 | 模型负责理解、解释、选择下一步；工具负责读事实和执行副作用 |
| 当前毛球现状 | 已经有 `AiIntentGate`、`EvidencePlanner`、`RuntimePhase`、`LoopStep`、`PolicyGuard`，但它们还没有被正式定义为统一的规划执行协议 |
| 当前核心缺口 | 缺少正式的 `Task/Step/ExecutionPolicy/ReplanPolicy` 协议层 |

## 2. 目标边界

### 2.1 本目标期必须明确

| 范围 | 目标 |
|---|---|
| 任务定义 | 明确什么请求是直接回答，什么请求是多步任务 |
| Step 定义 | 明确 step 的种类、输入、输出和依赖 |
| 执行顺序 | 明确先做什么后做什么 |
| 模型 vs 工具 | 明确什么时候调用模型、什么时候调用工具 |
| 停止条件 | 明确一轮或一步何时视为完成 |
| 重规划条件 | 明确什么失败要重试，什么失败要重规划，什么失败要直接终止 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 通用多 agent planner | 当前先聚焦单 agent 主链路 |
| 复杂 DAG 调度器 | 当前先把 step 顺序链路定住 |
| 自由长计划文档生成 | 当前先定义协议，不做交互式计划产物系统 |

## 3. 依据

### 3.1 项目内依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| Intent Gate | `maohuoban-ai-domain/src/ai/model/intent.rs` | 当前已定义 `AiIntent`、`AiGateDecision`，并决定是否进入 Workbench |
| 证据预取 | `maohuoban-ai-application/src/ai/runtime/evidence_planner.rs` | 当前已能基于用户问题和 fact schema 预取只读工具 |
| 执行阶段 | `maohuoban-ai-application/src/ai/runtime/runtime_phase.rs` | 当前已把 loop 拆成 `Model / ToolExecution / EvidenceToolExecution / FollowupModel / Done` |
| Runtime Step | `maohuoban-ai-domain/src/ai/model/runtime.rs` | 当前已有 `LoopStep::CallModel / MessageDelta / CallTools / Done` |
| Tool Result | `LoopToolResult / LoopToolStatus` | 当前工具结果已能表达 `Requested / Succeeded / Denied / Failed / RequiresConfirmation` |
| Policy | `maohuoban-ai-application/src/ai/policy/guard.rs` | 当前已能决定 allow/deny/require confirmation |
| Runtime Loop | `maohuoban-ai-application/src/ai/runtime/agent_runtime_loop_engine.rs` | 当前已具备 `模型 -> 工具 -> 再生成 -> Done` 的闭环 |

### 3.2 参考实现依据

| 参考项目 | 启发 |
|---|---|
| `codex` | turn 内部执行其实是 step 状态机，而不是自由流 |
| `pi` | assistant -> tool -> toolResult -> next turn 是固定主干 |
| `openclaw` | 先装配 attempt 运行态，再进入工具和消息循环 |
| `hermes-agent` | 一轮 `run_conversation` 内部已经隐含了任务推进和失败恢复规则 |

## 4. 规划协议的目标

### 4.1 任务不是一句话

用户输入进入后，不应直接理解为“交给模型输出一段话”，而应先映射成任务类型：

| 任务类型 | 说明 | 毛球示例 |
|---|---|---|
| `direct_answer` | 当前上下文足够，直接回答 | “猫拉肚子一般观察什么” |
| `context_answer` | 需要加载私域上下文 | “豆包几岁了” |
| `evidence_read_task` | 需要读工具取证 | “查近 7 天饮食变化” |
| `clarification_task` | 当前信息不足，先追问 | “它今天不舒服” |
| `write_task` | 需要副作用写入，必须确认 | “把这个症状记下来” |
| `reject_task` | 不进入执行链 | prompt injection / cost abuse |

### 4.2 Step 才是执行单位

| 对象 | 粒度 |
|---|---|
| session | 多轮长期容器 |
| turn | 一次完整执行 |
| task | 当前 turn 的任务目标 |
| step | 当前任务内的最小可推进单元 |

## 5. Step 协议

### 5.1 建议 Step 种类

| Step 类型 | 作用 |
|---|---|
| `load_context` | 装配当前轮上下文 |
| `prefetch_evidence` | 基于问题预取必要事实 |
| `model_reason` | 让模型基于当前证据决定下一步或生成回答 |
| `tool_read` | 调用只读工具 |
| `tool_write_prepare` | 组织写入参数与确认问题 |
| `tool_write_commit` | 用户确认后实际执行写入 |
| `clarify_user` | 向用户补问关键信息 |
| `finalize_answer` | 形成终态回答文本 |

### 5.2 当前毛球已有的 Step 映射

| 当前实现 | 对应 Step |
|---|---|
| `TurnContextBuilder` | `load_context` |
| `EvidencePlanner` | `prefetch_evidence` |
| `RuntimePhase::StreamingModel` | `model_reason` |
| `RuntimePhase::ToolExecution` | `tool_read` / `tool_write_prepare` |
| `LoopToolStatus::RequiresConfirmation` | `tool_write_prepare` 进入确认态 |
| `RuntimePhase::Done` | `finalize_answer` |

## 6. 执行顺序协议

### 6.1 推荐默认顺序

```text
Intent Gate
  -> load_context
  -> prefetch_evidence (optional)
  -> model_reason
  -> tool_read/tool_write_prepare (optional)
  -> followup model_reason (optional)
  -> finalize_answer
  -> finalizer
```

### 6.2 先后顺序规则

| 规则 | 说明 |
|---|---|
| 先判断是否需要上下文 | 不需要私域上下文的请求不读私域工具 |
| 先取证再总结 | 私域事实问题不能让模型先“猜” |
| 先确认再写入 | 写工具必须经过确认态 |
| 先失败分类再决定是否重规划 | 不能所有失败都直接重试 |

## 7. 什么时候调用模型，什么时候调用工具

### 7.1 调模型的场景

| 场景 | 原因 |
|---|---|
| 理解用户表达 | 语义理解和任务归类 |
| 整合事实 | 把多条证据组织成回答 |
| 生成追问 | 判断当前最关键缺失信息 |
| 生成解释文本 | 给用户看的人类可读答案 |
| 选择下一步 | 是否需要更多工具、是否可以结束 |

### 7.2 调工具的场景

| 场景 | 原因 |
|---|---|
| 读取宠物事实 | 模型自己不知道数据库事实 |
| 读取历史结构化记录 | 必须通过工具网关 |
| 创建确认任务 / 建议动作 | 是副作用 |
| 执行最终写入 | 也是副作用 |

### 7.3 决策边界

| 规则 | 归属 |
|---|---|
| 是否需要工具 | 先由 Runtime/Planner 判断，模型辅助 |
| 工具是否允许执行 | PolicyGuard 决定 |
| 工具执行结果是否足够 | 模型 + Runtime 共同决定 |
| 是否结束 | Runtime 状态机决定 |

## 8. 停止条件协议

### 8.1 单步停止条件

| Step | 停止条件 |
|---|---|
| `prefetch_evidence` | 拿到足够事实或没有可用工具 |
| `model_reason` | 得到最终回答 / tool call / clarification / error |
| `tool_read` | 得到成功/拒绝/失败/确认态 |
| `clarify_user` | 已生成待问问题并停止当前执行 |
| `finalize_answer` | 已生成终态文本 |

### 8.2 整轮停止条件

| 条件 | 结果 |
|---|---|
| 有最终文本且无更多工具调用 | `completed` |
| provider/tool/runtime 无法继续 | `failed` |
| 用户确认前必须停 | `requires_confirmation` |
| 用户中断或外部取消 | `interrupted` |

## 9. 重试 vs 重规划协议

### 9.1 什么叫重试

重试：**同一个 step，参数和目标基本不变，只是再执行一次。**

### 9.2 什么叫重规划

重规划：**当前路径已经不成立，需要重新决定下一步。**

### 9.3 判定规则

| 失败类型 | 处理 |
|---|---|
| provider timeout | 可重试 |
| stream interrupted | 可重试或恢复 |
| tool 参数格式错 | 小范围修正后重试 |
| tool 未授权 | 不重试，直接终止或拒绝 |
| 证据不足 | 重规划为追问或读其他工具 |
| 上下文超限 | 先压缩，再重试 |
| guardrail hard stop | 不重试，直接失败 |

## 10. 重规划协议

### 10.1 典型触发点

| 触发点 | 说明 |
|---|---|
| 取证后发现问题类型和预期不同 | 需要换工具或换回答路径 |
| 工具全部失败但问题还可通过追问推进 | 需要改成 clarification |
| 读到的事实冲突 | 需要改成确认或谨慎说明 |
| 当前 selected pet 不足以完成任务 | 需要改成 pet clarification |

### 10.2 毛球上的典型例子

| 用户输入 | 首轮路径 | 重规划路径 |
|---|---|---|
| “它今天不舒服” | 直接回答会很空 | 改成 `clarification_task` |
| “帮我记一下今天拉稀” | 直接写入不安全 | 改成 `tool_write_prepare -> requires_confirmation` |
| “豆包最近是不是换粮了” | 先读饮食上下文 | 若无记录，改成“无记录 + 引导补记” |

## 11. 当前毛球实现应如何收紧

### 11.1 当前已有但还未协议化的部分

| 当前能力 | 问题 |
|---|---|
| `EvidencePlanner` | 只是局部预取，不是正式 step planner |
| `RuntimePhase` | 是内部状态机，但还不是文档化执行协议 |
| `AiIntentGate` | 入口判断有了，但和 task type 还没正式映射 |
| `LoopStep` | 已是执行单元雏形，但还没上升到 `Task/Step Contract` |

### 11.2 推荐新增抽象

| 抽象 | 作用 |
|---|---|
| `TaskType` | 把输入映射为任务类型 |
| `ExecutionStep` | 正式定义 step 种类 |
| `ExecutionPolicy` | 定义顺序、停止条件、预算和并发规则 |
| `ReplanPolicy` | 定义失败后是 retry 还是 replan |

## 12. 和前面文档的关系

| 文档 | 本文怎么依赖它 |
|---|---|
| `03 Session Contract` | task/step 最终都属于某个 session |
| `04 Turn Contract` | planning/execution 都在一个 turn 内发生 |
| `05 Tool Contract` | step 的工具执行依赖它 |
| `06 Finalizer Contract` | 执行结束后的收口依赖它 |
| `07 Provider Capability Contract` | provider 失败是否重试、预算是否压缩依赖它 |
| `08 Memory & Retrieval Contract` | `load_context/prefetch_evidence` 依赖它 |

## 13. 不变约束

| 约束 | 说明 |
|---|---|
| 不让模型自由决定全部流程 | Runtime 必须保有控制权 |
| 私域事实问题先取证再回答 | 防止无依据回答 |
| 写入一定经过确认态 | 不绕过工具确认协议 |
| retry 和 replan 必须区分 | 否则会陷入死循环或错误重试 |

## 14. 风险

| 风险 | 处理 |
|---|---|
| 把轻规划做成重型复杂 planner | 当前先保持 step 协议轻量，避免过度设计 |
| 所有失败都统一重试 | 会浪费 token 且隐藏真实问题 |
| planner 逻辑散在 loop 各处 | 后续实现时应集中到统一 policy 层 |
| 模型和系统都能改执行顺序 | 必须明确 Runtime 是主导者 |

