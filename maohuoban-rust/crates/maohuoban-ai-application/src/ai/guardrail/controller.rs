// ToolCallGuardrail per-turn 工具循环 guardrail
// 核心职责：
// - 跟踪 per-turn 工具调用历史
// - 检测重复失败：同工具连续失败超过阈值 → HardStop
// - 检测同参重复：同工具同参数重复调用超过阈值 → SoftReminder
// - 检测只读工具无进展：连续多次只读工具无事实产出 → SoftReminder
// - 检测安全越界：高风险工具被 denied 后重复尝试 → HardStop；低风险 denied → SoftReminder
// - 借鉴 Hermes ToolCallGuardrailController

use maohuoban_ai_domain::ai::{LlmToolCall, LoopToolStatus};

use crate::ai::tools::AiToolRiskLevel;

use super::GuardrailDecision;

/// 同工具连续失败触发 HardStop 的阈值
const REPEATED_FAILURE_THRESHOLD: usize = 2;

/// 同工具同参数重复调用触发 SoftReminder 的阈值
const SAME_PARAM_REPEAT_THRESHOLD: usize = 2;

/// 只读工具无进展触发 SoftReminder 的阈值
const READ_ONLY_NO_PROGRESS_THRESHOLD: usize = 3;

/// 低风险 denied 重复尝试触发 SoftReminder 的阈值
const LOW_RISK_DENIED_THRESHOLD: usize = 2;

/// ToolCallRecord 工具调用记录
/// 核心职责：
/// - 承载单次工具调用的执行结果
/// - 记录是否产出事实和风险等级，供无进展和安全越界检测
#[derive(Debug, Clone)]
pub struct ToolCallRecord {
    pub tool_call: LlmToolCall,
    pub status: LoopToolStatus,
    pub produced_facts: bool,
    pub risk_level: Option<AiToolRiskLevel>,
}

/// ToolCallGuardrail per-turn 工具循环 guardrail
/// 核心职责：
/// - 在工具执行前评估是否允许调用
/// - 在工具执行后记录结果，更新内部状态
/// - 检测重复失败、同参重复、只读工具无进展
/// - 区分高风险 denied（HardStop）和低风险 denied（SoftReminder）
pub struct ToolCallGuardrail {
    records: Vec<ToolCallRecord>,
}

impl ToolCallGuardrail {
    /// new 构造空 guardrail
    #[must_use]
    pub fn new() -> Self {
        Self {
            records: Vec::new(),
        }
    }

    /// evaluate 评估即将执行的工具调用
    /// 核心职责：
    /// - 基于历史记录判断是否允许调用
    /// - 重复失败 → HardStop
    /// - 高风险工具 denied 后重复尝试 → HardStop
    /// - 低风险工具 denied 后重复尝试 → SoftReminder
    /// - 同参重复 → SoftReminder
    /// - 只读工具无进展 → SoftReminder
    #[must_use]
    pub fn evaluate(
        &self,
        call: &LlmToolCall,
        risk_level: Option<AiToolRiskLevel>,
    ) -> GuardrailDecision {
        let tool_name = &call.name;
        let args = &call.arguments;

        // 检测同工具重复失败
        let failure_count = self
            .records
            .iter()
            .filter(|r| {
                r.tool_call.name == *tool_name && matches!(r.status, LoopToolStatus::Failed)
            })
            .count();

        if failure_count >= REPEATED_FAILURE_THRESHOLD {
            return GuardrailDecision::HardStop {
                safe_user_message: "工具多次执行失败，请稍后重试或换一种方式。".to_owned(),
                internal_reason: format!(
                    "tool {tool_name} failed {failure_count} times, hard stop to prevent loop"
                ),
            };
        }

        // 检测安全越界：区分高风险和低风险 denied
        let high_risk_denied_count = self
            .records
            .iter()
            .filter(|r| {
                r.tool_call.name == *tool_name
                    && matches!(r.status, LoopToolStatus::Denied)
                    && matches!(
                        r.risk_level,
                        Some(AiToolRiskLevel::High | AiToolRiskLevel::Critical)
                    )
            })
            .count();

        if high_risk_denied_count >= 1 {
            return GuardrailDecision::HardStop {
                safe_user_message: "该操作未被授权，请换一种方式或联系管理员。".to_owned(),
                internal_reason: format!(
                    "tool {tool_name} high-risk denied {high_risk_denied_count} times, hard stop for safety"
                ),
            };
        }

        let low_risk_denied_count = self
            .records
            .iter()
            .filter(|r| {
                r.tool_call.name == *tool_name
                    && matches!(r.status, LoopToolStatus::Denied)
                    && !matches!(
                        r.risk_level,
                        Some(AiToolRiskLevel::High | AiToolRiskLevel::Critical)
                    )
            })
            .count();

        if low_risk_denied_count >= LOW_RISK_DENIED_THRESHOLD {
            return GuardrailDecision::SoftReminder {
                message: format!(
                    "工具 {tool_name} 已被拒绝 {low_risk_denied_count} 次，请尝试换工具或换参数。"
                ),
            };
        }

        // 检测同工具同参数重复
        let same_param_count = self
            .records
            .iter()
            .filter(|r| r.tool_call.name == *tool_name && r.tool_call.arguments == *args)
            .count();

        if same_param_count >= SAME_PARAM_REPEAT_THRESHOLD {
            return GuardrailDecision::SoftReminder {
                message: format!(
                    "工具 {tool_name} 已用相同参数调用 {same_param_count} 次，请尝试换参数或换工具。"
                ),
            };
        }

        // 检测只读工具无进展（连续多次只读工具无事实产出）
        let recent_no_progress = self
            .records
            .iter()
            .rev()
            .take(READ_ONLY_NO_PROGRESS_THRESHOLD)
            .filter(|r| !r.produced_facts && matches!(r.status, LoopToolStatus::Succeeded))
            .count();

        if recent_no_progress >= READ_ONLY_NO_PROGRESS_THRESHOLD {
            return GuardrailDecision::SoftReminder {
                message: "连续多次工具调用未产出新信息，请尝试直接回答用户问题。".to_owned(),
            };
        }

        let _ = risk_level;
        GuardrailDecision::Allow
    }

    /// record 记录工具调用结果
    /// 核心职责：
    /// - 在工具执行后记录结果
    /// - 更新内部历史，供下次 evaluate 使用
    pub fn record(&mut self, record: ToolCallRecord) {
        self.records.push(record);
    }

    /// reset 重置 guardrail（新 turn 开始时调用）
    pub fn reset(&mut self) {
        self.records.clear();
    }
}

impl Default for ToolCallGuardrail {
    fn default() -> Self {
        Self::new()
    }
}
