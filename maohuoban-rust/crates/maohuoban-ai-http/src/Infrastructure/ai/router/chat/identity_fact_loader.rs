use maohuoban_ai_application::ai::ports::AiToolAccessLog;
use maohuoban_ai_domain::ai::{
    AiFactPackage, AiPetDisplaySnapshot, AiStreamEvent, AiToolCallStatus,
};
use uuid::Uuid;

use super::super::AiHttpState;

/// load_identity_fact_package 加载宠物身份事实包
/// 核心职责：
/// - 调用后端宠物身份事实读模型
/// - 写入 load_pet_identity_context 工具审计并返回 tool_call 事件
pub(super) async fn load_identity_fact_package(
    state: &AiHttpState,
    session_id: Uuid,
    actor_user_id: Uuid,
    target_pet: Option<&AiPetDisplaySnapshot>,
) -> (Option<AiFactPackage>, Vec<AiStreamEvent>) {
    let Some(target_pet) = target_pet else {
        return (None, Vec::new());
    };

    match state
        .identity_fact_provider
        .load_identity_fact_package(actor_user_id, target_pet)
        .await
    {
        Ok(package) => {
            let _ = state
                .session_repository
                .insert_tool_access_log(&AiToolAccessLog {
                    session_id: Some(session_id),
                    actor_user_id,
                    tool_name: "load_pet_identity_context".to_owned(),
                    requested_scope: "pet_identity".to_owned(),
                    target_pet_id: Some(target_pet.pet_id),
                    allowed: true,
                    denied_reason: None,
                    returned_ref_ids: vec![target_pet.pet_id.to_string()],
                    duration_ms: 0,
                    risk_signal: None,
                })
                .await;

            (
                Some(package),
                vec![AiStreamEvent::ToolCall {
                    tool_name: "load_pet_identity_context".to_owned(),
                    status: AiToolCallStatus::Allowed,
                    citation_count: 0,
                }],
            )
        }
        Err(error) => {
            let _ = state
                .session_repository
                .insert_tool_access_log(&AiToolAccessLog {
                    session_id: Some(session_id),
                    actor_user_id,
                    tool_name: "load_pet_identity_context".to_owned(),
                    requested_scope: "pet_identity".to_owned(),
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
