//! intent 意图闸门
//! 核心职责：
//! - 识别入口硬安全边界
//! - 允许非安全风险请求进入 Agent Runtime 自主规划

use maohuoban_ai_domain::ai::{AiGateDecision, AiIntent};

const MAX_MESSAGE_CHARS: usize = 4000;

/// AiIntentGate 安全闸门
/// 核心职责：
/// - 只处理结构化硬边界
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
        let risk_signal = if matches!(intent, AiIntent::InvalidInput) {
            Some("invalid_input".to_owned())
        } else {
            None
        };
        let reason = intent_reason(intent, message);

        AiGateDecision {
            intent,
            context_loaded: false,
            risk_signal,
            reason,
        }
    }

    /// classify_boundary 安全边界分类核心逻辑
    fn classify_boundary(message: &str) -> AiIntent {
        if message.trim().is_empty() {
            return AiIntent::InvalidInput;
        }
        if message.chars().count() > MAX_MESSAGE_CHARS {
            return AiIntent::InvalidInput;
        }

        AiIntent::Allowed
    }
}

impl Default for AiIntentGate {
    fn default() -> Self {
        Self::new()
    }
}

/// intent_reason 返回意图的人类可读原因
fn intent_reason(intent: AiIntent, message: &str) -> String {
    match intent {
        AiIntent::Allowed => "允许进入 Agent Runtime".to_owned(),
        AiIntent::InvalidInput => {
            if message.trim().is_empty() {
                "请求缺少有效内容".to_owned()
            } else {
                format!("请求内容过长，超过 {MAX_MESSAGE_CHARS} 字符上限")
            }
        }
    }
}
