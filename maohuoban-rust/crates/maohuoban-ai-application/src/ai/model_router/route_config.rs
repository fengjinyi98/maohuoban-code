/// ModelRouteConfig 模型标签路由配置
/// 核心职责：
/// - 绑定稳定模型 label 与具体 provider model
/// - 允许首期使用内存配置，后续替换为配置平台
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModelRouteConfig {
    pub(super) label: String,
    pub(super) model: String,
}

impl ModelRouteConfig {
    /// new 构造模型标签路由配置
    #[must_use]
    pub fn new(label: impl Into<String>, model: impl Into<String>) -> Self {
        Self {
            label: label.into(),
            model: model.into(),
        }
    }
}
