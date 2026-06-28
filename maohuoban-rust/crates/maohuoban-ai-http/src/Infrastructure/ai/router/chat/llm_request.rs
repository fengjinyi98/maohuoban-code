use maohuoban_ai_application::ai::prompt::AiPromptBuilder;
use maohuoban_ai_domain::ai::{
    AiFactPackage, AiPetCandidate, AiPetDisplaySnapshot, LlmChatRequest,
};

/// build_llm_request 构建 LLM 请求
/// 核心职责：
/// - 通过 AiPromptBuilder 注入系统规则和授权宠物上下文
/// - 保持 Provider 请求使用内部稳定 LlmChatRequest
pub(super) fn build_llm_request(
    message: &str,
    target_pet: Option<&AiPetDisplaySnapshot>,
    fact_package: Option<&AiFactPackage>,
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
        model: "primary".to_owned(),
        messages: AiPromptBuilder::new().build_messages(message, &pet_candidates, fact_package),
        tools: vec![],
        tool_choice: None,
        temperature: 0.2,
        stream: true,
        max_output_tokens: None,
        response_format: None,
    }
}

#[cfg(test)]
mod tests {
    use super::build_llm_request;

    #[test]
    fn llm_request_uses_primary_model_label() {
        let request = build_llm_request("毛球今天怎么样", None, None);

        assert_eq!(request.model, "primary");
    }
}
