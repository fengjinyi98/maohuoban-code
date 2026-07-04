use axum::{
    Json,
    extract::{Multipart, Path, Query, State},
    response::Response,
};
use maohuoban_auth_http::auth::extractor::AuthenticatedUser;
use maohuoban_pet_application::pet::UpdateFoodInventoryItem;
use maohuoban_pet_domain::pet::{FoodInventoryCategory, FoodInventoryStatus, FoodScopeType};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::PetHttpState;
use crate::pet::{
    dto::{
        CreateFoodInventoryItemRequest, PetMediaUploadData, UpdateFoodInventoryItemRequest,
        UploadPetMediaRequest,
    },
    response::{created_response, error_response, ok_response, ok_response_with_message},
};

/// ListFoodInventoryQuery 食品资产列表查询
/// 核心职责：
/// - 接收 category 和 status 可选的查询过滤
#[derive(Debug, Deserialize)]
pub(super) struct ListFoodInventoryQuery {
    category: Option<FoodInventoryCategory>,
    status: Option<FoodInventoryStatus>,
}

/// FoodInventoryItemsData 食品资产列表响应
/// 核心职责：
/// - 保持列表接口 data.items 契约稳定
#[derive(Debug, Serialize)]
pub(super) struct FoodInventoryItemsData<T> {
    items: Vec<T>,
}

/// upload_pending_food_inventory_cover 上传储物柜物品照片
/// 核心职责：
/// - 将物品照片上传到当前用户媒资空间
/// - 返回可被 food_inventory_items.cover_asset_id 引用的媒资 ID
pub(super) async fn upload_pending_food_inventory_cover(
    State(state): State<PetHttpState>,
    actor: AuthenticatedUser,
    multipart: Multipart,
) -> Response {
    let request = match UploadPetMediaRequest::from_multipart(multipart).await {
        Ok(request) => request,
        Err(error) => return error_response(&error),
    };
    let input = request.into_pending_food_inventory_cover_input(actor.user_id());
    match state.pet.upload_pending_pet_media(input).await {
        Ok(upload) => created_response(
            "food_inventory.media_uploaded",
            "储物柜物品照片已上传",
            PetMediaUploadData::from(upload),
        ),
        Err(error) => error_response(&error),
    }
}

/// create_food_inventory_item 创建食品资产
/// 核心职责：
/// - 将前端入库请求落到当前用户的储物柜空间
/// - 保持食品资产归属为 user scope，不接收 pet_id 作为资产归属
pub(super) async fn create_food_inventory_item(
    State(state): State<PetHttpState>,
    actor: AuthenticatedUser,
    Json(request): Json<CreateFoodInventoryItemRequest>,
) -> Response {
    let actor_user_id = actor.user_id();

    let input = request.into_new(FoodScopeType::User, actor_user_id, actor_user_id);

    match state.pet.create_food_inventory_item(input).await {
        Ok(item) => created_response("food_inventory.item_created", "食品资产已入库", item),
        Err(error) => error_response(&error),
    }
}

/// list_food_inventory_items 查询食品资产列表
/// 核心职责：
/// - 查询当前用户储物柜空间内的食品资产
/// - 只支持 category/status 过滤，宠物维度由饮食配置接口表达
pub(super) async fn list_food_inventory_items(
    State(state): State<PetHttpState>,
    actor: AuthenticatedUser,
    Query(query): Query<ListFoodInventoryQuery>,
) -> Response {
    let actor_user_id = actor.user_id();

    match state
        .pet
        .list_food_inventory_items(
            FoodScopeType::User,
            actor_user_id,
            query.category,
            query.status,
        )
        .await
    {
        Ok(items) => ok_response(
            "food_inventory.list_loaded",
            "食品资产列表已加载",
            FoodInventoryItemsData { items },
        ),
        Err(error) => error_response(&error),
    }
}

/// get_food_inventory_item 获取单个食品资产
pub(super) async fn get_food_inventory_item(
    State(state): State<PetHttpState>,
    Path(item_id): Path<Uuid>,
    actor: AuthenticatedUser,
) -> Response {
    let actor_user_id = actor.user_id();

    match state.pet.find_food_inventory_item(item_id).await {
        Ok(item)
            if item.scope_type == FoodScopeType::User
                && item.scope_id == actor_user_id
                && item.archived_at.is_none() =>
        {
            ok_response("food_inventory.item_loaded", "食品资产已加载", item)
        }
        Ok(_) => error_response(&maohuoban_pet_domain::pet::PetError::FoodInventoryNotFound),
        Err(error) => error_response(&error),
    }
}

/// get_food_inventory_item_detail 获取食品资产详情
/// 核心职责：
/// - 返回物品详情页所需的后端读模型
/// - 保持关联宠物、喂食时间线和消耗统计由后端统一聚合
pub(super) async fn get_food_inventory_item_detail(
    State(state): State<PetHttpState>,
    Path(item_id): Path<Uuid>,
    actor: AuthenticatedUser,
) -> Response {
    let actor_user_id = actor.user_id();

    match state
        .pet
        .load_food_inventory_item_detail(item_id, actor_user_id)
        .await
    {
        Ok(detail) => ok_response(
            "food_inventory.item_detail_loaded",
            "食品资产详情已加载",
            detail,
        ),
        Err(error) => error_response(&error),
    }
}

/// update_food_inventory_item 编辑食品资产
pub(super) async fn update_food_inventory_item(
    State(state): State<PetHttpState>,
    Path(item_id): Path<Uuid>,
    actor: AuthenticatedUser,
    Json(request): Json<UpdateFoodInventoryItemRequest>,
) -> Response {
    let editor_user_id = actor.user_id();

    let input = request.into_update(item_id, editor_user_id);

    match state.pet.update_food_inventory_item(input).await {
        Ok(item) => ok_response("food_inventory.item_updated", "食品资产已更新", item),
        Err(error) => error_response(&error),
    }
}

/// delete_food_inventory_item 移出储物柜
/// 核心职责：
/// - 将用户删除动作映射到食品资产软删除
/// - 保持 HTTP 契约使用删除语义
pub(super) async fn delete_food_inventory_item(
    State(state): State<PetHttpState>,
    Path(item_id): Path<Uuid>,
    actor: AuthenticatedUser,
) -> Response {
    let editor_user_id = actor.user_id();

    match state
        .pet
        .delete_food_inventory_item(item_id, editor_user_id)
        .await
    {
        Ok(item) => ok_response("food_inventory.item_deleted", "食品资产已移出储物柜", item),
        Err(error) => error_response(&error),
    }
}

/// RestockFoodInventoryRequest 补库存请求
#[derive(Debug, Deserialize)]
pub(super) struct RestockFoodInventoryRequest {
    quantity_delta: i32,
    inventory_status: Option<FoodInventoryStatus>,
}

/// restock_food_inventory_item 补库存
pub(super) async fn restock_food_inventory_item(
    State(state): State<PetHttpState>,
    Path(item_id): Path<Uuid>,
    actor: AuthenticatedUser,
    Json(request): Json<RestockFoodInventoryRequest>,
) -> Response {
    let editor_user_id = actor.user_id();

    if request
        .inventory_status
        .is_some_and(FoodInventoryStatus::is_archived)
    {
        return error_response(&maohuoban_pet_domain::pet::PetError::InvalidInput(
            "归档状态只能通过归档操作设置".to_owned(),
        ));
    }

    match state
        .pet
        .restock_food_inventory_item(item_id, editor_user_id, request.quantity_delta)
        .await
    {
        Ok(mut item) => {
            if let Some(status) = request.inventory_status {
                let input = UpdateFoodInventoryItem {
                    item_id,
                    editor_user_id,
                    name: None,
                    brand: None,
                    category: None,
                    inventory_status: Some(status),
                    quantity: None,
                    unit: None,
                    spec: None,
                    package_weight_grams: None,
                    package_count: None,
                    package_unit: None,
                    production_date: None,
                    shelf_life_months: None,
                    cover_asset_id: None,
                    barcode: None,
                    note: None,
                };
                match state.pet.update_food_inventory_item(input).await {
                    Ok(updated) => item = updated,
                    Err(error) => return error_response(&error),
                }
            }
            ok_response("food_inventory.item_restocked", "库存已补充", item)
        }
        Err(error) => error_response(&error),
    }
}

/// consume_one_food_inventory_item 确认消耗一个包装单位
/// 核心职责：
/// - 将用户低心智“已吃完”动作提交给后端库存用例
/// - 返回后端生成的 toast 文案和扣减后的库存状态
pub(super) async fn consume_one_food_inventory_item(
    State(state): State<PetHttpState>,
    Path(item_id): Path<Uuid>,
    actor: AuthenticatedUser,
) -> Response {
    let editor_user_id = actor.user_id();

    match state
        .pet
        .consume_one_food_inventory_item(item_id, editor_user_id)
        .await
    {
        Ok(result) => {
            let message = result.message.clone();
            ok_response_with_message("food_inventory.item_consumed", &message, result)
        }
        Err(error) => error_response(&error),
    }
}
