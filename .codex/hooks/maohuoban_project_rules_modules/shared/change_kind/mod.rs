/// ChangeKind 文件变更类型
/// 核心职责：
/// - 标记新增文件需要严格阻断
/// - 标记既有文件更新以提示为主
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum ChangeKind {
    Added,
    Updated,
    Deleted,
}
