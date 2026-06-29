use serde::{Deserialize, Serialize};

/// ToolFactSchema 工具事实输出 schema
/// 核心职责：
/// - 声明工具返回的事实 key 列表和描述
/// - 供事实投影层校验工具输出结构
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ToolFactSchema {
    /// 工具可能返回的事实 key 列表
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub fact_keys: Vec<String>,
    /// 事实输出描述
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub description: String,
}

impl Default for ToolFactSchema {
    fn default() -> Self {
        Self {
            fact_keys: Vec::new(),
            description: String::new(),
        }
    }
}
