use std::time::Duration;

use maohuoban_diagnostics::PrivacyPolicy;

mod diagnostics_config;
mod diagnostics_ingest;
mod diagnostics_network;

pub use diagnostics_config::{
    backend_diagnostics_bootstrap_config, cleanup_interval_from_env,
    cleanup_interval_from_env_value, cleanup_policy_from_env, cleanup_policy_from_env_values,
    diagnostics_ingest_config_from_env, diagnostics_segments_directory_from_env,
};
pub use diagnostics_ingest::{DiagnosticsIngestConfig, build_diagnostics_ingest_router};
pub use diagnostics_network::record_http_network;

const DEFAULT_INGEST_TOKEN: &str = "maohuoban-local-diagnostics";
const DEFAULT_MAX_BODY_BYTES: usize = 256 * 1024;
const DEFAULT_CLEANUP_MAX_TOTAL_BYTES: u64 = 10 * 1024 * 1024;
const DEFAULT_CLEANUP_MAX_SEGMENT_AGE_HOURS: u64 = 24;
const DEFAULT_CLEANUP_MAX_EXPORT_AGE_HOURS: u64 = 6;
const DEFAULT_CLEANUP_INTERVAL_MINS: u64 = 30;

fn backend_privacy_policy() -> PrivacyPolicy {
    PrivacyPolicy::default()
        .redact_key("authorization")
        .redact_key("password")
        .redact_key("token")
        .redact_key("cookie")
        .redact_query_item("token")
        .redact_query_item("access_token")
}

fn parse_u64_or(value: Option<&str>, fallback: u64) -> u64 {
    value
        .and_then(|value| value.parse().ok())
        .unwrap_or(fallback)
}

fn cleanup_interval_from_value(value: Option<&str>) -> Duration {
    Duration::from_mins(parse_u64_or(value, DEFAULT_CLEANUP_INTERVAL_MINS).max(1))
}
