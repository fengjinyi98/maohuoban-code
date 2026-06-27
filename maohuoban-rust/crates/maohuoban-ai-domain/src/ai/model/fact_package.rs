use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::AiPetDisplaySnapshot;

/// AiFactStrength 事实强度
/// 核心职责：
/// - 区分强事实与弱线索，驱动回答校验
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiFactStrength {
    Strong,
    Weak,
    PendingConfirmation,
}

/// AiCitationSourceKind 引用来源类型
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiCitationSourceKind {
    PetEvent,
    DietAssignment,
    FoodInventoryHint,
    AttentionHint,
    ConfirmationTask,
    AbnormalEpisode,
}

/// AiCitation 回答引用
/// 核心职责：
/// - 关联回答与事实来源 ID 和类型，供前端引用 chip 展示
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AiCitation {
    pub source_kind: AiCitationSourceKind,
    pub source_id: Uuid,
    pub label: String,
}

/// AiFactEntry 单条事实条目
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AiFactEntry {
    pub key: String,
    pub value: String,
    pub strength: AiFactStrength,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub citation_id: Option<Uuid>,
}

/// AiFactPackage 事实包
/// 核心职责：
/// - 聚合目标宠物、强事实、弱线索、引用和缺失信息
/// - 作为 Prompt 构建和回答校验的唯一事实依据
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AiFactPackage {
    pub target_pet: Option<AiPetDisplaySnapshot>,
    pub facts: Vec<AiFactEntry>,
    pub computed: Vec<AiFactEntry>,
    pub weak_hints: Vec<AiFactEntry>,
    pub citations: Vec<AiCitation>,
    pub missing_info: Vec<String>,
    pub fact_strength: AiFactStrength,
}

impl AiFactPackage {
    /// empty 构建空事实包
    pub fn empty() -> Self {
        Self {
            target_pet: None,
            facts: Vec::new(),
            computed: Vec::new(),
            weak_hints: Vec::new(),
            citations: Vec::new(),
            missing_info: Vec::new(),
            fact_strength: AiFactStrength::Weak,
        }
    }

    /// strong_fact_values 返回所有强事实的值集合，用于回答校验
    pub fn strong_fact_values(&self) -> Vec<&str> {
        self.facts
            .iter()
            .filter(|f| f.strength == AiFactStrength::Strong)
            .map(|f| f.value.as_str())
            .collect()
    }

    /// weak_hint_values 返回所有弱线索的值集合
    pub fn weak_hint_values(&self) -> Vec<&str> {
        self.weak_hints.iter().map(|f| f.value.as_str()).collect()
    }
}

impl Default for AiFactPackage {
    fn default() -> Self {
        Self::empty()
    }
}
