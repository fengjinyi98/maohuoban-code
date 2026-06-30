use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AgentSessionState, AiResult, LoopStep};

use crate::ai::runtime::LoopEngine;

use super::{FakeRigStep, RigStepSource};

/// RigLoopEngineAdapter Rig 到 LoopEngine 的适配器
/// 核心职责：
/// - 将 Rig POC step 映射为毛伙伴 Runtime LoopStep
/// - 保持 Tool Gateway、Provider、HTTP 和 SSE 主权在自有代码内
pub struct RigLoopEngineAdapter<S> {
    source: S,
}

impl<S> RigLoopEngineAdapter<S> {
    /// new 构造 Rig adapter
    #[must_use]
    pub fn new(source: S) -> Self {
        Self { source }
    }
}

#[async_trait]
impl<S: RigStepSource> LoopEngine for RigLoopEngineAdapter<S> {
    fn engine_mode(&self) -> &'static str {
        "rig_poc"
    }

    async fn next(&mut self, state: &mut AgentSessionState) -> AiResult<Option<LoopStep>> {
        Ok(self.source.next_rig_step(state).await?.map(map_rig_step))
    }
}

/// map_rig_step 将 Rig POC step 转换为 Runtime step
/// 核心职责：
/// - 固定 adapter 输出契约
/// - 避免上层感知 Rig 内部状态表示
fn map_rig_step(step: FakeRigStep) -> LoopStep {
    match step {
        FakeRigStep::CallModel {
            model_label,
            tool_count,
            finish_reason,
            usage,
        } => LoopStep::model_finished(model_label, tool_count, finish_reason, usage),
        FakeRigStep::CallTools { tool_calls } => LoopStep::call_tools(tool_calls),
        FakeRigStep::CallToolResults { tool_results } => LoopStep::call_tool_results(tool_results),
        FakeRigStep::Done {
            message_id,
            final_text,
            status,
        } => LoopStep::done(message_id, final_text, status),
    }
}
