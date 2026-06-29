// tool_guardrail per-turn 工具循环 guardrail 测试
// 核心职责：
// - 验证检测重复失败（同工具连续失败）
// - 验证检测同参重复（同工具同参数重复调用）
// - 验证检测只读工具无进展（连续多次只读工具无事实产出）
// - 验证正常调用不触发 guardrail
// - 验证高风险 denied → HardStop，低风险 denied → SoftReminder

use maohuoban_ai_application::ai::guardrail::{
    GuardrailDecision, ToolCallGuardrail, ToolCallRecord,
};
use maohuoban_ai_application::ai::tools::AiToolRiskLevel;
use maohuoban_ai_domain::ai::{LlmToolCall, LoopToolStatus};

fn tool_call(id: &str, name: &str, args: &str) -> LlmToolCall {
    LlmToolCall {
        id: id.to_owned(),
        name: name.to_owned(),
        arguments: args.to_owned(),
    }
}

fn record(
    tool_call: LlmToolCall,
    status: LoopToolStatus,
    produced_facts: bool,
    risk_level: Option<AiToolRiskLevel>,
) -> ToolCallRecord {
    ToolCallRecord {
        tool_call,
        status,
        produced_facts,
        risk_level,
    }
}

#[test]
fn guardrail_allows_normal_first_call() {
    let guardrail = ToolCallGuardrail::new();
    let call = tool_call("call_1", "query_pet_profile", r#"{"pet_id":"abc"}"#);

    let decision = guardrail.evaluate(&call, None);
    assert!(
        matches!(decision, GuardrailDecision::Allow),
        "first call should be allowed"
    );
}

#[test]
fn guardrail_detects_repeated_failure() {
    let mut guardrail = ToolCallGuardrail::new();

    let call1 = tool_call("call_1", "create_reminder", r#"{"title":"vet"}"#);
    guardrail.record(record(
        call1,
        LoopToolStatus::Failed,
        false,
        Some(AiToolRiskLevel::Medium),
    ));

    let call2 = tool_call("call_2", "create_reminder", r#"{"title":"vet"}"#);
    guardrail.record(record(
        call2,
        LoopToolStatus::Failed,
        false,
        Some(AiToolRiskLevel::Medium),
    ));

    let call3 = tool_call("call_3", "create_reminder", r#"{"title":"vet"}"#);
    let decision = guardrail.evaluate(&call3, Some(AiToolRiskLevel::Medium));

    assert!(
        matches!(decision, GuardrailDecision::HardStop { .. }),
        "repeated failures for same tool should trigger hard stop"
    );
}

#[test]
fn guardrail_detects_same_param_repeat() {
    let mut guardrail = ToolCallGuardrail::new();

    let call1 = tool_call("call_1", "query_pet_diet", r#"{"pet_id":"abc"}"#);
    guardrail.record(record(
        call1,
        LoopToolStatus::Succeeded,
        true,
        Some(AiToolRiskLevel::Low),
    ));

    let call2 = tool_call("call_2", "query_pet_diet", r#"{"pet_id":"abc"}"#);
    guardrail.record(record(
        call2,
        LoopToolStatus::Succeeded,
        true,
        Some(AiToolRiskLevel::Low),
    ));

    let call3 = tool_call("call_3", "query_pet_diet", r#"{"pet_id":"abc"}"#);
    let decision = guardrail.evaluate(&call3, Some(AiToolRiskLevel::Low));

    assert!(
        matches!(decision, GuardrailDecision::SoftReminder { .. }),
        "repeated same-param calls should trigger soft reminder"
    );
}

#[test]
fn guardrail_detects_read_only_no_progress() {
    let mut guardrail = ToolCallGuardrail::new();

    for i in 1..=3 {
        let call = tool_call(
            &format!("call_{i}"),
            "search_kb",
            &format!(r#"{{"q":"query_{i}"}}"#),
        );
        guardrail.record(record(
            call,
            LoopToolStatus::Succeeded,
            false,
            Some(AiToolRiskLevel::Low),
        ));
    }

    let call4 = tool_call("call_4", "search_kb", r#"{"q":"query_4"}"#);
    let decision = guardrail.evaluate(&call4, Some(AiToolRiskLevel::Low));

    assert!(
        matches!(decision, GuardrailDecision::SoftReminder { .. }),
        "read-only tool with no progress should trigger soft reminder"
    );
}

#[test]
fn guardrail_different_params_do_not_trigger() {
    let mut guardrail = ToolCallGuardrail::new();

    let call1 = tool_call("call_1", "query_pet_diet", r#"{"pet_id":"abc"}"#);
    guardrail.record(record(
        call1,
        LoopToolStatus::Succeeded,
        true,
        Some(AiToolRiskLevel::Low),
    ));

    let call2 = tool_call("call_2", "query_pet_diet", r#"{"pet_id":"def"}"#);
    let decision = guardrail.evaluate(&call2, Some(AiToolRiskLevel::Low));

    assert!(
        matches!(decision, GuardrailDecision::Allow),
        "different params should not trigger guardrail"
    );
}

#[test]
fn guardrail_hard_stop_for_high_risk_denied() {
    let mut guardrail = ToolCallGuardrail::new();

    let call1 = tool_call("call_1", "delete_pet_record", r#"{"pet_id":"abc"}"#);
    guardrail.record(record(
        call1,
        LoopToolStatus::Denied,
        false,
        Some(AiToolRiskLevel::Critical),
    ));

    let call2 = tool_call("call_2", "delete_pet_record", r#"{"pet_id":"abc"}"#);
    let decision = guardrail.evaluate(&call2, Some(AiToolRiskLevel::Critical));

    assert!(
        matches!(decision, GuardrailDecision::HardStop { .. }),
        "high-risk denied repeated should trigger hard stop"
    );
}

#[test]
fn guardrail_soft_reminder_for_low_risk_denied() {
    let mut guardrail = ToolCallGuardrail::new();

    let call1 = tool_call("call_1", "query_pet_diet", r#"{"pet_id":"abc"}"#);
    guardrail.record(record(
        call1,
        LoopToolStatus::Denied,
        false,
        Some(AiToolRiskLevel::Low),
    ));

    // 第一次低风险 denied 不触发 HardStop
    let call2 = tool_call("call_2", "query_pet_diet", r#"{"pet_id":"abc"}"#);
    let decision = guardrail.evaluate(&call2, Some(AiToolRiskLevel::Low));
    assert!(
        matches!(decision, GuardrailDecision::Allow),
        "first low-risk denied should not trigger"
    );

    // 记录第二次低风险 denied
    guardrail.record(record(
        call2,
        LoopToolStatus::Denied,
        false,
        Some(AiToolRiskLevel::Low),
    ));

    // 第三次尝试，低风险 denied 重复 ≥2 次 → SoftReminder
    let call3 = tool_call("call_3", "query_pet_diet", r#"{"pet_id":"abc"}"#);
    let decision = guardrail.evaluate(&call3, Some(AiToolRiskLevel::Low));
    assert!(
        matches!(decision, GuardrailDecision::SoftReminder { .. }),
        "low-risk denied repeated should trigger soft reminder, not hard stop"
    );
}

#[test]
fn guardrail_soft_reminder_does_not_block_turn() {
    let mut guardrail = ToolCallGuardrail::new();

    for i in 1..=2 {
        let call = tool_call(&format!("call_{i}"), "search_kb", r#"{"q":"same"}"#);
        guardrail.record(record(
            call,
            LoopToolStatus::Succeeded,
            false,
            Some(AiToolRiskLevel::Low),
        ));
    }

    let call3 = tool_call("call_3", "search_kb", r#"{"q":"same"}"#);
    let decision = guardrail.evaluate(&call3, Some(AiToolRiskLevel::Low));

    if let GuardrailDecision::SoftReminder { message } = decision {
        assert!(
            !message.is_empty(),
            "soft reminder should carry guidance message"
        );
    } else {
        panic!("expected SoftReminder");
    }
}
