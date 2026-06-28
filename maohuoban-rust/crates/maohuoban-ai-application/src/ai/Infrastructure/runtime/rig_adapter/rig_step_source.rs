use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AgentSessionState, AiResult};

use super::FakeRigStep;

/// RigStepSource Rig step 来源边界
/// 核心职责：
/// - 抽象 Rig POC 的下一步输出
/// - 避免 Adapter 直接依赖真实业务服务
#[async_trait]
pub trait RigStepSource: Send {
    async fn next_rig_step(
        &mut self,
        state: &mut AgentSessionState,
    ) -> AiResult<Option<FakeRigStep>>;
}
