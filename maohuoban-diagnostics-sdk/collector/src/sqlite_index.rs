use maohuoban_diagnostics::{DiagnosticEvent, DiagnosticsError};
use rusqlite::{Connection, params};
use std::{fs, path::Path};

/// `write_sqlite_index` 写入本地派生 `SQLite` 索引
/// 核心职责：
/// - 从已导出事件构建可删除重建的查询索引
/// - 为 trace、session、severity、screen 和 `request_id` 提供本地过滤基础
pub(crate) fn write_sqlite_index(
    path: &Path,
    events: &[DiagnosticEvent],
) -> Result<(), DiagnosticsError> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    if path.exists() {
        fs::remove_file(path)?;
    }
    let mut connection = Connection::open(path).map_err(|error| sqlite_error(&error))?;
    connection
        .execute_batch(
            r"
            CREATE TABLE events (
                id TEXT PRIMARY KEY,
                timestamp TEXT NOT NULL,
                kind TEXT NOT NULL,
                severity TEXT NOT NULL,
                message TEXT NOT NULL,
                trace_id TEXT,
                session_id TEXT,
                screen_name TEXT,
                request_id TEXT,
                metadata_json TEXT NOT NULL
            );
            CREATE INDEX idx_events_trace_id ON events(trace_id);
            CREATE INDEX idx_events_session_id ON events(session_id);
            CREATE INDEX idx_events_severity ON events(severity);
            CREATE INDEX idx_events_screen_name ON events(screen_name);
            CREATE INDEX idx_events_request_id ON events(request_id);
            ",
        )
        .map_err(|error| sqlite_error(&error))?;
    let transaction = connection
        .transaction()
        .map_err(|error| sqlite_error(&error))?;
    {
        let mut statement = transaction
            .prepare(
                r"
                INSERT INTO events (
                    id,
                    timestamp,
                    kind,
                    severity,
                    message,
                    trace_id,
                    session_id,
                    screen_name,
                    request_id,
                    metadata_json
                )
                VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)
                ",
            )
            .map_err(|error| sqlite_error(&error))?;
        for event in events {
            statement
                .execute(params![
                    event.id.to_string(),
                    event.timestamp.to_rfc3339(),
                    serde_json::to_value(event.kind)
                        .map_err(DiagnosticsError::from)?
                        .as_str()
                        .unwrap_or("unknown"),
                    serde_json::to_value(event.severity)
                        .map_err(DiagnosticsError::from)?
                        .as_str()
                        .unwrap_or("unknown"),
                    event.message,
                    event.trace_id,
                    event.session_id,
                    metadata_string(event, "screen_name")
                        .or_else(|| metadata_string(event, "screen")),
                    metadata_string(event, "request_id"),
                    serde_json::to_string(&event.metadata).map_err(DiagnosticsError::from)?,
                ])
                .map_err(|error| sqlite_error(&error))?;
        }
    }
    transaction.commit().map_err(|error| sqlite_error(&error))?;
    Ok(())
}

fn metadata_string(event: &DiagnosticEvent, key: &str) -> Option<String> {
    event.metadata.get(key)?.as_str().map(ToOwned::to_owned)
}

fn sqlite_error(error: &rusqlite::Error) -> DiagnosticsError {
    std::io::Error::other(error.to_string()).into()
}
