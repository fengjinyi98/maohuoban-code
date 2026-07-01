// MHB_STRUCTURE_EXEMPTION: WT04 replay domain type belongs to existing Rust AI model module tree.
use uuid::Uuid;

use super::AgentSessionEventEntry;

/// AgentTurnReplay 单个 turn 的 replay 视图
/// 核心职责：
/// - 按持久化顺序承载 turn runtime events
/// - 为合同测试和后续诊断导出提供事件序列断言入口
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AgentTurnReplay {
    pub turn_id: Uuid,
    pub events: Vec<AgentSessionEventEntry>,
}

impl AgentTurnReplay {
    /// new 构造 turn replay 视图
    #[must_use]
    pub fn new(turn_id: Uuid, events: Vec<AgentSessionEventEntry>) -> Self {
        Self { turn_id, events }
    }

    /// event_names 返回 replay 事件名序列
    /// 核心职责：
    /// - 隐藏 entry 结构细节
    /// - 让测试直接验证关键 runtime 顺序
    #[must_use]
    pub fn event_names(&self) -> Vec<&str> {
        self.events
            .iter()
            .map(|entry| entry.event_name.as_str())
            .collect()
    }
}
