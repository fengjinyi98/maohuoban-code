use std::collections::VecDeque;

use async_trait::async_trait;
use maohuoban_ai_domain::ai::{
    AgentSessionState, AgentTurnStatus, AiResult, LlmFinishReason, LlmUsage, ModelLabel,
};
use uuid::Uuid;

use super::{FakeRigStep, RigStepSource};

/// FakeRigState 测试用 Rig 状态
/// 核心职责：
/// - 按脚本顺序输出 Rig POC step
/// - 不访问 Tool Gateway、Provider 或业务事实源
#[derive(Debug, Clone)]
pub struct FakeRigState {
    steps: VecDeque<FakeRigStep>,
}

impl FakeRigState {
    /// new 构造脚本化 Rig 状态
    #[must_use]
    pub fn new(steps: Vec<FakeRigStep>) -> Self {
        Self {
            steps: VecDeque::from(steps),
        }
    }

    /// poc_direct_answer 构造 Rig POC 默认直答脚本
    /// 核心职责：
    /// - 用固定 step 验证运行时 engine 选择链路
    /// - 保持 POC 不访问 Provider、Tool Gateway 或业务事实源
    #[must_use]
    pub fn poc_direct_answer() -> Self {
        Self::new(vec![
            FakeRigStep::CallModel {
                model_label: ModelLabel::Primary,
                tool_count: 0,
                finish_reason: LlmFinishReason::Stop,
                usage: LlmUsage::default(),
            },
            FakeRigStep::Done {
                message_id: Uuid::new_v4(),
                final_text: "Rig POC 引擎已接入，当前仅验证 LoopEngine adapter 边界。".to_owned(),
                status: AgentTurnStatus::Completed,
            },
        ])
    }
}

#[async_trait]
impl RigStepSource for FakeRigState {
    async fn next_rig_step(
        &mut self,
        _state: &mut AgentSessionState,
    ) -> AiResult<Option<FakeRigStep>> {
        Ok(self.steps.pop_front())
    }
}
