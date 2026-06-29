use serde::{Deserialize, Serialize};

/// Toolset 工具分组
/// 核心职责：
/// - 表达工具所属的受控分组
/// - 每个 turn 的模型工具清单由 toolset + 权限 + selected pet 共同决定
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Toolset {
    /// 公共宠物领域能力，无授权宠物也可使用
    PublicPetDomain,
    /// 私域宠物上下文能力，需要已选授权宠物
    PrivatePetContext,
    /// App 产品帮助能力
    AppSupport,
    /// 记忆读写能力
    Memory,
    /// 确认流程能力
    Confirmation,
}

impl Toolset {
    /// as_str 返回稳定分组名
    #[must_use]
    pub fn as_str(self) -> &'static str {
        match self {
            Self::PublicPetDomain => "public_pet_domain",
            Self::PrivatePetContext => "private_pet_context",
            Self::AppSupport => "app_support",
            Self::Memory => "memory",
            Self::Confirmation => "confirmation",
        }
    }
}
