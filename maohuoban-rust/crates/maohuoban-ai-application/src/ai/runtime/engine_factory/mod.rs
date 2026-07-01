use super::{AgentRuntimeEngineInput, AgentRuntimeEngineMode, AgentRuntimeLoopEngine, LoopEngine};

/// AgentRuntimeEngineFactory Runtime 引擎工厂
/// 核心职责：
/// - 构造自研 LoopEngine
/// - 保持 HTTP handler 不感知具体 Runtime 依赖装配
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
    #[must_use]
    pub fn build(&self, input: AgentRuntimeEngineInput) -> Box<dyn LoopEngine> {
        match self.mode {
            AgentRuntimeEngineMode::SelfHosted => Box::new(AgentRuntimeLoopEngine::new(
                input.provider,
                input.registry,
                input.tool_context,
                input.fact_package,
            )),
        }
    }
}
