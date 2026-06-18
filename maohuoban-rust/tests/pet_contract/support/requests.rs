use std::{
    collections::HashMap,
    sync::{LazyLock, Mutex},
};

use super::*;

static ACCESS_TOKENS: LazyLock<Mutex<HashMap<String, String>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

pub(crate) fn remember_access_token(user_id: String, access_token: String) {
    ACCESS_TOKENS
        .lock()
        .expect("access token map")
        .insert(user_id, access_token);
}

/// `json_request` 构造 JSON HTTP 请求
/// 核心职责：
/// - 固定测试请求的 Content-Type
/// - 支持附加服务端签发的 Bearer token
pub(crate) fn json_request(
    method: &str,
    uri: &str,
    body: Value,
    user_id: Option<&str>,
) -> Request<Body> {
    let mut builder = Request::builder()
        .method(method)
        .uri(uri)
        .header("content-type", "application/json");
    if let Some(user_id) = user_id
        && let Some(token) = ACCESS_TOKENS.lock().expect("access token map").get(user_id)
    {
        builder = builder.header("authorization", format!("Bearer {token}"));
    }
    builder
        .body(Body::from(body.to_string()))
        .expect("build json request")
}

/// `multipart_media_request` 构造媒体上传 multipart 请求
/// 核心职责：
/// - 固定媒体上传测试的 multipart 协议
/// - 同时提交 file、`source_client` 和 Bearer token
pub(crate) fn multipart_media_request(
    uri: &str,
    file_name: &str,
    mime_type: &str,
    content: &[u8],
    source_client: &str,
    user_id: &str,
) -> Request<Body> {
    let boundary = format!("maohuoban-test-{}", uuid::Uuid::new_v4());
    let mut body = Vec::new();
    body.extend_from_slice(format!("--{boundary}\r\n").as_bytes());
    body.extend_from_slice(
        format!(
            "Content-Disposition: form-data; name=\"file\"; filename=\"{file_name}\"\r\n\
             Content-Type: {mime_type}\r\n\r\n"
        )
        .as_bytes(),
    );
    body.extend_from_slice(content);
    body.extend_from_slice(b"\r\n");
    body.extend_from_slice(format!("--{boundary}\r\n").as_bytes());
    body.extend_from_slice(
        format!(
            "Content-Disposition: form-data; name=\"source_client\"\r\n\r\n{source_client}\r\n"
        )
        .as_bytes(),
    );
    body.extend_from_slice(format!("--{boundary}--\r\n").as_bytes());

    let token = ACCESS_TOKENS
        .lock()
        .expect("access token map")
        .get(user_id)
        .cloned()
        .expect("access token for user");

    Request::builder()
        .method("POST")
        .uri(uri)
        .header(
            "content-type",
            format!("multipart/form-data; boundary={boundary}"),
        )
        .header("authorization", format!("Bearer {token}"))
        .body(Body::from(body))
        .expect("build multipart media request")
}

/// `multipart_live_photo_request` 构造 Live Photo 上传 multipart 请求
/// 核心职责：
/// - 同时提交静态图和配对视频资源
/// - 固定 Live Photo 背景上传契约字段
pub(crate) fn multipart_live_photo_request(
    still_content: &[u8],
    video_content: &[u8],
    user_id: &str,
) -> Request<Body> {
    multipart_live_photo_request_with_crop(still_content, video_content, user_id, None)
}

pub(crate) fn multipart_live_photo_request_with_crop(
    still_content: &[u8],
    video_content: &[u8],
    user_id: &str,
    crop_fields: Option<[(&str, &str); 4]>,
) -> Request<Body> {
    multipart_live_photo_request_custom(
        "live-still.png",
        "image/png",
        still_content,
        "live-motion.mov",
        "video/quicktime",
        video_content,
        user_id,
        crop_fields,
    )
}

#[allow(clippy::too_many_arguments)]
pub(crate) fn multipart_live_photo_request_custom(
    still_file_name: &str,
    still_mime_type: &str,
    still_content: &[u8],
    paired_video_file_name: &str,
    paired_video_mime_type: &str,
    video_content: &[u8],
    user_id: &str,
    crop_fields: Option<[(&str, &str); 4]>,
) -> Request<Body> {
    let boundary = format!("maohuoban-test-{}", uuid::Uuid::new_v4());
    let mut body = Vec::new();
    for (field_name, file_name, mime_type, content) in [
        (
            "still_file",
            still_file_name,
            still_mime_type,
            still_content,
        ),
        (
            "paired_video_file",
            paired_video_file_name,
            paired_video_mime_type,
            video_content,
        ),
    ] {
        body.extend_from_slice(format!("--{boundary}\r\n").as_bytes());
        body.extend_from_slice(
            format!(
                "Content-Disposition: form-data; name=\"{field_name}\"; filename=\"{file_name}\"\r\n\
                 Content-Type: {mime_type}\r\n\r\n"
            )
            .as_bytes(),
        );
        body.extend_from_slice(content);
        body.extend_from_slice(b"\r\n");
    }
    body.extend_from_slice(format!("--{boundary}\r\n").as_bytes());
    body.extend_from_slice(
        b"Content-Disposition: form-data; name=\"source_client\"\r\n\r\nios\r\n",
    );
    if let Some(crop_fields) = crop_fields {
        for (field_name, value) in crop_fields {
            body.extend_from_slice(format!("--{boundary}\r\n").as_bytes());
            body.extend_from_slice(
                format!("Content-Disposition: form-data; name=\"{field_name}\"\r\n\r\n{value}\r\n")
                    .as_bytes(),
            );
        }
    }
    body.extend_from_slice(format!("--{boundary}--\r\n").as_bytes());

    let token = ACCESS_TOKENS
        .lock()
        .expect("access token map")
        .get(user_id)
        .cloned()
        .expect("access token for user");

    Request::builder()
        .method("POST")
        .uri("/api/v1/pet-media/background-live-photo")
        .header(
            "content-type",
            format!("multipart/form-data; boundary={boundary}"),
        )
        .header("authorization", format!("Bearer {token}"))
        .body(Body::from(body))
        .expect("build multipart live photo request")
}

/// `empty_request` 构造无 body HTTP 请求
/// 核心职责：
/// - 固定 GET 请求形态
/// - 支持附加服务端签发的 Bearer token
pub(crate) fn empty_request(method: &str, uri: &str, user_id: Option<&str>) -> Request<Body> {
    let mut builder = Request::builder().method(method).uri(uri);
    if let Some(user_id) = user_id
        && let Some(token) = ACCESS_TOKENS.lock().expect("access token map").get(user_id)
    {
        builder = builder.header("authorization", format!("Bearer {token}"));
    }
    builder.body(Body::empty()).expect("build empty request")
}

/// `response_json` 读取 JSON 响应
/// 核心职责：
/// - 校验响应 body 可解析
/// - 为契约测试提供统一断言入口
pub(crate) async fn response_json(response: axum::response::Response) -> Value {
    let bytes = to_bytes(response.into_body(), 1024 * 1024)
        .await
        .expect("read response body");
    serde_json::from_slice(&bytes).expect("parse response json")
}
