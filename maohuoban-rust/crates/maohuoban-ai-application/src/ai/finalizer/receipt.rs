use maohuoban_ai_domain::ai::AiSessionTurnStatus;

use super::{FinalizerAsyncFailure, FinalizerAsyncJobKind, FinalizerSynchronousWrite};

/// FinalizationReceipt Finalizer 收口回执
/// 核心职责：
/// - 返回终态、同步写入对象、异步触发对象和异步失败对象
/// - 作为 diagnostics tail 的权威数据源
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FinalizationReceipt {
    pub terminal_status: AiSessionTurnStatus,
    pub synchronous_writes: Vec<FinalizerSynchronousWrite>,
    pub async_triggers: Vec<FinalizerAsyncJobKind>,
    pub async_failures: Vec<FinalizerAsyncFailure>,
}
