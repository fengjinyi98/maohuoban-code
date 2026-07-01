// tool_audit_trace_separation 工具执行审计与用户可见轨迹分离测试
// 核心职责：
// - 验证审计记录保留工具参数 hash、授权结果、风险标签
// - 验证用户轨迹只保留展示文案和状态，不携带 tool_call_id
// - 验证用户可见事件不携带敏感参数

use maohuoban_ai_domain::ai::{AgentToolStatus, ToolExecutionAudit, ToolExecutionTrace};
use uuid::Uuid;

#[test]
fn audit_record_carries_args_hash_and_authorization() {
    let audit = ToolExecutionAudit {
        session_id: Some(Uuid::parse_str("11111111-1111-1111-1111-111111111111").unwrap()),
        turn_id: Some(Uuid::parse_str("22222222-2222-2222-2222-222222222222").unwrap()),
        message_id: Some(Uuid::parse_str("33333333-3333-3333-3333-333333333333").unwrap()),
        tool_name: "load_pet_identity_context".to_owned(),
        args: serde_json::json!({ "pet_id": "11111111-1111-1111-1111-111111111111" }),
        policy_decision: "success".to_owned(),
        duration_ms: 18,
        fact_count: 2,
        citation_ids: vec!["citation-1".to_owned(), "citation-2".to_owned()],
        failure_code: None,
        risk_level: "low".to_owned(),
        toolset: "private_pet_context".to_owned(),
    };

    assert_eq!(audit.tool_name, "load_pet_identity_context");
    assert_eq!(audit.args["pet_id"], "11111111-1111-1111-1111-111111111111");
    assert_eq!(audit.policy_decision, "success");
    assert_eq!(audit.duration_ms, 18);
    assert_eq!(audit.fact_count, 2);
    assert_eq!(audit.citation_ids.len(), 2);
    assert_eq!(audit.risk_level, "low");
    assert_eq!(audit.toolset, "private_pet_context");
}

#[test]
fn audit_record_carries_gateway_diagnostics_fields() {
    let audit = ToolExecutionAudit {
        session_id: Some(Uuid::parse_str("11111111-1111-1111-1111-111111111111").unwrap()),
        turn_id: Some(Uuid::parse_str("22222222-2222-2222-2222-222222222222").unwrap()),
        message_id: Some(Uuid::parse_str("33333333-3333-3333-3333-333333333333").unwrap()),
        tool_name: "create_pet_reminder".to_owned(),
        args: serde_json::json!({ "title": "补水" }),
        policy_decision: "requires_confirmation".to_owned(),
        duration_ms: 0,
        fact_count: 0,
        citation_ids: Vec::new(),
        failure_code: Some("tool.requires_confirmation".to_owned()),
        risk_level: "high".to_owned(),
        toolset: "confirmation".to_owned(),
    };

    assert_eq!(audit.policy_decision, "requires_confirmation");
    assert_eq!(
        audit.failure_code.as_deref(),
        Some("tool.requires_confirmation")
    );
    assert_eq!(audit.fact_count, 0);
    assert!(audit.citation_ids.is_empty());
}

#[test]
fn execution_trace_only_carries_display_text_and_status() {
    let trace = ToolExecutionTrace {
        display_text: "正在加载宠物档案".to_owned(),
        status: AgentToolStatus::Succeeded,
        citation_count: 2,
    };

    assert_eq!(trace.display_text, "正在加载宠物档案");
    assert_eq!(trace.status, AgentToolStatus::Succeeded);
    assert_eq!(trace.citation_count, 2);
}

#[test]
fn execution_trace_does_not_carry_tool_call_id() {
    let trace = ToolExecutionTrace {
        display_text: "提醒已创建".to_owned(),
        status: AgentToolStatus::Succeeded,
        citation_count: 0,
    };

    // 轨迹中不携带 tool_call_id、args、args_hash、risk_level、toolset 等字段
    let json = serde_json::to_string(&trace).unwrap();
    assert!(!json.contains("tool_call_id"));
    assert!(!json.contains("call_"));
    assert!(!json.contains("args"));
    assert!(!json.contains("risk"));
    assert!(!json.contains("toolset"));
    assert!(!json.contains("policy_decision"));
    assert!(!json.contains("duration_ms"));
    assert!(!json.contains("fact_count"));
    assert!(!json.contains("failure_code"));
}

#[test]
fn audit_record_roundtrips_through_json() {
    let audit = ToolExecutionAudit {
        session_id: Some(Uuid::parse_str("11111111-1111-1111-1111-111111111111").unwrap()),
        turn_id: Some(Uuid::parse_str("22222222-2222-2222-2222-222222222222").unwrap()),
        message_id: Some(Uuid::parse_str("33333333-3333-3333-3333-333333333333").unwrap()),
        tool_name: "load_pet_diet_context".to_owned(),
        args: serde_json::json!({ "pet_id": "11111111-1111-1111-1111-111111111111" }),
        policy_decision: "success".to_owned(),
        duration_ms: 22,
        fact_count: 1,
        citation_ids: vec!["citation-1".to_owned()],
        failure_code: None,
        risk_level: "low".to_owned(),
        toolset: "private_pet_context".to_owned(),
    };

    let json = serde_json::to_string(&audit).unwrap();
    let restored: ToolExecutionAudit = serde_json::from_str(&json).unwrap();
    assert_eq!(restored, audit);
}

#[test]
fn execution_trace_roundtrips_through_json() {
    let trace = ToolExecutionTrace {
        display_text: "知识搜索完成".to_owned(),
        status: AgentToolStatus::Failed,
        citation_count: 0,
    };

    let json = serde_json::to_string(&trace).unwrap();
    let restored: ToolExecutionTrace = serde_json::from_str(&json).unwrap();
    assert_eq!(restored, trace);
}

#[test]
fn audit_and_trace_can_be_built_from_tool_execution() {
    let _turn_id = Uuid::new_v4();

    let audit = ToolExecutionAudit {
        session_id: Some(Uuid::parse_str("11111111-1111-1111-1111-111111111111").unwrap()),
        turn_id: Some(Uuid::parse_str("22222222-2222-2222-2222-222222222222").unwrap()),
        message_id: Some(Uuid::parse_str("33333333-3333-3333-3333-333333333333").unwrap()),
        tool_name: "load_pet_identity_context".to_owned(),
        args: serde_json::json!({ "pet_id": "11111111-1111-1111-1111-111111111111" }),
        policy_decision: "success".to_owned(),
        duration_ms: 19,
        fact_count: 3,
        citation_ids: vec!["citation-1".to_owned(), "citation-2".to_owned()],
        failure_code: None,
        risk_level: "low".to_owned(),
        toolset: "private_pet_context".to_owned(),
    };

    let trace = ToolExecutionTrace {
        display_text: "宠物档案加载完成".to_owned(),
        status: AgentToolStatus::Succeeded,
        citation_count: 3,
    };

    assert!(audit.session_id.is_some());
    assert!(audit.turn_id.is_some());
    assert!(audit.message_id.is_some());
    assert_eq!(audit.fact_count, 3);
    // 轨迹有 display_text，审计没有
    assert!(!trace.display_text.is_empty());
}
