//! LlmProviderEnvValues LLM Provider 环境变量值
//! 核心职责：
//! - 承载单 Provider 环境配置的原始字符串
//! - 支撑 from_env_values 单元测试和启动配置解析

/// LlmProviderEnvValues LLM Provider 环境变量值
#[derive(Clone, Copy, Debug, Default)]
pub struct LlmProviderEnvValues<'a> {
    pub provider_kind: Option<&'a str>,
    pub provider_id: Option<&'a str>,
    pub display_name: Option<&'a str>,
    pub enabled: Option<&'a str>,
    pub is_default: Option<&'a str>,
    pub base_url: Option<&'a str>,
    pub api_key: Option<&'a str>,
    pub model: Option<&'a str>,
    pub timeout_secs: Option<&'a str>,
    pub temperature: Option<&'a str>,
    pub max_output_tokens: Option<&'a str>,
    pub response_format: Option<&'a str>,
}
