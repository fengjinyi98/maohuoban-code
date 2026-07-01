// tool_registry 工具白名单与鉴权测试
// 核心职责：
// - 验证未注册工具被拒绝
// - 验证已注册 pet tool 通过 pet application 完成权限校验
// - 遵循 TDD：先写失败测试（red），再实现工具注册（green）

use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolGatewayObserver, AiToolMetadata, AiToolResult,
    AiToolRiskLevel, DateCalculatorTool, ToolGatewayExecutionContext, ToolRegistry,
};
use maohuoban_ai_domain::ai::{
    AiCitation, AiCitationSourceKind, AiFactEntry, AiFactStrength, LlmToolCall, ToolExecutionAudit,
    ToolProgressText, Toolset,
};
use serde_json::json;
use std::sync::{Arc, Mutex};
use std::time::Duration;
use uuid::Uuid;

fn test_tool_context(pet_id: Uuid) -> AiToolContext {
    AiToolContext {
        actor_user_id: Uuid::new_v4(),
        authorized_pet_id: pet_id,
        gateway_context: ToolGatewayExecutionContext::default(),
        gateway_observer: None,
    }
}

/// `CapturingGatewayObserver` 测试用 Gateway 审计观察者
/// 核心职责：
/// - 收集 Tool Gateway 审计记录
/// - 让测试验证 Gateway 产出的正式审计字段
struct CapturingGatewayObserver {
    audits: Arc<Mutex<Vec<ToolExecutionAudit>>>,
}

#[async_trait]
impl AiToolGatewayObserver for CapturingGatewayObserver {
    async fn record(&self, audit: &ToolExecutionAudit) {
        self.audits.lock().expect("audits").push(audit.clone());
    }
}

fn test_tool_context_with_audits(
    pet_id: Uuid,
    audits: Arc<Mutex<Vec<ToolExecutionAudit>>>,
) -> AiToolContext {
    AiToolContext {
        actor_user_id: Uuid::new_v4(),
        authorized_pet_id: pet_id,
        gateway_context: ToolGatewayExecutionContext::default(),
        gateway_observer: Some(Arc::new(CapturingGatewayObserver { audits })),
    }
}

/// `FakePetTool` 测试用假宠物工具
struct FakePetTool;

#[async_trait]
impl AiToolDefinition for FakePetTool {
    fn name(&self) -> &'static str {
        "load_pet_identity_context"
    }

    fn description(&self) -> &'static str {
        "加载宠物身份上下文"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "pet_id": { "type": "string", "format": "uuid" }
            },
            "required": ["pet_id"]
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.identity.read".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["identity".to_owned(), "pet_profile".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, ctx: &AiToolContext, args: &serde_json::Value) -> AiToolResult {
        let pet_id = args
            .get("pet_id")
            .and_then(|v| v.as_str())
            .and_then(|s| Uuid::parse_str(s).ok());

        match pet_id {
            Some(id) if id == ctx.authorized_pet_id => AiToolResult::allowed(vec![]),
            Some(_) => AiToolResult::denied("pet not authorized"),
            None => AiToolResult::failed("missing pet_id"),
        }
    }
}

/// `SlowPetTool` 测试用慢工具
/// 核心职责：
/// - 人为制造可观测耗时
/// - 验证 Gateway 审计记录真实 `duration_ms`
struct SlowPetTool;

#[async_trait]
impl AiToolDefinition for SlowPetTool {
    fn name(&self) -> &'static str {
        "load_pet_identity_context"
    }

    fn description(&self) -> &'static str {
        "加载宠物身份上下文"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({"type": "object", "properties": {}, "required": []})
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.identity.read".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["identity".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        tokio::time::sleep(Duration::from_millis(5)).await;
        AiToolResult::allowed(vec![])
    }
}

/// `HighRiskWriteTool` 测试用高风险写入工具
struct HighRiskWriteTool;

#[async_trait]
impl AiToolDefinition for HighRiskWriteTool {
    fn name(&self) -> &'static str {
        "create_pet_reminder"
    }

    fn description(&self) -> &'static str {
        "创建宠物提醒"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "pet_id": { "type": "string", "format": "uuid" },
                "title": { "type": "string" }
            },
            "required": ["pet_id", "title"]
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.reminder.write".to_owned(),
            read_only: false,
            concurrency_safe: false,
            risk_level: AiToolRiskLevel::High,
            requires_confirmation: false,
            domain_tags: vec!["reminder".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::allowed(vec![])
    }
}

#[tokio::test]
async fn tool_registry_rejects_unknown_tool() {
    let registry = ToolRegistry::new();
    let ctx = test_tool_context(Uuid::new_v4());
    let result = registry.call("nonexistent_tool", &ctx, &json!({})).await;
    assert!(!result.is_success());
    assert!(result.denied_reason().unwrap_or("").contains("unknown"));
}

#[tokio::test]
async fn registered_tool_executes_successfully() {
    let mut registry = ToolRegistry::new();
    registry.register(FakePetTool);
    let pet_id = Uuid::new_v4();
    let ctx = test_tool_context(pet_id);
    let result = registry
        .call(
            "load_pet_identity_context",
            &ctx,
            &json!({ "pet_id": pet_id.to_string() }),
        )
        .await;
    assert!(result.is_success());
    assert!(result.denied_reason().is_none());
}

#[tokio::test]
async fn date_calculator_adds_days_as_read_only_temporal_tool() {
    let mut registry = ToolRegistry::new();
    registry.register(DateCalculatorTool);
    let ctx = test_tool_context(Uuid::new_v4());

    let result = registry
        .call(
            "date_calculator",
            &ctx,
            &json!({
                "operation": "add_days",
                "base_date": "2026-06-17",
                "days": -7
            }),
        )
        .await;

    assert!(result.is_success());
    let facts = result.facts();
    assert_eq!(facts.len(), 1);
    assert_eq!(facts[0].key, "temporal.date_calculation");
    assert_eq!(facts[0].value, "2026-06-17 加 -7 天 = 2026-06-10");

    let tool = registry
        .list_definitions()
        .into_iter()
        .find(|tool| tool.name == "date_calculator")
        .expect("date calculator definition");
    assert_eq!(tool.toolset, Toolset::Temporal);
    assert!(tool.read_only);
    assert!(!tool.requires_confirmation);
}

#[tokio::test]
async fn date_calculator_finds_next_interval_date_after_local_date() {
    let mut registry = ToolRegistry::new();
    registry.register(DateCalculatorTool);
    let ctx = test_tool_context(Uuid::new_v4());

    let result = registry
        .call(
            "date_calculator",
            &ctx,
            &json!({
                "operation": "next_interval_date",
                "start_date": "2026-06-17",
                "interval_days": 30,
                "after_date": "2026-07-02"
            }),
        )
        .await;

    assert!(result.is_success());
    let facts = result.facts();
    assert_eq!(facts.len(), 1);
    assert_eq!(facts[0].key, "temporal.date_calculation");
    assert_eq!(
        facts[0].value,
        "从 2026-06-17 每 30 天一次，2026-07-02 之后的下次日期 = 2026-07-17"
    );
}

#[tokio::test]
async fn date_calculator_counts_days_between_dates() {
    let mut registry = ToolRegistry::new();
    registry.register(DateCalculatorTool);
    let ctx = test_tool_context(Uuid::new_v4());

    let result = registry
        .call(
            "date_calculator",
            &ctx,
            &json!({
                "operation": "days_between",
                "date1": "2026-07-02",
                "date2": "2027-06-17"
            }),
        )
        .await;

    assert!(result.is_success());
    let facts = result.facts();
    assert_eq!(facts.len(), 1);
    assert_eq!(facts[0].key, "temporal.date_calculation");
    assert_eq!(facts[0].value, "2026-07-02 到 2027-06-17 相差 350 天");

    let tool = registry
        .list_definitions()
        .into_iter()
        .find(|tool| tool.name == "date_calculator")
        .expect("date calculator definition");
    let operations = tool.parameters["properties"]["operation"]["enum"]
        .as_array()
        .expect("operation enum");
    assert!(
        operations
            .iter()
            .any(|operation| operation.as_str() == Some("days_between")),
        "date_calculator schema must declare days_between operation"
    );
}

#[tokio::test]
async fn gateway_rejects_date_calculator_operation_outside_schema() {
    let mut registry = ToolRegistry::new();
    registry.register(DateCalculatorTool);
    let audits = Arc::new(Mutex::new(Vec::new()));
    let ctx = test_tool_context_with_audits(Uuid::new_v4(), audits.clone());
    let tool_call = LlmToolCall {
        id: "call_unknown_operation".to_owned(),
        name: "date_calculator".to_owned(),
        arguments: json!({
            "operation": "invent_magic_date",
            "date1": "2026-07-02",
            "date2": "2027-06-17"
        })
        .to_string(),
    };

    let result = registry.execute_tool_call(&ctx, &tool_call).await;

    assert_eq!(result.audit.policy_decision, "failed");
    assert_eq!(
        result.audit.failure_code.as_deref(),
        Some("tool.invalid_arguments")
    );
    let audits = audits.lock().expect("audits");
    assert_eq!(audits.len(), 1);
    assert_eq!(
        audits[0].failure_code.as_deref(),
        Some("tool.invalid_arguments")
    );
}

#[tokio::test]
async fn pet_tool_authorization_denies_unauthorized_pet() {
    let mut registry = ToolRegistry::new();
    registry.register(FakePetTool);
    let ctx = test_tool_context(Uuid::new_v4());
    let other_pet = Uuid::new_v4();
    let result = registry
        .call(
            "load_pet_identity_context",
            &ctx,
            &json!({ "pet_id": other_pet.to_string() }),
        )
        .await;
    assert!(!result.is_success());
    assert!(
        result
            .denied_reason()
            .unwrap_or("")
            .contains("not authorized")
    );
    // 不泄露其他宠物信息
    assert!(result.reference_ids().is_empty());
}

#[tokio::test]
async fn tool_result_can_carry_facts_and_citations() {
    let citation_id = Uuid::new_v4();
    let result = AiToolResult::allowed_with_facts(
        vec![AiFactEntry {
            key: "current_staple".to_owned(),
            value: "渴望六种鱼".to_owned(),
            strength: AiFactStrength::Strong,
            citation_id: Some(citation_id),
        }],
        vec![AiCitation {
            source_kind: AiCitationSourceKind::DietAssignment,
            source_id: citation_id,
            label: "当前主粮".to_owned(),
        }],
    );
    assert!(result.is_success());
    assert_eq!(result.facts().len(), 1);
    assert_eq!(result.citations().len(), 1);
    assert_eq!(result.facts()[0].strength, AiFactStrength::Strong);
}

#[tokio::test]
async fn tool_registry_lists_registered_tools() {
    let mut registry = ToolRegistry::new();
    registry.register(FakePetTool);
    let tools = registry.list_definitions();
    assert_eq!(tools.len(), 1);
    assert_eq!(tools[0].name, "load_pet_identity_context");
}

#[tokio::test]
async fn tool_registry_lists_metadata() {
    let mut registry = ToolRegistry::new();
    registry.register(FakePetTool);

    let tools = registry.list_definitions();

    assert_eq!(tools.len(), 1);
    assert_eq!(tools[0].scope, "pet.identity.read");
    assert!(tools[0].read_only);
    assert!(tools[0].concurrency_safe);
    assert_eq!(tools[0].risk_level, AiToolRiskLevel::Low);
    assert!(!tools[0].declared_requires_confirmation);
    assert!(!tools[0].requires_confirmation);
    assert_eq!(tools[0].domain_tags, vec!["identity", "pet_profile"]);
}

#[tokio::test]
async fn tool_registry_exposes_effective_confirmation_requirement() {
    let mut registry = ToolRegistry::new();
    registry.register(HighRiskWriteTool);

    let tools = registry.list_definitions();

    assert_eq!(tools.len(), 1);
    assert!(!tools[0].declared_requires_confirmation);
    assert!(tools[0].requires_confirmation);
    assert_eq!(tools[0].risk_level, AiToolRiskLevel::High);
    assert!(!tools[0].read_only);
}

#[tokio::test]
async fn gateway_audit_records_real_duration_ms() {
    let mut registry = ToolRegistry::new();
    registry.register(SlowPetTool);
    let pet_id = Uuid::new_v4();
    let audits = Arc::new(Mutex::new(Vec::new()));
    let ctx = test_tool_context_with_audits(pet_id, audits.clone());
    let tool_call = LlmToolCall {
        id: "call_duration".to_owned(),
        name: "load_pet_identity_context".to_owned(),
        arguments: "{}".to_owned(),
    };

    let result = registry.execute_tool_call(&ctx, &tool_call).await;

    assert_eq!(result.audit.policy_decision, "success");
    assert!(
        result.audit.duration_ms > 0,
        "Gateway audit should record real duration_ms, got {}",
        result.audit.duration_ms
    );
    let recorded = audits.lock().expect("audits");
    assert_eq!(recorded.len(), 1);
    assert!(
        recorded[0].duration_ms > 0,
        "observer should receive real duration_ms, got {}",
        recorded[0].duration_ms
    );
}
