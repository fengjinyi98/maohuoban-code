use serde::{Deserialize, Serialize};

/// CapabilityDomain Agent 能力域
/// 核心职责：
/// - 表达模型可使用的受控能力边界
/// - 区分公共宠物能力、私域事实能力和硬安全能力
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CapabilityDomain {
    PublicPetDomain,
    PrivatePetContext,
    AppProductSupport,
    AssistantIdentity,
    HardSafety,
}
