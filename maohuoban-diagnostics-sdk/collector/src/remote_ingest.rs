use maohuoban_diagnostics::{DiagnosticEvent, EventStore, FileSegmentStore};
use std::{
    io::{Read as _, Write as _},
    net::{TcpListener, TcpStream},
    path::PathBuf,
    sync::{Arc, Mutex},
};

/// `serve_remote_ingest` 启动远端诊断事件接收服务
/// 核心职责：
/// - 接收 Debug 真机回流的诊断事件
/// - 将事件写入本机 workspace segments 目录
pub fn serve_remote_ingest(bind: &str, segments: PathBuf) -> Result<(), String> {
    let listener = TcpListener::bind(bind).map_err(|error| error.to_string())?;
    let store = Arc::new(Mutex::new(
        FileSegmentStore::new(segments, 1024 * 1024).map_err(|error| error.to_string())?,
    ));
    println!("maohuoban diagnostics ingest listening on http://{bind}/ingest");
    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                let store = Arc::clone(&store);
                if let Err(error) = handle_remote_ingest_connection(stream, &store) {
                    eprintln!("diagnostics ingest request failed: {error}");
                }
            }
            Err(error) => eprintln!("diagnostics ingest connection failed: {error}"),
        }
    }
    Ok(())
}

/// `handle_remote_ingest_connection` 处理单条远端诊断写入请求
/// 核心职责：
/// - 解析最小 HTTP JSON 请求
/// - 写入共享段文件存储并返回 HTTP 状态
pub(crate) fn handle_remote_ingest_connection(
    mut stream: TcpStream,
    store: &Arc<Mutex<FileSegmentStore>>,
) -> Result<(), String> {
    let mut buffer = Vec::new();
    let mut chunk = [0_u8; 4096];
    let header_end = loop {
        let read = stream.read(&mut chunk).map_err(|error| error.to_string())?;
        if read == 0 {
            return Err("empty request".to_string());
        }
        buffer.extend_from_slice(&chunk[..read]);
        if let Some(index) = find_header_end(&buffer) {
            break index;
        }
        if buffer.len() > 64 * 1024 {
            return Err("request headers too large".to_string());
        }
    };

    let headers = String::from_utf8_lossy(&buffer[..header_end]);
    if !headers.starts_with("POST /ingest ") {
        write_response(&mut stream, 404, "Not Found")?;
        return Ok(());
    }
    let content_length = content_length(&headers)?;
    let body_start = header_end + 4;
    while buffer.len().saturating_sub(body_start) < content_length {
        let read = stream.read(&mut chunk).map_err(|error| error.to_string())?;
        if read == 0 {
            break;
        }
        buffer.extend_from_slice(&chunk[..read]);
    }
    let body_end = body_start + content_length;
    if buffer.len() < body_end {
        write_response(&mut stream, 400, "Bad Request")?;
        return Ok(());
    }

    let event: DiagnosticEvent =
        serde_json::from_slice(&buffer[body_start..body_end]).map_err(|error| error.to_string())?;
    store
        .lock()
        .map_err(|error| error.to_string())?
        .append(&event)
        .map_err(|error| error.to_string())?;
    write_response(&mut stream, 202, "Accepted")?;
    Ok(())
}

fn find_header_end(buffer: &[u8]) -> Option<usize> {
    buffer.windows(4).position(|window| window == b"\r\n\r\n")
}

fn content_length(headers: &str) -> Result<usize, String> {
    headers
        .lines()
        .find_map(|line| {
            let (name, value) = line.split_once(':')?;
            if name.eq_ignore_ascii_case("content-length") {
                value.trim().parse::<usize>().ok()
            } else {
                None
            }
        })
        .ok_or_else(|| "missing content-length".to_string())
}

fn write_response(stream: &mut TcpStream, status: u16, reason: &str) -> Result<(), String> {
    let body = format!(r#"{{"ok":{}}}"#, status < 400);
    write!(
        stream,
        "HTTP/1.1 {status} {reason}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        body.len(),
        body
    )
    .map_err(|error| error.to_string())
}
