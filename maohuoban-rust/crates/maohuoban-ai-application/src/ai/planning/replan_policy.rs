use super::{ReplanAction, ReplanCause, ReplanDecision, TaskType};

/// ReplanPolicy 重试与重规划策略
/// 核心职责：
/// - 固定失败后 retry、replan 和 terminal 的区分
/// - 防止工具未授权、guardrail hard stop 等硬终止被误重试
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq)]
pub struct ReplanPolicy;

impl ReplanPolicy {
    /// decide 返回失败原因对应的重规划裁决
    #[must_use]
    pub const fn decide(self, cause: ReplanCause) -> ReplanDecision {
        match cause {
            ReplanCause::ProviderTimeout => {
                ReplanDecision::new(cause, ReplanAction::RetrySameStep, true, None)
            }
            ReplanCause::StreamInterrupted => {
                ReplanDecision::new(cause, ReplanAction::RecoverOrRetryStep, true, None)
            }
            ReplanCause::ToolInvalidArguments => {
                ReplanDecision::new(cause, ReplanAction::CorrectArgumentsAndRetry, true, None)
            }
            ReplanCause::ToolUnauthorized | ReplanCause::GuardrailHardStop => ReplanDecision::new(
                cause,
                ReplanAction::Terminate,
                false,
                Some(TaskType::RejectTask),
            ),
            ReplanCause::EvidenceInsufficient => ReplanDecision::new(
                cause,
                ReplanAction::ReplanToTask,
                false,
                Some(TaskType::ClarificationTask),
            ),
            ReplanCause::ContextLimitExceeded => {
                ReplanDecision::new(cause, ReplanAction::CompressContextAndRetry, true, None)
            }
        }
    }
}
