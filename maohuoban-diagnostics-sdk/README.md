# Maohuoban Diagnostics SDK

`maohuoban-diagnostics-sdk` 是独立诊断 SDK 目录，服务于 `maohuoban` App 和 `maohuoban-rust` 后端项目。

## 架构边界

| 目录 | 角色 |
| --- | --- |
| `rust/` | Rust 诊断核心库，承载事件、日志、性能、网络和清理策略 |
| `swift/` | Swift Package，面向 iOS/macOS 原生接入 |
| `collector/` | 本地采集器 CLI，负责汇总段文件并导出 Debug Bundle |
| `docs/` | SDK 协议、清理策略、导出格式和工作流说明 |

## 分层模型

| 层 | 职责 |
| --- | --- |
| Facade | 一次 `install` 后全局可用 |
| Context | 维护 service、environment、trace、session 元信息 |
| Capture | 采集日志、网络、性能、错误、生命周期事件，并控制最低级别与字段大小 |
| Normalize | 转成统一 `DiagnosticEvent` 协议 |
| Privacy | 写入前执行字段脱敏 |
| Storage | JSONL 分段落盘 |
| Cleanup | 按大小、时间窗口、导出生命周期清理 |
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
                    privacy: PrivacyPolicy(redactedKeys: ["authorization", "password", "token"]),
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

let span = await Diagnostics.beginSpan("load detail")
await span?.end(metadata: ["result": "failed"])

let bundle = try await Diagnostics.exportDebugBundle(to: diagnosticsBundleURL)
let prompt = try await Diagnostics.exportLLMPrompt(title: "分析这个 bug")
```

网络采集使用稳定的 `URLProtocol` 注入方式：

```swift
let diagnostics = await Diagnostics.current()
let configuration = await diagnostics?.instrumentedURLSessionConfiguration(.default)
let session = URLSession(configuration: configuration ?? .default)
```

## Rust 一次接入

```rust
use maohuoban_diagnostics::{CapturePolicy, CleanupPolicy, Diagnostics, DiagnosticsConfig, FileSegmentStore, PrivacyPolicy, Severity};
use serde_json::json;

let store = FileSegmentStore::new("target/maohuoban-diagnostics/segments", 1024 * 1024)?;
let diagnostics = Diagnostics::install(DiagnosticsConfig {
    service_name: "maohuoban-rust".to_string(),
    environment: "local".to_string(),
    privacy: PrivacyPolicy::default().redact_key("authorization").redact_key("password"),
    capture: CapturePolicy::default(),
    cleanup: CleanupPolicy::default(),
    store: Box::new(store),
})?;
diagnostics.install_panic_hook();
diagnostics.set_session_id("session-local");
diagnostics.set_trace_id("sync-home");
diagnostics.set_context_metadata("worker", json!("scheduler"));

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
```

服务启动阶段也可以使用 `bootstrap` 组合文件存储、默认上下文、panic hook、启动清理和启动快照：

```rust
let diagnostics = Diagnostics::bootstrap(DiagnosticsBootstrapConfig::new(
    "maohuoban-rust",
    "local",
    "target/maohuoban-diagnostics/segments",
))?;
diagnostics.set_context_metadata("worker", json!("scheduler"));
```

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
| Debug 前导出诊断包 | Swift `Diagnostics.exportDebugBundle` / Rust `DebugBundleExporter` / Collector CLI |
| 定期清理 | Swift `Diagnostics.cleanup()` / Rust `diagnostics.cleanup()` |
| 发给 LLM 分析 | 使用 Debug Bundle 中的 `archive.tar`，或直接使用 `prompt.md` 和 `timeline.jsonl` |

`bootstrap` 会完成安装、默认上下文注入、启动生命周期事件、可选运行时快照和启动清理，适合作为 App 或服务进程的唯一接入点。

全局上下文会在统一 `record` 管线内补齐到后续事件。事件自身的 `traceID`、`sessionID` 或同名 metadata 优先级更高，适合局部覆盖某次请求或页面。

作用域 trace API 会在操作结束后恢复进入前的 trace，失败路径同样恢复，适合包住一次用户动作、网络请求或后台任务。

结构化错误 API 会自动记录错误描述和错误链。Swift 记录 `NSError` 的 domain、code、description 和 underlying chain；Rust 记录错误类型和 `std::error::Error::source()` chain。

运行时快照 API 会以 `performance` 事件记录进程、系统、架构和 SDK uptime。Swift 额外记录物理内存大小；发生事件落盘失败后，Swift 快照还会带出 `dropped_event_count` 和 `last_storage_error`。

网络摘要 API 会记录 method、url、status code、duration 和 error。Swift `URLProtocol` 自动采集会额外记录请求体字节数、响应体字节数、响应 MIME type、请求 header key 和响应 header key，避免采集 header value。显式 error 或 HTTP 状态码大于等于 400 时，事件会自动标记为 `severity=error` 且 message 为 `network request failed`。

采集策略默认保留全部事件。需要控制日志量时，可以配置 Swift `CapturePolicy(minimumSeverity:maxMessageLength:maxMetadataValueLength:)` 或 Rust `CapturePolicy`，在统一 `record` 管线内过滤低优先级事件并裁剪超长字段。

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
