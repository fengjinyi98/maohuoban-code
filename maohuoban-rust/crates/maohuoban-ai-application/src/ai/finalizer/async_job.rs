use super::FinalizerAsyncJobKind;

/// FinalizerAsyncJob 异步后处理任务
/// 核心职责：
/// - 承载 Finalizer 收口后的派生任务触发请求
/// - 保留任务类型供 diagnostics 和后续调度器使用
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FinalizerAsyncJob {
    pub kind: FinalizerAsyncJobKind,
}

impl FinalizerAsyncJob {
    /// new 构造异步后处理任务
    #[must_use]
    pub fn new(kind: FinalizerAsyncJobKind) -> Self {
        Self { kind }
    }
}
