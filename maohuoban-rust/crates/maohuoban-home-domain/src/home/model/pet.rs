use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// PetHeroSummary 宠物主卡摘要
/// 核心职责：
/// - 承载首页首屏宠物主体信息
/// - 避免首页依赖完整宠物档案字段
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PetHeroSummary {
    pub id: Uuid,
    pub name: String,
    pub species: PetSpecies,
    pub breed: String,
    pub sex: PetSex,
    pub age_text: String,
    pub status_text: String,
    pub updated_text: String,
    pub avatar_url: Option<String>,
    #[serde(default)]
    pub avatar_width: Option<i32>,
    #[serde(default)]
    pub avatar_height: Option<i32>,
    #[serde(default)]
    pub hero_image_url: Option<String>,
    #[serde(default)]
    pub hero_image_width: Option<i32>,
    #[serde(default)]
    pub hero_image_height: Option<i32>,
    #[serde(default)]
    pub hero_video_url: Option<String>,
    #[serde(default)]
    pub hero_video_width: Option<i32>,
    #[serde(default)]
    pub hero_video_height: Option<i32>,
    #[serde(default)]
    pub hero_live_photo: Option<HeroLivePhotoSummary>,
    #[serde(default)]
    pub hero_theme_color_hex: Option<String>,
    #[serde(default)]
    pub hero_content_color_scheme: Option<String>,
    #[serde(default)]
    pub profile_number: Option<String>,
    #[serde(default)]
    pub microchip_number: Option<String>,
    pub birthday: Option<chrono::NaiveDate>,
    #[serde(default)]
    pub arrival_date: Option<chrono::NaiveDate>,
    #[serde(default)]
    pub world_days: Option<i32>,
    #[serde(default)]
    pub weight_grams: Option<i32>,
    #[serde(default)]
    pub neuter_status: Option<PetNeuterStatus>,
    #[serde(default)]
    pub personality_tags: Vec<String>,
    #[serde(default)]
    pub note: Option<String>,
    #[serde(default)]
    pub name_edit_policy: Option<PetNameEditPolicy>,
    pub companionship_days: Option<i32>,
}

/// HeroLivePhotoSummary 首页 Live Photo 背景摘要
/// 核心职责：
/// - 返回 Live Photo 静态图和配对视频组件
/// - 为客户端重建 PHLivePhoto 提供尺寸与 URL 契约
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct HeroLivePhotoSummary {
    pub still_url: String,
    #[serde(default)]
    pub still_width: Option<i32>,
    #[serde(default)]
    pub still_height: Option<i32>,
    pub paired_video_url: String,
    #[serde(default)]
    pub paired_video_width: Option<i32>,
    #[serde(default)]
    pub paired_video_height: Option<i32>,
    #[serde(default)]
    pub paired_video_duration_ms: Option<i32>,
    #[serde(default)]
    pub crop: Option<HeroLivePhotoCrop>,
}

/// HeroLivePhotoCrop 首页 Live Photo 裁剪区域
/// 核心职责：
/// - 使用归一化坐标返回后端持久化的展示裁剪区域
/// - 让客户端用原始 Live Photo 资源重建后仍能保持同一构图
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub struct HeroLivePhotoCrop {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

/// PetNameEditPolicy 宠物名字编辑策略
/// 核心职责：
/// - 承载首页进入编辑页所需的改名额度
/// - 保持前端只展示后端计算结果
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PetNameEditPolicy {
    pub max_count: i32,
    pub used_count: i32,
    pub remaining_count: i32,
    pub window_days: i32,
    pub window_ends_at: Option<chrono::DateTime<chrono::Utc>>,
    pub display_text: String,
}

/// PetSpecies 宠物物种
/// 核心职责：
/// - 约束首页和事件模型中的物种表达
/// - 为后续猫狗以外物种保留扩展枚举
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PetSpecies {
    Dog,
    Cat,
    Other,
}

/// PetSex 宠物性别
/// 核心职责：
/// - 统一宠物基础档案和首页主卡性别表达
/// - 支持未知状态
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PetSex {
    Female,
    Male,
    Unknown,
}

/// PetNeuterStatus 宠物绝育状态
/// 核心职责：
/// - 承载首页进入编辑页所需档案字段
/// - 与宠物档案后端枚举保持同名语义
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PetNeuterStatus {
    Unknown,
    Intact,
    Neutered,
}

/// PetSwitchItem 宠物切换项
/// 核心职责：
/// - 承载多宠用户和商家多宠切换入口
/// - 让首页保持当前宠物和其他宠物的轻量索引
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct PetSwitchItem {
    pub id: Uuid,
    pub name: String,
    pub species: PetSpecies,
    #[serde(default)]
    pub breed: String,
    pub avatar_url: Option<String>,
    #[serde(default)]
    pub avatar_width: Option<i32>,
    #[serde(default)]
    pub avatar_height: Option<i32>,
    #[serde(default)]
    pub profile_number: Option<String>,
    #[serde(default)]
    pub microchip_number: Option<String>,
    #[serde(default)]
    pub birthday: Option<chrono::NaiveDate>,
    #[serde(default)]
    pub arrival_date: Option<chrono::NaiveDate>,
    #[serde(default)]
    pub weight_grams: Option<i32>,
    #[serde(default)]
    pub neuter_status: Option<PetNeuterStatus>,
    #[serde(default)]
    pub personality_tags: Vec<String>,
    #[serde(default)]
    pub note: Option<String>,
    #[serde(default)]
    pub name_edit_policy: Option<PetNameEditPolicy>,
    pub is_selected: bool,
}
