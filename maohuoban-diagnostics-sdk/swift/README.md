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

## 一次接入

```swift
import MaohuobanDiagnostics

try await Diagnostics.bootstrap(
    DiagnosticsBootstrapConfiguration(
        serviceName: "maohuoban-ios",
        environment: "local",
        privacy: .init(
            redactedKeys: ["authorization", "password", "token"],
            redactedQueryItems: ["token", "access_token", "refresh_token"],
            redactedTextPatterns: [.email, .phoneNumber]
        ),
        capture: .init(
            enabled: true,
            consent: .granted,
            sampleRate: 1,
            minimumSeverity: .info
        ),
        defaults: ["app_version": "1.0.0"],
        sessionID: "session-\(UUID().uuidString)"
    )
)
```

`bootstrap` 会完成安装、默认上下文注入、启动生命周期事件、运行时快照和启动清理。网络采集默认保持手动注入模式，不会注册全进程 `URLProtocol`。需要完全自定义存储生命周期时使用 `Diagnostics.install(...)`。

## 全局使用

| 场景 | API |
| --- | --- |
| 会话上下文 | `await Diagnostics.setSessionID("session-id")` |
| 链路上下文 | `await Diagnostics.setTraceID("trace-id")` / `await Diagnostics.clearTraceID()` |
| 作用域链路 | `try await Diagnostics.withTraceID("checkout") { ... }` |
| 默认 metadata | `await Diagnostics.setContextMetadata("screen", "home")` |
| 日志 | `await Diagnostics.log(.info, "message")` |
| 面包屑 | `await Diagnostics.breadcrumb("open detail", metadata: ["screen": "detail"])` |
| 错误 | `await Diagnostics.error("load failed", metadata: ["reason": "timeout"])` |
| 结构化错误 | `await Diagnostics.captureError(error, metadata: ["feature": "checkout"])` |
| 运行时快照 | `await Diagnostics.captureRuntimeSnapshot(metadata: ["phase": "startup"])` |
| 性能 | `let span = await Diagnostics.beginSpan("load detail")` + `await span?.end()` |
| 网络 | `Diagnostics.current()?.instrumentedURLSessionConfiguration(...)` |
| SwiftUI 页面曝光 | `.diagnosticsScreen("home", metadata: ["tab": "main"])` |
| SwiftUI 点击 | `.diagnosticsTap("home.refresh", metadata: ["source": "toolbar"])` |
| 采集授权 | `await Diagnostics.setTrackingConsent(.granted)` |
| 采集开关 | `await Diagnostics.setCaptureEnabled(true)` |
| 采样率 | `await Diagnostics.setSampleRate(0.2)` |
| 清理 | `try await Diagnostics.cleanup()` |
| 诊断包 | `try await Diagnostics.exportDebugBundle(to: outputURL)` |
| LLM Prompt | `try await Diagnostics.exportLLMPrompt(title: "分析这个 bug")` |

```swift
await Diagnostics.setSessionID("session-\(UUID().uuidString)")
await Diagnostics.setTraceID("checkout")
await Diagnostics.setContextMetadata("screen", "checkout")

try await Diagnostics.withTraceID("payment") {
    await Diagnostics.breadcrumb("payment opened")
}
await Diagnostics.error("checkout failed", metadata: ["screen": "payment"])
await Diagnostics.captureError(error, metadata: ["feature": "checkout"])
await Diagnostics.captureRuntimeSnapshot(metadata: ["phase": "startup"])
await Diagnostics.clearTraceID()
```

全局上下文会在统一记录管线中自动注入后续事件。事件自身的 `traceID`、`sessionID` 或同名 metadata 会保留自身值，适合临时覆盖某个页面、请求或 span。

`withTraceID` 使用 Swift `TaskLocal` 绑定临时 trace。作用域结束后恢复进入前的 trace，抛错路径同样恢复；并发任务会保留自身 trace，适合包住一次用户动作、网络请求或后台任务。

`captureError` 会把 Swift `Error` 桥接为 `NSError`，记录 domain、code、description 和 `NSUnderlyingErrorKey` chain，方便 LLM 直接分析错误因果。

`captureRuntimeSnapshot` 会记录进程 ID、进程名、系统版本、架构、SDK uptime 和物理内存大小，适合放在启动、卡顿、网络异常前后。发生事件落盘失败后，快照还会带出 `dropped_event_count` 和 `last_storage_error`，用于判断诊断数据自身是否丢失。

`NetworkSummary` 会记录 method、url、statusCode、durationMs、error、W3C `traceparent` 和取消状态。事件会同时写入兼容字段 `method`、`url`、`status_code`，以及 OpenTelemetry 风格字段 `http.request.method`、`url.full`、`http.response.status_code`。Swift `URLProtocol` 自动采集还会补充请求体字节数、响应体字节数、响应 MIME type、请求 header key 和响应 header key；header value 不会进入事件。取消请求会生成 `severity=.warn` 的取消网络事件；显式 error 或 `statusCode >= 400` 会自动生成 `severity=.error` 的失败网络事件。

网络采集默认使用低侵入手动注入：

```swift
let diagnostics = await Diagnostics.current()
let configuration = await diagnostics?.instrumentedURLSessionConfiguration(.default)
let session = URLSession(configuration: configuration ?? .default)
```

没有上游 trace 时，`DiagnosticsURLProtocol` 会自动生成 W3C `traceparent` 并注入请求 header；已有 `traceparent` 时会保留调用方提供的值。手动网络采集可以直接传入 `DiagnosticsTraceContext(...).traceparent`。

需要覆盖全进程 URL Loading 时，显式开启全局模式：

```swift
try await Diagnostics.bootstrap(
    DiagnosticsBootstrapConfiguration(
        serviceName: "maohuoban-ios",
        environment: "local",
        networkCapture: .globalURLProtocol
    )
)
```

`CapturePolicy` 默认启用、授权为 `.granted`、采样率为 `1`。生产环境可用 `enabled`、`consent`、`sampleRate`、最低严重级别、message 最大长度和 metadata 字符串最大长度控制数据量；策略在统一记录管线内执行，所有日志、网络、错误、性能和生命周期事件都会遵守同一边界。用户授权状态变化时，可调用 `Diagnostics.setTrackingConsent(...)` 动态更新。

`PrivacyPolicy` 会在写入前统一处理 metadata key、URL query item 和文本模式。内置文本模式包含 `.email` 和 `.phoneNumber`，也支持 `.custom(pattern:replacement:)` 扩展业务规则。

Swift Package 已包含 `PrivacyInfo.xcprivacy`。SDK 默认不上传数据、不声明追踪域名；当前清单声明 SDK 为清理策略读取 app 容器内文件时间戳。

## Debug Bundle

| 文件 | 内容 |
| --- | --- |
| `manifest.json` | schema、SDK 版本、事件数量、导出时间、`timelineSHA256`、`promptSHA256`、`archivePath` |
| `timeline.jsonl` | 脱敏后的标准诊断事件 |
| `prompt.md` | 可直接交给 LLM 的分析输入摘要 |
| `archive.tar` | 包含 manifest、timeline 和 prompt 的无压缩 tar，可作为单文件附件传输 |

`Diagnostics.exportDebugBundle(to:)` 返回的 `DebugBundle` 会暴露 `archiveURL`，用于上传、复制或附加到 LLM 分析流程。

读取 JSONL 段文件时，Swift Storage 会跳过无法解码的单行，并注入 `storage segment decode failed` 告警事件。诊断包会继续包含后续合法事件，同时把损坏段文件名、行号和错误摘要交给 LLM。

## SwiftUI 边界

| 位置 | 规则 |
| --- | --- |
| `App.init` / `task` / `onAppear` | 可以执行 `install`、记录事件、导出和清理 |
| `body` / 同步计算属性 / View Builder | 保持纯读取，避免写磁盘、写全局状态和触发网络 |

SwiftUI 页面和点击埋点推荐用 modifier：

```swift
ContentView()
    .diagnosticsScreen("home", metadata: ["screen_type": "root"])

Button("刷新") {
    reload()
}
.diagnosticsTap("home.refresh")
```

`diagnosticsScreen` 在 `onAppear` 事件边界记录 `screen appeared`，可选 `trackDisappear: true` 记录 `screen disappeared`。`diagnosticsTap` 在点击事件边界记录 `ui tapped`。
