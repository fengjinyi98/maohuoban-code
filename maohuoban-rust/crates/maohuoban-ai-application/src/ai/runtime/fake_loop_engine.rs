use std::collections::VecDeque;

use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AgentSessionState, AiResult, LoopStep};

use super::LoopEngine;

/// FakeLoopEngine 测试用脚本化 LoopEngine
/// 核心职责：
/// - 按预设顺序输出 LoopStep
/// - 不依赖真实 Provider、Tool Gateway 或持久化
#[derive(Debug, Clone)]
pub struct FakeLoopEngine {
    steps: VecDeque<LoopStep>,
}

impl FakeLoopEngine {
    /// new 构造脚本化 fake loop
    #[must_use]
    pub fn new(steps: Vec<LoopStep>) -> Self {
        Self {
            steps: VecDeque::from(steps),
        }
    }
}

#[async_trait]
impl LoopEngine for FakeLoopEngine {
    async fn next(&mut self, _state: &mut AgentSessionState) -> AiResult<Option<LoopStep>> {
        Ok(self.steps.pop_front())
    }
}
