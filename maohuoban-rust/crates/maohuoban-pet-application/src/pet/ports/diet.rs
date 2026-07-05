use async_trait::async_trait;
use chrono::NaiveDate;
use maohuoban_pet_domain::pet::{
    DietAssignmentRole, FoodInventoryCategory, FoodInventoryItem, FoodInventoryStatus,
    FoodScopeType, FoodSnapshot, PetDietAssignment, PetResult,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// SetPetCurrentStapleInput 设为当前主粮输入
/// 核心职责：
/// - 结束旧 active 当前主粮，创建新 active 当前主粮
/// - 写入 diet_change 事件
#[derive(Debug, Clone)]
pub struct SetPetCurrentStapleInput {
    pub pet_id: Uuid,
    pub food_item_id: Uuid,
    pub created_by_user_id: Uuid,
    pub reason: Option<String>,
}

/// SetPetDietAssignmentInput 饮食配置输入
/// 核心职责：
/// - 设置尝试中、常用零食/营养品、禁用/不适合
#[derive(Debug, Clone)]
pub struct SetPetDietAssignmentInput {
    pub pet_id: Uuid,
    pub food_item_id: Uuid,
    pub role: DietAssignmentRole,
    pub created_by_user_id: Uuid,
    pub reason: Option<String>,
}

/// DietRepository 宠物饮食配置仓储端口
/// 核心职责：
/// - 持久化宠物对食品资产的消费配置关系
/// - 同一宠物同一时间只能有一个 active current_staple
#[async_trait]
pub trait DietRepository: Send + Sync {
    async fn set_current_staple(
        &self,
        input: SetPetCurrentStapleInput,
    ) -> PetResult<PetDietAssignment>;

    async fn set_assignment(
        &self,
        input: SetPetDietAssignmentInput,
    ) -> PetResult<PetDietAssignment>;

    async fn end_assignment(
        &self,
        pet_id: Uuid,
        assignment_id: Uuid,
        ended_by_user_id: Uuid,
    ) -> PetResult<PetDietAssignment>;

    async fn list_active_assignments(&self, pet_id: Uuid) -> PetResult<Vec<PetDietAssignment>>;

    async fn find_current_staple(&self, pet_id: Uuid) -> PetResult<Option<PetDietAssignment>>;

    /// 加载宠物当前饮食上下文（强事实）
    async fn load_pet_current_diet_context(&self, pet_id: Uuid)
    -> PetResult<PetCurrentDietContext>;

    /// 加载近期储物柜变化线索（弱线索）
    async fn load_food_inventory_change_hints(
        &self,
        scope_type: FoodScopeType,
        scope_id: Uuid,
        since: chrono::DateTime<chrono::Utc>,
    ) -> PetResult<FoodInventoryChangeHints>;
}

/// DietContextItem 饮食上下文单项
/// 核心职责：
/// - 表达某只宠物当前的饮食配置项
/// - 包含食品引用和角色信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DietContextItem {
    pub assignment_id: Uuid,
    pub food_item_id: Uuid,
    pub food_name: String,
    pub food_brand: Option<String>,
    pub food_category: String,
    pub role: String,
    pub status: String,
}

/// PetCurrentDietContext 宠物当前饮食上下文（强事实）
/// 核心职责：
/// - 汇总当前主粮、尝试中、常用零食/营养品
/// - 包含最近喂食事件和饮食配置变更
/// - Agent 分析的强事实来源
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PetCurrentDietContext {
    pub current_staple: Option<DietContextItem>,
    pub trying_foods: Vec<DietContextItem>,
    pub usual_treats: Vec<DietContextItem>,
    pub usual_nutritions: Vec<DietContextItem>,
    pub recent_feeding_events: Vec<RecentFeedingFact>,
    pub recent_diet_changes: Vec<RecentDietChangeFact>,
}

/// RecentFeedingFact 最近喂食事实
/// 核心职责：
/// - 携带 food_item_id 和 food_snapshot
/// - Agent 用于分析宠物实际摄入
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecentFeedingFact {
    pub event_id: Uuid,
    pub occurred_at: chrono::DateTime<chrono::Utc>,
    pub food_item_id: Option<Uuid>,
    pub food_name: String,
    pub food_snapshot: Option<FoodSnapshot>,
}

/// RecentDietChangeFact 最近饮食配置变更事实
/// 核心职责：
/// - 暴露 diet_change 事件中的食品切换信息
/// - 让 Agent 在异常分析时优先读取强事实
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecentDietChangeFact {
    pub event_id: Uuid,
    pub occurred_at: chrono::DateTime<chrono::Utc>,
    pub event_subkind: String,
    pub from_food_item_id: Option<Uuid>,
    pub to_food_item_id: Uuid,
    pub assignment_id: Uuid,
    pub transition_state: String,
}

/// FoodInventoryChangeHint 储物柜变化线索（弱线索）
/// 核心职责：
/// - 标记近期储物柜新增/编辑/恢复的食品
/// - 仅作为 Agent 追问线索，不能直接推断宠物吃过
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FoodInventoryChangeHint {
    pub item_id: Uuid,
    pub name: String,
    pub category: String,
    pub change_kind: String,
    pub changed_at: chrono::DateTime<chrono::Utc>,
    pub fact_strength: String,
}

/// FoodInventoryChangeHints 储物柜变化线索集合
/// 核心职责：
/// - 汇总近期储物柜变化弱线索
/// - Agent 仅在强事实不足时才参考
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FoodInventoryChangeHints {
    pub hints: Vec<FoodInventoryChangeHint>,
}

/// PetDietConfirmationCandidate 宠物饮食待确认候选
/// 核心职责：
/// - 将未绑定宠物的近期储物柜食品变化转成 Agent 追问候选
/// - 明确标记为待确认线索，避免被误用为摄入事实
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PetDietConfirmationCandidate {
    pub food_item_id: Uuid,
    pub food_name: String,
    pub category: String,
    pub candidate_kind: String,
    pub fact_strength: String,
    pub source_change_kind: String,
    pub source_question: String,
}

/// PetDietConfirmationCandidates 宠物饮食待确认候选集合
/// 核心职责：
/// - 汇总 Agent 需要向用户确认的可能换粮/新食品线索
/// - 保持候选和强事实读模型分离
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PetDietConfirmationCandidates {
    pub candidates: Vec<PetDietConfirmationCandidate>,
}

/// ConfirmPetDietCandidateInput 确认饮食候选输入
/// 核心职责：
/// - 承载用户对 Agent 追问候选的确认结果
/// - 明确是否需要派生饮食配置变更
#[derive(Debug, Clone)]
pub struct ConfirmPetDietCandidateInput {
    pub pet_id: Uuid,
    pub food_item_id: Uuid,
    pub confirmed_by_user_id: Uuid,
    pub confirmed_fact_kind: String,
    pub source_question: String,
    pub derive_diet_change: bool,
    pub derive_feeding_correction: bool,
}

/// ConfirmPetDietCandidateResult 确认饮食候选结果
/// 核心职责：
/// - 返回确认事实事件和可选派生配置
/// - 让 HTTP 层输出稳定可追溯 ID
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConfirmPetDietCandidateResult {
    pub confirmed_event_id: Uuid,
    pub assignment_id: Option<Uuid>,
    pub correction_event_id: Option<Uuid>,
}

/// NewFoodInventoryItem 新建食品资产输入
/// 核心职责：
/// - 汇总创建储物柜食品资产所需字段
/// - 保持 HTTP DTO 与仓储写入解耦
#[derive(Debug, Clone)]
pub struct NewFoodInventoryItem {
    pub scope_type: FoodScopeType,
    pub scope_id: Uuid,
    pub created_by_user_id: Uuid,
    pub name: String,
    pub brand: Option<String>,
    pub category: FoodInventoryCategory,
    pub inventory_status: FoodInventoryStatus,
    pub quantity: i32,
    pub unit: Option<String>,
    pub spec: Option<String>,
    pub production_date: NaiveDate,
    pub shelf_life_months: i32,
    pub expiry_date: NaiveDate,
    pub cover_asset_id: Option<Uuid>,
    pub barcode: Option<String>,
    pub source_kind: maohuoban_pet_domain::pet::FoodSourceKind,
    pub note: Option<String>,
}

/// UpdateFoodInventoryItem 编辑食品资产输入
/// 核心职责：
/// - 表达可编辑的食品资产字段
/// - 保持不可编辑字段由应用服务校验
#[derive(Debug, Clone, Default)]
pub struct UpdateFoodInventoryItem {
    pub item_id: Uuid,
    pub editor_user_id: Uuid,
    pub name: Option<String>,
    pub brand: Option<String>,
    pub category: Option<FoodInventoryCategory>,
    pub inventory_status: Option<FoodInventoryStatus>,
    pub quantity: Option<i32>,
    pub unit: Option<String>,
    pub spec: Option<String>,
    pub production_date: Option<NaiveDate>,
    pub shelf_life_months: Option<i32>,
    pub expiry_date: Option<NaiveDate>,
    pub cover_asset_id: Option<Uuid>,
    pub barcode: Option<String>,
    pub note: Option<String>,
}

/// FoodInventoryRepository 食品资产仓储端口
/// 核心职责：
/// - 持久化用户/家庭空间储物柜食品资产
/// - 支持 CRUD、软删除、补库存和分类查询
#[async_trait]
pub trait FoodInventoryRepository: Send + Sync {
    async fn create_item(&self, input: NewFoodInventoryItem) -> PetResult<FoodInventoryItem>;

    async fn list_items(
        &self,
        scope_type: FoodScopeType,
        scope_id: Uuid,
        category: Option<FoodInventoryCategory>,
        status: Option<FoodInventoryStatus>,
    ) -> PetResult<Vec<FoodInventoryItem>>;

    async fn find_item(&self, item_id: Uuid) -> PetResult<Option<FoodInventoryItem>>;

    async fn update_item(&self, input: UpdateFoodInventoryItem) -> PetResult<FoodInventoryItem>;

    async fn delete_item(
        &self,
        item_id: Uuid,
        editor_user_id: Uuid,
    ) -> PetResult<FoodInventoryItem>;

    async fn restock_item(
        &self,
        item_id: Uuid,
        editor_user_id: Uuid,
        quantity: i32,
    ) -> PetResult<FoodInventoryItem>;
}
