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

/// `multipart_media_request` 构造媒体上传 multipart 请求
/// 核心职责：
/// - 固定媒体上传测试的 multipart 协议
/// - 同时提交 `file`、`source_client` 和 Bearer token
pub(crate) fn multipart_media_request(
    uri: &str,
    file_name: &str,
    mime_type: &str,
    content: &[u8],
    source_client: &str,
    user_id: &str,
) -> Request<Body> {
    let boundary = format!("maohuoban-home-test-{}", uuid::Uuid::new_v4());
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

pub(crate) fn multipart_live_photo_request_with_crop(
    still_content: &[u8],
    video_content: &[u8],
    user_id: &str,
    crop_fields: Option<[(&str, &str); 4]>,
) -> Request<Body> {
    let boundary = format!("maohuoban-home-test-{}", uuid::Uuid::new_v4());
    let mut body = Vec::new();
    for (field_name, file_name, mime_type, content) in [
        ("still_file", "live-still.png", "image/png", still_content),
        (
            "paired_video_file",
            "live-motion.mov",
            "video/quicktime",
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
/// - 固定首页契约测试请求形态
/// - 保持测试对路由细节的依赖最小
pub(crate) fn empty_request(method: &str, uri: &str) -> Request<Body> {
    contextual_empty_request(method, uri, None)
}

/// `range_request` 构造媒体 Range 读取请求
/// 核心职责：
/// - 固定视频播放器所需的字节范围读取形态
/// - 验证媒体内容接口返回 Partial Content 语义
pub(crate) fn range_request(uri: &str, range: &str) -> Request<Body> {
    Request::builder()
        .method("GET")
        .uri(uri)
        .header("range", range)
        .body(Body::empty())
        .expect("build range request")
}

/// `contextual_empty_request` 构造携带用户上下文的无 body 请求
/// 核心职责：
/// - 支持首页真实聚合读取当前用户宠物数据
/// - 使用登录接口返回的 access token 作为认证凭证
pub(crate) fn contextual_empty_request(
    method: &str,
    uri: &str,
    user_id: Option<&str>,
) -> Request<Body> {
    let mut builder = Request::builder().method(method).uri(uri);
    if let Some(user_id) = user_id
        && let Some(token) = ACCESS_TOKENS.lock().expect("access token map").get(user_id)
    {
        builder = builder.header("authorization", format!("Bearer {token}"));
    }
    builder.body(Body::empty()).expect("build test request")
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

/// `response_json` 读取 JSON 响应
/// 核心职责：
/// - 校验测试响应 body 可被解析为 JSON
/// - 为接口契约断言提供统一入口
pub(crate) async fn response_json(response: axum::response::Response) -> Value {
    let bytes = to_bytes(response.into_body(), 1024 * 1024)
        .await
        .expect("read response body");
    serde_json::from_slice(&bytes).expect("parse response json")
}
