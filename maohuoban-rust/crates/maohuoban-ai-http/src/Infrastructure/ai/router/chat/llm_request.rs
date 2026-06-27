use maohuoban_ai_application::ai::prompt::AiPromptBuilder;
use maohuoban_ai_domain::ai::{AiPetCandidate, AiPetDisplaySnapshot, LlmChatRequest};

/// build_llm_request 构建 LLM 请求
/// 核心职责：
/// - 通过 AiPromptBuilder 注入系统规则和授权宠物上下文
/// - 保持 Provider 请求使用内部稳定 LlmChatRequest
pub(super) fn build_llm_request(
    message: &str,
    target_pet: Option<&AiPetDisplaySnapshot>,
) -> LlmChatRequest {
    let pet_candidates = target_pet.map_or_else(Vec::new, |snapshot| {
        vec![AiPetCandidate {
            pet_id: snapshot.pet_id,
            name: snapshot.pet_name.clone(),
            avatar_url: snapshot.pet_avatar_url.clone(),
            species: snapshot.pet_species.clone(),
            profile_number: snapshot.profile_number.clone(),
        }]
    });

    LlmChatRequest {
        model: "default".to_owned(),
        messages: AiPromptBuilder::new().build_messages(message, &pet_candidates, None),
        tools: vec![],
        tool_choice: None,
        temperature: 0.2,
        stream: true,
        max_output_tokens: None,
        response_format: None,
    }
}
