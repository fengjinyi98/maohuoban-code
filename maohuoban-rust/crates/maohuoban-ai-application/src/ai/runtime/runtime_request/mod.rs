use maohuoban_ai_domain::ai::{
    AgentSessionState, AiFactPackage, LlmChatRequest, LlmDiagnosticsCorrelation, LlmMessage,
    LlmRole, LlmToolCall, LlmToolSchema, LoopToolResult,
};

use crate::ai::prompt::AiPromptBuilder;
use crate::ai::skill::SkillBundle;
use crate::ai::tools::ToolRegistry;

use super::agent_runtime_request_policy::AgentRuntimeRequestPolicy;
use super::tool_messages::tool_result_to_message;
use super::workbench_prompt_projection::workbench_context_prompt;

pub(crate) fn build_request(
    state: &AgentSessionState,
    fact_package: Option<&AiFactPackage>,
    registry: &ToolRegistry,
    skill_bundle: Option<&SkillBundle>,
    assistant_reasoning_content: Option<&str>,
    assistant_tool_calls: &[LlmToolCall],
    tool_results: &[LoopToolResult],
) -> LlmChatRequest {
    let is_followup_answer = !assistant_tool_calls.is_empty() || !tool_results.is_empty();
    let tools = if let Some(skill_bundle) = skill_bundle {
        let base_visible_tools =
            AgentRuntimeRequestPolicy::base_visible_tool_definitions(registry, state);
        AgentRuntimeRequestPolicy::visible_tool_schemas_for_bundle(base_visible_tools, skill_bundle)
    } else {
        AgentRuntimeRequestPolicy::visible_tool_schemas(registry, state)
    };
    let response_format = AgentRuntimeRequestPolicy::response_format_for_model_phase(
        is_followup_answer,
        tools.is_empty(),
    );
    let messages = build_messages(
        state,
        fact_package,
        assistant_reasoning_content,
        assistant_tool_calls,
        tool_results,
        &tools,
        skill_bundle,
    );

    LlmChatRequest {
        model: "primary".to_owned(),
        messages,
        tools,
        tool_choice: None,
        temperature: 0.2,
        stream: false,
        max_output_tokens: None,
        response_format,
        diagnostics_correlation: diagnostics_correlation(state, assistant_tool_calls, tool_results),
    }
}

pub(crate) fn request_tool_count(request: &LlmChatRequest) -> u32 {
    u32::try_from(request.tools.len()).unwrap_or(u32::MAX)
}

fn build_messages(
    state: &AgentSessionState,
    fact_package: Option<&AiFactPackage>,
    assistant_reasoning_content: Option<&str>,
    assistant_tool_calls: &[LlmToolCall],
    tool_results: &[LoopToolResult],
    visible_tools: &[LlmToolSchema],
    skill_bundle: Option<&SkillBundle>,
) -> Vec<LlmMessage> {
    let user_message = state.user_inputs.last().cloned().unwrap_or_default();
    let mut messages = AiPromptBuilder::new().build_messages(&user_message, &[], fact_package);

    if let Some(workbench) = state.workbench.as_ref() {
        let user_msg_index = messages.len().saturating_sub(1);
        let mut pre_user_messages: Vec<LlmMessage> = Vec::new();

        pre_user_messages.push(LlmMessage {
            role: LlmRole::System,
            content: workbench_context_prompt(workbench, visible_tools, skill_bundle),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        });

        if let Some(pack) = workbench.recent_conversation_pack.as_ref() {
            pre_user_messages.extend(pack.to_messages());
        }

        for (offset, msg) in pre_user_messages.into_iter().enumerate() {
            messages.insert(user_msg_index + offset, msg);
        }
    }

    if !assistant_tool_calls.is_empty() {
        messages.push(LlmMessage {
            role: LlmRole::Assistant,
            content: String::new(),
            reasoning_content: assistant_reasoning_content.map(str::to_owned),
            tool_call_id: None,
            tool_calls: assistant_tool_calls.to_vec(),
        });
    }

    if !assistant_tool_calls.is_empty() {
        for tool_result in tool_results {
            messages.push(tool_result_to_message(tool_result));
        }
        if tool_results
            .iter()
            .any(|result| result.tool_call.name == "load_pet_identity_context")
        {
            messages.push(LlmMessage {
                role: LlmRole::System,
                content: "可见 UI 提示：load_pet_identity_context 成功后，客户端会用工具结果渲染宠物资料卡。最终自然语言正文不要重复列出资料卡已经展示的品种、性别、生日、年龄、来到世界天数、到家时间和陪伴天数；正文只保留用户问题需要的补充解读、其他上下文、风险提示或确认问题。".to_owned(),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            });
        }
    }

    messages
}

/// diagnostics_correlation 构建 Provider 请求诊断关联键
/// 核心职责：
/// - 将当前 in-memory session、turn 和 message 映射到 LLM 请求
/// - 在 follow-up 模型请求中携带关联工具调用 ID
fn diagnostics_correlation(
    state: &AgentSessionState,
    assistant_tool_calls: &[LlmToolCall],
    tool_results: &[LoopToolResult],
) -> LlmDiagnosticsCorrelation {
    LlmDiagnosticsCorrelation {
        session_id: Some(state.chat_session_id),
        turn_id: state
            .current_turn_id
            .map(maohuoban_ai_domain::ai::AgentTurnId::as_uuid),
        message_id: state.current_turn_diagnostics_message_id,
        tool_call_id: diagnostics_tool_call_id(assistant_tool_calls, tool_results),
    }
}

fn diagnostics_tool_call_id(
    assistant_tool_calls: &[LlmToolCall],
    tool_results: &[LoopToolResult],
) -> Option<String> {
    assistant_tool_calls
        .first()
        .map(|tool_call| tool_call.id.clone())
        .or_else(|| {
            tool_results
                .first()
                .map(|tool_result| tool_result.tool_call.id.clone())
        })
}
