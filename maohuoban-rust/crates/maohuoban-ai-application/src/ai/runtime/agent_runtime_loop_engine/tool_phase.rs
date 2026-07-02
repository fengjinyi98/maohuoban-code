use maohuoban_ai_domain::ai::{
    AgentSessionState, AiFactPackage, AiFactStrength, AiResult, LlmToolCall, LoopStep,
    LoopToolResult, LoopToolStatus,
};

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
        completed_tool_rounds: u8,
    ) -> AiResult<Option<LoopStep>> {
        if !tool_calls.is_empty() {
            self.record_planning_step(
                state,
                StepKind::ToolRead,
                Some((StepKind::ModelReason, StepKind::ToolRead)),
            );
            self.phase = RuntimePhase::ToolExecution {
                assistant_reasoning_content,
                assistant_tool_calls,
                tool_calls: Vec::new(),
                completed_tool_rounds,
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
                    termination_reason:
                        maohuoban_ai_domain::ai::AgentTurnTerminationReason::OutputGuardFailed,
                    error_code: None,
                };
            }
            return Ok(Some(LoopStep::CallTools { tool_results }));
        }

        if let Some(decision) = self.record_tool_replan_decision(state, &tool_results, false) {
            self.phase = runtime_phase_for_tool_replan(decision, &tool_results);
            return Ok(Some(LoopStep::CallTools { tool_results }));
        }

        for result in tool_results
            .iter()
            .filter(|result| matches!(result.status, LoopToolStatus::Succeeded))
        {
            if self
                .registry
                .get(&result.tool_call.name)
                .is_some_and(|tool| !tool.metadata().read_only)
                && !self
                    .current_turn_successful_write_tools
                    .iter()
                    .any(|name| name == &result.tool_call.name)
            {
                self.current_turn_successful_write_tools
                    .push(result.tool_call.name.clone());
            }
        }
        self.merge_successful_tool_fact_packages(&tool_results);

        let needs_confirmation = tool_results
            .iter()
            .any(|result| matches!(result.status, LoopToolStatus::RequiresConfirmation));

        if self.accumulated_total_tokens > self.turn_token_budget {
            self.phase = RuntimePhase::Done {
                message_id: uuid::Uuid::new_v4(),
                final_text: String::new(),
                status: maohuoban_ai_domain::ai::AgentTurnStatus::Failed,
                termination_reason:
                    maohuoban_ai_domain::ai::AgentTurnTerminationReason::BudgetExhausted,
                error_code: Some("ai.runtime.budget_exhausted".to_owned()),
            };
        } else if needs_confirmation {
            self.phase = RuntimePhase::Done {
                message_id: uuid::Uuid::new_v4(),
                final_text: String::new(),
                status: maohuoban_ai_domain::ai::AgentTurnStatus::AwaitingConfirmation,
                termination_reason: maohuoban_ai_domain::ai::AgentTurnTerminationReason::ModelStop,
                error_code: None,
            };
        } else {
            self.phase = RuntimePhase::FollowupModel {
                assistant_reasoning_content,
                assistant_tool_calls,
                tool_results: tool_results.clone(),
                completed_tool_rounds: completed_tool_rounds.saturating_add(1),
            };
        }

        Ok(Some(LoopStep::CallTools { tool_results }))
    }

    fn merge_successful_tool_fact_packages(&mut self, tool_results: &[LoopToolResult]) {
        for package in tool_results
            .iter()
            .filter(|result| matches!(result.status, LoopToolStatus::Succeeded))
            .filter_map(|result| result.fact_package.as_deref())
        {
            self.fact_package = Some(merge_runtime_fact_package(
                self.fact_package
                    .take()
                    .unwrap_or_else(AiFactPackage::empty),
                package.clone(),
            ));
        }
    }
}

fn merge_runtime_fact_package(mut base: AiFactPackage, incoming: AiFactPackage) -> AiFactPackage {
    if base.target_pet.is_none() {
        base.target_pet = incoming.target_pet;
    }
    base.facts.extend(incoming.facts);
    base.computed.extend(incoming.computed);
    base.pending_confirmations
        .extend(incoming.pending_confirmations);
    base.weak_hints.extend(incoming.weak_hints);
    base.citations.extend(incoming.citations);
    base.missing_info.extend(incoming.missing_info);
    base.fact_strength = strongest_fact_strength(base.fact_strength, incoming.fact_strength);
    base
}

fn strongest_fact_strength(left: AiFactStrength, right: AiFactStrength) -> AiFactStrength {
    match (left, right) {
        (AiFactStrength::Strong, _) | (_, AiFactStrength::Strong) => AiFactStrength::Strong,
        (AiFactStrength::PendingConfirmation, _) | (_, AiFactStrength::PendingConfirmation) => {
            AiFactStrength::PendingConfirmation
        }
        (AiFactStrength::Weak, AiFactStrength::Weak) => AiFactStrength::Weak,
    }
}
