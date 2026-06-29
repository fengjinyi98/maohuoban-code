# 毛球 Agent 入口路由与硬软边界混淆 Issue

- 创建时间：2026-06-28
- 文档类型：Issue / 架构问题记录
- 当前状态：已确认问题归属，待 ADR / 目标文档承接
- 关联链路：iOS AI 聊天页、Rust AI HTTP Stream、Agent Runtime、Intent Gate、Fact Projection、Tool Gateway、Diagnostics SDK

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 问题类型 | 工程架构边界问题 |
| 直接表现 | 用户问“几岁了”“你是谁”时，后端返回固定边界文案：“我现在只能处理宠物照护、宠物记录和毛伙伴 App 相关问题。” |
| 运行时事实 | SDK 观测显示这些请求没有进入安全硬拦截，`allow_processing=true`、`blocked_reason=null`、`verification_status=passed` |
| 核心根因 | 当前 `context_loaded=false` 同时承担“不加载宠物事实”和“不进入 Agent / Provider”的执行含义 |
| 当前风险 | 继续补关键词会让意图分类器膨胀，真实用户短追问、上下文省略、助手身份问题会持续误伤 |
| 本文边界 | 只记录问题、证据、根因和影响，不定义解决方案 |

## 2. 现象记录

| 用户输入 | 当前表现 | 问题含义 |
|---|---|---|
| `几岁了` | 被识别为 `off_topic`，返回固定边界文案 | 短追问没有被会话语义承接 |
| `你是谁` | 被识别为 `off_topic`，返回固定边界文案 | 助手身份问题被当作普通非宠物话题 |
| 非宠物泛话题 | 返回固定边界文案 | 普通产品边界和拒答体验混在一起 |
| Prompt injection / 越权读取 / 成本滥用 | 与普通 off-topic 共用入口分支 | 安全硬边界和普通软边界共用完成路径 |

## 3. 证据

### 3.1 SDK 观测证据

| 时间 | 事件 | 关键字段 | 结论 |
|---|---|---|---|
| 2026-06-28 17:29:27 | `ai.chat.gate.decided` | `intent=off_topic`、`gate_decision=skip_main_agent`、`allow_processing=true`、`context_loaded=false` | 这是软路由跳过主链路，不是安全阻断 |
| 2026-06-28 17:29:27 | `ai.chat.stream.event.emitted` | `event_name=message_completed`、`input_tokens=0`、`output_tokens=0`、`verification_status=passed`、`blocked_reason=null` | 后端直接完成固定回复，Provider 未参与 |
| 2026-06-28 17:30:33 | `ai.chat.gate.decided` | `intent=off_topic`、`gate_decision=skip_main_agent`、`allow_processing=true` | 同类输入重复触发同一路径 |
| 2026-06-28 17:28:45 / 17:29:13 | `ai.chat.provider.started` | `fact_package_present=true`、`target_pet_present=true`、`initial_event_count=5` | 宠物问题链路已能进入 Provider / Runtime |

诊断包路径：

```text
.maohuoban-diagnostics/latest/index.json
.maohuoban-diagnostics/latest/timeline.jsonl
.maohuoban-diagnostics/latest/prompt.md
```

### 3.2 代码证据

| 层 | 文件 | 事实 |
|---|---|---|
| Intent Domain | `maohuoban-rust/crates/maohuoban-ai-domain/src/ai/model/intent.rs` | `allow_processing()` 只对 `PromptInjection` / `CostAbuse` 返回 false |
| Stream Handler | `maohuoban-rust/crates/maohuoban-ai-http/src/Infrastructure/ai/router/chat/stream_handler.rs` | `if !gate_decision.context_loaded { return gated_stream_response(...) }` |
| Gated Response | `maohuoban-rust/crates/maohuoban-ai-http/src/Infrastructure/ai/router/chat/gated_stream_response.rs` | `OffTopic`、`AppSupport` 和安全风险共用不进入主 Agent 的响应构造 |
| Intent Gate | `maohuoban-rust/crates/maohuoban-ai-application/src/ai/intent/mod.rs` | 宠物上下文识别依赖关键词，`年龄` 命中，`几岁了` / `多大了` 没有独立表达 |
| Prompt Builder | `maohuoban-rust/crates/maohuoban-ai-application/src/ai/prompt/mod.rs` | 已有“只有用户明确询问你是谁时才说明你是毛球助手”的系统规则，但当前 gate 短路导致模型没有机会执行 |

### 3.3 文档证据

| 文档 | 相关结论 |
|---|---|
| `docs/engineering/ai-agent-runtime/00_毛球AgentRuntime架构讨论记录.md` | 已记录“只靠代码关键词判断用户意图会越来越硬，无法覆盖真实用户语义” |
| `docs/engineering/agent-memory-security/00_毛球Agent记忆隔离与工具安全目标文档.md` | 已定义 Agent Gateway、工具授权、事实白名单、prompt 不是安全边界等原则 |

## 4. 架构问题拆解

| 当前设计点 | 问题 |
|---|---|
| `AiIntentGate` 输出 `context_loaded` | 字段名表达事实加载，实际驱动了执行路径 |
| HTTP Handler 直接读取 `context_loaded` 分支 | 应用层把规划决策折叠为固定响应策略 |
| `gated_stream_response` 同时服务 off-topic / app_support / prompt injection / cost abuse | 软产品边界和硬安全边界共用一套完成语义 |
| 短追问依赖关键词命中 | 缺少会话上下文解析层，无法理解“几岁了”这类省略主语 |
| 身份问题被 off-topic 截断 | 助手身份路由缺失，系统 prompt 无法发挥作用 |
| `verification=passed` 配合固定拒答 | 输出校验状态和产品路由状态混淆，观测语义不足 |

## 5. 为什么会出问题

### 5.1 决策字段被复用

| 字段 / 分支 | 原始语义 | 实际语义漂移 |
|---|---|---|
| `context_loaded` | 是否需要加载宠物私有事实 | 是否进入主 Agent / Provider |
| `allow_processing` | 是否允许继续处理请求 | 没有参与 `context_loaded=false` 的实际分支裁决 |
| `gate_decision=skip_main_agent` | 跳过主 Agent 的执行路径标签 | 被用户体验感知为“硬拒答” |
| `verification=passed` | 输出校验通过 | 不能表达“这是固定边界回复还是正常回答” |

`AiGateDecision::allow_processing()` 已经把安全阻断限定在 `PromptInjection` 和 `CostAbuse`。但 Stream Handler 没有先判断硬安全，而是直接用 `context_loaded=false` 返回 `gated_stream_response`。因此 `off_topic` 这类非硬安全意图虽然 `allow_processing=true`，仍然不会进入后续表达路径。

### 5.2 Handler 把加载事实和回答生成绑在一起

当前 stream 入口的分支顺序是：

```text
classify(message)
  -> resolve pet only when context_loaded=true
  -> persist current turn
  -> load pet catalog initial events only when context_loaded=true
  -> if context_loaded=false return gated_stream_response
  -> provider_response_for_context
```

这条链路导致一个副作用：只要某个输入不触发宠物事实加载，它就被直接完成为固定边界回复。这里的问题不是分类器漏了某个词，而是“事实加载开关”被用成了“回答执行开关”。

### 5.3 固定边界响应承担了过多语义

| 分支 | 当前共用响应 | 语义冲突 |
|---|---|---|
| `off_topic` | `gated_stream_response` | 普通非宠物话题被呈现成强边界拒答 |
| `app_support` | `gated_stream_response` | App 帮助本应是产品能力，却与拒答共用框架 |
| `prompt_injection` | `gated_stream_response` | 安全风险与普通软路由共用完成状态 |
| `cost_abuse` | `gated_stream_response` | 成本风险与普通软路由共用完成状态 |

`gated_stream_response` 的注释写着“构建不进入主 Agent 的安全 SSE 响应”，但它实际覆盖了 off-topic、app support 和风险请求。这个命名和职责扩大让后续实现更容易把“非宠物 / 不加载事实”理解成“安全边界”。

### 5.4 分类器没有会话语义

| 输入 | 为什么容易误判 |
|---|---|
| `几岁了` | 省略了宠物主语，当前分类器只看本轮文本，不看上一轮目标宠物和 selected pet |
| `你是谁` | 是助手身份问题，不属于宠物事实问题，但也不是非宠物泛聊 |
| `再确认下我的宠物信息` | 能命中宠物，但后续追问会丢失同一上下文 |

当前分类器是单轮关键词判断。它可以命中显式关键词，例如“宠物”“猫”“年龄”，但无法理解短追问、上下文省略和助手身份问题。继续给关键词表加“几岁”“多大”“你是谁”只能修局部样例，不能改变系统缺少会话语义的问题。

### 5.5 旧契约把当前行为固化了

现有测试中存在“off-topic 请求跳过主 Provider”的契约。这类测试原本用于控制成本和隐私，但它也把 `off_topic = skip_main_agent = fixed boundary message` 固化成默认行为。测试保护了旧边界，也阻碍了硬边界和软路由分离。

### 5.6 观测字段不足以表达真实状态

SDK 当前能看到：

```text
intent=off_topic
gate_decision=skip_main_agent
context_loaded=false
allow_processing=true
verification_status=passed
blocked_reason=null
input_tokens=0
output_tokens=0
```

这些字段能证明请求没有进 Provider，也能证明不是安全阻断。但它不能表达“为什么这个 allow_processing=true 的请求仍然被固定回复完成”。缺少更上层的执行语义，导致排查时容易在意图关键词、prompt 或模型表现之间来回猜。

## 6. 不是哪些问题

| 不是 | 依据 |
|---|---|
| 不是 iOS 渲染问题 | iOS 正常消费了 `message_started` 和 `message_completed`，文本来自后端最终事件 |
| 不是 DeepSeek / 本机 3050 Provider 问题 | 问题请求 `input_tokens=0`、`output_tokens=0`，Provider 没有参与 |
| 不是单纯 prompt 问题 | 系统 prompt 已写助手身份规则，但请求被 handler 短路，模型没有机会执行 |
| 不是单个关键词缺失问题 | “几岁了”确实可被关键词修掉，但“你是谁”和更多短追问仍会暴露同一边界混淆 |
| 不是安全硬拦截生效 | 观测中 `allow_processing=true`、`blocked_reason=null`、`verification_status=passed` |

## 7. 影响范围

| 范围 | 影响 |
|---|---|
| 用户体验 | 用户正常追问会收到拒答式文案，破坏连续对话感 |
| 产品边界 | 毛球助手身份、App 帮助、普通软边界与安全拒绝混在一起 |
| 后端架构 | HTTP handler 承担了过多路由语义，Application 层没有独立表达 turn 决策 |
| 观测诊断 | 只能看到 gate 结果和完成事件，缺少能解释执行路径的中间语义 |
| 测试体系 | 部分契约测试锁住了旧行为，后续重构容易被旧语义牵制 |
| 扩展性 | 接更多模型、更多工具、更多软边界场景时，分支会继续堆在 handler 和关键词分类器上 |

## 8. 不变约束

| 约束 | 说明 |
|---|---|
| 前端只消费后端事件 | 工具进度文案、软边界状态、引用和完成状态仍由后端提供 |
| LLM 看不到内部字段 | 事实投影继续裁剪内部 key、生命周期内部状态和架构细节 |
| Prompt 不是安全边界 | 权限、医疗、写入确认、越权、成本滥用由后端策略裁决 |
| 宠物事实以 `pet_id` 为根 | 宠物名只用于展示和候选解析，不能替代授权身份 |
| 引用基于事实使用 | 引用只绑定回答实际使用的事实 |
| Provider 可替换 | DeepSeek / OpenAI compatible / 后续 GLM / Kimi 适配不能改变业务安全边界 |

## 9. 问题继续存在的风险

| 风险 | 后果 |
|---|---|
| 继续补关键词 | 分类器越来越重，仍然无法覆盖上下文省略和多轮追问 |
| 继续改 prompt | 被 handler 短路的请求仍然不会进入模型，prompt 改动没有执行机会 |
| 继续把 off-topic 当硬边界 | 用户会把正常身份问题、短追问和 App 帮助理解为产品拒绝 |
| 继续共用 `gated_stream_response` | 安全阻断、软边界、产品帮助和普通完成状态会继续混淆 |
| 继续缺少执行语义观测 | 后续排查会反复落到“模型问题 / prompt 问题 / 分类器问题”的猜测循环 |
