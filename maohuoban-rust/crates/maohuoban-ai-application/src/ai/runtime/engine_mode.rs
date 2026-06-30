/// AgentRuntimeEngineMode Agent Runtime 引擎模式
/// 核心职责：
/// - 表达运行时可选择的 LoopEngine 实现
/// - 将配置字符串收敛为安全的枚举值
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AgentRuntimeEngineMode {
    SelfHosted,
    RigPoc,
}

impl AgentRuntimeEngineMode {
    /// as_str 返回配置和诊断使用的稳定编码
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::SelfHosted => "self_hosted",
            Self::RigPoc => "rig_poc",
        }
    }

    /// from_config_value 解析配置字符串
    /// 核心职责：
    /// - 支持 self_hosted / rig_poc 两种稳定配置值
    /// - 未知值回退到自研引擎，保持生产默认路径稳定
    #[must_use]
    pub fn from_config_value(value: &str) -> Self {
        match value.trim().to_ascii_lowercase().as_str() {
            "rig_poc" => Self::RigPoc,
            _ => Self::SelfHosted,
        }
    }
}
