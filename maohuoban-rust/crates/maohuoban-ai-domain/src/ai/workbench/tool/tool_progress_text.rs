use serde::{Deserialize, Serialize};

/// ToolProgressText 工具进度文案
/// 核心职责：
/// - 携带工具执行开始和完成时的用户可见展示文案
/// - 前端直接使用此文案，不需要根据工具名映射
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ToolProgressText {
    /// 工具开始执行时的展示文案
    #[serde(default)]
    pub started: String,
    /// 工具执行完成时的展示文案
    #[serde(default)]
    pub completed: String,
}

impl Default for ToolProgressText {
    fn default() -> Self {
        Self {
            started: String::new(),
            completed: String::new(),
        }
    }
}
