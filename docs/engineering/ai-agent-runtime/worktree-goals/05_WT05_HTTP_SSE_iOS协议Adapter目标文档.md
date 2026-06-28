# WT-05 HTTP / SSE / iOS 协议 Adapter 目标文档

- 更新时间：2026-06-28
- Goal：稳定后端 runtime event 到 HTTP/SSE/iOS 的 adapter，iOS 聊天页能展示等待态、流式文本、工具态、确认态、Provider 失败态和完成态；历史页继续正确展示宠物头像、名称和会话消息。
- 执行方式：TDD；后端改 `maohuoban-ai-http`，iOS 只改 `Features/AI`；不改 Provider、Tool、Session Store。

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 前端协议 | iOS 消费毛伙伴 SSE 事件，不消费 Provider chunk |
| 工具活动 | iOS 只消费后端输出的 `AgentActivity` / `ToolCall` 文案、状态和完成结果，不根据工具名自行映射展示文案 |
| 用户体验 | 发送后必须立即进入等待态，Provider 失败显示错误 / 重试态，不锁死发送按钮 |
| 历史展示 | 历史 row 使用后端 pet display snapshot，头像和名字必须正确 |
| Xcode 文件规则 | 当前项目使用系统自动同步，不需要每次手动检查 `.xcodeproj` target 文件列表 |

## 2. 目标边界

### 2.1 本目标期必须完成

| 范围 | 目标 |
|---|---|
| SSE Adapter | 映射 runtime event 到现有 / 新增 `AiStreamEvent` |
| HTTP 合同 | `/api/v1/ai/chat/stream` 输出工具态、错误态和完成态顺序稳定 |
| 活动文案 | 后端 SSE 事件包含可直接展示的工具进度文案、活动状态、完成状态和错误状态 |
| iOS DTO | 解析新增事件并映射到 Store 状态 |
| iOS Store | Provider 错误后发送按钮恢复；输入不被异常锁死 |
| iOS 历史 | 继续显示 pet name / avatar，进入历史消息后状态一致 |
| 构建 | iOS Debug 构建通过 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 新 UI 大改版 | 本目标是协议和状态修复 |
| 多 Agent UI | 首期只显示主 Agent |
| 复杂确认弹窗 | 可先用现有 proposed action / pending action 卡片 |
| Provider fallback UI | WT-03 定义错误，WT-05 只展示 |

## 3. 依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| 后端 SSE | `maohuoban-rust/crates/maohuoban-ai-domain/src/ai/model/stream.rs` | 已有稳定 `AiStreamEvent` |
| 后端 HTTP | `maohuoban-rust/crates/maohuoban-ai-http/src/Infrastructure/ai/router/chat/stream_handler.rs` | 当前流式入口 |
| 合同测试 | `maohuoban-rust/tests/ai_contract/chat_stream.rs` | 已验证 message_started、error、provider delta、诊断事件 |
| iOS DTO | `maohuoban/maohuoban/Features/AI/Data/AIStreamEventDTO.swift` | iOS 解析事件入口 |
| iOS Store | `maohuoban/maohuoban/Features/AI/Stores/AIAssistantStore.swift` | 管理发送、等待、消息、pending action |
| iOS 历史 | `maohuoban/maohuoban/Features/AI/Presentation/AIAssistantHistoryScreen.swift` | 历史 row 展示宠物头像和名字 |

## 4. 推荐数据流

```text
AgentEvent
  -> HTTP adapter maps to AiStreamEvent
  -> SSE text/event-stream
  -> AIStreamEventParser
  -> AIAssistantStore state
  -> AIAssistantScreen / HistoryScreen
```

## 5. 允许修改

| 文件 / 模块 | 要求 |
|---|---|
| `maohuoban-rust/crates/maohuoban-ai-http/src/Infrastructure/ai/router/chat/*` | SSE adapter 和流式 handler |
| `maohuoban-rust/crates/maohuoban-ai-http/src/Infrastructure/ai/response.rs` | 必要 DTO 映射 |
| `maohuoban-rust/tests/ai_contract/chat_stream.rs` | 后端合同测试 |
| `maohuoban/maohuoban/Features/AI/Data/*` | iOS DTO、parser、repository |
| `maohuoban/maohuoban/Features/AI/Stores/*` | Store 状态 |
| `maohuoban/maohuoban/Features/AI/Presentation/*` | 只做必要状态展示，不做大改版 |

## 6. 禁止修改

| 文件 / 模块 | 原因 |
|---|---|
| Provider implementation | WT-03 负责 |
| Tool / Policy | WT-02 负责 |
| Session Event Store migration | WT-04 负责 |
| Runtime LoopEngine | WT-01 负责 |

## 7. TDD 任务拆分

### Task 1：后端 SSE adapter 合同

| 项 | 内容 |
|---|---|
| 目标 | SSE 事件顺序和错误事件稳定 |
| 前置依赖 | 可使用现有 `AiStreamEvent`；WT-01 合并后映射 runtime event |
| 回归验证 | `cargo test -p maohuoban_rust --test ai_contract ai_chat_stream` |

#### Slice 1.1：Provider error 不锁成正常完成

| 项 | 要求 |
|---|---|
| 行为目标 | Provider 未配置时输出 `message_started -> error`，不输出伪完成回答 |
| 先写失败测试 | `maohuoban-rust/tests/ai_contract/chat_stream.rs` |
| 允许修改 | `maohuoban-ai-http/src/Infrastructure/ai/router/chat/*` |
| 最小绿灯命令 | `cargo test -p maohuoban_rust --test ai_contract ai_chat_stream_authenticated_emits_sse_events` |
| 回归命令 | `cargo test -p maohuoban_rust --test ai_contract ai_chat_stream` |
| 完成证据 | 记录 SSE 顺序和 error data |
| 停止条件 | 需要改 Provider 分类时停止并交给 WT-03 |

#### Slice 1.2：工具态和确认态映射

| 项 | 要求 |
|---|---|
| 行为目标 | tool / confirmation event 可被 SSE 输出并保持事件名稳定 |
| 先写失败测试 | `maohuoban-rust/tests/ai_contract/chat_stream.rs` |
| 允许修改 | `maohuoban-ai-http/src/Infrastructure/ai/router/chat/*` |
| 最小绿灯命令 | `cargo test -p maohuoban_rust --test ai_contract ai_chat_stream_emits_tool_and_confirmation_events` |
| 回归命令 | `cargo test -p maohuoban_rust --test ai_contract ai_chat_stream` |
| 完成证据 | 记录 `event: tool_call` / `event: confirmation_task` |
| 停止条件 | 需要真实 Tool Gateway 时停止，可使用 fixture event |

### Task 2：iOS 解析和 Store 状态

| 项 | 内容 |
|---|---|
| 目标 | iOS 正确消费 error、tool、confirmation、completed |
| 前置依赖 | Task 1 的事件名 |
| 回归验证 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build` |

#### Slice 2.1：错误后发送按钮恢复

| 项 | 要求 |
|---|---|
| 行为目标 | 收到 error event 后 Store 退出 sending / streaming 锁定，草稿可继续发送 |
| 先写失败测试 | iOS AI Store 测试；若当前无专用测试 target case，先新增 `maohuobanTests` 下 AI Store 测试 |
| 允许修改 | `Features/AI/Data/*`、`Features/AI/Stores/*`、对应测试文件 |
| 最小绿灯命令 | `xcodebuild test -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:maohuobanTests` |
| 回归命令 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build` |
| 完成证据 | 记录 error event 后 `canSend == true` 的断言 |
| 停止条件 | 测试 target 不可运行时，记录原因并至少执行 Debug build |

#### Slice 2.2：历史宠物展示不回退成名字占位

| 项 | 要求 |
|---|---|
| 行为目标 | history DTO 中 pet avatar / name 映射到 row view model |
| 先写失败测试 | iOS history mapper / store 测试 |
| 允许修改 | `Features/AI/Data/*`、`Features/AI/Domain/*`、`Features/AI/Presentation/AIAssistantHistoryScreen.swift` |
| 最小绿灯命令 | `xcodebuild test -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:maohuobanTests` |
| 回归命令 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build` |
| 完成证据 | 记录头像 URL / 名称断言 |
| 停止条件 | 需要修改后端历史 schema 时停止并对齐合同 |

## 8. 验收门禁

| 类型 | 命令 / 验收 |
|---|---|
| 后端合同 | `cargo test -p maohuoban_rust --test ai_contract ai_chat_stream` |
| 后端构建 | `cargo check -p maohuoban-ai-http` |
| iOS scheme | `xcodebuild -list -project maohuoban/maohuoban.xcodeproj` |
| iOS 构建 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build` |

## 9. 不变约束

| 约束 | 说明 |
|---|---|
| iOS 不读 Provider chunk | 只消费毛伙伴 SSE |
| 不做自动聚焦改动 | 键盘返回链路已决定不自动聚焦 |
| 不保留临时打印 | 修复后清理 DEBUG 打印 |

## 10. 风险

| 风险 | 处理 |
|---|---|
| iOS 测试 target 不完整 | 至少新增纯 Swift mapper / store 测试；不可运行时执行 Debug build 并说明 |
| 后端与 iOS 并行协议漂移 | 以本目标文档冻结事件名和合同测试为准 |
