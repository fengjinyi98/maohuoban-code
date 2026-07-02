# 毛球Agent可见输出块流式协议目标文档

- 更新时间：2026-07-02
- Goal：定义 Agent 面向客户端的可见输出块流式协议，确保标题、正文和 UI 卡片按后端 SSE 事件顺序稳定渲染
- 执行方式：先契约测试后实现；后端负责输出判定与顺序，前端只消费稳定 DTO 并渲染

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 协议归属 | 可见输出顺序属于后端 SSE 契约，不属于前端文案解析 |
| 触发归属 | UI 块触发必须来自 `VisibleOutputPlan`、稳定工具类型或 finalizer 合同 |
| 标题判定 | 标题必须由后端输出 `section_heading` 内容块 |
| 正文判定 | 普通流式正文使用 `answer_delta`；需要结构化段落时由后端输出 `paragraph` 内容块 |
| UI 块判定 | 卡片、骨架屏、工具结果视图必须由后端输出明确 content block |
| 前端职责 | 前端按事件顺序写入当前 assistant 消息并渲染 DTO |
| 禁止路径 | 前端和 projector 不得从 `agent_activity.display_text`、`answer_delta`、`final_text` 反推标题、骨架屏或卡片 |

## 2. 目标边界

### 2.1 本目标期必须完成

| 范围 | 目标 |
|---|---|
| SSE 事件 | 增加并消费 `content_block_delta` |
| 宠物信息场景 | 工具开始时先输出标题块和宠物资料骨架块 |
| 完成态 | `answer_completed/message_completed` 输出最终 `content_blocks`，替换流式骨架块 |
| iOS DTO | iOS 只解码 `content_block_delta`，不做文案推断 |
| 测试 | 覆盖后端事件顺序、iOS DTO 解码、Store 消费行为 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 医院卡片完整 DTO | 本次只固定可扩展协议，医院卡片后续新增 block 类型 |
| 所有正文都改为 content block | 普通长文本继续用 `answer_delta` 保持真实流式体验 |
| 前端 markdown 渲染 | 当前目标是原生 DTO 渲染，不引入 markdown 语义 |

## 3. 依据

### 3.1 项目内依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| 后端 Stream Event | `maohuoban-rust/crates/maohuoban-ai-domain/src/ai/model/stream/stream.rs` | 已有 `AiContentBlock` 与 `AiStreamEvent`，适合承载稳定 UI 块 |
| 后端 Projector | `maohuoban-rust/crates/maohuoban-ai-http/src/Infrastructure/ai/router/chat/runtime_stream_projector.rs` | Runtime event 在这里投影为用户可见 SSE，顺序应在这里固定 |
| iOS DTO | `maohuoban/maohuoban/Features/AI/Data/AIStreamEventDTO.swift` | 前端流式消费入口应只表达后端稳定事件 |
| iOS Store | `maohuoban/maohuoban/Features/AI/Stores/AIAssistantStore+Streaming.swift` | 当前 assistant 消息状态在这里按事件更新 |
| 历史回放 | `maohuoban/maohuoban/Features/AI/Data/AIAssistantRepository.swift` / `AIChatSessionDTO.swift` | 历史消息已支持 `content_blocks`，刷新后应与新流一致 |

### 3.2 用户反馈依据

| 反馈 | 协议要求 |
|---|---|
| 标题和 UI 块顺序不稳定 | 后端必须先发标题块，再发骨架块，前端按到达顺序渲染 |
| 前端兜底导致补丁堆叠 | 移除前端文案推断，改为后端契约测试约束 |
| 后续医院等卡片会扩展 | 所有新 UI 形态都应新增 block 类型和 contract test |

## 4. 推荐数据流

```text
用户输入“我的宠物信息”
  -> VisibleOutputPlan 判定本轮需要 pet_profile_card
  -> Runtime 判定需要 load_pet_identity_context
  -> ToolStarted
  -> Projector 输出 content_block_delta
       [section_heading, pet_profile_card_skeleton]
  -> Projector 不再输出重复 execution_trace_started
  -> ToolFinished 写入事实包
  -> TurnFinished
  -> Projector 输出 answer_completed/message_completed
       content_blocks = [section_heading, pet_profile_card]
  -> iOS Store 用最终块替换当前消息 contentBlocks
  -> iOS View 原生渲染内容块
```

## 5. 后端目标

| 任务 | 目标文件 / 模块 | 要求 |
|---|---|---|
| 定义事件 | `maohuoban-ai-domain/src/ai/model/stream/stream.rs` | `ContentBlockDelta` 是稳定 SSE 事件 |
| 固定顺序 | `runtime_stream_projector.rs` | 宠物信息工具开始时第一事件为 `content_block_delta`，骨架块承接加载态 |
| 输出计划 | `visible_output_plan.rs` | 基于 surface、事实工具计划和稳定工具名决定是否展示资料卡 UI |
| 完成态校验 | `runtime_stream_helpers.rs` / `content_block_projector.rs` | 最终资料卡必须从事实包投影，缺失时失败诊断 |
| 诊断 | `diagnostics_common.rs` | 记录 `content_block_delta` 与块数量 |

## 6. iOS 目标

| 任务 | 目标文件 / 模块 | 要求 |
|---|---|---|
| DTO | `AIStreamEventDTO.swift` | 增加 `.contentBlockDelta(contentBlocks:)` |
| 解码 | `AIStreamEventDecoder.swift` | 解码 `content_block_delta` 的 `content_blocks` |
| Store | `AIAssistantStore+Streaming.swift` | 只把后端内容块写入当前 assistant 消息 |
| 诊断 | `AIAssistantDiagnostics.swift` / `AIAssistantStore+Diagnostics.swift` | 记录事件名和块数量 |
| 渲染 | ContentBlock 组件 | 只根据 `AIAssistantContentBlock` 类型渲染 |

## 7. 判定规则

| 输出形态 | 后端事件 / block | 判定方 | 前端行为 |
|---|---|---|---|
| 标题 | `section_heading` | 后端 projector / finalizer | 渲染标题样式 |
| 普通流式正文 | `answer_delta` | 后端 visible text projector | 渲染文本流 |
| 结构化段落 | `paragraph` | 后端 projector / finalizer | 渲染段落块 |
| 加载骨架 | `*_skeleton` block | 后端 projector | 渲染对应骨架屏 |
| 资料卡 / 医院卡 / 服务卡 | 对应 card block | 后端 projector / finalizer | 渲染对应原生 UI |
| 工具状态 | `execution_trace_started/completed` | 后端 projector | 仅作为工具状态，不生成内容块 |

### 7.1 可见输出计划约束

| 约束 | 要求 |
|---|---|
| 计划入口 | 新 UI 形态必须先进入 `VisibleOutputPlan` 或同级计划模型 |
| 工具关联 | 骨架屏只能由计划项与稳定工具名共同触发 |
| 文案隔离 | `display_text` 只作为活动展示文案，不参与 UI 块判定 |
| 重复活动 | 已由 skeleton content block 承接加载态的工具开始事件，不再额外发送顶部 `execution_trace_started` |
| 扩展方式 | 医院、服务、商品等 UI 新增独立 block 类型、计划项和合同测试 |

## 8. TDD 任务拆分

### Task 1：固定后端可见块顺序

| 项 | 内容 |
|---|---|
| 目标 | 宠物信息工具开始时立即输出标题和骨架块 |
| 前置依赖 | 已有 `AiContentBlock` |
| 回归验证 | `cargo test -p maohuoban-ai-http --test runtime_stream_projector` |

#### Slice 1.1：工具开始事件输出内容块

| 项 | 要求 |
|---|---|
| 行为目标 | `ToolStarted(load_pet_identity_context)` 的第一个 SSE 事件是 `ContentBlockDelta` |
| 先写失败测试 | `projector_emits_pet_profile_heading_and_skeleton_when_identity_tool_starts` |
| 允许修改 | `stream.rs`、`runtime_stream_projector.rs`、`diagnostics_common.rs` |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-http --test runtime_stream_projector projector_emits_pet_profile_heading_and_skeleton_when_identity_tool_starts` |
| 完成证据 | 记录红灯缺事件、绿灯通过、事件顺序断言 |
| 停止条件 | 需要前端解析自然语言才能通过 |

### Task 2：固定 iOS DTO 消费路径

| 项 | 内容 |
|---|---|
| 目标 | iOS 只根据 `content_block_delta` 写入内容块 |
| 前置依赖 | Task 1 |
| 回归验证 | `xcodebuild test -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'id=<真机ID>' -only-testing:maohuobanTests/AIAssistantDTOTests -only-testing:maohuobanTests/AIAssistantStoreRuntimeAdapterTests` |

#### Slice 2.1：DTO 解码

| 项 | 要求 |
|---|---|
| 行为目标 | `content_block_delta` JSON 解码为 `.contentBlockDelta` |
| 先写失败测试 | `AIAssistantDTOTests.testDecodeContentBlockDeltaEvent` |
| 允许修改 | `AIStreamEventDTO.swift`、`AIStreamEventDecoder.swift`、payload DTO |
| 最小绿灯命令 | `xcodebuild test ... -only-testing:maohuobanTests/AIAssistantDTOTests/testDecodeContentBlockDeltaEvent` |
| 完成证据 | 记录红灯缺 enum case、绿灯解码通过 |
| 停止条件 | 需要解析 markdown 或自然语言才能通过 |

#### Slice 2.2：Store 消费

| 项 | 要求 |
|---|---|
| 行为目标 | Store 把后端块原样写入当前 assistant 消息 |
| 先写失败测试 | `AIAssistantStoreRuntimeAdapterTests.testContentBlockDeltaAppliesBackendHeadingAndSkeleton` |
| 允许修改 | `AIAssistantStore+Streaming.swift`、诊断 switch |
| 最小绿灯命令 | `xcodebuild test ... -only-testing:maohuobanTests/AIAssistantStoreRuntimeAdapterTests` |
| 完成证据 | 记录红灯缺 case、绿灯 Store 顺序断言 |
| 停止条件 | Store 需要从 `agent_activity` 或 `final_text` 推断 block |

## 9. 验收门禁

| 类型 | 命令 / 验收 |
|---|---|
| Rust 格式 | `cargo fmt --all --check` |
| Rust projector | `cargo test -p maohuoban-ai-http --test runtime_stream_projector` |
| Rust 编译 | `cargo check --workspace --all-targets` |
| iOS DTO/Store | `xcodebuild test -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'id=<真机ID>' -only-testing:maohuobanTests/AIAssistantDTOTests -only-testing:maohuobanTests/AIAssistantStoreRuntimeAdapterTests` |
| iOS Debug build | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'id=<真机ID>' -configuration Debug build` |

## 10. 不变约束

| 约束 | 说明 |
|---|---|
| 前端无文案推断 | 前端不得从工具文案、正文文本、完成文本推导标题或 UI 块 |
| Projector 无文案推断 | Projector 不得从 `display_text` 内容推导 `content_block_delta` |
| 顺序由 SSE 决定 | 同一 assistant 消息内的可见顺序等于后端事件顺序 |
| 完成态替换骨架 | 骨架只存在于流式准备阶段，完成态由最终 `content_blocks` 决定 |
| 历史回放一致 | 历史接口必须持久化并返回 `content_blocks`，刷新后保持同样 UI |
| 失败显式暴露 | 后端不能产出必要内容块时，应输出 error 事件和诊断，不输出不完整 UI |

## 11. 风险

| 风险 | 处理 |
|---|---|
| block 类型增长过快 | 每个新卡片先加 DTO、projector 测试和 iOS 解码测试 |
| 普通正文和 paragraph 混用 | 由后端 finalizer 明确输出策略，同一段内容不重复输出 |
| 历史消息缺块 | 后端持久化 assistant message 时写入 `content_blocks`，历史接口合同测试覆盖 |
| 工具状态误当内容 | `execution_trace_*` 只表示运行状态，不能触发 UI 内容块生成 |
