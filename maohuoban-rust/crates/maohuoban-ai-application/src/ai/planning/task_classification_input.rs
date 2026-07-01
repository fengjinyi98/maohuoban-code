use maohuoban_ai_domain::ai::AiGateDecision;

/// TaskClassificationInput 任务分类输入
/// 核心职责：
/// - 汇总 Intent Gate 与 Runtime 预取判断所需的最小信号
/// - 避免分类逻辑直接读取分散状态
pub struct TaskClassificationInput<'a> {
    pub gate_decision: AiGateDecision,
    pub user_input: &'a str,
    pub selected_pet_present: bool,
    pub evidence_tool_count: usize,
    pub write_tool_visible: bool,
}
