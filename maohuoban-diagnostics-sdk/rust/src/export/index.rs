use crate::{DiagnosticEvent, EventKind, Severity, sdk_version};
use serde_json::{Value, json};
use std::collections::BTreeMap;

use super::time_basis::{local_rfc3339, time_basis_json};

/// `bundle_index_json` 生成诊断包索引
/// 核心职责：
/// - 为 LLM 提供首读入口和文件读取顺序
/// - 汇总事件数量、类型分布和严重级别分布
pub(super) fn bundle_index_json(events: &[DiagnosticEvent]) -> Result<Vec<u8>, serde_json::Error> {
    let mut kind_counts = BTreeMap::new();
    let mut severity_counts = BTreeMap::new();
    for event in events {
        *kind_counts.entry(kind_name(event.kind)).or_insert(0usize) += 1;
        *severity_counts
            .entry(severity_name(event.severity))
            .or_insert(0usize) += 1;
    }

    serde_json::to_vec(&json!({
        "schema": "maohuoban.diagnostics.index.v1",
        "sdk_version": sdk_version(),
        "event_count": events.len(),
        "first_event_at": events.first().map(|event| event.timestamp),
        "first_event_at_local": events.first().map(|event| local_rfc3339(&event.timestamp)),
        "latest_event_at": events.last().map(|event| event.timestamp),
        "latest_event_at_local": events.last().map(|event| local_rfc3339(&event.timestamp)),
        "time_basis": time_basis_json(),
        "kind_counts": kind_counts,
        "severity_counts": severity_counts,
        "recommended_read_order": [
            "index.json",
            "prompt.md",
            "timeline.jsonl",
            "manifest.json"
        ],
        "files": [
            file_entry(
                "index.json",
                "诊断包索引和读取路由",
                "始终先读，用于决定后续打开哪些报告文件。"
            ),
            file_entry(
                "prompt.md",
                "面向 LLM 的压缩时间线摘要",
                "需要快速判断问题现象、最近关键事件和用户问题时读取。"
            ),
            file_entry(
                "timeline.jsonl",
                "完整事件时间线",
                "需要按时间顺序定位具体 SDK 事件、日志、错误和 metadata 时读取。"
            ),
            file_entry(
                "manifest.json",
                "诊断包清单和校验值",
                "需要核对文件完整性、SDK 版本和导出时间时读取。"
            ),
            file_entry(
                "archive.tar",
                "包含核心诊断文件的无压缩归档",
                "需要把完整诊断包作为单文件传递给其他工具时使用。"
            )
        ],
        "important_queries": [
            {
                "target": "timeline.jsonl",
                "query": "\"severity\":\"error\"",
                "purpose": "定位 error 级别事件"
            },
            {
                "target": "timeline.jsonl",
                "query": "\"severity\":\"fatal\"",
                "purpose": "定位 fatal 级别事件"
            },
            {
                "target": "timeline.jsonl",
                "query": "\"kind\":\"network\"",
                "purpose": "定位网络请求事件"
            },
            {
                "target": "timeline.jsonl",
                "query": "\"kind\":\"lifecycle\"",
                "purpose": "定位启动、授权和生命周期事件"
            }
        ]
    }))
}

fn file_entry(path: &'static str, purpose: &'static str, read_when: &'static str) -> Value {
    json!({
        "path": path,
        "purpose": purpose,
        "read_when": read_when,
    })
}

fn kind_name(kind: EventKind) -> &'static str {
    match kind {
        EventKind::Log => "log",
        EventKind::Network => "network",
        EventKind::Performance => "performance",
        EventKind::Error => "error",
        EventKind::Breadcrumb => "breadcrumb",
        EventKind::Lifecycle => "lifecycle",
        EventKind::Analytics => "analytics",
        EventKind::Identity => "identity",
    }
}

fn severity_name(severity: Severity) -> &'static str {
    match severity {
        Severity::Trace => "trace",
        Severity::Debug => "debug",
        Severity::Info => "info",
        Severity::Warn => "warn",
        Severity::Error => "error",
        Severity::Fatal => "fatal",
    }
}
