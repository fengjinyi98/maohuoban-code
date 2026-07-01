use maohuoban_ai_domain::ai::AiIntent;

use super::{TaskClassificationInput, TaskType};

/// TaskClassifier 轻任务分类器
/// 核心职责：
/// - 在不引入复杂 planner 的前提下固定 WT08 任务映射
/// - 保持硬安全拒绝、取证、追问和写入确认的优先级
pub struct TaskClassifier;

impl TaskClassifier {
    /// classify 根据 gate 与运行时信号分类任务
    #[must_use]
    pub fn classify(input: &TaskClassificationInput<'_>) -> TaskType {
        if !input.gate_decision.allow_processing() {
            return TaskType::RejectTask;
        }

        Self::classify_runtime(
            input.user_input,
            input.selected_pet_present || input.gate_decision.context_loaded,
            input.evidence_tool_count,
            input.write_tool_visible,
            Some(input.gate_decision.intent),
        )
    }

    /// classify_runtime 根据 Runtime 可见信号分类任务
    /// 核心职责：
    /// - 服务 Runtime loop 内部诊断
    /// - 保持入口 Intent Gate 作为安全裁决来源
    #[must_use]
    pub fn classify_runtime(
        user_input: &str,
        selected_pet_present: bool,
        evidence_tool_count: usize,
        write_tool_visible: bool,
        intent: Option<AiIntent>,
    ) -> TaskType {
        if write_tool_visible && looks_like_write_request(user_input) {
            return TaskType::WriteTask;
        }
        if selected_pet_present && looks_like_clarification_request(user_input) {
            return TaskType::ClarificationTask;
        }
        if evidence_tool_count > 0 {
            return TaskType::EvidenceReadTask;
        }
        if selected_pet_present || intent.is_some_and(AiIntent::requires_context_load) {
            return TaskType::ContextAnswer;
        }
        TaskType::DirectAnswer
    }
}

fn looks_like_write_request(input: &str) -> bool {
    let normalized = normalize(input);
    [
        "记下来",
        "记录",
        "保存",
        "新建",
        "创建",
        "提醒",
        "写入",
        "帮我记",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
}

fn looks_like_clarification_request(input: &str) -> bool {
    let normalized = normalize(input);
    let char_count = normalized.chars().count();
    char_count <= 10
        && ["不舒服", "有点不对", "怎么了", "怪怪的", "难受"]
            .iter()
            .any(|keyword| normalized.contains(keyword))
}

fn normalize(input: &str) -> String {
    input.chars().filter(|ch| !ch.is_whitespace()).collect()
}
