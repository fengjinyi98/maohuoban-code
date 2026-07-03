use std::{env, fs, process::Command};

use super::*;

/// `tiny_png` 返回 1x1 像素 PNG 字节
/// 核心职责：
/// - 提供可解码图片媒资测试夹具
/// - 固定图片上传合同中的宽高元数据来源
pub(crate) fn tiny_png() -> Vec<u8> {
    STANDARD
        .decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC",
        )
        .expect("decode tiny png")
}

/// `upload_pending_media` 上传未绑定媒体并返回响应数据
/// 核心职责：
/// - 固定宠物媒体 pending 上传测试流程
/// - 避免合约测试继续依赖旧 `pet_id` 上传端点
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

/// `upload_pending_live_photo` 上传未绑定 Live Photo 背景
/// 核心职责：
/// - 固定 Live Photo pending 上传测试流程
/// - 验证后端返回逻辑资产和成对组件
pub(crate) async fn upload_pending_live_photo(
    app: &maohuoban_rust::test_support::AuthTestApp,
    still_content: &[u8],
    video_content: &[u8],
    user_id: &str,
) -> Value {
    let response = app
        .router()
        .oneshot(multipart_live_photo_request(
            still_content,
            video_content,
            user_id,
        ))
        .await
        .expect("upload pending live photo");
    assert_eq!(response.status(), StatusCode::CREATED);
    response_json(response).await
}

/// `bind_uploaded_media` 将 pending 媒体绑定到宠物
/// 核心职责：
/// - 固定宠物媒体绑定测试流程
/// - 验证编辑和创建后的媒体替换统一走绑定接口
pub(crate) async fn bind_uploaded_media(
    app: &maohuoban_rust::test_support::AuthTestApp,
    pet_id: &str,
    asset_id: &str,
    user_id: &str,
) -> Value {
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
    response_json(response).await
}

/// `assert_name_edit_policy` 校验宠物改名策略
/// 核心职责：
/// - 固定后端返回的改名额度字段
/// - 降低宠物档案契约测试重复断言
pub(crate) fn assert_name_edit_policy(data: &Value, used_count: i64, remaining_count: i64) {
    assert_eq!(data["name_edit_policy"]["max_count"], 5);
    assert_eq!(data["name_edit_policy"]["used_count"], used_count);
    assert_eq!(data["name_edit_policy"]["remaining_count"], remaining_count);
    if used_count == 0 {
        assert_eq!(
            data["name_edit_policy"]["display_text"],
            "30 天内最多修改 5 次名字。"
        );
    } else {
        let display_text = data["name_edit_policy"]["display_text"]
            .as_str()
            .expect("name edit display text");
        assert!(display_text.contains("日前还可以修改"));
        assert!(!display_text.contains("本周期"));
    }
}

/// `red_video_base64` 生成红色视频测试样本
/// 核心职责：
/// - 使用本机 ffmpeg 创建最小 mp4
/// - 返回接口上传所需 base64 内容
pub(crate) fn red_video_base64() -> Option<String> {
    let output_path =
        env::temp_dir().join(format!("maohuoban-red-video-{}.mp4", uuid::Uuid::new_v4()));
    let status = Command::new("ffmpeg")
        .arg("-v")
        .arg("error")
        .arg("-y")
        .arg("-f")
        .arg("lavfi")
        .arg("-i")
        .arg("color=c=red:s=16x16:d=1")
        .arg("-frames:v")
        .arg("1")
        .arg("-pix_fmt")
        .arg("yuv420p")
        .arg(&output_path)
        .status()
        .ok()?;
    if !status.success() {
        return None;
    }

    let content = fs::read(&output_path).ok()?;
    let _ = fs::remove_file(output_path);
    Some(STANDARD.encode(content))
}

/// `red_video_bytes` 生成红色视频测试样本
/// 核心职责：
/// - 复用当前视频 fixture 生成方式
/// - 为 multipart 视频上传提供原始二进制内容
pub(crate) fn red_video_bytes() -> Option<Vec<u8>> {
    red_video_base64().and_then(|content| STANDARD.decode(content).ok())
}

/// `assert_media_cleanup_state` 校验媒体清理状态
/// 核心职责：
/// - 固定资产、绑定和清理任务三项断言
/// - 降低媒体生命周期契约测试重复代码
pub(crate) async fn assert_media_cleanup_state(
    app: &maohuoban_rust::test_support::AuthTestApp,
    asset_id: &str,
    asset_status: &str,
    binding_status: &str,
    job_status: &str,
) {
    let cleanup_state = app.media_cleanup_state(asset_id).await;
    assert_eq!(cleanup_state.asset_status, asset_status);
    assert_eq!(cleanup_state.binding_status, binding_status);
    assert_eq!(cleanup_state.job_status, job_status);
}
