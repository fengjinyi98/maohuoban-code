use std::io::{Read, Write};
use std::net::TcpListener;
use std::sync::mpsc;

pub fn spawn_body_capture_server() -> (String, mpsc::Receiver<String>) {
    let listener = TcpListener::bind("127.0.0.1:0").expect("bind test server");
    let addr = listener.local_addr().expect("local addr");
    let (body_tx, body_rx) = mpsc::channel();

    std::thread::spawn(move || {
        let (mut stream, _) = listener.accept().expect("accept request");
        let mut buffer = Vec::new();
        let mut chunk = [0_u8; 1024];
        let header_end = loop {
            let read = stream.read(&mut chunk).expect("read request");
            assert!(read > 0, "request closed before headers");
            buffer.extend_from_slice(&chunk[..read]);
            if let Some(index) = buffer.windows(4).position(|w| w == b"\r\n\r\n") {
                break index + 4;
            }
        };

        let headers = String::from_utf8_lossy(&buffer[..header_end]);
        let content_length = headers
            .lines()
            .find_map(|line| {
                line.strip_prefix("content-length: ")
                    .or_else(|| line.strip_prefix("Content-Length: "))
            })
            .and_then(|value| value.parse::<usize>().ok())
            .expect("content-length header");

        while buffer.len() < header_end + content_length {
            let read = stream.read(&mut chunk).expect("read body");
            assert!(read > 0, "request closed before body");
            buffer.extend_from_slice(&chunk[..read]);
        }

        let body = String::from_utf8(buffer[header_end..header_end + content_length].to_vec())
            .expect("body utf8");
        body_tx.send(body).expect("send captured body");

        let response_body = serde_json::json!({
            "id": "chatcmpl-1",
            "model": "test-model",
            "choices": [{
                "index": 0,
                "message": {"role": "assistant", "content": "ok"},
                "finish_reason": "stop"
            }],
            "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}
        })
        .to_string();
        let response = format!(
            "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: {}\r\n\r\n{}",
            response_body.len(),
            response_body
        );
        stream
            .write_all(response.as_bytes())
            .expect("write response");
    });

    (format!("http://{addr}"), body_rx)
}
