use serde::{Deserialize, Serialize};

/// MemoryScope 记忆作用域
/// 核心职责：
/// - 区分用户、宠物、家庭和会话级记忆
/// - 支撑后续记忆隔离与事实投影
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MemoryScope {
    User,
    Pet,
    Household,
    Session,
}
