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
        tool_name: "load_pet_identity_context".to_owned(),
        tool_call_id: "call_1".to_owned(),
        args_hash: "sha256:abc123".to_owned(),
        allowed: true,
        risk_level: "low".to_owned(),
        toolset: "private_pet_context".to_owned(),
    };

    assert_eq!(audit.tool_name, "load_pet_identity_context");
    assert_eq!(audit.args_hash, "sha256:abc123");
    assert!(audit.allowed);
    assert_eq!(audit.risk_level, "low");
    assert_eq!(audit.toolset, "private_pet_context");
}

#[test]
fn audit_record_does_not_carry_raw_args() {
    let audit = ToolExecutionAudit {
        tool_name: "create_pet_reminder".to_owned(),
        tool_call_id: "call_2".to_owned(),
        args_hash: "sha256:def456".to_owned(),
        allowed: false,
        risk_level: "high".to_owned(),
        toolset: "confirmation".to_owned(),
    };

    // 审计记录只有 hash，没有原始参数
    assert!(!audit.args_hash.is_empty());
    // 不存在 args 字段
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
    assert!(!json.contains("hash"));
    assert!(!json.contains("risk"));
    assert!(!json.contains("toolset"));
    assert!(!json.contains("allowed"));
}

#[test]
fn audit_record_roundtrips_through_json() {
    let audit = ToolExecutionAudit {
        tool_name: "load_pet_diet_context".to_owned(),
        tool_call_id: "call_4".to_owned(),
        args_hash: "sha256:xyz789".to_owned(),
        allowed: true,
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
        tool_name: "load_pet_identity_context".to_owned(),
        tool_call_id: "call_6".to_owned(),
        args_hash: "sha256:hash001".to_owned(),
        allowed: true,
        risk_level: "low".to_owned(),
        toolset: "private_pet_context".to_owned(),
    };

    let trace = ToolExecutionTrace {
        display_text: "宠物档案加载完成".to_owned(),
        status: AgentToolStatus::Succeeded,
        citation_count: 3,
    };

    // 审计保留 tool_call_id 供内部追踪；轨迹不携带 tool_call_id
    assert!(!audit.tool_call_id.is_empty());
    // 审计有 args_hash，轨迹没有
    assert!(!audit.args_hash.is_empty());
    // 轨迹有 display_text，审计没有
    assert!(!trace.display_text.is_empty());
}
