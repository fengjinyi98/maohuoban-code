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
| Capture | 采集日志、网络、性能、错误、生命周期事件 |
| Normalize | 转成统一 `DiagnosticEvent` 协议 |
| Privacy | 写入前执行字段脱敏 |
| Storage | JSONL 分段落盘 |
| Cleanup | 按大小、时间窗口、导出生命周期清理 |
| Export | 生成 `manifest.json` 与 `timeline.jsonl` Debug Bundle |

## Swift 一次接入

```swift
import MaohuobanDiagnostics

@main
struct AppMain: App {
    init() {
        Task {
            let diagnostics = try await Diagnostics.install(
                DiagnosticsConfiguration(
                    serviceName: "maohuoban-ios",
                    environment: "local",
                    privacy: PrivacyPolicy(redactedKeys: ["authorization", "password", "token"])
                )
            )
            await diagnostics.record(
                DiagnosticEvent(kind: .lifecycle, severity: .info, message: "app launched")
            )
        }
    }
}
```

网络采集使用稳定的 `URLProtocol` 注入方式：

```swift
let diagnostics = await Diagnostics.current()
let configuration = await diagnostics?.instrumentedURLSessionConfiguration(.default)
let session = URLSession(configuration: configuration ?? .default)
```

## Rust 一次接入

```rust
use maohuoban_diagnostics::{
    CleanupPolicy, DiagnosticEvent, Diagnostics, DiagnosticsConfig, EventKind, FileSegmentStore,
    PrivacyPolicy, Severity,
};

let store = FileSegmentStore::new("target/maohuoban-diagnostics/segments", 1024 * 1024)?;
let diagnostics = Diagnostics::install(DiagnosticsConfig {
    service_name: "maohuoban-rust".to_string(),
    environment: "local".to_string(),
    privacy: PrivacyPolicy::default().redact_key("authorization").redact_key("password"),
    cleanup: CleanupPolicy::default(),
    store: Box::new(store),
})?;
diagnostics.record(DiagnosticEvent::new(EventKind::Lifecycle, Severity::Info, "started"));
```

## Collector 导出

```bash
cargo run -p maohuoban_diagnostics_collector -- \
  --segments target/maohuoban-diagnostics/segments \
  --output target/maohuoban-diagnostics/bundle
```

输出：

| 文件 | 内容 |
| --- | --- |
| `manifest.json` | schema、SDK 版本、事件数量、导出时间 |
| `timeline.jsonl` | 按时间排序的诊断事件 |

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
