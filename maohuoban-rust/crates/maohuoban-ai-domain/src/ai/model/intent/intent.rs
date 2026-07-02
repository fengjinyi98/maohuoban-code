use serde::{Deserialize, Serialize};

/// AiIntent 毛球 Agent 安全边界分类
/// 核心职责：
/// - 表达入口安全边界裁决结果
/// - 不承载领域意图、工具选择或上下文加载规划
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiIntent {
    Allowed,
    InvalidInput,
}

impl AiIntent {
    /// is_pet_domain 领域意图已移出 Gate
    /// 核心职责：
    /// - 保持旧调用点编译稳定
    /// - 明确 Gate 不再声明宠物领域归属
    pub fn is_pet_domain(self) -> bool {
        false
    }

    /// requires_context_load 上下文加载由 Runtime Planner 决定
    /// 核心职责：
    /// - 防止 Gate 继续驱动私域事实加载
    /// - 保持旧调用点编译稳定
    pub fn requires_context_load(self) -> bool {
        false
    }

    /// code 返回审计用意图编码
    /// 核心职责：
    /// - 使用稳定 snake_case 字符串作为意图的跨层编码
    /// - 统一 turn_preparation、diagnostics、eval_case 的编码来源
    #[must_use]
    pub fn code(self) -> &'static str {
        match self {
            Self::Allowed => "allowed",
            Self::InvalidInput => "invalid_input",
        }
    }
}

/// AiGateDecision 安全闸门决策结果
/// 核心职责：
/// - 记录入口是否允许进入 Agent Runtime
/// - 记录硬安全风险信号，不承载领域规划
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AiGateDecision {
    pub intent: AiIntent,
    pub context_loaded: bool,
    pub risk_signal: Option<String>,
    pub reason: String,
}

impl AiGateDecision {
    /// allow_processing 判断该决策是否允许进入主 Agent 编排
    pub fn allow_processing(&self) -> bool {
        !matches!(self.intent, AiIntent::InvalidInput)
    }

    /// enters_workbench 判断该决策是否进入 AgentSession Workbench
    /// 核心职责：
    /// - 只让硬安全阻断拦截工作台入口
    /// - 将私域事实加载与 Agent 执行入口解耦
    pub fn enters_workbench(&self) -> bool {
        self.allow_processing()
    }

    /// gate_code 返回审计用 gate 决策编码
    /// 核心职责：
    /// - 统一安全边界语义：blocked / enter_workbench
    /// - 作为 turn_preparation、diagnostics、eval_case 的唯一编码来源
    #[must_use]
    pub fn gate_code(&self) -> &'static str {
        if self.enters_workbench() {
            "enter_workbench"
        } else {
            "blocked"
        }
    }

    /// gate_message 返回 gate 分支的安全提示
    /// 核心职责：
    /// - 根据 gate 决策属性返回对应边界文案
    /// - 避免调用方直接匹配 intent 枚举决定展示文本
    #[must_use]
    pub fn gate_message(&self) -> &'static str {
        if self.enters_workbench() {
            "允许进入毛球 Agent Runtime。"
        } else {
            match self.intent {
                AiIntent::InvalidInput => "这个请求缺少有效内容，我不能继续处理。",
                AiIntent::Allowed => "这个请求不符合毛球助手的安全边界，我不能继续处理。",
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn blocked_decision(intent: AiIntent) -> AiGateDecision {
        AiGateDecision {
            intent,
            context_loaded: false,
            risk_signal: Some("hard_block".to_owned()),
            reason: format!("{intent:?} blocked by gate"),
        }
    }

    fn enter_workbench_decision() -> AiGateDecision {
        AiGateDecision {
            intent: AiIntent::Allowed,
            context_loaded: false,
            risk_signal: None,
            reason: "allowed".to_owned(),
        }
    }

    /// gate_message 对结构化 invalid_input 返回稳定文案
    #[test]
    fn gate_message_distinguishes_blocked_intents() {
        let invalid = blocked_decision(AiIntent::InvalidInput);
        let invalid_msg = invalid.gate_message();

        assert!(invalid_msg.contains("缺少有效内容"));
    }

    /// gate_message 对非 blocked 路径保持原有文案不变
    #[test]
    fn gate_message_preserves_non_blocked_messages() {
        let enter = enter_workbench_decision();

        assert!(enter.gate_message().contains("Agent Runtime"));
    }

    // gate_message 中 blocked 分支的 _ => 兜底文案在当前枚举下不可达：
    // allow_processing() 只对 InvalidInput 返回 false，
    // 而该变体在 match 中已显式处理。兜底分支仅作为防御性编程，
    // 为未来新增 blocked 意图但忘记更新 gate_message 时提供安全边界。
}
