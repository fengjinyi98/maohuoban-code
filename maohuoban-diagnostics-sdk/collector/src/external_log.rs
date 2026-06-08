use maohuoban_diagnostics::{DiagnosticEvent, DiagnosticsError, EventKind, Severity};
use serde_json::json;
use std::{
    io::{BufRead, BufReader},
    path::Path,
};

/// `read_external_log_file` 读取外部日志文件
/// 核心职责：
/// - 将 Xcode、Rust 进程和脚本输出转换为标准 log 事件
/// - 为 Collector 多来源 timeline 提供统一事件输入
pub(crate) fn read_external_log_file(
    path: &Path,
) -> Result<Vec<DiagnosticEvent>, DiagnosticsError> {
    let file = std::fs::File::open(path)?;
    let reader = BufReader::new(file);
    let source_path = path.display().to_string();
    let mut events = Vec::new();
    for line in reader.lines() {
        let line = line?;
        let message = line.trim();
        if message.is_empty() {
            continue;
        }
        let parsed = parse_external_log_line(message);
        let mut event = DiagnosticEvent::new(EventKind::Log, parsed.severity, message)
            .metadata("source", json!("external_log"))
            .metadata("source_path", json!(source_path));
        if let Some(marker) = parsed.marker {
            event = event.metadata("external_log_marker", json!(marker));
        }
        if let Some(format) = parsed.format {
            event = event.metadata("external_log_format", json!(format));
        }
        events.push(event);
    }
    Ok(events)
}

/// `ParsedExternalLogLine` 外部日志解析结果
/// 核心职责：
/// - 承载从原始日志行识别出的严重级别
/// - 为事件 metadata 保留解析依据
struct ParsedExternalLogLine<'a> {
    severity: Severity,
    marker: Option<&'a str>,
    format: Option<&'static str>,
}

/// `parse_external_log_line` 解析外部日志行
/// 核心职责：
/// - 识别 Xcode、Rust 和脚本日志里的常见级别标记
/// - 保留原始日志文本，由 Collector 统一转换为标准事件
fn parse_external_log_line(line: &str) -> ParsedExternalLogLine<'_> {
    for token in line.split(|character: char| {
        character.is_whitespace()
            || matches!(
                character,
                '[' | ']' | '(' | ')' | '{' | '}' | '<' | '>' | ':' | '=' | ',' | ';'
            )
    }) {
        let Some(severity) = severity_from_marker(token) else {
            continue;
        };
        return ParsedExternalLogLine {
            severity,
            marker: Some(token),
            format: Some(classify_external_log_format(line)),
        };
    }

    ParsedExternalLogLine {
        severity: Severity::Info,
        marker: None,
        format: None,
    }
}

/// `severity_from_marker` 映射日志级别标记
/// 核心职责：
/// - 将常见大小写日志级别转换为诊断事件严重级别
/// - 保持外部日志解析逻辑集中在 Collector 层
fn severity_from_marker(marker: &str) -> Option<Severity> {
    match marker {
        "TRACE" | "Trace" | "trace" => Some(Severity::Trace),
        "DEBUG" | "Debug" | "debug" => Some(Severity::Debug),
        "INFO" | "Info" | "info" => Some(Severity::Info),
        "WARN" | "Warn" | "warn" | "WARNING" | "Warning" | "warning" => Some(Severity::Warn),
        "ERROR" | "Error" | "error" => Some(Severity::Error),
        "FATAL" | "Fatal" | "fatal" => Some(Severity::Fatal),
        _ => None,
    }
}

/// `classify_external_log_format` 判断外部日志格式
/// 核心职责：
/// - 标记日志行来源形态，辅助 LLM 判断上下文
/// - 为 Xcode、Rust 和普通脚本输出提供轻量分类
fn classify_external_log_format(line: &str) -> &'static str {
    if looks_like_xcode_or_system_log(line) {
        "xcode_or_system"
    } else if line.contains(" src/") || line.contains(".rs:") {
        "rust"
    } else {
        "plain"
    }
}

/// `looks_like_xcode_or_system_log` 判断 Xcode 或系统日志行
/// 核心职责：
/// - 识别带日期、进程和线程片段的 Apple 平台日志
/// - 为外部日志格式分类提供无依赖判断
fn looks_like_xcode_or_system_log(line: &str) -> bool {
    let bytes = line.as_bytes();
    bytes.len() >= 23
        && bytes[4] == b'-'
        && bytes[7] == b'-'
        && bytes[10].is_ascii_whitespace()
        && bytes[13] == b':'
        && bytes[16] == b':'
        && line.contains('[')
        && line.contains(']')
}
