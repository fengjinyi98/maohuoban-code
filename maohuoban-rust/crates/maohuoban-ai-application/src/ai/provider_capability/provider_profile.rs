//! provider_profile Provider 能力画像
//! 核心职责：
//! - 绑定 Provider 名称与固定能力声明
//! - 作为 Request Policy 裁剪请求的唯一依据
//! - 所有 Provider 差异判断必须通过 profile，不得绕过

use maohuoban_ai_domain::ai::ProviderCapability;

/// ProviderProfile Provider 能力画像
/// 核心职责：
/// - 绑定 Provider 名称与固定能力声明
/// - 作为 Request Policy 裁剪请求的唯一依据
/// - 所有 Provider 差异判断必须通过 profile，不得绕过
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProviderProfile {
    pub capability: ProviderCapability,
}

impl ProviderProfile {
    /// openai_compatible 标准 OpenAI 兼容 Provider 画像
    /// 核心职责：
    /// - 声明 OpenAI 兼容协议族的完整能力画像
    #[must_use]
    pub fn openai_compatible(model: impl Into<String>) -> Self {
        Self {
            capability: ProviderCapability::openai_compatible(model),
        }
    }

    /// deepseek DeepSeek 厂商 Provider 画像
    /// 核心职责：
    /// - 声明 DeepSeek 的能力画像，标记 JSON Output 不稳定等已知差异
    #[must_use]
    pub fn deepseek(model: impl Into<String>) -> Self {
        Self {
            capability: ProviderCapability::deepseek(model),
        }
    }

    /// provider_name 返回 Provider 名称标识
    #[must_use]
    pub fn provider_name(&self) -> &str {
        &self.capability.provider_name
    }
}

impl From<ProviderCapability> for ProviderProfile {
    fn from(capability: ProviderCapability) -> Self {
        Self { capability }
    }
}
