//! intent 意图闸门
//! 核心职责：
//! - 识别入口硬安全边界
//! - 允许非安全风险请求进入 Agent Runtime 自主规划

use maohuoban_ai_domain::ai::{AiGateDecision, AiIntent};

/// AiIntentGate 安全闸门
/// 核心职责：
/// - 阻断 prompt injection 和成本滥用请求
/// - 不负责领域意图、工具选择和上下文加载
pub struct AiIntentGate;

impl AiIntentGate {
    /// new 构造意图闸门
    #[must_use]
    pub fn new() -> Self {
        Self
    }

    /// classify 分类用户消息意图
    #[must_use]
    pub fn classify(&self, message: &str) -> AiGateDecision {
        let intent = Self::classify_boundary(message);
        let risk_signal = if matches!(intent, AiIntent::PromptInjection | AiIntent::CostAbuse) {
            Some(intent_label(intent))
        } else {
            None
        };
        let reason = intent_reason(intent);

        AiGateDecision {
            intent,
            context_loaded: false,
            risk_signal,
            reason,
        }
    }

    /// classify_boundary 安全边界分类核心逻辑
    fn classify_boundary(message: &str) -> AiIntent {
        if is_prompt_injection(message) {
            return AiIntent::PromptInjection;
        }

        if is_cost_abuse(message) {
            return AiIntent::CostAbuse;
        }

        AiIntent::Allowed
    }
}

impl Default for AiIntentGate {
    fn default() -> Self {
        Self::new()
    }
}

/// is_prompt_injection 检测 prompt injection 模式
fn is_prompt_injection(message: &str) -> bool {
    const PATTERNS: &[&str] = &[
        "忽略",
        "指令",
        "管理员模式",
        "管理员",
        "读取数据库",
        "读取全部",
        "读取所有",
        "绕过",
        "权限",
        "system prompt",
        "你的提示词",
        " jailbreak",
    ];
    PATTERNS.iter().any(|p| message.contains(p))
}

/// is_cost_abuse 检测成本滥用模式
fn is_cost_abuse(message: &str) -> bool {
    const PATTERNS: &[&str] = &[
        "一万字",
        "写小说",
        "写论文",
        "写代码",
        "翻译整篇",
        "生成全部",
        "批量生成",
    ];
    PATTERNS.iter().any(|p| message.contains(p))
}

/// intent_label 返回意图的风险标签
fn intent_label(intent: AiIntent) -> String {
    match intent {
        AiIntent::PromptInjection => "prompt_injection".to_owned(),
        AiIntent::CostAbuse => "cost_abuse".to_owned(),
        AiIntent::Allowed => intent.reason_label(),
    }
}

/// intent_reason 返回意图的人类可读原因
fn intent_reason(intent: AiIntent) -> String {
    match intent {
        AiIntent::Allowed => "允许进入 Agent Runtime".to_owned(),
        AiIntent::PromptInjection => "prompt injection 检测".to_owned(),
        AiIntent::CostAbuse => "成本滥用检测".to_owned(),
    }
}

trait IntentLabelExt {
    fn reason_label(&self) -> String;
}

impl IntentLabelExt for AiIntent {
    fn reason_label(&self) -> String {
        intent_reason(*self)
    }
}
