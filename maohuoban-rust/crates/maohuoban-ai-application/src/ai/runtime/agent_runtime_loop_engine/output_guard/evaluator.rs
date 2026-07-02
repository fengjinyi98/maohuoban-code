use maohuoban_ai_domain::ai::{AgentSessionState, AiFactPackage};

use crate::ai::runtime::agent_runtime_diagnostics::AgentRuntimeDiagnostics;
use crate::ai::verifier::{AiAnswerVerificationContext, AiAnswerVerifier};

use super::decision::OutputGuardDecision;
use super::repair_request::build_output_repair_request;

const MAX_OUTPUT_REPAIR_ATTEMPTS: u8 = 2;

/// evaluate_output_guard 校验 Runtime 最终候选回答
/// 核心职责：
/// - 在 TurnFinished 前校验模型最终回答
/// - 校验失败时构造内部修复请求，而不是产出 fallback 正文
pub(in crate::ai::runtime::agent_runtime_loop_engine) fn evaluate_output_guard(
    state: &AgentSessionState,
    fact_package: Option<&AiFactPackage>,
    candidate_answer: &str,
    repair_attempt: u8,
    successful_write_tools: &[String],
) -> OutputGuardDecision {
    let package = fact_package.cloned().unwrap_or_else(AiFactPackage::empty);
    let verification = AiAnswerVerifier::new().verify_with_context(
        candidate_answer,
        &package,
        AiAnswerVerificationContext {
            identity_context_tool_required: package.target_pet.is_some(),
            identity_context_tool_succeeded: package.target_pet.is_some(),
            successful_write_tools: successful_write_tools.to_vec(),
        },
    );
    AgentRuntimeDiagnostics::record_output_guard_decided(
        state.chat_session_id,
        &verification,
        repair_attempt,
        candidate_answer,
        successful_write_tools,
    );

    if !verification.is_blocked() {
        return OutputGuardDecision::Accept;
    }
    if repair_attempt >= MAX_OUTPUT_REPAIR_ATTEMPTS {
        return OutputGuardDecision::Fail;
    }

    OutputGuardDecision::Repair {
        request: Box::new(build_output_repair_request(
            state,
            &package,
            candidate_answer,
            &verification,
            successful_write_tools,
        )),
        attempt: repair_attempt.saturating_add(1),
    }
}
