use maohuoban_ai_domain::ai::{AiConversationSurface, AiPetDisplaySnapshot, LlmToolCall};

/// `VisibleOutputPlan` 本轮用户可见结构化输出计划
/// 核心职责：
/// - 在 projector 之前确定本轮需要渲染的结构化 UI 块
/// - 将 UI 触发依据固定为入口、事实工具计划和稳定工具名
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub(super) struct VisibleOutputPlan {
    pub(super) pet_profile_card: bool,
}

impl VisibleOutputPlan {
    #[must_use]
    pub(crate) const fn empty() -> Self {
        Self {
            pet_profile_card: false,
        }
    }

    #[must_use]
    pub(crate) const fn pet_profile_card() -> Self {
        Self {
            pet_profile_card: true,
        }
    }
}

/// `plan_visible_output` 规划本轮流式可见 UI 块
/// 核心职责：
/// - 基于产品入口和 Runtime 事实证据工具计划决定结构化输出
/// - 避免 projector 或前端解析自然语言文案
#[must_use]
pub(super) fn plan_visible_output(
    surface: AiConversationSurface,
    target_pet: Option<&AiPetDisplaySnapshot>,
    evidence_tool_calls: &[LlmToolCall],
) -> VisibleOutputPlan {
    if target_pet.is_none() {
        return VisibleOutputPlan::empty();
    }
    if surface == AiConversationSurface::PetProfile {
        return VisibleOutputPlan::pet_profile_card();
    }

    if evidence_tool_calls
        .iter()
        .any(|call| call.name == "load_pet_identity_context")
    {
        VisibleOutputPlan::pet_profile_card()
    } else {
        VisibleOutputPlan::empty()
    }
}
