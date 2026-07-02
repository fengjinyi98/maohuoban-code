use crate::ai::planning::{
    PlanningDiagnosticsSnapshot, StepKind, StepPlan, StepPlanner, TaskClassifier,
};
use crate::ai::skill::{BuiltinSkillRuntime, SkillBundle};
use maohuoban_ai_domain::ai::AgentSessionState;

use super::super::{
    agent_runtime_diagnostics::AgentRuntimeDiagnostics,
    agent_runtime_request_policy::AgentRuntimeRequestPolicy,
};
use super::AgentRuntimeLoopEngine;

impl AgentRuntimeLoopEngine {
    pub(super) fn plan_current_turn(&mut self, state: &AgentSessionState) -> Option<StepPlan> {
        let turn_id = state.current_turn_id?;
        if let Some((cached_turn_id, plan)) = &self.current_step_plan
            && *cached_turn_id == turn_id
        {
            return Some(plan.clone());
        }
        let selected_pet_present = state
            .workbench
            .as_ref()
            .and_then(|workbench| workbench.context_pack.selected_pet.as_ref())
            .is_some();
        let task_type = TaskClassifier::classify_runtime(selected_pet_present);
        let plan = StepPlanner::plan(task_type);
        self.current_step_plan = Some((turn_id, plan.clone()));
        Some(plan)
    }

    pub(super) fn record_planning_if_needed(&mut self, state: &AgentSessionState, plan: &StepPlan) {
        let Some(turn_id) = state.current_turn_id else {
            return;
        };
        if self.planning_recorded_turn_id == Some(turn_id) {
            return;
        }
        let message_id = state
            .current_turn_diagnostics_message_id
            .unwrap_or_else(uuid::Uuid::nil);
        let snapshot =
            PlanningDiagnosticsSnapshot::new(state.chat_session_id, turn_id, message_id, plan);
        AgentRuntimeDiagnostics::record_planning_snapshot(&snapshot);
        self.planning_recorded_turn_id = Some(turn_id);
    }

    pub(super) fn current_plan_for_state(&self, state: &AgentSessionState) -> Option<&StepPlan> {
        let turn_id = state.current_turn_id?;
        let (planned_turn_id, plan) = self.current_step_plan.as_ref()?;
        (*planned_turn_id == turn_id).then_some(plan)
    }

    pub(super) fn current_skill_bundle_for_state(
        &mut self,
        state: &AgentSessionState,
    ) -> Option<SkillBundle> {
        let turn_id = state.current_turn_id?;
        if let Some((cached_turn_id, bundle)) = &self.current_skill_bundle
            && *cached_turn_id == turn_id
        {
            return Some(bundle.clone());
        }
        let workbench = state.workbench.as_ref()?;
        let task_type = self
            .current_plan_for_state(state)
            .map(|plan| plan.task_type().as_str().to_owned());
        let base_visible_tools =
            AgentRuntimeRequestPolicy::base_visible_tool_definitions(self.registry.as_ref(), state);
        let available_toolsets = base_visible_tools
            .iter()
            .map(|tool| tool.toolset)
            .collect::<Vec<_>>();
        let bundle = BuiltinSkillRuntime::match_runtime(
            workbench,
            available_toolsets,
            task_type.as_deref(),
            Some(self.tool_context.actor_user_id),
        );
        AgentRuntimeRequestPolicy::record_skill_match(state, &bundle);
        self.current_skill_bundle = Some((turn_id, bundle.clone()));
        Some(bundle)
    }

    pub(super) fn record_planning_step(
        &self,
        state: &AgentSessionState,
        current_step: StepKind,
        transition: Option<(StepKind, StepKind)>,
    ) {
        let Some(turn_id) = state.current_turn_id else {
            return;
        };
        let Some(plan) = self.current_plan_for_state(state) else {
            return;
        };
        let message_id = state
            .current_turn_diagnostics_message_id
            .unwrap_or_else(uuid::Uuid::nil);
        let mut snapshot =
            PlanningDiagnosticsSnapshot::new(state.chat_session_id, turn_id, message_id, plan)
                .with_current_step(current_step);
        if let Some((from, to)) = transition {
            snapshot = snapshot.with_step_transition(from, to);
        }
        AgentRuntimeDiagnostics::record_planning_snapshot(&snapshot);
    }
}
