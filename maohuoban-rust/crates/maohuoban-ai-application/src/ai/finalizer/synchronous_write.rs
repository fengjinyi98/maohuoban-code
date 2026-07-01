/// FinalizerSynchronousWrite 同步写入对象
/// 核心职责：
/// - 为 diagnostics 和合同测试记录关键写入顺序
/// - 区分权威写入和派生后处理
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FinalizerSynchronousWrite {
    AssistantMessage,
    Citations,
    ProposedActions,
    TurnStatus,
    SessionHeader,
}
