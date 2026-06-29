use maohuoban_ai_application::ai::ports::AiToolAccessLog;
use maohuoban_ai_domain::ai::{AiFactPackage, AiPetDisplaySnapshot, AiStreamEvent};
use uuid::Uuid;

use super::super::AiHttpState;
use super::runtime_stream::safe_execution_trace_completed_for_tool;

/// load_identity_fact_package 加载宠物身份事实包
/// 核心职责：
/// - 调用后端宠物身份事实读模型
/// - 写入 load_pet_identity_context 工具审计并返回安全执行态事件
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
        .pet_context_providers
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
                vec![safe_execution_trace_completed_for_tool(
                    "load_pet_identity_context",
                    &target_pet.pet_name,
                    0,
                )],
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
