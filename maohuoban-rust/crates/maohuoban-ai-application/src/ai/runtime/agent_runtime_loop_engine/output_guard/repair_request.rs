use maohuoban_ai_domain::ai::{
    AgentSessionState, AiAnswerVerification, AiFactEntry, AiFactPackage, LlmChatRequest,
    LlmDiagnosticsCorrelation, LlmMessage, LlmRole,
};

/// build_output_repair_request 构造输出修复模型请求
/// 核心职责：
/// - 将校验失败作为内部反馈回灌模型
/// - 携带候选回答、校验反馈和已确认事实
pub(super) fn build_output_repair_request(
    state: &AgentSessionState,
    package: &AiFactPackage,
    candidate_answer: &str,
    verification: &AiAnswerVerification,
    successful_write_tools: &[String],
) -> LlmChatRequest {
    let user_message = state.user_inputs.last().cloned().unwrap_or_default();
    LlmChatRequest {
        model: "primary".to_owned(),
        messages: vec![
            LlmMessage {
                role: LlmRole::System,
                content: repair_system_prompt(package),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
            LlmMessage {
                role: LlmRole::User,
                content: format!(
                    "用户原始问题：\n{user_message}\n\n上一次候选回答未通过校验：\n{candidate_answer}\n\n结构化裁决：\n- blocked_reason: {}\n- successful_write_tools: {}\n\n校验反馈：\n{}\n\n请重新生成只给用户看的中文回答。",
                    verification
                        .blocked_reason
                        .map(|reason| reason.as_str())
                        .unwrap_or("none"),
                    if successful_write_tools.is_empty() {
                        "[]".to_owned()
                    } else {
                        format!("[{}]", successful_write_tools.join(", "))
                    },
                    verification
                        .safe_fallback_text
                        .as_deref()
                        .unwrap_or("回答未通过事实校验，请基于已确认事实重写。")
                ),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
        ],
        tools: Vec::new(),
        tool_choice: None,
        temperature: 0.2,
        stream: false,
        max_output_tokens: None,
        response_format: None,
        diagnostics_correlation: LlmDiagnosticsCorrelation {
            session_id: Some(state.chat_session_id),
            turn_id: state
                .current_turn_id
                .map(maohuoban_ai_domain::ai::AgentTurnId::as_uuid),
            message_id: state.current_turn_diagnostics_message_id,
            tool_call_id: None,
        },
    }
}

fn repair_system_prompt(package: &AiFactPackage) -> String {
    let mut prompt = String::new();
    prompt.push_str("你是毛球助手的最终回答修复阶段。\n");
    prompt.push_str("上一次回答与已确认事实冲突，必须重新生成。\n");
    prompt.push_str("规则：只能基于下面已确认事实回答；不要声称档案缺失已有事实；不要输出内部校验文本、字段名、JSON、Markdown 代码块。\n\n");
    prompt.push_str("## 已确认事实\n");
    if let Some(target_pet) = package.target_pet.as_ref() {
        prompt.push_str("- 宠物名字: ");
        prompt.push_str(&target_pet.pet_name);
        prompt.push('\n');
        prompt.push_str("- 宠物物种: ");
        prompt.push_str(&target_pet.pet_species);
        prompt.push('\n');
    }
    append_fact_lines(&mut prompt, &package.facts);
    append_fact_lines(&mut prompt, &package.computed);
    prompt
}

fn append_fact_lines(prompt: &mut String, facts: &[AiFactEntry]) {
    for fact in facts {
        prompt.push_str("- ");
        prompt.push_str(&fact.key);
        prompt.push_str(": ");
        prompt.push_str(&fact.value);
        prompt.push('\n');
    }
}
