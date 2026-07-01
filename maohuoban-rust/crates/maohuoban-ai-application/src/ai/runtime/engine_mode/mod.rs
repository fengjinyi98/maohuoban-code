/// AgentRuntimeEngineMode Agent Runtime 引擎模式
/// 核心职责：
/// - 表达当前唯一允许的自研 Runtime 引擎
/// - 为运行时事件和诊断提供稳定编码
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AgentRuntimeEngineMode {
    SelfHosted,
}

impl AgentRuntimeEngineMode {
    /// as_str 返回配置和诊断使用的稳定编码
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::SelfHosted => "self_hosted",
        }
    }
}
