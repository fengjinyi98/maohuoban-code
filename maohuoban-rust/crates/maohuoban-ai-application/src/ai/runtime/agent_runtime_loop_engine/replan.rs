use crate::ai::planning::{
    PlanningDiagnosticsSnapshot, ReplanAction, ReplanCause, ReplanDecision, ReplanPolicy, TaskType,
};
use maohuoban_ai_domain::ai::{
    AgentSessionState, AiError, LlmChatRequest, LlmDiagnosticsCorrelation, LlmFinishReason,
    LlmRole, LlmUsage, LoopToolResult, LoopToolStatus, PROVIDER_USER_VISIBLE_FAILURE_MESSAGE,
    ProviderError, ProviderErrorCategory,
};

use super::super::{
    agent_runtime_diagnostics::AgentRuntimeDiagnostics, runtime_phase::RuntimePhase,
    streaming_model_purpose::StreamingModelPurpose,
};
use super::{AgentRuntimeLoopEngine, model_stream::model_stream};

/// StreamingRetryRequest 流式模型重试上下文
/// 核心职责：
/// - 保存同一模型 step 重试所需的原始请求和诊断关联
/// - 限制 retry 只发生在尚未输出可见内容的 step 边界
#[derive(Clone, Copy)]
pub(super) struct StreamingRetryRequest<'a> {
    pub(super) request: &'a LlmChatRequest,
    pub(super) purpose: StreamingModelPurpose,
    pub(super) tool_count: u32,
    pub(super) diagnostics_correlation: &'a LlmDiagnosticsCorrelation,
    pub(super) retry_count: u8,
    pub(super) retry_boundary_clear: bool,
}

impl AgentRuntimeLoopEngine {
    pub(super) fn record_replan_decision(
        &self,
        state: &AgentSessionState,
        decision: ReplanDecision,
    ) {
        let Some(turn_id) = state.current_turn_id else {
            return;
        };
        let Some((planned_turn_id, plan)) = &self.current_step_plan else {
            return;
        };
        if *planned_turn_id != turn_id {
            return;
        }
        let message_id = state
            .current_turn_diagnostics_message_id
            .unwrap_or_else(uuid::Uuid::nil);
        let snapshot =
            PlanningDiagnosticsSnapshot::new(state.chat_session_id, turn_id, message_id, plan)
                .with_replan_reason(decision.reason);
        AgentRuntimeDiagnostics::record_planning_snapshot(&snapshot);
    }

    pub(super) fn record_tool_replan_decision(
        &self,
        state: &AgentSessionState,
        tool_results: &[LoopToolResult],
        evidence_prefetch: bool,
    ) -> Option<ReplanDecision> {
        let cause = replan_cause_for_tool_results(tool_results, evidence_prefetch)?;
        let decision = ReplanPolicy.decide(cause);
        self.record_replan_decision(state, decision);
        Some(decision)
    }

    pub(super) fn replan_streaming_model_error(
        &self,
        state: &AgentSessionState,
        error: &AiError,
        retry: StreamingRetryRequest<'_>,
    ) -> Option<RuntimePhase> {
        let cause = replan_cause_for_error(error)?;
        let decision = ReplanPolicy.decide(cause);
        self.record_replan_decision(state, decision);
        if !decision.retryable || retry.retry_count > 0 || !retry.retry_boundary_clear {
            return None;
        }
        let request = match decision.action {
            ReplanAction::RetrySameStep | ReplanAction::RecoverOrRetryStep => retry.request.clone(),
            ReplanAction::CompressContextAndRetry => compress_request_context(retry.request),
            ReplanAction::CorrectArgumentsAndRetry
            | ReplanAction::ReplanToTask
            | ReplanAction::Terminate => return None,
        };
        Some(RuntimePhase::StreamingModel {
            request: Box::new(request.clone()),
            stream: model_stream(self.provider.clone(), request),
            purpose: retry.purpose,
            accumulated_text: String::new(),
            accumulated_reasoning_content: String::new(),
            tool_calls: Vec::new(),
            usage: LlmUsage::default(),
            finish_reason: LlmFinishReason::Stop,
            tool_count: retry.tool_count,
            diagnostics_correlation: retry.diagnostics_correlation.clone(),
            retry_count: retry.retry_count.saturating_add(1),
        })
    }
}

pub(super) fn runtime_phase_for_tool_replan(
    decision: ReplanDecision,
    tool_results: &[LoopToolResult],
) -> RuntimePhase {
    match decision.action {
        ReplanAction::ReplanToTask
            if decision.replanned_task_type == Some(TaskType::ClarificationTask) =>
        {
            RuntimePhase::ClarifyUser {
                reason: "取证结果不足，无法可靠回答当前问题".to_owned(),
                suggested_actions: vec![
                    "补充要查询的宠物和时间范围".to_owned(),
                    "稍后重新查询宠物档案或记录".to_owned(),
                ],
            }
        }
        ReplanAction::CorrectArgumentsAndRetry => RuntimePhase::ClarifyUser {
            reason: "工具参数无效，无法确认要操作的对象或内容".to_owned(),
            suggested_actions: vec![
                "补充宠物、时间或记录内容".to_owned(),
                "重新提交更明确的请求".to_owned(),
            ],
        },
        ReplanAction::CompressContextAndRetry => RuntimePhase::ClarifyUser {
            reason: "上下文过长，当前请求需要压缩后重试".to_owned(),
            suggested_actions: vec!["缩短问题或减少历史上下文后重试".to_owned()],
        },
        ReplanAction::Terminate
        | ReplanAction::RetrySameStep
        | ReplanAction::RecoverOrRetryStep
        | ReplanAction::ReplanToTask => RuntimePhase::Done {
            message_id: uuid::Uuid::new_v4(),
            final_text: safe_tool_replan_message(tool_results),
            status: maohuoban_ai_domain::ai::AgentTurnStatus::Failed,
            error_code: None,
        },
    }
}

fn replan_cause_for_tool_results(
    tool_results: &[LoopToolResult],
    evidence_prefetch: bool,
) -> Option<ReplanCause> {
    if tool_results
        .iter()
        .any(|result| matches!(result.status, LoopToolStatus::Denied))
    {
        return Some(ReplanCause::ToolUnauthorized);
    }
    if tool_results.iter().any(|result| {
        matches!(result.status, LoopToolStatus::Failed)
            && result
                .failure
                .as_ref()
                .is_some_and(|failure| failure.error_code == "tool.invalid_arguments")
    }) {
        return Some(ReplanCause::ToolInvalidArguments);
    }
    if evidence_prefetch
        && !tool_results
            .iter()
            .any(|result| matches!(result.status, LoopToolStatus::Succeeded))
    {
        return Some(ReplanCause::EvidenceInsufficient);
    }
    None
}

fn safe_tool_replan_message(tool_results: &[LoopToolResult]) -> String {
    tool_results
        .iter()
        .find_map(|result| {
            result
                .denied_reason
                .as_deref()
                .or(result.failed_reason.as_deref())
                .filter(|message| !message.trim().is_empty())
                .map(str::to_owned)
        })
        .unwrap_or_else(|| PROVIDER_USER_VISIBLE_FAILURE_MESSAGE.to_owned())
}

fn compress_request_context(request: &LlmChatRequest) -> LlmChatRequest {
    let last_user_index = request
        .messages
        .iter()
        .rposition(|message| message.role == LlmRole::User);
    let mut compressed = request.clone();
    compressed.messages = request
        .messages
        .iter()
        .enumerate()
        .filter(|(index, message)| {
            message.role == LlmRole::System
                || Some(*index) == last_user_index
                || message.role == LlmRole::Tool
                || !message.tool_calls.is_empty()
        })
        .map(|(_, message)| message.clone())
        .collect();
    if compressed.messages.is_empty() {
        request.clone()
    } else {
        compressed
    }
}

/// replan_cause_for_error 映射运行时错误到重规划原因
/// 核心职责：
/// - 只把 Provider 流式瞬时错误交给 ReplanPolicy 裁决
/// - 保留业务错误和确定性校验错误的原始失败语义
fn replan_cause_for_error(error: &AiError) -> Option<ReplanCause> {
    match error {
        AiError::Provider(provider_error) => {
            if is_context_limit_provider_error(provider_error) {
                Some(ReplanCause::ContextLimitExceeded)
            } else {
                ReplanCause::from_provider_category(provider_error.category())
            }
        }
        AiError::ProviderStreamError(_) => Some(ReplanCause::StreamInterrupted),
        _ => None,
    }
}

fn is_context_limit_provider_error(error: &ProviderError) -> bool {
    if error.category() != ProviderErrorCategory::InvalidResponse {
        return false;
    }
    let message = error.message().to_ascii_lowercase();
    message.contains("context")
        && (message.contains("limit")
            || message.contains("length")
            || message.contains("window")
            || message.contains("exceed"))
}
