/// ReplanAction 失败后的执行动作
/// 核心职责：
/// - 区分同 step 重试、恢复重试、改参重试、压缩重试、重规划和终止
/// - 避免所有失败都走同一种 retry 分支
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ReplanAction {
    RetrySameStep,
    RecoverOrRetryStep,
    CorrectArgumentsAndRetry,
    CompressContextAndRetry,
    ReplanToTask,
    Terminate,
}

impl ReplanAction {
    /// as_str 返回冻结动作编码
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::RetrySameStep => "retry_same_step",
            Self::RecoverOrRetryStep => "recover_or_retry_step",
            Self::CorrectArgumentsAndRetry => "correct_arguments_and_retry",
            Self::CompressContextAndRetry => "compress_context_and_retry",
            Self::ReplanToTask => "replan_to_task",
            Self::Terminate => "terminate",
        }
    }
}
