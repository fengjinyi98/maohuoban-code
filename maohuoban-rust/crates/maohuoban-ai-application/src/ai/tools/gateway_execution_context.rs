use uuid::Uuid;

/// ToolGatewayExecutionContext Tool Gateway 调用关联上下文
/// 核心职责：
/// - 统一携带 session/turn/message 关联键
/// - 让审计、diagnostics 和回放字段从 Gateway 一处产出
#[derive(Debug, Clone, Default)]
pub struct ToolGatewayExecutionContext {
    pub session_id: Option<Uuid>,
    pub turn_id: Option<Uuid>,
    pub message_id: Option<Uuid>,
}
