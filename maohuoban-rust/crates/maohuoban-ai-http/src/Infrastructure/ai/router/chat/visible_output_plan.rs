use maohuoban_ai_domain::ai::{AiConversationSurface, AiPetDisplaySnapshot};

/// `VisibleBlockKind` 可见渲染块类型
/// 核心职责：
/// - 约束当前会话允许输出的原生 UI block 类型
/// - 为后续医院、饮食、保险等生成式 UI 扩展稳定入口
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) enum VisibleBlockKind {
    PetProfileCard,
}

impl VisibleBlockKind {
    #[must_use]
    pub(super) const fn code(self) -> &'static str {
        match self {
            Self::PetProfileCard => "pet_profile_card",
        }
    }
}

/// `VisibleOutputPlan` 本轮用户可见结构化输出计划
/// 核心职责：
/// - 在 projector 之前确定本轮需要渲染的结构化 UI 块
/// - 将 UI 触发依据固定为显式入口或后续 `RenderPlan` 合同
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub(super) struct VisibleOutputPlan {
    pub(super) allowed_block_kinds: &'static [VisibleBlockKind],
}

impl VisibleOutputPlan {
    #[must_use]
    pub(crate) const fn empty() -> Self {
        Self {
            allowed_block_kinds: &[],
        }
    }

    #[must_use]
    pub(super) fn allows(self, kind: VisibleBlockKind) -> bool {
        self.allowed_block_kinds.contains(&kind)
    }

    #[must_use]
    pub(super) fn block_kind_codes(self) -> Vec<&'static str> {
        self.allowed_block_kinds
            .iter()
            .map(|kind| kind.code())
            .collect()
    }
}

/// `plan_visible_output` 规划本轮流式可见 UI 块
/// 核心职责：
/// - 保持产品入口不预加载资料卡 UI
/// - 将资料卡展示交给后续显式 `RenderPlan` 合同决定
#[must_use]
pub(super) fn plan_visible_output(
    _surface: AiConversationSurface,
    _target_pet: Option<&AiPetDisplaySnapshot>,
) -> VisibleOutputPlan {
    VisibleOutputPlan::empty()
}
