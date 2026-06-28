use std::collections::VecDeque;

use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AgentSessionState, AiResult};

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
