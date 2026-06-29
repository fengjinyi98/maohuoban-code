// GuardrailDecision guardrail 决策结果
// 核心职责：
// - Allow：允许工具调用执行
// - SoftReminder：允许执行但给模型内部提醒（普通无进展）
// - HardStop：终止 turn（安全越界、重复危险写入、重复失败超限）

/// GuardrailDecision guardrail 决策
/// 核心职责：
/// - 区分软提醒和硬停止
/// - 普通无进展先给模型内部提醒
/// - 安全越界、重复危险写入进入硬停止
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum GuardrailDecision {
    /// 允许工具调用
    Allow,
    /// 软提醒：允许执行但给模型内部引导
    SoftReminder { message: String },
    /// 硬停止：终止 turn，返回安全文案
    HardStop {
        safe_user_message: String,
        internal_reason: String,
    },
}
