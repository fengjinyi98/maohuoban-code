use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::ai::{AiConversationSurface, AiIntent, CapabilityDomain, Toolset};

/// SkillMatchConditions Skill 命中条件
/// 核心职责：
/// - 表达意图、任务类型、入口、能力域和用户作用域等匹配条件
/// - 只描述匹配输入，不承载执行逻辑
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct SkillMatchConditions {
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub intents: Vec<AiIntent>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub capability_domains: Vec<CapabilityDomain>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub capability_codes: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub task_types: Vec<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub surfaces: Vec<AiConversationSurface>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub toolsets: Vec<Toolset>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub actor_user_ids: Vec<Uuid>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub household_ids: Vec<Uuid>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub requires_selected_pet: Option<bool>,
}

impl SkillMatchConditions {
    /// is_empty 判断是否没有任何显式条件
    #[must_use]
    pub fn is_empty(&self) -> bool {
        self.intents.is_empty()
            && self.capability_domains.is_empty()
            && self.capability_codes.is_empty()
            && self.task_types.is_empty()
            && self.surfaces.is_empty()
            && self.toolsets.is_empty()
            && self.actor_user_ids.is_empty()
            && self.household_ids.is_empty()
            && self.requires_selected_pet.is_none()
    }
}
