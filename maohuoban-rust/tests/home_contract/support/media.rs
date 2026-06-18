use super::*;

/// `upload_pending_media` 上传未绑定媒体并返回响应数据
/// 核心职责：
/// - 固定首页测试的媒体上传入口
/// - 避免首页契约继续依赖旧 `pet_id` 上传端点
pub(crate) async fn upload_pending_media(
    app: &maohuoban_rust::test_support::AuthTestApp,
    uri: &str,
    file_name: &str,
    mime_type: &str,
    content: &[u8],
    user_id: &str,
) -> Value {
    let response = app
        .router()
        .oneshot(multipart_media_request(
            uri, file_name, mime_type, content, "ios", user_id,
        ))
        .await
        .expect("upload pending media");
    assert_eq!(response.status(), StatusCode::CREATED);
    response_json(response).await
}

pub(crate) async fn upload_pending_live_photo_with_crop(
    app: &maohuoban_rust::test_support::AuthTestApp,
    still_content: &[u8],
    video_content: &[u8],
    user_id: &str,
    crop_fields: Option<[(&str, &str); 4]>,
) -> Value {
    let response = app
        .router()
        .oneshot(multipart_live_photo_request_with_crop(
            still_content,
            video_content,
            user_id,
            crop_fields,
        ))
        .await
        .expect("upload pending live photo");
    assert_eq!(response.status(), StatusCode::CREATED);
    response_json(response).await
}

/// `bind_uploaded_media` 将 pending 媒体绑定到宠物
/// 核心职责：
/// - 固定首页测试的媒体绑定入口
/// - 保持首页只验证最终可消费媒体 URL 和尺寸
pub(crate) async fn bind_uploaded_media(
    app: &maohuoban_rust::test_support::AuthTestApp,
    pet_id: &str,
    asset_id: &str,
    user_id: &str,
) {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/media-bindings"),
            json!({ "asset_id": asset_id }),
            Some(user_id),
        ))
        .await
        .expect("bind uploaded media");
    assert_eq!(response.status(), StatusCode::CREATED);
}

/// `assert_media_range_content` 验证媒体内容 Range 响应
/// 核心职责：
/// - 固定视频播放器依赖的 Partial Content 契约
/// - 避免首页聚合测试承担底层响应头断言细节
pub(crate) async fn assert_media_range_content(
    app: &maohuoban_rust::test_support::AuthTestApp,
    media_url: &str,
    expected_bytes: &[u8],
) {
    let range_response = app
        .router()
        .oneshot(range_request(media_url, "bytes=0-15"))
        .await
        .expect("get media range content");
    assert_eq!(range_response.status(), StatusCode::PARTIAL_CONTENT);
    assert_eq!(
        range_response
            .headers()
            .get("accept-ranges")
            .and_then(|value| value.to_str().ok()),
        Some("bytes")
    );
    let expected_content_range = format!("bytes 0-15/{}", expected_bytes.len());
    assert_eq!(
        range_response
            .headers()
            .get("content-range")
            .and_then(|value| value.to_str().ok()),
        Some(expected_content_range.as_str())
    );
    assert_eq!(
        range_response
            .headers()
            .get("content-length")
            .and_then(|value| value.to_str().ok()),
        Some("16")
    );
    let range_bytes = to_bytes(range_response.into_body(), 1024 * 1024)
        .await
        .expect("read media range content");
    assert_eq!(&range_bytes[..], &expected_bytes[..16]);
}
