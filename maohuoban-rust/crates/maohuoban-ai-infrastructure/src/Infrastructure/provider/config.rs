//! config OpenAI 兼容 Provider 配置
//! 核心职责：
//! - 从环境变量读取 LLM Provider 配置
//! - 缺少必填项时允许服务降级为未配置状态
//! - 对 Debug 输出脱敏 API key

use std::fmt;

use serde::{Deserialize, Serialize};
use serde_json::Value;

use super::DeepSeekConfig;

/// OpenAiCompatibleConfig OpenAI 兼容 Provider 配置
/// 核心职责：
/// - 承载 base_url、api_key、model、timeout 等配置
/// - api_key 只在 infrastructure 内使用
#[derive(Clone, PartialEq)]
pub struct OpenAiCompatibleConfig {
    pub base_url: String,
    pub api_key: String,
    pub model: String,
    pub timeout_secs: u64,
    pub temperature: f32,
    pub max_output_tokens: Option<u32>,
    pub response_format: Option<Value>,
}

/// LlmProviderKind LLM Provider 类型
/// 核心职责：
/// - 标识运营配置中的 Provider 实现类型
/// - 为后续扩展非 OpenAI 兼容 Provider 保留稳定枚举入口
#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum LlmProviderKind {
    #[serde(rename = "openai_compatible")]
    OpenAiCompatible,
    #[serde(rename = "deepseek")]
    DeepSeek,
}

/// LlmProviderRuntimeConfig LLM Provider 运行时配置
/// 核心职责：
/// - 将运营配置中的 kind 分发为具体厂商 Provider 配置
/// - 让装配层只依赖该枚举选择 Provider 实现
#[derive(Clone, PartialEq)]
pub enum LlmProviderRuntimeConfig {
    OpenAiCompatible(OpenAiCompatibleConfig),
    DeepSeek(DeepSeekConfig),
}

/// LlmProviderOperationalConfig LLM Provider 运营配置
/// 核心职责：
/// - 承载管理后台需要读写的 Provider 元数据和运行参数
/// - 将密钥限制在后端配置和运行时装配层使用
#[derive(Clone, Deserialize, PartialEq, Serialize)]
pub struct LlmProviderOperationalConfig {
    pub id: String,
    pub display_name: String,
    pub kind: LlmProviderKind,
    pub enabled: bool,
    pub is_default: bool,
    pub base_url: String,
    #[serde(skip_serializing)]
    pub api_key: String,
    pub model: String,
    pub timeout_secs: u64,
    pub temperature: f32,
    pub max_output_tokens: Option<u32>,
    pub response_format: Option<Value>,
}

impl fmt::Debug for LlmProviderOperationalConfig {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("LlmProviderOperationalConfig")
            .field("id", &self.id)
            .field("display_name", &self.display_name)
            .field("kind", &self.kind)
            .field("enabled", &self.enabled)
            .field("is_default", &self.is_default)
            .field("base_url", &self.base_url)
            .field("api_key", &"<redacted>")
            .field("model", &self.model)
            .field("timeout_secs", &self.timeout_secs)
            .field("temperature", &self.temperature)
            .field("max_output_tokens", &self.max_output_tokens)
            .field("response_format", &self.response_format)
            .finish()
    }
}

impl LlmProviderOperationalConfig {
    /// from_openai_compatible_config 从运行时配置构造运营配置
    /// 核心职责：
    /// - 复用现有 OpenAI 兼容 Provider 参数
    /// - 补齐运营侧 Provider 标识、名称、启用和默认状态
    #[must_use]
    pub fn from_openai_compatible_config(
        id: impl Into<String>,
        display_name: impl Into<String>,
        enabled: bool,
        is_default: bool,
        config: OpenAiCompatibleConfig,
    ) -> Self {
        let id = id.into();
        let display_name = display_name.into();
        Self {
            id: non_empty_or_default(&id, "openai-compatible"),
            display_name: non_empty_or_default(&display_name, "OpenAI Compatible"),
            kind: LlmProviderKind::OpenAiCompatible,
            enabled,
            is_default,
            base_url: config.base_url,
            api_key: config.api_key,
            model: config.model,
            timeout_secs: config.timeout_secs,
            temperature: config.temperature,
            max_output_tokens: config.max_output_tokens,
            response_format: config.response_format,
        }
    }

    /// from_deepseek_config 从 DeepSeek 配置构造运营配置
    /// 核心职责：
    /// - 保留 DeepSeek 厂商 Provider 的独立 kind
    /// - 复用通用连接参数供管理后台配置
    #[must_use]
    pub fn from_deepseek_config(
        id: impl Into<String>,
        display_name: impl Into<String>,
        enabled: bool,
        is_default: bool,
        config: DeepSeekConfig,
    ) -> Self {
        let id = id.into();
        let display_name = display_name.into();
        Self {
            id: non_empty_or_default(&id, "deepseek"),
            display_name: non_empty_or_default(&display_name, "DeepSeek"),
            kind: LlmProviderKind::DeepSeek,
            enabled,
            is_default,
            base_url: config.base_url,
            api_key: config.api_key,
            model: config.model,
            timeout_secs: config.timeout_secs,
            temperature: config.temperature,
            max_output_tokens: config.max_output_tokens,
            response_format: config.response_format,
        }
    }

    /// to_openai_compatible_config 转换为运行时 OpenAI 兼容配置
    /// 核心职责：
    /// - 隔离运营配置字段和 Provider HTTP 调用字段
    /// - 让运行时继续复用既有 OpenAI 兼容 Provider
    #[must_use]
    pub fn to_openai_compatible_config(&self) -> Option<OpenAiCompatibleConfig> {
        if self.kind != LlmProviderKind::OpenAiCompatible || !self.enabled {
            return None;
        }

        Some(self.to_openai_compatible_protocol_config())
    }

    /// to_runtime_provider_config 转换为具体厂商运行时配置
    /// 核心职责：
    /// - 统一检查启用状态
    /// - 根据 kind 构造厂商 Provider 配置
    #[must_use]
    pub fn to_runtime_provider_config(&self) -> Option<LlmProviderRuntimeConfig> {
        if !self.enabled {
            return None;
        }

        let config = self.to_openai_compatible_protocol_config();
        Some(match self.kind {
            LlmProviderKind::OpenAiCompatible => LlmProviderRuntimeConfig::OpenAiCompatible(config),
            LlmProviderKind::DeepSeek => LlmProviderRuntimeConfig::DeepSeek(
                DeepSeekConfig::from_openai_compatible_config(config),
            ),
        })
    }

    /// to_openai_compatible_protocol_config 生成 OpenAI 兼容协议参数
    /// 核心职责：
    /// - 复用运营配置中的通用连接字段
    /// - 供 OpenAI 兼容协议客户端和厂商 wrapper 使用
    fn to_openai_compatible_protocol_config(&self) -> OpenAiCompatibleConfig {
        OpenAiCompatibleConfig {
            base_url: self.base_url.clone(),
            api_key: self.api_key.clone(),
            model: self.model.clone(),
            timeout_secs: self.timeout_secs,
            temperature: self.temperature,
            max_output_tokens: self.max_output_tokens,
            response_format: self.response_format.clone(),
        }
    }
}

/// LlmProviderPublicSettings LLM Provider 公开配置投影
/// 核心职责：
/// - 为后续管理后台列表和详情接口提供安全响应形态
/// - 只暴露密钥是否已配置，不返回密钥明文
#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct LlmProviderPublicSettings {
    pub id: String,
    pub display_name: String,
    pub kind: LlmProviderKind,
    pub enabled: bool,
    pub is_default: bool,
    pub base_url: String,
    pub model: String,
    pub timeout_secs: u64,
    pub temperature: f32,
    pub max_output_tokens: Option<u32>,
    pub response_format: Option<Value>,
    pub api_key_configured: bool,
}

impl From<&LlmProviderOperationalConfig> for LlmProviderPublicSettings {
    fn from(config: &LlmProviderOperationalConfig) -> Self {
        Self {
            id: config.id.clone(),
            display_name: config.display_name.clone(),
            kind: config.kind,
            enabled: config.enabled,
            is_default: config.is_default,
            base_url: config.base_url.clone(),
            model: config.model.clone(),
            timeout_secs: config.timeout_secs,
            temperature: config.temperature,
            max_output_tokens: config.max_output_tokens,
            response_format: config.response_format.clone(),
            api_key_configured: !config.api_key.trim().is_empty(),
        }
    }
}

/// LlmProviderRegistryConfig LLM Provider 配置注册表
/// 核心职责：
/// - 汇总可运营配置的 Provider 列表
/// - 为运行时装配选择当前启用的默认 Provider
#[derive(Clone, Debug, Default, PartialEq)]
pub struct LlmProviderRegistryConfig {
    pub providers: Vec<LlmProviderOperationalConfig>,
}

impl LlmProviderRegistryConfig {
    /// new 构造 Provider 配置注册表
    #[must_use]
    pub const fn new(providers: Vec<LlmProviderOperationalConfig>) -> Self {
        Self { providers }
    }

    /// from_env 读取单 Provider 环境配置并映射为运营配置
    /// 核心职责：
    /// - 兼容现有 AI_LLM_* 环境变量
    /// - 补齐后续管理后台需要的 Provider 元数据
    #[must_use]
    pub fn from_env() -> Self {
        let provider_id = std::env::var("AI_LLM_PROVIDER_ID").ok();
        let provider_kind = std::env::var("AI_LLM_PROVIDER_KIND").ok();
        let display_name = std::env::var("AI_LLM_PROVIDER_DISPLAY_NAME").ok();
        let enabled = std::env::var("AI_LLM_PROVIDER_ENABLED").ok();
        let is_default = std::env::var("AI_LLM_PROVIDER_IS_DEFAULT").ok();
        let base_url = std::env::var("AI_LLM_BASE_URL").ok();
        let api_key = std::env::var("AI_LLM_API_KEY").ok();
        let model = std::env::var("AI_LLM_MODEL").ok();
        let timeout_secs = std::env::var("AI_LLM_TIMEOUT_SECS").ok();
        let temperature = std::env::var("AI_LLM_TEMPERATURE").ok();
        let max_output_tokens = std::env::var("AI_LLM_MAX_OUTPUT_TOKENS").ok();
        let response_format = std::env::var("AI_LLM_RESPONSE_FORMAT").ok();

        Self::from_env_values(LlmProviderEnvValues {
            provider_kind: provider_kind.as_deref(),
            provider_id: provider_id.as_deref(),
            display_name: display_name.as_deref(),
            enabled: enabled.as_deref(),
            is_default: is_default.as_deref(),
            base_url: base_url.as_deref(),
            api_key: api_key.as_deref(),
            model: model.as_deref(),
            timeout_secs: timeout_secs.as_deref(),
            temperature: temperature.as_deref(),
            max_output_tokens: max_output_tokens.as_deref(),
            response_format: response_format.as_deref(),
        })
    }

    /// from_env_values 从环境变量值构造 Provider 注册表
    /// 核心职责：
    /// - 便于测试配置解析，不修改进程级环境变量
    /// - 缺少必要运行参数时返回空注册表，允许服务降级启动
    #[must_use]
    pub fn from_env_values(values: LlmProviderEnvValues<'_>) -> Self {
        let Some(openai_config) = OpenAiCompatibleConfig::from_env_values(
            values.base_url,
            values.api_key,
            values.model,
            values.timeout_secs,
            values.temperature,
            values.max_output_tokens,
            values.response_format,
        ) else {
            return Self::default();
        };

        let kind = provider_kind_from_env_values(values.provider_kind, values.provider_id);
        let enabled = bool_from_env_value(values.enabled, true);
        let is_default = bool_from_env_value(values.is_default, true);
        let provider = match kind {
            LlmProviderKind::OpenAiCompatible => {
                LlmProviderOperationalConfig::from_openai_compatible_config(
                    required_trimmed(values.provider_id)
                        .unwrap_or_else(|| "env-openai-compatible".to_owned()),
                    required_trimmed(values.display_name)
                        .unwrap_or_else(|| "OpenAI Compatible".to_owned()),
                    enabled,
                    is_default,
                    openai_config,
                )
            }
            LlmProviderKind::DeepSeek => LlmProviderOperationalConfig::from_deepseek_config(
                required_trimmed(values.provider_id).unwrap_or_else(|| "deepseek".to_owned()),
                required_trimmed(values.display_name).unwrap_or_else(|| "DeepSeek".to_owned()),
                enabled,
                is_default,
                DeepSeekConfig::from_openai_compatible_config(openai_config),
            ),
        };

        Self::new(vec![provider])
    }

    /// active_runtime_provider_config 获取当前启用默认 Provider 的运行时配置
    /// 核心职责：
    /// - 保留厂商 kind 信息供 factory 装配具体 Provider
    /// - 没有启用默认配置时返回 None 交给 Disabled Provider 降级
    #[must_use]
    pub fn active_runtime_provider_config(&self) -> Option<LlmProviderRuntimeConfig> {
        self.providers
            .iter()
            .find(|provider| provider.enabled && provider.is_default)
            .and_then(LlmProviderOperationalConfig::to_runtime_provider_config)
    }

    /// active_openai_compatible_config 获取当前启用默认 OpenAI 兼容 Provider
    /// 核心职责：
    /// - 按运营配置选择默认 Provider
    /// - 没有启用默认配置时返回 None 交给 Disabled Provider 降级
    #[must_use]
    pub fn active_openai_compatible_config(&self) -> Option<OpenAiCompatibleConfig> {
        self.providers
            .iter()
            .find(|provider| {
                provider.enabled
                    && provider.is_default
                    && provider.kind == LlmProviderKind::OpenAiCompatible
            })
            .and_then(LlmProviderOperationalConfig::to_openai_compatible_config)
    }

    /// public_settings 生成管理后台可安全消费的配置列表
    /// 核心职责：
    /// - 返回 Provider 运营元数据
    /// - 避免 API key 明文进入 HTTP 响应或日志
    #[must_use]
    pub fn public_settings(&self) -> Vec<LlmProviderPublicSettings> {
        self.providers
            .iter()
            .map(LlmProviderPublicSettings::from)
            .collect()
    }
}

impl From<OpenAiCompatibleConfig> for LlmProviderRegistryConfig {
    fn from(config: OpenAiCompatibleConfig) -> Self {
        Self::new(vec![
            LlmProviderOperationalConfig::from_openai_compatible_config(
                "default-openai-compatible",
                "OpenAI Compatible",
                true,
                true,
                config,
            ),
        ])
    }
}

/// LlmProviderEnvValues LLM Provider 环境变量值
/// 核心职责：
/// - 承载单 Provider 环境配置的原始字符串
/// - 支撑 from_env_values 单元测试和启动配置解析
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

impl fmt::Debug for OpenAiCompatibleConfig {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("OpenAiCompatibleConfig")
            .field("base_url", &self.base_url)
            .field("api_key", &"<redacted>")
            .field("model", &self.model)
            .field("timeout_secs", &self.timeout_secs)
            .field("temperature", &self.temperature)
            .field("max_output_tokens", &self.max_output_tokens)
            .field("response_format", &self.response_format)
            .finish()
    }
}

impl OpenAiCompatibleConfig {
    /// from_env 读取 OpenAI 兼容 Provider 环境配置
    /// 核心职责：
    /// - 缺少 base_url、api_key 或 model 时返回 None，允许服务降级启动
    /// - 解析 timeout、temperature 和 max output tokens 默认值
    #[must_use]
    pub fn from_env() -> Option<Self> {
        Self::from_env_values(
            std::env::var("AI_LLM_BASE_URL").ok().as_deref(),
            std::env::var("AI_LLM_API_KEY").ok().as_deref(),
            std::env::var("AI_LLM_MODEL").ok().as_deref(),
            std::env::var("AI_LLM_TIMEOUT_SECS").ok().as_deref(),
            std::env::var("AI_LLM_TEMPERATURE").ok().as_deref(),
            std::env::var("AI_LLM_MAX_OUTPUT_TOKENS").ok().as_deref(),
            std::env::var("AI_LLM_RESPONSE_FORMAT").ok().as_deref(),
        )
    }

    /// from_env_values 从已读取环境变量值构造 Provider 配置
    /// 核心职责：
    /// - 便于测试配置解析，不在测试中修改进程级环境变量
    /// - 空字符串按缺失处理
    #[must_use]
    pub fn from_env_values(
        base_url: Option<&str>,
        api_key: Option<&str>,
        model: Option<&str>,
        timeout_secs: Option<&str>,
        temperature: Option<&str>,
        max_output_tokens: Option<&str>,
        response_format: Option<&str>,
    ) -> Option<Self> {
        let base_url = required_trimmed(base_url)?;
        let api_key = required_trimmed(api_key)?;
        let model = required_trimmed(model)?;

        Some(Self {
            base_url,
            api_key,
            model,
            timeout_secs: timeout_secs
                .and_then(|value| value.trim().parse::<u64>().ok())
                .unwrap_or(30),
            temperature: temperature
                .and_then(|value| value.trim().parse::<f32>().ok())
                .unwrap_or(0.2),
            max_output_tokens: max_output_tokens.and_then(|value| value.trim().parse().ok()),
            response_format: response_format_from_env_value(response_format),
        })
    }
}

/// response_format_from_env_value 解析 Provider 默认响应格式
/// 核心职责：
/// - 支持 DeepSeek JSON Output 的 json_object 快捷配置
/// - 保留传入原始 JSON 对象的扩展能力
fn response_format_from_env_value(value: Option<&str>) -> Option<Value> {
    let trimmed = value?.trim();
    if trimmed.is_empty() {
        return None;
    }

    match trimmed.to_ascii_lowercase().as_str() {
        "none" | "text" => None,
        "json" | "json_object" => Some(serde_json::json!({ "type": "json_object" })),
        _ => serde_json::from_str::<Value>(trimmed).ok(),
    }
}

/// provider_kind_from_env_values 解析环境配置中的 Provider 类型
/// 核心职责：
/// - 优先使用显式 AI_LLM_PROVIDER_KIND
/// - 兼容当前本地配置通过 provider_id=deepseek 推断厂商
fn provider_kind_from_env_values(
    provider_kind: Option<&str>,
    provider_id: Option<&str>,
) -> LlmProviderKind {
    if let Some(kind) = provider_kind.and_then(parse_provider_kind) {
        return kind;
    }

    let provider_id = provider_id
        .map(str::trim)
        .unwrap_or_default()
        .to_ascii_lowercase();
    if provider_id == "deepseek" || provider_id.starts_with("deepseek-") {
        return LlmProviderKind::DeepSeek;
    }

    LlmProviderKind::OpenAiCompatible
}

/// parse_provider_kind 解析 Provider kind 字符串
/// 核心职责：
/// - 支持管理后台和环境变量使用稳定 snake_case 值
/// - 未知值回落给调用方处理
fn parse_provider_kind(value: &str) -> Option<LlmProviderKind> {
    match value.trim().to_ascii_lowercase().as_str() {
        "openai_compatible" | "openai-compatible" | "openai" => {
            Some(LlmProviderKind::OpenAiCompatible)
        }
        "deepseek" => Some(LlmProviderKind::DeepSeek),
        _ => None,
    }
}

/// required_trimmed 读取非空配置值
/// 核心职责：
/// - 将缺失或空白字符串统一视为缺配置
fn required_trimmed(value: Option<&str>) -> Option<String> {
    let trimmed = value?.trim();
    if trimmed.is_empty() {
        None
    } else {
        Some(trimmed.to_owned())
    }
}

/// bool_from_env_value 解析环境变量布尔值
/// 核心职责：
/// - 兼容 true/false、1/0、yes/no、on/off
/// - 无法解析时使用调用方默认值
fn bool_from_env_value(value: Option<&str>, default: bool) -> bool {
    match value.map(str::trim).map(str::to_ascii_lowercase).as_deref() {
        Some("true" | "1" | "yes" | "on") => true,
        Some("false" | "0" | "no" | "off") => false,
        _ => default,
    }
}

/// non_empty_or_default 规范化非空字符串
/// 核心职责：
/// - 去除运营配置标识和名称两端空白
/// - 空字符串回落到稳定默认值
fn non_empty_or_default(value: &str, default: &str) -> String {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        default.to_owned()
    } else {
        trimmed.to_owned()
    }
}
