use serde::{Deserialize, Serialize};

use crate::ai::AiConversationSurface;

use super::{ContextPetSummary, TemporalContext};

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
    pub temporal_context: Option<TemporalContext>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub selected_pet: Option<ContextPetSummary>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub authorized_pets: Vec<ContextPetSummary>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub session_summary: Option<String>,
}

impl ContextPack {
    /// has_private_context 判断本轮是否携带私域宠物上下文
    /// 核心职责：
    /// - 基于 selected_pet 是否存在判断私域上下文可用性
    /// - 供 TurnContextBuilder 和 RuntimeRequestPolicy 决定私域工具可见性
    #[must_use]
    pub fn has_private_context(&self) -> bool {
        self.selected_pet.is_some()
    }
}
