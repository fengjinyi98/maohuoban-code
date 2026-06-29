use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AgentSessionState, AiResult, LoopStep};

/// LoopEngine Agent Runtime loop 引擎边界
/// 核心职责：
/// - 基于当前 session state 产出下一步 Runtime step
/// - 让 FakeLoopEngine、Rig adapter 或其他实现可替换
#[async_trait]
pub trait LoopEngine: Send {
    /// next 推进 Runtime loop 一步
    async fn next(&mut self, state: &mut AgentSessionState) -> AiResult<Option<LoopStep>>;
}

#[async_trait]
impl<T: LoopEngine + ?Sized> LoopEngine for Box<T> {
    async fn next(&mut self, state: &mut AgentSessionState) -> AiResult<Option<LoopStep>> {
        (**self).next(state).await
    }
}
