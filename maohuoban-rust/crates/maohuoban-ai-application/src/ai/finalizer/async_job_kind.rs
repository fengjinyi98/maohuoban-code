/// FinalizerAsyncJobKind 异步后处理类型
/// 核心职责：
/// - 固定 summary、memory candidate、evaluation 等派生任务的触发语义
/// - 防止派生任务阻塞主回复同步收口
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FinalizerAsyncJobKind {
    SessionSummary,
    MemoryCandidate,
    Evaluation,
}
