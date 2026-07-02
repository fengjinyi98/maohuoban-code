use maohuoban_ai_domain::ai::{AiFactPackage, AiFactStrength};

/// `merge_fact_packages` 合并 Runtime 工具返回的事实包
/// 核心职责：
/// - 将多个工具结果聚合为最终回答校验和引用依据
/// - 保持事实桶分离，避免弱线索或待确认事实被提升为强事实
pub(super) fn merge_fact_packages(
    mut base: AiFactPackage,
    incoming: AiFactPackage,
) -> AiFactPackage {
    if base.target_pet.is_none() {
        base.target_pet = incoming.target_pet;
    }
    base.facts.extend(incoming.facts);
    base.computed.extend(incoming.computed);
    base.pending_confirmations
        .extend(incoming.pending_confirmations);
    base.weak_hints.extend(incoming.weak_hints);
    base.citations.extend(incoming.citations);
    base.missing_info.extend(incoming.missing_info);
    base.fact_strength = strongest_fact_strength(base.fact_strength, incoming.fact_strength);
    base
}

fn strongest_fact_strength(left: AiFactStrength, right: AiFactStrength) -> AiFactStrength {
    match (left, right) {
        (AiFactStrength::Strong, _) | (_, AiFactStrength::Strong) => AiFactStrength::Strong,
        (AiFactStrength::PendingConfirmation, _) | (_, AiFactStrength::PendingConfirmation) => {
            AiFactStrength::PendingConfirmation
        }
        (AiFactStrength::Weak, AiFactStrength::Weak) => AiFactStrength::Weak,
    }
}
