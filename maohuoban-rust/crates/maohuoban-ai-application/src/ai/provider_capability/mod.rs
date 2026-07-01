//! provider_capability Provider 能力协议与请求策略
//! 核心职责：
//! - 定义 ProviderProfile 作为 Provider 能力的唯一声明入口
//! - 提供 RequestPolicy 决定请求字段的发放条件
//! - 禁止在 HTTP/Runtime 调用现场散写 provider 特判

mod provider_profile;
mod request_policy;

pub use provider_profile::ProviderProfile;
pub use request_policy::ProviderRequestPolicy;
