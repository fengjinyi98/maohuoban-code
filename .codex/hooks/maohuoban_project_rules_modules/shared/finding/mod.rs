use super::Severity;

/// Finding 项目结构检查结果
/// 核心职责：
/// - 表达单个文件触发的结构规则
/// - 区分提示项和阻断项
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct Finding {
    pub(crate) path: String,
    pub(crate) rule: &'static str,
    pub(crate) severity: Severity,
    pub(crate) message: String,
}
