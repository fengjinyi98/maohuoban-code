use std::env;

use axum::{
    Router,
    body::Body,
    extract::{Path, State},
    http::{
        HeaderValue, StatusCode,
        header::{CACHE_CONTROL, CONTENT_TYPE},
    },
    response::{IntoResponse, Response},
    routing::get,
};
use maohuoban_media_storage::MediaObjectStore;
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

const DEFAULT_CACHE_CONTROL: &str = "public, max-age=31536000, immutable";

/// MediaContentState 媒体内容读取状态
/// 核心职责：
/// - 持有数据库连接用于定位媒体对象
/// - 持有对象存储客户端用于读取真实内容
#[derive(Clone)]
struct MediaContentState {
    pool: PgPool,
    object_store: MediaObjectStore,
    cache_control: String,
}

/// build_media_content_router 构建媒体内容只读路由
/// 核心职责：
/// - 通过稳定 asset id 对外暴露媒体内容
/// - 为前端远端图片和视频展示设置可缓存响应头
pub fn build_media_content_router(pool: PgPool) -> Router {
    let object_store =
        MediaObjectStore::from_env().unwrap_or_else(|error| panic!("media store config: {error}"));
    let cache_control = env::var("MAOHUOBAN_MEDIA_CACHE_CONTROL")
        .ok()
        .map(|value| value.trim().to_owned())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| DEFAULT_CACHE_CONTROL.to_owned());

    Router::new()
        .route(
            "/api/v1/media/assets/{asset_id}/content",
            get(get_media_content),
        )
        .with_state(MediaContentState {
            pool,
            object_store,
            cache_control,
        })
}

async fn get_media_content(
    State(state): State<MediaContentState>,
    Path(asset_id): Path<Uuid>,
) -> Response {
    match load_media_asset(&state.pool, asset_id).await {
        Ok(Some(asset)) => match state
            .object_store
            .get(&asset.bucket, &asset.object_key)
            .await
        {
            Ok(content) => media_response(&asset.mime_type, &state.cache_control, content),
            Err(error) => {
                tracing::warn!(asset_id = %asset_id, error = %error, "读取媒体对象失败");
                StatusCode::NOT_FOUND.into_response()
            }
        },
        Ok(None) => StatusCode::NOT_FOUND.into_response(),
        Err(error) => {
            tracing::warn!(asset_id = %asset_id, error = %error, "读取媒体资产失败");
            StatusCode::INTERNAL_SERVER_ERROR.into_response()
        }
    }
}

fn media_response(mime_type: &str, cache_control: &str, content: Vec<u8>) -> Response {
    let mut response = Body::from(content).into_response();
    if let Ok(value) = HeaderValue::from_str(mime_type) {
        response.headers_mut().insert(CONTENT_TYPE, value);
    }
    if let Ok(value) = HeaderValue::from_str(cache_control) {
        response.headers_mut().insert(CACHE_CONTROL, value);
    }
    response
}

async fn load_media_asset(
    pool: &PgPool,
    asset_id: Uuid,
) -> Result<Option<MediaContentAssetRow>, sqlx::Error> {
    sqlx::query_as::<_, MediaContentAssetRow>(
        r#"
        SELECT bucket, object_key, mime_type
        FROM media_assets
        WHERE id = $1
          AND deleted_at IS NULL
          AND status IN ('uploaded', 'bound')
        "#,
    )
    .bind(asset_id)
    .fetch_optional(pool)
    .await
}

#[derive(Debug, FromRow)]
struct MediaContentAssetRow {
    bucket: String,
    object_key: String,
    mime_type: String,
}
