use serde::{Deserialize, Serialize};

/// AiIntent 毛球 Agent 意图分类
/// 核心职责：
/// - 表达用户消息的领域意图，驱动是否加载宠物上下文
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiIntent {
    PetCare,
    PetRecordQuery,
    PetFood,
    PetHealthRisk,
    EmotionalPetContext,
    AppSupport,
    OffTopic,
    PromptInjection,
    CostAbuse,
}

impl AiIntent {
    /// is_pet_domain 判断该意图是否属于宠物领域，需要加载宠物事实
    pub fn is_pet_domain(self) -> bool {
        matches!(
            self,
            Self::PetCare
                | Self::PetRecordQuery
                | Self::PetFood
                | Self::PetHealthRisk
                | Self::EmotionalPetContext
        )
    }

    /// requires_context_load 判断该意图是否需要加载私有事实上下文
    pub fn requires_context_load(self) -> bool {
        self.is_pet_domain()
    }
}

/// AiGateDecision 意图闸门决策结果
/// 核心职责：
/// - 记录意图分类、是否加载上下文和风险信号
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AiGateDecision {
    pub intent: AiIntent,
    pub context_loaded: bool,
    pub risk_signal: Option<String>,
    pub reason: String,
}

impl AiGateDecision {
    /// allow_processing 判断该决策是否允许进入主 Agent 编排
    pub fn allow_processing(&self) -> bool {
        !matches!(self.intent, AiIntent::PromptInjection | AiIntent::CostAbuse)
    }
}
