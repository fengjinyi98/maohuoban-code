use axum::{
    Json,
    extract::{Path, Query, State},
    http::HeaderMap,
    response::Response,
};
use maohuoban_pet_application::pet::UpdateFoodInventoryItem;
use maohuoban_pet_domain::pet::{FoodInventoryCategory, FoodInventoryStatus, FoodScopeType};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::{PetHttpState, auth::current_user_id};
use crate::pet::{
    dto::{CreateFoodInventoryItemRequest, UpdateFoodInventoryItemRequest},
    response::{created_response, error_response, ok_response, unauthorized_response},
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

/// create_food_inventory_item 创建食品资产
pub(super) async fn create_food_inventory_item(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Json(request): Json<CreateFoodInventoryItemRequest>,
) -> Response {
    let Ok(actor_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    let input = request.into_new(FoodScopeType::User, actor_user_id, actor_user_id);

    match state.pet.create_food_inventory_item(input).await {
        Ok(item) => created_response("food_inventory.item_created", "食品资产已入库", item),
        Err(error) => error_response(&error),
    }
}

/// list_food_inventory_items 查询食品资产列表
pub(super) async fn list_food_inventory_items(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Query(query): Query<ListFoodInventoryQuery>,
) -> Response {
    let Ok(actor_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

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
    headers: HeaderMap,
    Path(item_id): Path<Uuid>,
) -> Response {
    let Ok(actor_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    match state.pet.find_food_inventory_item(item_id).await {
        Ok(item) if item.scope_type == FoodScopeType::User && item.scope_id == actor_user_id => {
            ok_response("food_inventory.item_loaded", "食品资产已加载", item)
        }
        Ok(_) => error_response(&maohuoban_pet_domain::pet::PetError::FoodInventoryNotFound),
        Err(error) => error_response(&error),
    }
}

/// update_food_inventory_item 编辑食品资产
pub(super) async fn update_food_inventory_item(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(item_id): Path<Uuid>,
    Json(request): Json<UpdateFoodInventoryItemRequest>,
) -> Response {
    let Ok(editor_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    let input = request.into_update(item_id, editor_user_id);

    match state.pet.update_food_inventory_item(input).await {
        Ok(item) => ok_response("food_inventory.item_updated", "食品资产已更新", item),
        Err(error) => error_response(&error),
    }
}

/// archive_food_inventory_item 归档食品资产
pub(super) async fn archive_food_inventory_item(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(item_id): Path<Uuid>,
) -> Response {
    let Ok(editor_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    match state
        .pet
        .archive_food_inventory_item(item_id, editor_user_id)
        .await
    {
        Ok(item) => ok_response("food_inventory.item_archived", "食品资产已归档", item),
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
    headers: HeaderMap,
    Path(item_id): Path<Uuid>,
    Json(request): Json<RestockFoodInventoryRequest>,
) -> Response {
    let Ok(editor_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

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
                    expiry_date: None,
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

/// RestoreFoodInventoryRequest 恢复食品资产请求
#[derive(Debug, Deserialize)]
pub(super) struct RestoreFoodInventoryRequest {
    inventory_status: FoodInventoryStatus,
}

/// restore_food_inventory_item 恢复食品资产
pub(super) async fn restore_food_inventory_item(
    State(state): State<PetHttpState>,
    headers: HeaderMap,
    Path(item_id): Path<Uuid>,
    Json(request): Json<RestoreFoodInventoryRequest>,
) -> Response {
    let Ok(editor_user_id) = current_user_id(&state.auth, &headers).await else {
        return unauthorized_response();
    };

    match state
        .pet
        .restore_food_inventory_item(item_id, editor_user_id, request.inventory_status)
        .await
    {
        Ok(item) => ok_response("food_inventory.item_restored", "食品资产已恢复", item),
        Err(error) => error_response(&error),
    }
}
