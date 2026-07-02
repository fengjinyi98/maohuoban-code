// policy_guard 工具策略裁决测试
// 核心职责：
// - 验证工具执行前统一裁决
// - 验证确认型工具不会被直接执行

use std::sync::{
    Arc,
    atomic::{AtomicUsize, Ordering},
};

use async_trait::async_trait;
use maohuoban_ai_application::ai::{
    policy::{PolicyDecision, PolicyGuard},
    tools::{
        AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
        ToolGatewayExecutionContext, ToolRegistry,
    },
};
use maohuoban_ai_domain::ai::{ToolProgressText, Toolset};
use serde_json::json;
use uuid::Uuid;

fn test_tool_context(pet_id: Uuid) -> AiToolContext {
    AiToolContext {
        actor_user_id: Uuid::new_v4(),
        authorized_pet_id: pet_id,
        gateway_context: ToolGatewayExecutionContext::default(),
        gateway_observer: None,
    }
}

/// `ReadonlyPetTool` 测试用只读工具
/// 核心职责：
/// - 声明低风险只读 metadata
/// - 在策略允许时返回成功结果
struct ReadonlyPetTool;

#[async_trait]
impl AiToolDefinition for ReadonlyPetTool {
    fn name(&self) -> &'static str {
        "load_pet_diet_context"
    }

    fn description(&self) -> &'static str {
        "加载宠物饮食上下文"
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
            scope: "pet.diet.read".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["diet".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::allowed(vec![])
    }
}

/// `ConfirmationTool` 测试用确认型写入工具
/// 核心职责：
/// - 声明高风险且需要确认
/// - 通过计数器证明确认前不会执行
struct ConfirmationTool {
    execute_count: Arc<AtomicUsize>,
}

struct CommitObservationTool;

#[async_trait]
impl AiToolDefinition for CommitObservationTool {
    fn name(&self) -> &'static str {
        "commit_pet_observation_write"
    }

    fn description(&self) -> &'static str {
        "确认后提交宠物观察记录"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "confirmation_task_id": { "type": "string" }
            },
            "required": ["confirmation_task_id"]
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.observation.write_commit".to_owned(),
            read_only: false,
            concurrency_safe: false,
            risk_level: AiToolRiskLevel::High,
            requires_confirmation: false,
            domain_tags: vec!["observation".to_owned()],
            toolset: Toolset::Confirmation,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::allowed(vec![])
    }
}

#[async_trait]
impl AiToolDefinition for ConfirmationTool {
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
            requires_confirmation: true,
            domain_tags: vec!["reminder".to_owned()],
            toolset: Toolset::Confirmation,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        self.execute_count.fetch_add(1, Ordering::SeqCst);
        AiToolResult::allowed(vec![])
    }
}

#[tokio::test]
async fn policy_guard_allows_readonly_tool() {
    let mut registry = ToolRegistry::new();
    registry.register(ReadonlyPetTool);
    let pet_id = Uuid::new_v4();
    let ctx = test_tool_context(pet_id);

    let decision = PolicyGuard.evaluate_registry(
        &registry,
        "load_pet_diet_context",
        &ctx,
        &json!({ "pet_id": pet_id.to_string() }),
    );

    assert_eq!(decision, PolicyDecision::Allow);
}

#[tokio::test]
async fn policy_guard_requires_confirmation() {
    let execute_count = Arc::new(AtomicUsize::new(0));
    let mut registry = ToolRegistry::new();
    registry.register(ConfirmationTool {
        execute_count: execute_count.clone(),
    });
    let pet_id = Uuid::new_v4();
    let ctx = test_tool_context(pet_id);

    let result = registry
        .call(
            "create_pet_reminder",
            &ctx,
            &json!({ "pet_id": pet_id.to_string(), "title": "吃药" }),
        )
        .await;

    assert!(!result.is_success());
    assert!(result.confirmation().is_some());
    assert_eq!(execute_count.load(Ordering::SeqCst), 0);
}

#[tokio::test]
async fn policy_guard_denies_unknown_or_unauthorized() {
    let mut registry = ToolRegistry::new();
    registry.register(ReadonlyPetTool);
    let ctx = test_tool_context(Uuid::new_v4());
    let other_pet_id = Uuid::new_v4();

    let unknown = PolicyGuard.evaluate_registry(
        &registry,
        "missing_tool",
        &ctx,
        &json!({ "pet_id": ctx.authorized_pet_id.to_string() }),
    );
    let unauthorized = registry
        .call(
            "load_pet_diet_context",
            &ctx,
            &json!({ "pet_id": other_pet_id.to_string() }),
        )
        .await;

    assert!(matches!(unknown, PolicyDecision::Deny { .. }));
    assert!(!unauthorized.is_success());
    assert!(unauthorized.facts().is_empty());
    assert!(unauthorized.citations().is_empty());
}

#[tokio::test]
async fn policy_guard_denies_commit_without_matching_confirmation_task() {
    let mut registry = ToolRegistry::new();
    registry.register(CommitObservationTool);
    let pet_id = Uuid::new_v4();
    let mut ctx = test_tool_context(pet_id);
    ctx.gateway_context.confirmation_task_id = Some("confirmed-task-1".to_owned());

    let result = registry
        .call(
            "commit_pet_observation_write",
            &ctx,
            &json!({ "confirmation_task_id": "other-task" }),
        )
        .await;

    assert!(!result.is_success());
    assert!(
        result
            .denied_reason()
            .is_some_and(|reason| reason.contains("confirmation task"))
    );
}
