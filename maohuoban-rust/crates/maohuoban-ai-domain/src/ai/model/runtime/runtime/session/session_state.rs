use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::ai::AgentSessionWorkbench;

use super::super::{AgentId, AgentTurnId, AiConversationSurface};

/// AgentSessionState Runtime session 内存状态
/// 核心职责：
/// - 保存 LoopEngine 推进时需要的最小 session 上下文
/// - 首期只服务 fake loop 和事件契约验证，不负责持久化
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AgentSessionState {
    pub chat_session_id: Uuid,
    pub agent_id: AgentId,
    pub surface: AiConversationSurface,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub workbench: Option<AgentSessionWorkbench>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub user_inputs: Vec<String>,
    pub turn_index: u32,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub current_turn_id: Option<AgentTurnId>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub current_turn_diagnostics_message_id: Option<Uuid>,
}

impl AgentSessionState {
    /// new 创建最小 in-memory session 状态
    pub fn new(chat_session_id: Uuid, agent_id: AgentId, surface: AiConversationSurface) -> Self {
        Self {
            chat_session_id,
            agent_id,
            surface,
            workbench: None,
            user_inputs: Vec::new(),
            turn_index: 0,
            current_turn_id: None,
            current_turn_diagnostics_message_id: None,
        }
    }

    /// attach_workbench 设置本轮 Runtime 工作台上下文
    pub fn attach_workbench(&mut self, workbench: Option<AgentSessionWorkbench>) {
        self.workbench = workbench;
    }

    /// begin_turn 记录用户输入并开启新 turn
    pub fn begin_turn(&mut self, user_input: String) -> AgentTurnId {
        self.begin_turn_with_id_and_diagnostics_message_id(user_input, AgentTurnId::new(), None)
    }

    /// begin_turn_with_diagnostics_message_id 开启带诊断 message 关联键的 turn
    /// 核心职责：
    /// - 每轮开始时刷新 turn、用户输入和 message 关联键
    /// - 避免复用 Runtime session 时沿用上一轮 message_id
    pub fn begin_turn_with_diagnostics_message_id(
        &mut self,
        user_input: String,
        diagnostics_message_id: Option<Uuid>,
    ) -> AgentTurnId {
        self.begin_turn_with_id_and_diagnostics_message_id(
            user_input,
            AgentTurnId::new(),
            diagnostics_message_id,
        )
    }

    /// begin_turn_with_id 使用外部提供的 turn_id 开启新 turn
    /// 核心职责：
    /// - 让 HTTP Ingress Tx 先建 turn row，再由 Runtime 使用同一 turn_id
    /// - 保持 Runtime 事件与数据库 turn 行主键一致
    pub fn begin_turn_with_id(&mut self, user_input: String, turn_id: AgentTurnId) -> AgentTurnId {
        self.begin_turn_with_id_and_diagnostics_message_id(user_input, turn_id, None)
    }

    /// begin_turn_with_id_and_diagnostics_message_id 使用外部 turn_id 和诊断 message 关联键开启新 turn
    /// 核心职责：
    /// - 同时满足 WT01 的 turn 主链和 WT00 的 diagnostics 关联需求
    /// - 让 Runtime 事件、turn 行和 provider diagnostics 指向同一轮
    pub fn begin_turn_with_id_and_diagnostics_message_id(
        &mut self,
        user_input: String,
        turn_id: AgentTurnId,
        diagnostics_message_id: Option<Uuid>,
    ) -> AgentTurnId {
        self.turn_index = self.turn_index.saturating_add(1);
        self.user_inputs.push(user_input);
        self.current_turn_id = Some(turn_id);
        self.current_turn_diagnostics_message_id = diagnostics_message_id;
        turn_id
    }
}
