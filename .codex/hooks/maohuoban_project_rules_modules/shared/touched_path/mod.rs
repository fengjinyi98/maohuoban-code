use std::path::PathBuf;

use super::ChangeKind;

/// TouchedPath 本次工具触碰的文件
/// 核心职责：
/// - 携带文件路径和变更类型
/// - 支持新增文件与既有文件采用不同门禁强度
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct TouchedPath {
    pub(crate) path: PathBuf,
    pub(crate) kind: ChangeKind,
}
