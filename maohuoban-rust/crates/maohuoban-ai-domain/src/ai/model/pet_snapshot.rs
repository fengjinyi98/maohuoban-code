use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// AiPetCandidate 授权宠物候选摘要
/// 核心职责：
/// - 承载 Agent 解析宠物所需的最小展示字段
/// - 严格裁剪，不携带饮食、异常、事件等强事实
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AiPetCandidate {
    pub pet_id: Uuid,
    pub name: String,
    pub avatar_url: Option<String>,
    pub species: String,
    pub profile_number: String,
}

/// AiPetDisplaySnapshot 宠物展示快照
/// 核心职责：
/// - 用于 AI 会话历史列表展示
/// - 只服务展示，不作为新一轮事实判断来源
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AiPetDisplaySnapshot {
    pub pet_id: Uuid,
    pub pet_name: String,
    pub pet_avatar_url: Option<String>,
    pub pet_species: String,
    pub profile_number: String,
}

impl From<&AiPetCandidate> for AiPetDisplaySnapshot {
    fn from(candidate: &AiPetCandidate) -> Self {
        Self {
            pet_id: candidate.pet_id,
            pet_name: candidate.name.clone(),
            pet_avatar_url: candidate.avatar_url.clone(),
            pet_species: candidate.species.clone(),
            profile_number: candidate.profile_number.clone(),
        }
    }
}
