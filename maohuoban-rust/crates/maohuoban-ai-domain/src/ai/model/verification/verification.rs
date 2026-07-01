use serde::{Deserialize, Serialize};

/// AiVerificationStatus 回答校验状态
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiVerificationStatus {
    Passed,
    Blocked,
    NeedsReview,
}

/// AiBlockedReason 回答阻断原因
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiBlockedReason {
    UnsupportedFact,
    WeakHintMisuse,
    MedicalBlocked,
    PrivacyBlocked,
    UnconfirmedWrite,
}

impl AiBlockedReason {
    /// as_str 返回稳定字符串
    pub fn as_str(self) -> &'static str {
        match self {
            Self::UnsupportedFact => "unsupported_fact",
            Self::WeakHintMisuse => "weak_hint_misuse",
            Self::MedicalBlocked => "medical_blocked",
            Self::PrivacyBlocked => "privacy_blocked",
            Self::UnconfirmedWrite => "unconfirmed_write",
        }
    }
}

/// AiAnswerVerification 回答校验结果
/// 核心职责：
/// - 表达校验状态、阻断原因、重试建议和安全回退文案
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AiAnswerVerification {
    pub status: AiVerificationStatus,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub blocked_reason: Option<AiBlockedReason>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub retry_suggestion: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub safe_fallback_text: Option<String>,
}

impl AiAnswerVerification {
    /// passed 构造通过校验结果
    pub fn passed() -> Self {
        Self {
            status: AiVerificationStatus::Passed,
            blocked_reason: None,
            retry_suggestion: None,
            safe_fallback_text: None,
        }
    }

    /// blocked 构造阻断校验结果
    pub fn blocked(reason: AiBlockedReason, safe_fallback_text: String) -> Self {
        Self {
            status: AiVerificationStatus::Blocked,
            blocked_reason: Some(reason),
            retry_suggestion: Some("请基于已确认的事实重新提问".to_owned()),
            safe_fallback_text: Some(safe_fallback_text),
        }
    }

    /// is_blocked 判断是否被阻断
    pub fn is_blocked(&self) -> bool {
        self.status == AiVerificationStatus::Blocked
    }
}
