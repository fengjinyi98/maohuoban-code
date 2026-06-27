//! pet_resolver 宠物解析器
//! 核心职责：
//! - 结合当前入口 selected pet、用户消息中的宠物名、授权宠物列表解析唯一目标宠物
//! - 歧义时返回 needs_selection，未授权时返回统一拒绝

use std::sync::Arc;

use maohuoban_ai_domain::ai::{AiPetCandidate, AiPetDisplaySnapshot, AiPetResolution, AiResult};

use crate::ai::ports::AuthorizedPetCatalog;

/// AiPetResolver 宠物解析器
/// 核心职责：
/// - 在授权宠物集合内解析用户消息对应的目标宠物
/// - 最终 target_pet_id 必须由后端在授权集合内确定
pub struct AiPetResolver {
    catalog: Arc<dyn AuthorizedPetCatalog>,
}

impl AiPetResolver {
    /// new 构造宠物解析器
    #[must_use]
    pub fn new(catalog: impl AuthorizedPetCatalog + 'static) -> Self {
        Self {
            catalog: Arc::new(catalog),
        }
    }

    /// resolve 解析目标宠物
    /// 核心职责：
    /// - 优先使用 selected_pet_id（消息未提及切换时）
    /// - 消息中出现唯一授权宠物名时切换到该宠物
    /// - 同名歧义返回 needs_selection
    pub async fn resolve(
        &self,
        message: &str,
        selected_pet_id: Option<uuid::Uuid>,
        actor_user_id: uuid::Uuid,
    ) -> AiResult<AiPetResolution> {
        let candidates = self
            .catalog
            .list_authorized_candidates(actor_user_id)
            .await?;

        if candidates.is_empty() {
            return Ok(AiPetResolution::NoPetContext);
        }

        let name_matches = match_pets_by_name(&candidates, message);

        if let Some(selected) = selected_pet_id {
            return Ok(Self::resolve_with_selected(
                &candidates,
                &name_matches,
                selected,
            ));
        }

        // 无 selected pet
        match name_matches.len() {
            0 => {
                // 没有授权宠物名匹配，检测是否消息引用了未知宠物名
                if detect_unknown_pet_name_reference(message) {
                    return Ok(AiPetResolution::UnauthorizedOrNotFound);
                }
                if candidates.len() == 1 {
                    Ok(resolved_from_candidate(&candidates[0]))
                } else {
                    Ok(AiPetResolution::NeedsSelection { candidates })
                }
            }
            1 => Ok(resolved_from_candidate(&name_matches[0])),
            _ => Ok(AiPetResolution::NeedsSelection {
                candidates: name_matches,
            }),
        }
    }

    /// resolve_with_selected 有 selected pet 时的解析
    fn resolve_with_selected(
        candidates: &[AiPetCandidate],
        name_matches: &[AiPetCandidate],
        selected_pet_id: uuid::Uuid,
    ) -> AiPetResolution {
        let Some(selected_candidate) = candidates.iter().find(|c| c.pet_id == selected_pet_id)
        else {
            return AiPetResolution::UnauthorizedOrNotFound;
        };

        let switch_match: Vec<&AiPetCandidate> = name_matches
            .iter()
            .filter(|c| c.pet_id != selected_pet_id)
            .collect();

        match switch_match.len() {
            0 => resolved_from_candidate(selected_candidate),
            1 => resolved_from_candidate(switch_match[0]),
            _ => AiPetResolution::NeedsSelection {
                candidates: switch_match.into_iter().cloned().collect(),
            },
        }
    }
}

/// match_pets_by_name 在候选中查找名字出现在消息里的宠物
fn match_pets_by_name(candidates: &[AiPetCandidate], message: &str) -> Vec<AiPetCandidate> {
    candidates
        .iter()
        .filter(|c| message.contains(c.name.as_str()))
        .cloned()
        .collect()
}

/// detect_unknown_pet_name_reference 检测消息是否引用了不在授权列表中的宠物名
/// 核心职责：
/// - 通过高置信触发词（今天、最近）和 2 字前缀模式识别宠物名引用
/// - 帮助区分"用户提到了一个名字"与"用户只是在描述症状"
fn detect_unknown_pet_name_reference(message: &str) -> bool {
    const TRIGGERS: &[&str] = &["今天", "最近"];

    for trigger in TRIGGERS {
        if let Some(pos) = message.find(trigger) {
            let prefix = &message[..pos];
            let char_count = prefix.chars().count();
            if char_count == 2 {
                return true;
            }
        }
    }
    false
}

/// resolved_from_candidate 从候选构造 Resolved 结果
fn resolved_from_candidate(candidate: &AiPetCandidate) -> AiPetResolution {
    AiPetResolution::Resolved {
        pet_id: candidate.pet_id,
        snapshot: AiPetDisplaySnapshot::from(candidate),
    }
}
