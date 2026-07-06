/// HomeAttentionHintRealtimeEventKind 首页轻提醒实时事件类型
/// 核心职责：
/// - 表达轻提醒新增投影和解决态变化
/// - 作为 AI 应用层到首页 SSE 基础设施的稳定桥接枚举
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HomeAttentionHintRealtimeEventKind {
    Projected,
    Resolved,
}
