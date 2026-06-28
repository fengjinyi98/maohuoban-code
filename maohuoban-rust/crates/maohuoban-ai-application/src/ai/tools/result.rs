use maohuoban_ai_domain::ai::{AiCitation, AiFactEntry};

use maohuoban_ai_domain::ai::AiToolConfirmationRequirement;

/// AiToolResult 工具执行结果
/// 核心职责：
/// - 表达工具调用的授权状态、返回事实条目和引用
/// - 未授权时不泄露宠物名、食品名或存在性细节
#[derive(Debug, Clone)]
pub struct AiToolResult {
    pub allowed: bool,
    pub denied_reason: Option<String>,
    pub failed_reason: Option<String>,
    pub confirmation: Option<AiToolConfirmationRequirement>,
    pub facts: Vec<AiFactEntry>,
    pub citations: Vec<AiCitation>,
    pub returned_ref_ids: Vec<String>,
}

impl AiToolResult {
    /// allowed 构造允许且无事实返回的结果
    #[must_use]
    pub fn allowed(ref_ids: Vec<String>) -> Self {
        Self {
            allowed: true,
            denied_reason: None,
            failed_reason: None,
            confirmation: None,
            facts: Vec::new(),
            citations: Vec::new(),
            returned_ref_ids: ref_ids,
        }
    }

    /// allowed_with_facts 构造允许且携带事实和引用的结果
    #[must_use]
    pub fn allowed_with_facts(facts: Vec<AiFactEntry>, citations: Vec<AiCitation>) -> Self {
        let ref_ids: Vec<String> = citations.iter().map(|c| c.source_id.to_string()).collect();
        Self {
            allowed: true,
            denied_reason: None,
            failed_reason: None,
            confirmation: None,
            facts,
            citations,
            returned_ref_ids: ref_ids,
        }
    }

    /// denied 构造拒绝结果
    #[must_use]
    pub fn denied(reason: &str) -> Self {
        Self {
            allowed: false,
            denied_reason: Some(reason.to_owned()),
            failed_reason: None,
            confirmation: None,
            facts: Vec::new(),
            citations: Vec::new(),
            returned_ref_ids: Vec::new(),
        }
    }

    /// failed 构造工具执行失败结果
    #[must_use]
    pub fn failed(reason: &str) -> Self {
        Self {
            allowed: false,
            denied_reason: None,
            failed_reason: Some(reason.to_owned()),
            confirmation: None,
            facts: Vec::new(),
            citations: Vec::new(),
            returned_ref_ids: Vec::new(),
        }
    }

    /// requires_confirmation 构造确认需求结果
    #[must_use]
    pub fn requires_confirmation(confirmation: AiToolConfirmationRequirement) -> Self {
        Self {
            allowed: false,
            denied_reason: None,
            failed_reason: None,
            confirmation: Some(confirmation),
            facts: Vec::new(),
            citations: Vec::new(),
            returned_ref_ids: Vec::new(),
        }
    }
}
