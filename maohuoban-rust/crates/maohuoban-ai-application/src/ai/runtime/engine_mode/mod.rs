/// AgentRuntimeEngineMode Agent Runtime 引擎模式
/// 核心职责：
/// - 表达当前唯一允许的自研 Runtime 引擎
/// - 拒绝旧 engine 配置，避免开发阶段继续保留双路径
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

    /// from_config_value 解析配置字符串
    /// 核心职责：
    /// - 只接受 self_hosted
    /// - 对旧 engine 或未知值返回显式错误
    pub fn from_config_value(value: &str) -> Result<Self, String> {
        match value.trim().to_ascii_lowercase().as_str() {
            "self_hosted" => Ok(Self::SelfHosted),
            other => Err(format!(
                "unsupported MAOHUOBAN_AI_RUNTIME_ENGINE value `{other}`; expected `self_hosted`"
            )),
        }
    }
}
