/// Severity 检查结果严重程度
/// 核心职责：
/// - 标记可继续的建议项
/// - 标记需要阻断的违规项
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Severity {
    Warning,
    Violation,
}
