use super::FinalizerAsyncJobKind;

/// FinalizerAsyncFailure 异步后处理失败记录
/// 核心职责：
/// - 记录 fail-open 后处理失败对象和稳定错误码
/// - 供 diagnostics tail 暴露派生任务状态
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FinalizerAsyncFailure {
    pub job_kind: FinalizerAsyncJobKind,
    pub error_code: String,
}
