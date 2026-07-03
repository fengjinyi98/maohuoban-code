use maohuoban_ai_domain::ai::{
    LlmChatRequest, LlmDiagnosticsCorrelation, LlmMessage, LlmRole, LlmToolSchema,
};

pub fn sample_request() -> LlmChatRequest {
    LlmChatRequest {
        model: "test-model".to_owned(),
        messages: vec![
            LlmMessage {
                role: LlmRole::System,
                content: "你是毛球助手".to_owned(),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
            LlmMessage {
                role: LlmRole::User,
                content: "毛球怎么样了".to_owned(),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
        ],
        tools: vec![LlmToolSchema {
            name: "load_pet_identity_context".to_owned(),
            description: "加载宠物身份".to_owned(),
            parameters: serde_json::json!({"type": "object"}),
        }],
        tool_choice: Some("auto".to_owned()),
        temperature: 0.2,
        stream: false,
        max_output_tokens: Some(1024),
        response_format: None,
        diagnostics_correlation: LlmDiagnosticsCorrelation::default(),
    }
}
