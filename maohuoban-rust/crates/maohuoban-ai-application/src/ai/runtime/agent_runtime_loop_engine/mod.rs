// MHB_STRUCTURE_EXEMPTION: ai/runtime 为既有 Agent Runtime 目录；本次仅拆分超长 runtime loop 文件，后续 code-structure P1 统一迁移到 Infrastructure/Services 分层目录。
mod loop_engine;
mod model_stream;
mod output_guard;
mod planning;
mod replan;
mod tool_phase;

#[cfg(test)]
mod tests;

use std::sync::Arc;

use crate::ai::guardrail::ToolCallGuardrail;
use crate::ai::planning::StepPlan;
use crate::ai::ports::LlmProvider;
use crate::ai::skill::SkillBundle;
use crate::ai::tools::{AiToolContext, ToolRegistry};
use maohuoban_ai_domain::ai::{AgentTurnId, AiFactPackage};

const DEFAULT_MAX_TOOL_ROUNDS: u8 = 4;

use super::runtime_phase::RuntimePhase;

/// AgentRuntimeLoopEngine 毛球 Agent Runtime loop 实现
/// 核心职责：
/// - 组装模型请求、工具执行和结果回灌
/// - 保持 Tool Gateway、Provider 和 Runtime 可替换
/// - 集成 ToolCallGuardrail 防止工具循环
pub struct AgentRuntimeLoopEngine {
    provider: Arc<dyn LlmProvider>,
    registry: Arc<ToolRegistry>,
    tool_context: AiToolContext,
    fact_package: Option<AiFactPackage>,
    guardrail: ToolCallGuardrail,
    phase: RuntimePhase,
    planning_recorded_turn_id: Option<AgentTurnId>,
    current_step_plan: Option<(AgentTurnId, StepPlan)>,
    current_skill_bundle: Option<(AgentTurnId, SkillBundle)>,
    max_tool_rounds: u8,
    current_round: u8,
    accumulated_total_tokens: u32,
    current_turn_successful_write_tools: Vec<String>,
}

impl AgentRuntimeLoopEngine {
    /// new 构造 runtime loop
    #[must_use]
    pub fn new(
        provider: Arc<dyn LlmProvider>,
        registry: Arc<ToolRegistry>,
        tool_context: AiToolContext,
        fact_package: Option<AiFactPackage>,
    ) -> Self {
        Self {
            provider,
            registry,
            tool_context,
            fact_package,
            guardrail: ToolCallGuardrail::new(),
            phase: RuntimePhase::Model,
            planning_recorded_turn_id: None,
            current_step_plan: None,
            current_skill_bundle: None,
            max_tool_rounds: DEFAULT_MAX_TOOL_ROUNDS,
            current_round: 0,
            accumulated_total_tokens: 0,
            current_turn_successful_write_tools: Vec::new(),
        }
    }

    /// set_max_tool_rounds 配置单 turn 最大工具轮次
    /// 核心职责：
    /// - 为测试与装配层提供显式轮次上限入口
    /// - 避免把单轮工具深度硬编码在 loop 结构里
    pub fn set_max_tool_rounds(&mut self, max_tool_rounds: u8) {
        self.max_tool_rounds = max_tool_rounds;
    }
}
