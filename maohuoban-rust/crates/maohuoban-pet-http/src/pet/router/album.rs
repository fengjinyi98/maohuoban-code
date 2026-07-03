use axum::{
    Json,
    extract::{Multipart, Path, Query, State},
    response::Response,
};
use maohuoban_auth_http::auth::extractor::AuthenticatedUser;
use serde::Deserialize;
use uuid::Uuid;

use super::PetHttpState;
use crate::pet::{
    dto::{
        AddPetAlbumAssetRequest, CreatePetAlbumRequest, PetAlbumAssetData, PetAlbumAssetListData,
        PetAlbumData, PetAlbumDetailData, PetAlbumListData, PetMediaUploadData,
        UpdatePetAlbumRequest, UploadPetMediaRequest,
    },
    response::{created_response, error_response, ok_response},
};

pub(super) async fn create_pet_album(
    State(state): State<PetHttpState>,
    Path(pet_id): Path<Uuid>,
    actor: AuthenticatedUser,
    Json(request): Json<CreatePetAlbumRequest>,
) -> Response {
    let input = request.into_input(Some(pet_id), actor.user_id());
    match state.pet.create_pet_album(input).await {
        Ok(album) => created_response("pet_album.created", "相册已创建", PetAlbumData::from(album)),
        Err(error) => error_response(&error),
    }
}

/// create_user_pet_album 创建用户相册空间内的宠物相册
/// 核心职责：
/// - 不要求客户端提供当前宠物 ID
/// - 让宠物只作为可选来源/筛选上下文进入相册模型
pub(super) async fn create_user_pet_album(
    State(state): State<PetHttpState>,
    actor: AuthenticatedUser,
    Json(request): Json<CreatePetAlbumRequest>,
) -> Response {
    let input = request.into_input(None, actor.user_id());
    match state.pet.create_pet_album(input).await {
        Ok(album) => created_response("pet_album.created", "相册已创建", PetAlbumData::from(album)),
        Err(error) => error_response(&error),
    }
}

pub(super) async fn list_pet_albums(
    State(state): State<PetHttpState>,
    Path(_pet_id): Path<Uuid>,
    actor: AuthenticatedUser,
    Query(query): Query<PageQuery>,
) -> Response {
    list_user_pet_albums(State(state), actor, Query(query)).await
}

/// list_user_pet_albums 查询用户相册空间
/// 核心职责：
/// - 按当前用户返回相册分页
/// - 避免首页或我的页用宠物 ID 分裂相册数据源
pub(super) async fn list_user_pet_albums(
    State(state): State<PetHttpState>,
    actor: AuthenticatedUser,
    Query(query): Query<PageQuery>,
) -> Response {
    match state
        .pet
        .list_user_pet_albums(actor.user_id(), query.limit, query.cursor)
        .await
    {
        Ok(page) => ok_response(
            "pet_album.list_loaded",
            "相册列表已加载",
            PetAlbumListData::from(page),
        ),
        Err(error) => error_response(&error),
    }
}

pub(super) async fn load_pet_album(
    State(state): State<PetHttpState>,
    Path(album_id): Path<Uuid>,
    actor: AuthenticatedUser,
) -> Response {
    match state.pet.load_pet_album(album_id, actor.user_id()).await {
        Ok(album) => ok_response(
            "pet_album.loaded",
            "相册详情已加载",
            PetAlbumDetailData::from(album),
        ),
        Err(error) => error_response(&error),
    }
}

pub(super) async fn update_pet_album(
    State(state): State<PetHttpState>,
    Path(album_id): Path<Uuid>,
    actor: AuthenticatedUser,
    Json(request): Json<UpdatePetAlbumRequest>,
) -> Response {
    let input = request.into_input(album_id, actor.user_id());
    match state.pet.update_pet_album(input).await {
        Ok(album) => ok_response("pet_album.updated", "相册已更新", PetAlbumData::from(album)),
        Err(error) => error_response(&error),
    }
}

pub(super) async fn archive_pet_album(
    State(state): State<PetHttpState>,
    Path(album_id): Path<Uuid>,
    actor: AuthenticatedUser,
) -> Response {
    match state.pet.archive_pet_album(album_id, actor.user_id()).await {
        Ok(album) => ok_response(
            "pet_album.archived",
            "相册已归档",
            PetAlbumData::from(album),
        ),
        Err(error) => error_response(&error),
    }
}

pub(super) async fn upload_pending_pet_album_photo(
    State(state): State<PetHttpState>,
    Path(pet_id): Path<Uuid>,
    actor: AuthenticatedUser,
    multipart: Multipart,
) -> Response {
    let request = match UploadPetMediaRequest::from_multipart(multipart).await {
        Ok(request) => request,
        Err(error) => return error_response(&error),
    };
    let input = request.into_pending_album_photo_input(actor.user_id());
    match state
        .pet
        .upload_pending_pet_album_photo_with_source_pet(pet_id, input)
        .await
    {
        Ok(upload) => created_response(
            "pet.media_uploaded",
            "媒体已上传",
            PetMediaUploadData::from(upload),
        ),
        Err(error) => error_response(&error),
    }
}

/// upload_pending_user_pet_album_photo 上传用户相册照片
/// 核心职责：
/// - 上传尚未绑定具体宠物的相册照片
/// - 让照片先进入用户相册空间，后续再按需要关联宠物标签
pub(super) async fn upload_pending_user_pet_album_photo(
    State(state): State<PetHttpState>,
    actor: AuthenticatedUser,
    multipart: Multipart,
) -> Response {
    let request = match UploadPetMediaRequest::from_multipart(multipart).await {
        Ok(request) => request,
        Err(error) => return error_response(&error),
    };
    let input = request.into_pending_album_photo_input(actor.user_id());
    match state.pet.upload_pending_pet_album_photo(input).await {
        Ok(upload) => created_response(
            "pet.media_uploaded",
            "媒体已上传",
            PetMediaUploadData::from(upload),
        ),
        Err(error) => error_response(&error),
    }
}

pub(super) async fn add_pet_album_asset(
    State(state): State<PetHttpState>,
    Path(album_id): Path<Uuid>,
    actor: AuthenticatedUser,
    Json(request): Json<AddPetAlbumAssetRequest>,
) -> Response {
    let input = request.into_input(album_id, actor.user_id());
    match state.pet.add_pet_album_asset(input).await {
        Ok(asset) => created_response(
            "pet_album.asset_added",
            "相册照片已添加",
            PetAlbumAssetData::from(asset),
        ),
        Err(error) => error_response(&error),
    }
}

pub(super) async fn list_pet_album_assets(
    State(state): State<PetHttpState>,
    Path(album_id): Path<Uuid>,
    actor: AuthenticatedUser,
    Query(query): Query<PageQuery>,
) -> Response {
    match state
        .pet
        .list_pet_album_assets(album_id, actor.user_id(), query.limit, query.cursor)
        .await
    {
        Ok(page) => ok_response(
            "pet_album.assets_loaded",
            "相册照片已加载",
            PetAlbumAssetListData::from(page),
        ),
        Err(error) => error_response(&error),
    }
}

pub(super) async fn remove_pet_album_asset(
    State(state): State<PetHttpState>,
    Path(album_asset_id): Path<Uuid>,
    actor: AuthenticatedUser,
) -> Response {
    match state
        .pet
        .remove_pet_album_asset(album_asset_id, actor.user_id())
        .await
    {
        Ok(album) => ok_response(
            "pet_album.asset_removed",
            "相册照片已移除",
            PetAlbumDetailData::from(album),
        ),
        Err(error) => error_response(&error),
    }
}

/// PageQuery 分页查询参数
/// 核心职责：
/// - 接收客户端传入的页大小和 keyset cursor
/// - 让 HTTP handler 保持轻量
#[derive(Debug, Deserialize)]
pub(super) struct PageQuery {
    limit: Option<i64>,
    cursor: Option<String>,
}
