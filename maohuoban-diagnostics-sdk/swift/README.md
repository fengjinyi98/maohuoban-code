# Swift SDK

Swift SDK 面向 iOS/macOS 原生项目接入。

## 职责

| 能力 | 目标 |
| --- | --- |
| 日志 | 统一采集业务日志、系统日志关联信息和上下文标签 |
| 网络 | 记录请求摘要、响应摘要、耗时、错误和重试链路 |
| 性能 | 记录启动、卡顿、主线程阻塞、span 和资源指标 |
| 错误 | 记录异常、错误链、面包屑和环境快照 |
| 清理 | 管理本地缓存大小、时间窗口、隐私字段和导出生命周期 |

## 一次安装

```swift
import MaohuobanDiagnostics

try await Diagnostics.install(
    .init(
        serviceName: "maohuoban-ios",
        environment: "local",
        privacy: .init(redactedKeys: ["authorization", "password", "token"])
    )
)
```

## 全局使用

| 场景 | API |
| --- | --- |
| 会话上下文 | `await Diagnostics.setSessionID("session-id")` |
| 链路上下文 | `await Diagnostics.setTraceID("trace-id")` / `await Diagnostics.clearTraceID()` |
| 默认 metadata | `await Diagnostics.setContextMetadata("screen", "home")` |
| 日志 | `await Diagnostics.log(.info, "message")` |
| 面包屑 | `await Diagnostics.breadcrumb("open detail", metadata: ["screen": "detail"])` |
| 错误 | `await Diagnostics.error("load failed", metadata: ["reason": "timeout"])` |
| 结构化错误 | `await Diagnostics.captureError(error, metadata: ["feature": "checkout"])` |
| 运行时快照 | `await Diagnostics.captureRuntimeSnapshot(metadata: ["phase": "startup"])` |
| 性能 | `let span = await Diagnostics.beginSpan("load detail")` + `await span?.end()` |
| 网络 | `Diagnostics.current()?.instrumentedURLSessionConfiguration(...)` |
| 清理 | `try await Diagnostics.cleanup()` |
| 诊断包 | `try await Diagnostics.exportDebugBundle(to: outputURL)` |
| LLM Prompt | `try await Diagnostics.exportLLMPrompt(title: "分析这个 bug")` |

```swift
await Diagnostics.setSessionID("session-\(UUID().uuidString)")
await Diagnostics.setTraceID("checkout")
await Diagnostics.setContextMetadata("screen", "checkout")

await Diagnostics.error("checkout failed", metadata: ["screen": "payment"])
await Diagnostics.captureError(error, metadata: ["feature": "checkout"])
await Diagnostics.captureRuntimeSnapshot(metadata: ["phase": "startup"])
await Diagnostics.clearTraceID()
```

全局上下文会在统一记录管线中自动注入后续事件。事件自身的 `traceID`、`sessionID` 或同名 metadata 会保留自身值，适合临时覆盖某个页面、请求或 span。

`captureError` 会把 Swift `Error` 桥接为 `NSError`，记录 domain、code、description 和 `NSUnderlyingErrorKey` chain，方便 LLM 直接分析错误因果。

`captureRuntimeSnapshot` 会记录进程 ID、进程名、系统版本、架构、SDK uptime 和物理内存大小，适合放在启动、卡顿、网络异常前后。

## Debug Bundle

| 文件 | 内容 |
| --- | --- |
| `manifest.json` | schema、SDK 版本、事件数量、导出时间 |
| `timeline.jsonl` | 脱敏后的标准诊断事件 |
| `prompt.md` | 可直接交给 LLM 的分析输入摘要 |

## SwiftUI 边界

| 位置 | 规则 |
| --- | --- |
| `App.init` / `task` / `onAppear` | 可以执行 `install`、记录事件、导出和清理 |
| `body` / 同步计算属性 / View Builder | 保持纯读取，避免写磁盘、写全局状态和触发网络 |
