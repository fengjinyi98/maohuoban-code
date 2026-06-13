use chrono::{DateTime, NaiveDate, Utc};

/// `LegalDocumentKind` 法务文档类型
/// 核心职责：
/// - 固定客户端可请求的文档标识
/// - 隔离 HTTP path 字符串与领域模型
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LegalDocumentKind {
    UserAgreement,
    PrivacyPolicy,
}

impl LegalDocumentKind {
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::UserAgreement => "user_agreement",
            Self::PrivacyPolicy => "privacy_policy",
        }
    }

    #[must_use]
    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "user_agreement" => Some(Self::UserAgreement),
            "privacy_policy" => Some(Self::PrivacyPolicy),
            _ => None,
        }
    }
}

/// `LegalDocument` 后端托管法务文档
/// 核心职责：
/// - 承载运营可更新的 HTML 正文和版本信息
/// - 为客户端原生富文本页面展示提供稳定数据结构
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LegalDocument {
    pub kind: LegalDocumentKind,
    pub title: String,
    pub version: String,
    pub effective_date: NaiveDate,
    pub published_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub html: String,
}
