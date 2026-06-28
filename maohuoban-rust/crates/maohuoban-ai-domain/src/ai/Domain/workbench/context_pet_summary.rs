use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// ContextPetSummary 模型可见宠物摘要
/// 核心职责：
/// - 承载工具调用和表达所需的最小宠物身份
/// - 避免暴露展示状态、权限字段和内部结构
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContextPetSummary {
    pub pet_id: Uuid,
    pub name: String,
    pub species: String,
}
