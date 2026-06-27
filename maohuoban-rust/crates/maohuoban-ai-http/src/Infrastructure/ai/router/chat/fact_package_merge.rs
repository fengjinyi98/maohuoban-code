use maohuoban_ai_domain::ai::{AiFactPackage, AiFactStrength};

/// merge_fact_packages 合并多工具事实包
/// 核心职责：
/// - 保留同一目标宠物下的事实、弱线索、引用和缺失信息
/// - 重新计算合并后事实强度，保证 Prompt 使用完整事实包
pub(super) fn merge_fact_packages(
    base: Option<AiFactPackage>,
    addition: Option<AiFactPackage>,
) -> Option<AiFactPackage> {
    match (base, addition) {
        (Some(mut base), Some(addition)) => {
            if base.target_pet.is_none() {
                base.target_pet = addition.target_pet;
            }
            base.facts.extend(addition.facts);
            base.computed.extend(addition.computed);
            base.weak_hints.extend(addition.weak_hints);
            base.citations.extend(addition.citations);
            base.missing_info.extend(addition.missing_info);
            base.fact_strength = merged_fact_strength(&base);
            Some(base)
        }
        (Some(base), None) => Some(base),
        (None, Some(addition)) => Some(addition),
        (None, None) => None,
    }
}

/// merged_fact_strength 计算合并事实包强度
/// 核心职责：
/// - 存在强事实时整体标记为 strong
/// - 仅存在待确认事实时标记为 pending_confirmation
fn merged_fact_strength(package: &AiFactPackage) -> AiFactStrength {
    if package
        .facts
        .iter()
        .any(|fact| fact.strength == AiFactStrength::Strong)
    {
        AiFactStrength::Strong
    } else if package
        .facts
        .iter()
        .any(|fact| fact.strength == AiFactStrength::PendingConfirmation)
    {
        AiFactStrength::PendingConfirmation
    } else {
        AiFactStrength::Weak
    }
}
