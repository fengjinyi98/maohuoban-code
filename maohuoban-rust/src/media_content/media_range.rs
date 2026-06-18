use axum::{
    body::Body,
    http::{
        HeaderValue, StatusCode,
        header::{ACCEPT_RANGES, CACHE_CONTROL, CONTENT_LENGTH, CONTENT_RANGE, CONTENT_TYPE},
    },
    response::{IntoResponse, Response},
};

pub(super) fn media_response(
    mime_type: &str,
    cache_control: &str,
    content: Vec<u8>,
    range_header: Option<&str>,
) -> Response {
    let total_len = content.len();
    let mut response = if let Some(range_header) = range_header {
        match parse_byte_range(range_header, total_len) {
            Ok(byte_range) => partial_media_response(&content, byte_range, total_len),
            Err(()) => range_not_satisfiable_response(total_len),
        }
    } else {
        let mut response = Body::from(content).into_response();
        if let Ok(value) = HeaderValue::from_str(&total_len.to_string()) {
            response.headers_mut().insert(CONTENT_LENGTH, value);
        }
        response
    };
    if let Ok(value) = HeaderValue::from_str(mime_type) {
        response.headers_mut().insert(CONTENT_TYPE, value);
    }
    if let Ok(value) = HeaderValue::from_str(cache_control) {
        response.headers_mut().insert(CACHE_CONTROL, value);
    }
    response
        .headers_mut()
        .insert(ACCEPT_RANGES, HeaderValue::from_static("bytes"));
    response
}

/// ByteRange 媒体内容字节范围
/// 核心职责：
/// - 表达 HTTP Range 解析后的闭区间
/// - 为视频播放器按需读取媒体片段提供边界
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct ByteRange {
    start: usize,
    end: usize,
}

fn partial_media_response(content: &[u8], range: ByteRange, total_len: usize) -> Response {
    let partial_content = content[range.start..=range.end].to_vec();
    let partial_len = partial_content.len();
    let mut response = Body::from(partial_content).into_response();
    *response.status_mut() = StatusCode::PARTIAL_CONTENT;
    if let Ok(value) = HeaderValue::from_str(&format!(
        "bytes {}-{}/{}",
        range.start, range.end, total_len
    )) {
        response.headers_mut().insert(CONTENT_RANGE, value);
    }
    if let Ok(value) = HeaderValue::from_str(&partial_len.to_string()) {
        response.headers_mut().insert(CONTENT_LENGTH, value);
    }
    response
}

fn range_not_satisfiable_response(total_len: usize) -> Response {
    let mut response = StatusCode::RANGE_NOT_SATISFIABLE.into_response();
    if let Ok(value) = HeaderValue::from_str(&format!("bytes */{total_len}")) {
        response.headers_mut().insert(CONTENT_RANGE, value);
    }
    response
}

fn parse_byte_range(value: &str, total_len: usize) -> Result<ByteRange, ()> {
    let value = value.trim();
    let range_value = value.strip_prefix("bytes=").ok_or(())?;
    if total_len == 0 || range_value.contains(',') {
        return Err(());
    }
    let (start_text, end_text) = range_value.split_once('-').ok_or(())?;

    if start_text.is_empty() {
        let suffix_len = end_text.parse::<usize>().map_err(|_| ())?;
        if suffix_len == 0 {
            return Err(());
        }
        let length = suffix_len.min(total_len);
        return Ok(ByteRange {
            start: total_len - length,
            end: total_len - 1,
        });
    }

    let start = start_text.parse::<usize>().map_err(|_| ())?;
    if start >= total_len {
        return Err(());
    }
    let end = if end_text.is_empty() {
        total_len - 1
    } else {
        end_text
            .parse::<usize>()
            .map_err(|_| ())?
            .min(total_len - 1)
    };
    if start > end {
        return Err(());
    }

    Ok(ByteRange { start, end })
}

#[cfg(test)]
mod tests {
    use super::{ByteRange, parse_byte_range};

    #[test]
    fn parse_byte_range_reads_closed_range() {
        assert_eq!(
            parse_byte_range("bytes=0-15", 100),
            Ok(ByteRange { start: 0, end: 15 })
        );
    }

    #[test]
    fn parse_byte_range_reads_open_ended_range() {
        assert_eq!(
            parse_byte_range("bytes=16-", 100),
            Ok(ByteRange { start: 16, end: 99 })
        );
    }

    #[test]
    fn parse_byte_range_reads_suffix_range() {
        assert_eq!(
            parse_byte_range("bytes=-16", 100),
            Ok(ByteRange { start: 84, end: 99 })
        );
    }

    #[test]
    fn parse_byte_range_rejects_unsatisfiable_range() {
        assert_eq!(parse_byte_range("bytes=100-120", 100), Err(()));
    }
}
