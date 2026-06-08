# Maohuoban Diagnostics SDK

`maohuoban-diagnostics-sdk` 是独立诊断 SDK 目录，服务于 `maohuoban` App 和 `maohuoban-rust` 后端项目。

## 架构边界

| 目录 | 角色 |
| --- | --- |
| `rust/` | Rust 诊断核心库，承载事件、日志、性能、网络和清理策略 |
| `swift/` | Swift Package，面向 iOS/macOS 原生接入 |
| `collector/` | 本地采集器 CLI，负责汇总段文件并导出 Debug Bundle |
| `docs/` | SDK 协议、清理策略、导出格式和工作流说明 |

## 目录职责

| 路径 | 职责 |
| --- | --- |
| `rust/src/lib.rs` | Rust SDK 公开导出入口 |
| `rust/src/event.rs` | 诊断事件、事件类型和严重级别协议 |
| `rust/src/network.rs` | Rust 网络摘要事件协议 |
| `rust/src/policy.rs` | 隐私脱敏和采集过滤策略 |
| `rust/src/storage/event_store.rs` | 存储接口协议 |
| `rust/src/storage/file_segment_store.rs` | JSONL 分段存储、损坏行恢复和段文件清理 |
| `rust/src/export/bundle.rs` | Debug Bundle manifest、timeline 和 archive 导出编排 |
| `rust/src/export/prompt.rs` | LLM Prompt 文本导出 |
| `rust/src/export/checksum.rs` | 导出文件 SHA256 校验 |
| `rust/src/export/tar.rs` | 无压缩 tar 归档写入 |
| `rust/src/runtime/` | 运行时安装、上下文、采集 API、存储 API、健康快照和生命周期编排 |
| `swift/Sources/MaohuobanDiagnostics/Core/` | Swift 事件协议、facade、配置、采集和隐私策略 |
| `swift/Sources/MaohuobanDiagnostics/Runtime/` | Swift runtime 共享状态、安装、采集、上下文、网络、性能、存储和健康 API |
| `swift/Sources/MaohuobanDiagnostics/Context/` | Swift session、trace、TaskLocal 和 W3C Trace Context |
| `swift/Sources/MaohuobanDiagnostics/Network/` | Swift URLSession 自动采集、网络摘要和 OpenTelemetry 风格字段 |
| `swift/Sources/MaohuobanDiagnostics/SwiftUI/` | SwiftUI 页面曝光和点击埋点 modifier |
| `swift/Sources/MaohuobanDiagnostics/Performance/` | Swift 性能 span |
| `swift/Sources/MaohuobanDiagnostics/Storage/` | Swift JSONL 分段存储和导出目录索引 |
| `swift/Sources/MaohuobanDiagnostics/Export/` | Swift Debug Bundle、Prompt、校验和 tar 归档导出 |
| `collector/src/lib.rs` | Collector 库公开入口 |
| `collector/src/config.rs` | Collector 输入源和输出目录配置 |
| `collector/src/export.rs` | Collector Debug Bundle 导出编排 |
| `collector/src/external_log.rs` | 外部日志行解析和严重级别归一 |
| `collector/src/multi_source_store.rs` | 多段目录和外部日志统一读取 |

## 测试组织

| 路径 | 覆盖 |
| --- | --- |
| `rust/tests/storage_pipeline.rs` | Rust 隐私、采集策略、段文件清理、损坏行恢复和导出清理 |
| `rust/tests/export_pipeline.rs` | Rust Debug Bundle、Prompt 和 facade 导出 |
| `rust/tests/facade_context_pipeline.rs` | Rust 全局入口、全局上下文和作用域 trace |
| `rust/tests/runtime_capture_pipeline.rs` | Rust 网络摘要、结构化错误、运行时快照、存储失败健康字段和 panic hook |
| `rust/tests/bootstrap_pipeline.rs` | Rust bootstrap 启动上下文和启动清理 |
| `rust/tests/support/` | Rust integration tests 的锁、tar 解析和可失败存储 |
| `swift/Tests/MaohuobanDiagnosticsTests/*PipelineTests.swift` | Swift 按存储、导出、网络、上下文、运行时和启动行为域拆分 |
| `swift/Tests/MaohuobanDiagnosticsTests/Support/` | Swift 测试临时目录、tar 解析和作用域 trace 错误 |
| `collector/tests/bundle_export.rs` | Collector 段文件汇总、Prompt、归档和损坏行恢复 |
| `collector/tests/external_logs.rs` | Collector 外部日志导入和严重级别识别 |

## 分层模型

| 层 | 职责 |
| --- | --- |
| Facade | 一次 `bootstrap` 或 `install` 后全局可用 |
| Context | 维护 service、environment、trace、session 元信息 |
| Capture | 采集日志、网络、性能、错误、生命周期事件，并控制最低级别与字段大小 |
| Normalize | 转成统一 `DiagnosticEvent` 协议 |
| Privacy | 写入前执行字段脱敏 |
| Storage | JSONL 分段落盘，读取时保留损坏段文件告警 |
| Cleanup | 按大小、时间窗口、导出生命周期清理，支持跨运行时清理遗留导出包 |
| Export | 生成 `manifest.json`、`timeline.jsonl`、`prompt.md` 与 `archive.tar` Debug Bundle |

## Swift 一次接入

```swift
import MaohuobanDiagnostics

@main
struct AppMain: App {
    init() {
        Task {
            try await Diagnostics.bootstrap(
                DiagnosticsBootstrapConfiguration(
                    serviceName: "maohuoban-ios",
                    environment: "local",
                    privacy: PrivacyPolicy(
                        redactedKeys: ["authorization", "password", "token"],
                        redactedQueryItems: ["token", "access_token", "refresh_token"],
                        redactedTextPatterns: [.email, .phoneNumber]
                    ),
                    capture: CapturePolicy(
                        enabled: true,
                        consent: .granted,
                        sampleRate: 1,
                        minimumSeverity: .info
                    ),
                    defaults: [
                        "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
                    ],
                    sessionID: "session-\(UUID().uuidString)"
                )
            )
        }
    }
}
```

安装后任意模块可以通过 `Diagnostics` facade 记录上下文：

```swift
await Diagnostics.setSessionID("session-\(UUID().uuidString)")
await Diagnostics.setTraceID("home-refresh")
await Diagnostics.setContextMetadata("screen", "home")

try await Diagnostics.withTraceID("open-detail") {
    await Diagnostics.breadcrumb("open detail", metadata: ["screen": "detail"])
}
await Diagnostics.error("load failed", metadata: ["reason": "timeout"])
await Diagnostics.captureError(error, metadata: ["feature": "checkout"])
await Diagnostics.captureRuntimeSnapshot(metadata: ["phase": "startup"])
await Diagnostics.setTrackingConsent(.granted)
await Diagnostics.setCaptureEnabled(true)
await Diagnostics.setSampleRate(0.2)

let span = await Diagnostics.beginSpan("load detail")
await span?.end(metadata: ["result": "failed"])

ContentView()
    .diagnosticsScreen("home", metadata: ["screen_type": "root"])

let bundle = try await Diagnostics.exportDebugBundle(to: diagnosticsBundleURL)
let prompt = try await Diagnostics.exportLLMPrompt(title: "分析这个 bug")
```

网络采集默认使用低侵入手动 `URLProtocol` 注入方式：

```swift
let diagnostics = await Diagnostics.current()
let configuration = await diagnostics?.instrumentedURLSessionConfiguration(.default)
let session = URLSession(configuration: configuration ?? .default)
```

需要覆盖全进程 URL Loading 时，显式配置 `networkCapture: .globalURLProtocol`。

## Rust 一次接入

```rust
use maohuoban_diagnostics::{
    Diagnostics, DiagnosticsBootstrapConfig, NetworkSummary, PrivacyPolicy, Severity,
    TextRedactionPattern, TraceContext, TrackingConsent,
};
use serde_json::json;

let mut config = DiagnosticsBootstrapConfig::new(
    "maohuoban-rust",
    "local",
    "target/maohuoban-diagnostics/segments",
);
config.privacy = PrivacyPolicy::default()
    .redact_key("authorization")
    .redact_key("password")
    .redact_query_item("token")
    .redact_text_pattern(TextRedactionPattern::Email);
config.capture.enabled = true;
config.capture.consent = TrackingConsent::Granted;
config.capture.sample_rate = 1.0;
config.defaults.insert("worker".to_string(), json!("scheduler"));
config.session_id = Some("session-local".to_string());
config.trace_id = Some("sync-home".to_string());

let diagnostics = Diagnostics::bootstrap(config)?;

Diagnostics::current().expect("diagnostics").log(Severity::Info, "started");
Diagnostics::current()
    .expect("diagnostics")
    .breadcrumb("job queued", [("job_id", json!("sync-home"))]);
Diagnostics::current()
    .expect("diagnostics")
    .with_trace_id("sync-home-task", || {
        Diagnostics::current()
            .expect("diagnostics")
            .log(Severity::Info, "sync task running");
    });
Diagnostics::current()
    .expect("diagnostics")
    .capture_error(&error, [("feature", json!("sync-home"))]);
Diagnostics::current()
    .expect("diagnostics")
    .capture_runtime_snapshot([("phase", json!("startup"))]);

let span = Diagnostics::current().expect("diagnostics").begin_span("sync home");
span.end([("result", json!("ok"))]);

diagnostics.network(
    NetworkSummary::new("GET", "https://api.example.com/feed")
        .trace_context(TraceContext::generate(true))
        .status_code(200),
);

let bundle = diagnostics.export_debug_bundle("target/maohuoban-diagnostics/bundle")?;
let prompt = diagnostics.export_llm_prompt("分析这个 bug")?;
```

需要完全自定义存储实例和生命周期时使用 `Diagnostics::install(...)`。服务启动阶段推荐使用 `bootstrap` 组合文件存储、默认上下文、panic hook、启动清理和启动快照。

最小启动配置：

```rust
let diagnostics = Diagnostics::bootstrap(DiagnosticsBootstrapConfig::new(
    "maohuoban-rust",
    "local",
    "target/maohuoban-diagnostics/segments",
))?;
diagnostics.set_context_metadata("worker", json!("scheduler"));
```

## 真实产品接入位置

| 项目 | 入口文件 | 接入方式 |
| --- | --- | --- |
| `maohuoban` | `maohuoban/maohuoban/App/MaohuobanApp.swift` | `Diagnostics.bootstrap(...)` |
| `maohuoban-rust` | `maohuoban-rust/src/main.rs` | `Diagnostics::bootstrap(...)` |

## Collector 导出

```bash
cargo run -p maohuoban_diagnostics_collector -- \
  --segments target/maohuoban-ios/segments \
  --segments target/maohuoban-rust/segments \
  --log-file target/xcode-run.log \
  --output target/maohuoban-diagnostics/bundle
```

输出：

| 文件 | 内容 |
| --- | --- |
| `manifest.json` | schema、SDK 版本、事件数量、导出时间、内容校验值和归档路径 |
| `timeline.jsonl` | 按时间排序的 SDK 诊断事件和外部日志事件 |
| `prompt.md` | 包含 schema、标题、SDK 版本、事件数量和时间线摘要的 LLM 输入 |
| `archive.tar` | 包含 manifest、timeline 和 prompt 的无压缩 tar，便于直接传输或附加给 LLM 工作流 |

`--segments` 可以重复传入多个 SDK 段目录，`--log-file` 可以重复传入 Xcode、Rust 进程或脚本输出文件。Collector 会把外部日志的每个非空行转换为 `source=external_log` 的 `log` 事件，并识别 `TRACE`、`DEBUG`、`INFO`、`WARN`、`WARNING`、`ERROR`、`FATAL`、`warning:`、`error:` 等常见标记映射 `severity`，再按事件时间合并成同一个 timeline。

Collector 需要至少一种输入来源。SDK 还没接入某个进程时，可以只传 `--log-file` 生成 Debug Bundle，后续再逐步加入 `--segments`。

Rust SDK 与 Collector 的 manifest 使用 snake_case 字段：`timeline_sha256`、`prompt_sha256`、`archive_path`。Swift SDK 的 manifest 使用 camelCase 字段：`timelineSHA256`、`promptSHA256`、`archivePath`。

## 清理与导出工作流

| 场景 | 调用 |
| --- | --- |
| App 或服务启动 | Swift `Diagnostics.bootstrap(...)` / Rust `Diagnostics::bootstrap(...)` |
| 高级自定义安装 | Swift `Diagnostics.install(...)` / Rust `Diagnostics::install(...)` |
| 建立全局上下文 | Swift `setSessionID` / `setTraceID` / `setContextMetadata`，Rust `set_session_id` / `set_trace_id` / `set_context_metadata` |
| 建立作用域链路 | Swift `withTraceID`，Rust `with_trace_id` |
| 业务流程中记录上下文 | `breadcrumb`、`error`、`captureError/capture_error`、`log`、`captureRuntimeSnapshot/capture_runtime_snapshot`、`beginSpan/end` |
| Debug 前导出诊断包 | Swift `Diagnostics.exportDebugBundle` / Rust `diagnostics.export_debug_bundle(...)` / Collector CLI |
| 导出 LLM Prompt | Swift `Diagnostics.exportLLMPrompt` / Rust `diagnostics.export_llm_prompt(...)` |
| 定期清理 | Swift `Diagnostics.cleanup()` / Rust `diagnostics.cleanup()` |
| 发给 LLM 分析 | 使用 Debug Bundle 中的 `archive.tar`，或直接使用 `prompt.md` 和 `timeline.jsonl` |

`bootstrap` 会完成安装、默认上下文注入、启动生命周期事件、可选运行时快照和启动清理，适合作为 App 或服务进程的唯一接入点。

Debug Bundle 导出目录会写入 SDK storage 目录下的 `.debug-bundles.jsonl` 索引。`cleanup()` 会读取该索引，因此 App 或服务重启后仍能按 `maxExportAge` 清理上次运行遗留的导出包。

全局上下文会在统一 `record` 管线内补齐到后续事件。事件自身的 `traceID`、`sessionID` 或同名 metadata 优先级更高，适合局部覆盖某次请求或页面。

作用域 trace API 使用 Swift `TaskLocal` 绑定临时 trace。操作结束后恢复进入前的 trace，失败路径同样恢复，并发任务保留自身 trace，适合包住一次用户动作、网络请求或后台任务。

结构化错误 API 会自动记录错误描述和错误链。Swift 记录 `NSError` 的 domain、code、description 和 underlying chain；Rust 记录错误类型和 `std::error::Error::source()` chain。

运行时快照 API 会以 `performance` 事件记录进程、系统、架构和 SDK uptime。Swift 额外记录物理内存大小；发生事件落盘失败后，Swift 和 Rust 快照都会带出 `dropped_event_count` 和 `last_storage_error`。

网络摘要 API 会记录 method、url、status code、duration、error、W3C `traceparent` 和取消状态。Swift 与 Rust 都会写入兼容字段 `method`、`url`、`status_code`，以及 OpenTelemetry 风格字段 `http.request.method`、`url.full`、`http.response.status_code`。Swift `URLProtocol` 自动采集会额外记录请求体字节数、响应体字节数、响应 MIME type、请求 header key 和响应 header key，避免采集 header value。取消请求会生成 `severity=warn` 且 message 为 `network request cancelled`；显式 error 或 HTTP 状态码大于等于 400 时，事件会自动标记为 `severity=error` 且 message 为 `network request failed`。

采集策略默认启用、授权为 `.granted`、采样率为 `1`。需要控制日志量时，可以配置 Swift `CapturePolicy(enabled:consent:sampleRate:minimumSeverity:maxMessageLength:maxMetadataValueLength:)` 或 Rust `CapturePolicy { enabled, consent, sample_rate, ... }`，在统一 `record` 管线内过滤低优先级事件并裁剪超长字段。Swift 和 Rust 运行时都支持动态更新采集授权、启用状态和采样率。

Swift 与 Rust `PrivacyPolicy` 都会在写入前统一处理 metadata key、URL query item 和文本模式。Swift Package 已包含 `PrivacyInfo.xcprivacy`，默认不上传数据、不声明追踪域名。

## Hooks

```bash
scripts/install-hooks.sh
scripts/verify.sh
```

`scripts/verify.sh` 会执行：

| 命令 | 覆盖 |
| --- | --- |
| `cargo fmt --all --check` | Rust 格式 |
| `cargo test --workspace` | Rust SDK、Collector、产品 Rust |
| `cargo clippy --workspace --all-targets -- -D warnings` | Rust lint |
| `swift test --package-path maohuoban-diagnostics-sdk/swift` | Swift SDK |
| `xcodebuild ... Debug build` | 产品 App + Swift SDK 本地依赖 |
