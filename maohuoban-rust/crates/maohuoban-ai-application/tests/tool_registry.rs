// tool_registry 工具白名单与鉴权测试
// 核心职责：
// - 验证未注册工具被拒绝
// - 验证已注册 pet tool 通过 pet application 完成权限校验
// - 遵循 TDD：先写失败测试（red），再实现工具注册（green）

use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel, ToolRegistry,
};
use maohuoban_ai_domain::ai::{AiCitation, AiCitationSourceKind, AiFactEntry, AiFactStrength};
use serde_json::json;
use uuid::Uuid;

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
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::allowed(vec![])
    }
}

#[tokio::test]
async fn tool_registry_rejects_unknown_tool() {
    let registry = ToolRegistry::new();
    let ctx = AiToolContext {
        actor_user_id: Uuid::new_v4(),
        authorized_pet_id: Uuid::new_v4(),
    };
    let result = registry.call("nonexistent_tool", &ctx, &json!({})).await;
    assert!(!result.allowed);
    assert!(
        result
            .denied_reason
            .as_deref()
            .unwrap_or("")
            .contains("unknown")
    );
}

#[tokio::test]
async fn registered_tool_executes_successfully() {
    let mut registry = ToolRegistry::new();
    registry.register(FakePetTool);
    let pet_id = Uuid::new_v4();
    let ctx = AiToolContext {
        actor_user_id: Uuid::new_v4(),
        authorized_pet_id: pet_id,
    };
    let result = registry
        .call(
            "load_pet_identity_context",
            &ctx,
            &json!({ "pet_id": pet_id.to_string() }),
        )
        .await;
    assert!(result.allowed);
    assert!(result.denied_reason.is_none());
}

#[tokio::test]
async fn pet_tool_authorization_denies_unauthorized_pet() {
    let mut registry = ToolRegistry::new();
    registry.register(FakePetTool);
    let ctx = AiToolContext {
        actor_user_id: Uuid::new_v4(),
        authorized_pet_id: Uuid::new_v4(),
    };
    let other_pet = Uuid::new_v4();
    let result = registry
        .call(
            "load_pet_identity_context",
            &ctx,
            &json!({ "pet_id": other_pet.to_string() }),
        )
        .await;
    assert!(!result.allowed);
    assert!(
        result
            .denied_reason
            .as_deref()
            .unwrap_or("")
            .contains("not authorized")
    );
    // 不泄露其他宠物信息
    assert!(result.returned_ref_ids.is_empty());
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
    assert!(result.allowed);
    assert_eq!(result.facts.len(), 1);
    assert_eq!(result.citations.len(), 1);
    assert_eq!(result.facts[0].strength, AiFactStrength::Strong);
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
