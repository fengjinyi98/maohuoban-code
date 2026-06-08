use crate::{DiagnosticEvent, DiagnosticsError};
use serde_json::Value;
use std::{collections::BTreeSet, fs, panic, path::PathBuf};

use super::Diagnostics;

/// `TraceScopeGuard` 链路作用域恢复器
/// 核心职责：
/// - 在作用域退出时恢复原 trace
/// - 支持闭包失败或 panic unwind 路径的上下文恢复
pub(super) struct TraceScopeGuard {
    pub(super) diagnostics: Diagnostics,
    pub(super) previous: Option<String>,
}

impl Drop for TraceScopeGuard {
    fn drop(&mut self) {
        let previous = self.previous.take();
        let _ = self.diagnostics.replace_trace_id(previous);
    }
}

pub(crate) fn event_with_metadata(
    mut event: DiagnosticEvent,
    metadata: impl IntoIterator<Item = (impl Into<String>, Value)>,
) -> DiagnosticEvent {
    for (key, value) in metadata {
        event = event.metadata(key, value);
    }
    event
}

pub(super) fn panic_message(info: &panic::PanicHookInfo<'_>) -> String {
    let payload = info.payload();
    if let Some(message) = payload.downcast_ref::<&str>() {
        (*message).to_string()
    } else if let Some(message) = payload.downcast_ref::<String>() {
        message.clone()
    } else {
        "panic captured".to_string()
    }
}

pub(super) fn process_name() -> String {
    std::env::current_exe()
        .ok()
        .and_then(|path| {
            path.file_name()
                .map(|name| name.to_string_lossy().into_owned())
        })
        .or_else(|| std::env::args().next())
        .unwrap_or_else(|| "unknown".to_string())
}

pub(super) fn directory_size(directory: &PathBuf) -> Result<u64, DiagnosticsError> {
    let mut total = 0;
    for entry in fs::read_dir(directory)? {
        let path = entry?.path();
        let metadata = fs::metadata(&path)?;
        if metadata.is_dir() {
            total += directory_size(&path)?;
        } else {
            total += metadata.len();
        }
    }
    Ok(total)
}

pub(super) fn unique_paths(paths: Vec<PathBuf>) -> Vec<PathBuf> {
    let mut seen = BTreeSet::new();
    let mut output = Vec::new();
    for path in paths {
        let key = path.to_string_lossy().into_owned();
        if seen.insert(key) {
            output.push(path);
        }
    }
    output
}
