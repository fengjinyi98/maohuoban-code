//! `maohuoban_diagnostics` 诊断 SDK Rust 核心库
//!
//! 核心职责：
//! - 承载跨平台诊断事件、日志、性能、网络与清理策略的 Rust 实现
//! - 为 Swift SDK、命令行工具和本地 Collector 提供稳定的核心能力

mod cleanup;
mod error;
mod event;
mod export;
mod network;
mod policy;
mod runtime;
mod span;
mod storage;
mod version;

pub use cleanup::{CleanupPolicy, CleanupReport};
pub use error::DiagnosticsError;
pub use event::{DiagnosticEvent, EventKind, Severity};
pub use export::{DebugBundle, DebugBundleExporter, LlmPromptExporter};
pub use network::{NetworkSummary, TraceContext};
pub use policy::{CapturePolicy, PrivacyPolicy, TextRedactionPattern, TrackingConsent};
pub use runtime::{Diagnostics, DiagnosticsBootstrapConfig, DiagnosticsConfig};
pub use span::DiagnosticsSpan;
pub use storage::{EventStore, FileSegmentStore};
pub use version::sdk_version;

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn sdk_version_matches_package_version() {
        assert_eq!(sdk_version(), env!("CARGO_PKG_VERSION"));
    }

    #[test]
    fn privacy_policy_redacts_nested_values() {
        let event = DiagnosticEvent::new(EventKind::Log, Severity::Info, "login").metadata(
            "payload",
            json!({
                "password": "secret",
                "nested": { "authorization": "Bearer token" }
            }),
        );

        let event = PrivacyPolicy::default()
            .redact_key("password")
            .redact_key("authorization")
            .apply(&event);

        assert_eq!(event.metadata["payload"]["password"], "<redacted>");
        assert_eq!(
            event.metadata["payload"]["nested"]["authorization"],
            "<redacted>"
        );
    }
}
