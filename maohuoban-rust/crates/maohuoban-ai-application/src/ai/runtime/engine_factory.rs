use super::{
    AgentRuntimeEngineInput, AgentRuntimeEngineMode, AgentRuntimeLoopEngine, LoopEngine,
    RigAgentRunLoopEngine,
};

/// AgentRuntimeEngineFactory Runtime 引擎工厂
/// 核心职责：
/// - 根据配置选择自研 LoopEngine 或 Rig POC adapter
/// - 保持 Rig POC 只通过 LoopEngine、Provider 和 ToolRegistry 边界访问外部能力
pub struct AgentRuntimeEngineFactory {
    mode: AgentRuntimeEngineMode,
}

impl AgentRuntimeEngineFactory {
    /// new 构造 Runtime 引擎工厂
    #[must_use]
    pub fn new(mode: AgentRuntimeEngineMode) -> Self {
        Self { mode }
    }

    /// build 构造可替换 LoopEngine
    /// 核心职责：
    /// - self_hosted 返回自研 AgentRuntimeLoopEngine
    /// - rig_poc 返回 Rig AgentRun engine，用于验证 Rig state machine 边界
    #[must_use]
    pub fn build(&self, input: AgentRuntimeEngineInput) -> Box<dyn LoopEngine> {
        match self.mode {
            AgentRuntimeEngineMode::SelfHosted => Box::new(AgentRuntimeLoopEngine::new(
                input.provider,
                input.registry,
                input.tool_context,
                input.fact_package,
            )),
            AgentRuntimeEngineMode::RigPoc => Box::new(RigAgentRunLoopEngine::new(
                input.provider,
                input.registry,
                input.tool_context,
                input.fact_package,
            )),
        }
    }
}
