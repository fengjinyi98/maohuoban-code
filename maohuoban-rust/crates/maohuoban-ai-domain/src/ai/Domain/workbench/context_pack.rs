use serde::{Deserialize, Serialize};

use crate::ai::AiConversationSurface;

use super::ContextPetSummary;

/// ContextPack 本轮可见上下文包
/// 核心职责：
/// - 描述当前入口、语言环境和已授权宠物候选
/// - 只包含允许投影给模型的字段
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContextPack {
    pub surface: AiConversationSurface,
    pub locale: String,
    pub timezone: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub selected_pet: Option<ContextPetSummary>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub authorized_pets: Vec<ContextPetSummary>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub session_summary: Option<String>,
}
