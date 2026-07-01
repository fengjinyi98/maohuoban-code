use serde::{Deserialize, Serialize};

/// AiIntent 毛球 Agent 意图分类
/// 核心职责：
/// - 表达用户消息的领域意图，驱动是否加载宠物上下文
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiIntent {
    PetCare,
    PetRecordQuery,
    PetFood,
    PetHealthRisk,
    EmotionalPetContext,
    AppSupport,
    OffTopic,
    PromptInjection,
    CostAbuse,
}

impl AiIntent {
    /// is_pet_domain 判断该意图是否属于宠物领域，需要加载宠物事实
    pub fn is_pet_domain(self) -> bool {
        matches!(
            self,
            Self::PetCare
                | Self::PetRecordQuery
                | Self::PetFood
                | Self::PetHealthRisk
                | Self::EmotionalPetContext
        )
    }

    /// requires_context_load 判断该意图是否需要加载私有事实上下文
    pub fn requires_context_load(self) -> bool {
        self.is_pet_domain()
    }

    /// code 返回审计用意图编码
    /// 核心职责：
    /// - 使用稳定 snake_case 字符串作为意图的跨层编码
    /// - 统一 turn_preparation、diagnostics、eval_case 的编码来源
    #[must_use]
    pub fn code(self) -> &'static str {
        match self {
            Self::PetCare => "pet_care",
            Self::PetRecordQuery => "pet_record_query",
            Self::PetFood => "pet_food",
            Self::PetHealthRisk => "pet_health_risk",
            Self::EmotionalPetContext => "emotional_pet_context",
            Self::AppSupport => "app_support",
            Self::OffTopic => "off_topic",
            Self::PromptInjection => "prompt_injection",
            Self::CostAbuse => "cost_abuse",
        }
    }
}

/// AiGateDecision 意图闸门决策结果
/// 核心职责：
/// - 记录意图分类、是否加载上下文和风险信号
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
        !matches!(self.intent, AiIntent::PromptInjection | AiIntent::CostAbuse)
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
    /// - 统一三态语义：blocked / load_context / enter_workbench
    /// - 作为 turn_preparation、diagnostics、eval_case 的唯一编码来源
    #[must_use]
    pub fn gate_code(&self) -> &'static str {
        if !self.enters_workbench() {
            "blocked"
        } else if self.context_loaded {
            "load_context"
        } else {
            "enter_workbench"
        }
    }

    /// gate_message 返回 gate 分支的安全提示
    /// 核心职责：
    /// - 根据 gate 决策属性返回对应边界文案
    /// - 保持 PromptInjection 和 CostAbuse 的硬拦截文案区分
    /// - 避免调用方直接匹配 intent 枚举决定展示文本
    #[must_use]
    pub fn gate_message(&self) -> &'static str {
        if !self.enters_workbench() {
            match self.intent {
                AiIntent::PromptInjection => "这个请求包含不受支持的操作指令，我不能继续处理。",
                AiIntent::CostAbuse => "这个请求超出了毛球助手的回答范围，我不能继续处理。",
                _ => "这个请求不符合毛球助手的安全边界，我不能继续处理。",
            }
        } else if self.context_loaded {
            "我现在只能处理宠物照护、宠物记录和毛伙伴 App 相关问题。"
        } else {
            "这个问题属于毛伙伴 App 使用帮助，我先不读取宠物事实。你可以描述遇到的页面或操作，我会按应用功能边界说明。"
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

    fn load_context_decision() -> AiGateDecision {
        AiGateDecision {
            intent: AiIntent::PetCare,
            context_loaded: true,
            risk_signal: None,
            reason: "pet domain".to_owned(),
        }
    }

    fn enter_workbench_decision() -> AiGateDecision {
        AiGateDecision {
            intent: AiIntent::OffTopic,
            context_loaded: false,
            risk_signal: None,
            reason: "off topic".to_owned(),
        }
    }

    /// gate_message 对 PromptInjection 和 CostAbuse 返回不同文案
    #[test]
    fn gate_message_distinguishes_blocked_intents() {
        let injection = blocked_decision(AiIntent::PromptInjection);
        let cost_abuse = blocked_decision(AiIntent::CostAbuse);

        let injection_msg = injection.gate_message();
        let cost_abuse_msg = cost_abuse.gate_message();

        assert_ne!(injection_msg, cost_abuse_msg);
        assert!(injection_msg.contains("操作指令"));
        assert!(cost_abuse_msg.contains("回答范围"));
    }

    /// gate_message 对非 blocked 路径保持原有文案不变
    #[test]
    fn gate_message_preserves_non_blocked_messages() {
        let load = load_context_decision();
        let enter = enter_workbench_decision();

        assert!(load.gate_message().contains("宠物照护"));
        assert!(enter.gate_message().contains("App 使用帮助"));
    }

    // gate_message 中 blocked 分支的 _ => 兜底文案在当前枚举下不可达：
    // allow_processing() 只对 PromptInjection 和 CostAbuse 返回 false，
    // 而这两个变体在 match 中均已显式处理。兜底分支仅作为防御性编程，
    // 为未来新增 blocked 意图但忘记更新 gate_message 时提供安全边界。
}
