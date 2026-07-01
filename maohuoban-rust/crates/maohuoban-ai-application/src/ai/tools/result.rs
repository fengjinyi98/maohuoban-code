use maohuoban_ai_domain::ai::{
    AiCitation, AiFactEntry, AiToolConfirmationRequirement, LlmToolCall, LoopToolResult,
    PROVIDER_USER_VISIBLE_FAILURE_MESSAGE, ToolFactProjector, ToolFailure,
};

/// AiToolSuccess 工具成功结果
/// 核心职责：
/// - 承载结构化事实、引用和引用 ID
/// - 作为 Gateway 事实投影的唯一输入
#[derive(Debug, Clone)]
pub struct AiToolSuccess {
    pub facts: Vec<AiFactEntry>,
    pub citations: Vec<AiCitation>,
    pub reference_ids: Vec<String>,
}

/// AiToolDenied 工具拒绝结果
/// 核心职责：
/// - 保留安全用户文案
/// - 禁止泄露未授权对象存在性细节
#[derive(Debug, Clone)]
pub struct AiToolDenied {
    pub safe_user_message: String,
}

/// AiToolFailed 工具失败结果
/// 核心职责：
/// - 统一保留 failure code、recoverable 和安全用户文案
/// - 让 Runtime 和前端只消费结构化失败
#[derive(Debug, Clone)]
pub struct AiToolFailed {
    pub failure: ToolFailure,
}

/// AiToolResult 工具执行结果
/// 核心职责：
/// - 固定 success / denied / failed / requires_confirmation 四态
/// - 让 Tool Gateway 统一投影事实、引用和失败信息
#[derive(Debug, Clone)]
pub enum AiToolResult {
    Success(AiToolSuccess),
    Denied(AiToolDenied),
    Failed(AiToolFailed),
    RequiresConfirmation(AiToolConfirmationRequirement),
}

impl AiToolResult {
    /// allowed 构造允许且无事实返回的结果
    #[must_use]
    pub fn allowed(ref_ids: Vec<String>) -> Self {
        Self::Success(AiToolSuccess {
            facts: Vec::new(),
            citations: Vec::new(),
            reference_ids: ref_ids,
        })
    }

    /// allowed_with_facts 构造允许且携带事实和引用的结果
    #[must_use]
    pub fn allowed_with_facts(facts: Vec<AiFactEntry>, citations: Vec<AiCitation>) -> Self {
        let ref_ids: Vec<String> = citations.iter().map(|c| c.source_id.to_string()).collect();
        Self::Success(AiToolSuccess {
            facts,
            citations,
            reference_ids: ref_ids,
        })
    }

    /// denied 构造拒绝结果
    #[must_use]
    pub fn denied(reason: &str) -> Self {
        Self::Denied(AiToolDenied {
            safe_user_message: reason.to_owned(),
        })
    }

    /// failed 构造工具执行失败结果
    #[must_use]
    pub fn failed(reason: &str) -> Self {
        Self::Failed(AiToolFailed {
            failure: ToolFailure::new("tool.execution_failed", false, reason, reason),
        })
    }

    /// failed_with_failure 构造带结构化信息的工具失败结果
    /// 核心职责：
    /// - 携带 error_code、recoverable、safe_user_message、internal_reason
    /// - 前端只展示 safe_user_message
    /// - 模型可根据 recoverable 决定追问或换工具
    #[must_use]
    pub fn failed_with_failure(failure: ToolFailure) -> Self {
        Self::Failed(AiToolFailed { failure })
    }

    /// requires_confirmation 构造确认需求结果
    #[must_use]
    pub fn requires_confirmation(confirmation: AiToolConfirmationRequirement) -> Self {
        Self::RequiresConfirmation(confirmation)
    }

    #[must_use]
    pub fn is_success(&self) -> bool {
        matches!(self, Self::Success(_))
    }

    #[must_use]
    pub fn facts(&self) -> &[AiFactEntry] {
        match self {
            Self::Success(success) => &success.facts,
            Self::Denied(_) | Self::Failed(_) | Self::RequiresConfirmation(_) => &[],
        }
    }

    #[must_use]
    pub fn citations(&self) -> &[AiCitation] {
        match self {
            Self::Success(success) => &success.citations,
            Self::Denied(_) | Self::Failed(_) | Self::RequiresConfirmation(_) => &[],
        }
    }

    #[must_use]
    pub fn reference_ids(&self) -> &[String] {
        match self {
            Self::Success(success) => &success.reference_ids,
            Self::Denied(_) | Self::Failed(_) | Self::RequiresConfirmation(_) => &[],
        }
    }

    #[must_use]
    pub fn denied_reason(&self) -> Option<&str> {
        match self {
            Self::Denied(denied) => Some(denied.safe_user_message.as_str()),
            Self::Success(_) | Self::Failed(_) | Self::RequiresConfirmation(_) => None,
        }
    }

    #[must_use]
    pub fn failed_reason(&self) -> Option<&str> {
        match self {
            Self::Failed(failed) => Some(failed.failure.safe_user_message.as_str()),
            Self::Success(_) | Self::Denied(_) | Self::RequiresConfirmation(_) => None,
        }
    }

    #[must_use]
    pub fn confirmation(&self) -> Option<&AiToolConfirmationRequirement> {
        match self {
            Self::RequiresConfirmation(confirmation) => Some(confirmation),
            Self::Success(_) | Self::Denied(_) | Self::Failed(_) => None,
        }
    }

    #[must_use]
    pub fn failure(&self) -> Option<&ToolFailure> {
        match self {
            Self::Failed(failed) => Some(&failed.failure),
            Self::Success(_) | Self::Denied(_) | Self::RequiresConfirmation(_) => None,
        }
    }

    #[must_use]
    pub fn policy_decision(&self) -> &'static str {
        match self {
            Self::Success(_) => "success",
            Self::Denied(_) => "denied",
            Self::Failed(_) => "failed",
            Self::RequiresConfirmation(_) => "requires_confirmation",
        }
    }

    #[must_use]
    pub fn fact_count(&self) -> usize {
        self.facts().len()
    }

    #[must_use]
    pub fn citation_ids(&self) -> Vec<String> {
        self.reference_ids().to_vec()
    }

    #[must_use]
    pub fn failure_code(&self) -> Option<&str> {
        self.failure().map(|failure| failure.error_code.as_str())
    }

    #[must_use]
    pub fn to_loop_tool_result(&self, tool_call: LlmToolCall) -> LoopToolResult {
        match self {
            Self::Success(success) => {
                let mut projected = ToolFactProjector::project_facts(&success.facts);
                projected
                    .reference_ids
                    .extend(success.reference_ids.clone());
                let json = serde_json::to_string(&projected)
                    .unwrap_or_else(|_| "{\"facts\":[]}".to_owned());
                LoopToolResult::succeeded_with_citations(
                    tool_call,
                    json,
                    u32::try_from(success.citations.len()).unwrap_or(u32::MAX),
                )
            }
            Self::Denied(denied) => {
                LoopToolResult::denied(tool_call, denied.safe_user_message.clone())
            }
            Self::Failed(failed) => {
                LoopToolResult::failed_with_failure(tool_call, failed.failure.clone())
            }
            Self::RequiresConfirmation(confirmation) => {
                LoopToolResult::requires_confirmation(tool_call, confirmation.clone())
            }
        }
    }

    #[must_use]
    pub fn safe_user_message(&self) -> String {
        match self {
            Self::Success(_) => String::new(),
            Self::Denied(denied) => denied.safe_user_message.clone(),
            Self::Failed(failed) => failed.failure.safe_user_message.clone(),
            Self::RequiresConfirmation(confirmation) => confirmation.question_text.clone(),
        }
    }

    #[must_use]
    pub fn invalid_arguments_failure() -> Self {
        Self::failed_with_failure(ToolFailure::new(
            "tool.invalid_arguments",
            false,
            PROVIDER_USER_VISIBLE_FAILURE_MESSAGE,
            "invalid tool arguments",
        ))
    }
}
