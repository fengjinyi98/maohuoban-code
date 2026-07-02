use maohuoban_ai_domain::ai::{AgentSessionState, AiResult, LlmToolCall, LoopStep, LoopToolStatus};

use crate::ai::guardrail::GuardrailDecision;
use crate::ai::planning::{ReplanAction, ReplanCause, ReplanPolicy, StepKind};

use super::super::{runtime_phase::RuntimePhase, tool_executor::execute_tool_calls};
use super::{AgentRuntimeLoopEngine, replan::runtime_phase_for_tool_replan};

impl AgentRuntimeLoopEngine {
    pub(super) async fn advance_tool_execution_phase(
        &mut self,
        state: &AgentSessionState,
        assistant_reasoning_content: Option<String>,
        assistant_tool_calls: Vec<LlmToolCall>,
        tool_calls: Vec<LlmToolCall>,
    ) -> AiResult<Option<LoopStep>> {
        if !tool_calls.is_empty() {
            self.phase = RuntimePhase::ToolExecution {
                assistant_reasoning_content,
                assistant_tool_calls,
                tool_calls: Vec::new(),
            };
            return Ok(Some(LoopStep::call_tools(tool_calls)));
        }

        let (tool_results, hard_stop) = execute_tool_calls(
            self.registry.clone(),
            self.tool_context.clone(),
            assistant_tool_calls.clone(),
            &mut self.guardrail,
        )
        .await;

        if let Some(GuardrailDecision::HardStop {
            safe_user_message, ..
        }) = hard_stop
        {
            let decision = ReplanPolicy.decide(ReplanCause::GuardrailHardStop);
            self.record_replan_decision(state, decision);
            if matches!(decision.action, ReplanAction::Terminate) {
                self.phase = RuntimePhase::Done {
                    message_id: uuid::Uuid::new_v4(),
                    final_text: safe_user_message,
                    status: maohuoban_ai_domain::ai::AgentTurnStatus::Failed,
                    error_code: None,
                };
            }
            return Ok(Some(LoopStep::CallTools { tool_results }));
        }

        if let Some(decision) = self.record_tool_replan_decision(state, &tool_results, false) {
            self.phase = runtime_phase_for_tool_replan(decision, &tool_results);
            return Ok(Some(LoopStep::CallTools { tool_results }));
        }

        let needs_confirmation = tool_results
            .iter()
            .any(|result| matches!(result.status, LoopToolStatus::RequiresConfirmation));

        if needs_confirmation {
            self.phase = RuntimePhase::Done {
                message_id: uuid::Uuid::new_v4(),
                final_text: String::new(),
                status: maohuoban_ai_domain::ai::AgentTurnStatus::AwaitingConfirmation,
                error_code: None,
            };
        } else {
            self.phase = RuntimePhase::FollowupModel {
                assistant_reasoning_content,
                assistant_tool_calls,
                tool_results: tool_results.clone(),
            };
        }

        Ok(Some(LoopStep::CallTools { tool_results }))
    }

    pub(super) async fn advance_evidence_tool_execution_phase(
        &mut self,
        state: &AgentSessionState,
        assistant_tool_calls: Vec<LlmToolCall>,
        tool_calls: Vec<LlmToolCall>,
    ) -> AiResult<Option<LoopStep>> {
        if !tool_calls.is_empty() {
            self.record_planning_step(
                state,
                StepKind::ToolRead,
                Some((StepKind::PrefetchEvidence, StepKind::ToolRead)),
            );
            self.phase = RuntimePhase::EvidenceToolExecution {
                assistant_tool_calls,
                tool_calls: Vec::new(),
            };
            return Ok(Some(LoopStep::call_tools(tool_calls)));
        }

        let (tool_results, hard_stop) = execute_tool_calls(
            self.registry.clone(),
            self.tool_context.clone(),
            assistant_tool_calls,
            &mut self.guardrail,
        )
        .await;

        if let Some(GuardrailDecision::HardStop {
            safe_user_message, ..
        }) = hard_stop
        {
            let decision = ReplanPolicy.decide(ReplanCause::GuardrailHardStop);
            self.record_replan_decision(state, decision);
            if matches!(decision.action, ReplanAction::Terminate) {
                self.phase = RuntimePhase::Done {
                    message_id: uuid::Uuid::new_v4(),
                    final_text: safe_user_message,
                    status: maohuoban_ai_domain::ai::AgentTurnStatus::Failed,
                    error_code: None,
                };
            }
            return Ok(Some(LoopStep::CallTools { tool_results }));
        }

        if let Some(decision) = self.record_tool_replan_decision(state, &tool_results, true) {
            self.phase = runtime_phase_for_tool_replan(decision, &tool_results);
            return Ok(Some(LoopStep::CallTools { tool_results }));
        }

        let needs_confirmation = tool_results
            .iter()
            .any(|result| matches!(result.status, LoopToolStatus::RequiresConfirmation));

        if needs_confirmation {
            self.phase = RuntimePhase::Done {
                message_id: uuid::Uuid::new_v4(),
                final_text: String::new(),
                status: maohuoban_ai_domain::ai::AgentTurnStatus::AwaitingConfirmation,
                error_code: None,
            };
        } else {
            self.record_planning_step(
                state,
                StepKind::ModelReason,
                Some((StepKind::ToolRead, StepKind::ModelReason)),
            );
            self.phase = RuntimePhase::FollowupModel {
                assistant_reasoning_content: None,
                assistant_tool_calls: Vec::new(),
                tool_results: tool_results.clone(),
            };
        }

        Ok(Some(LoopStep::CallTools { tool_results }))
    }
}
