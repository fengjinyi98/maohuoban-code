use serde::{Deserialize, Serialize};

/// AiConversationSurface AI 对话入口类型
/// 核心职责：
/// - 标识用户从哪个产品入口进入毛球 Agent
/// - 驱动首版上下文裁剪和展示策略
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiConversationSurface {
    HomePrivate,
    PetProfile,
    AbnormalDetail,
    ConfirmationTask,
    /// ugc_comment 预留入口，首版不承载完整 handoff
    UgcComment,
}

impl AiConversationSurface {
    /// is_private_surface 判断是否为私域对话入口
    pub fn is_private_surface(self) -> bool {
        matches!(
            self,
            Self::HomePrivate | Self::PetProfile | Self::AbnormalDetail | Self::ConfirmationTask
        )
    }
}

impl Default for AiConversationSurface {
    fn default() -> Self {
        Self::HomePrivate
    }
}
