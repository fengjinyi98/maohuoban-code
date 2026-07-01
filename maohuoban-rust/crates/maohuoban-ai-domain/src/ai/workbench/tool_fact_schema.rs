use serde::{Deserialize, Serialize};

use crate::ai::AiFactStrength;

/// ToolFactSchema 工具事实输出 schema
/// 核心职责：
/// - 声明工具返回的事实 key、自然语言含义、默认强度和典型问法
/// - 供 Workbench、Planner 和事实投影层理解工具能力
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ToolFactSchema {
    /// 工具可能返回的事实 key 列表
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub fact_keys: Vec<String>,
    /// 事实输出描述
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub description: String,
    /// 面向模型的自然语言事实能力摘要
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub natural_language_summary: String,
    /// 工具事实字段的自然语言协议
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub fields: Vec<ToolFactField>,
    /// 工具返回事实的默认强度
    /// - Strong: 已确认结构化事实（如宠物档案、当前饮食配置）
    /// - Weak: 弱线索（如储物柜变化）
    /// - PendingConfirmation: 待确认候选
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub default_strength: Option<AiFactStrength>,
}

/// ToolFactField 工具事实字段协议
/// 核心职责：
/// - 用自然语言说明单个事实字段可回答的问题
/// - 为 Planner 和模型工具选择提供同义问法线索
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ToolFactField {
    pub key: String,
    pub label: String,
    pub meaning: String,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub example_queries: Vec<String>,
}

impl Default for ToolFactSchema {
    fn default() -> Self {
        Self {
            fact_keys: Vec::new(),
            description: String::new(),
            natural_language_summary: String::new(),
            fields: Vec::new(),
            default_strength: None,
        }
    }
}
