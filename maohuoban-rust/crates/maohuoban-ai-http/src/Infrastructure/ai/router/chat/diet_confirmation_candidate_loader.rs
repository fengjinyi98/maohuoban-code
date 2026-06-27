use maohuoban_ai_application::ai::ports::AiToolAccessLog;
use maohuoban_ai_domain::ai::{
    AiFactPackage, AiPetDisplaySnapshot, AiStreamEvent, AiToolCallStatus,
};
use uuid::Uuid;

use super::super::AiHttpState;

/// load_diet_confirmation_candidate_package 加载饮食待确认候选事实包
/// 核心职责：
/// - 调用后端宠物饮食待确认候选读模型
/// - 写入 load_pet_diet_confirmation_candidates 工具审计并返回 tool_call 事件
pub(super) async fn load_diet_confirmation_candidate_package(
    state: &AiHttpState,
    session_id: Uuid,
    actor_user_id: Uuid,
    target_pet: Option<&AiPetDisplaySnapshot>,
) -> (Option<AiFactPackage>, Vec<AiStreamEvent>) {
    let Some(target_pet) = target_pet else {
        return (None, Vec::new());
    };

    match state
        .pet_context_providers
        .diet_confirmation_candidate_provider
        .load_diet_confirmation_candidate_package(actor_user_id, target_pet)
        .await
    {
        Ok(package) => {
            let returned_ref_ids = package
                .citations
                .iter()
                .map(|citation| citation.source_id.to_string())
                .collect::<Vec<_>>();
            let citation_count = u32::try_from(package.citations.len()).unwrap_or(u32::MAX);
            let _ = state
                .session_repository
                .insert_tool_access_log(&AiToolAccessLog {
                    session_id: Some(session_id),
                    actor_user_id,
                    tool_name: "load_pet_diet_confirmation_candidates".to_owned(),
                    requested_scope: "pet_diet_confirmation_candidates".to_owned(),
                    target_pet_id: Some(target_pet.pet_id),
                    allowed: true,
                    denied_reason: None,
                    returned_ref_ids,
                    duration_ms: 0,
                    risk_signal: None,
                })
                .await;

            (
                Some(package),
                vec![AiStreamEvent::ToolCall {
                    tool_name: "load_pet_diet_confirmation_candidates".to_owned(),
                    status: AiToolCallStatus::Allowed,
                    citation_count,
                }],
            )
        }
        Err(error) => {
            let _ = state
                .session_repository
                .insert_tool_access_log(&AiToolAccessLog {
                    session_id: Some(session_id),
                    actor_user_id,
                    tool_name: "load_pet_diet_confirmation_candidates".to_owned(),
                    requested_scope: "pet_diet_confirmation_candidates".to_owned(),
                    target_pet_id: Some(target_pet.pet_id),
                    allowed: false,
                    denied_reason: Some(error.stable_code().to_owned()),
                    returned_ref_ids: vec![],
                    duration_ms: 0,
                    risk_signal: None,
                })
                .await;
            (None, Vec::new())
        }
    }
}
