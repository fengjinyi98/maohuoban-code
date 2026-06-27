use maohuoban_ai_domain::ai::{LlmChatRequest, LlmMessage, LlmRole};

/// build_llm_request 构建最小 LLM 请求
/// 核心职责：
/// - 将用户消息包装为内部稳定 LLM 请求
/// - 注入毛球助手基础系统提示
pub(super) fn build_llm_request(message: &str) -> LlmChatRequest {
    LlmChatRequest {
        model: "default".to_owned(),
        messages: vec![
            LlmMessage {
                role: LlmRole::System,
                content: "你是毛球助手，毛伙伴平台的宠物照护 AI 助手。".to_owned(),
                tool_call_id: None,
            },
            LlmMessage {
                role: LlmRole::User,
                content: message.to_owned(),
                tool_call_id: None,
            },
        ],
        tools: vec![],
        tool_choice: None,
        temperature: 0.2,
        stream: true,
        max_output_tokens: None,
        response_format: None,
    }
}
