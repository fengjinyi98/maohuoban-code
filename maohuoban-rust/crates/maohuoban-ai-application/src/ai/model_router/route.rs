/// ModelRoute 已解析模型路由
/// 核心职责：
/// - 向调用方暴露经 label 解析后的 provider model
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModelRoute {
    pub(super) label: String,
    pub(super) model: String,
}

impl ModelRoute {
    /// label 返回模型能力标签
    #[must_use]
    pub fn label(&self) -> &str {
        &self.label
    }

    /// model 返回 provider model 名称
    #[must_use]
    pub fn model(&self) -> &str {
        &self.model
    }
}
