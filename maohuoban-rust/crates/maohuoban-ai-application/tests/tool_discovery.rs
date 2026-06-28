// tool_discovery 工具发现测试
// 核心职责：
// - 验证按 domain_tags 形成工具组摘要
// - 验证按需展开 group schema

use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel, ToolRegistry,
};
use serde_json::json;

/// `TaggedTool` 测试用带标签工具
/// 核心职责：
/// - 通过 `domain_tags` 参与工具发现分组
/// - 暴露可展开的参数 schema
struct TaggedTool {
    name: &'static str,
    description: &'static str,
    scope: &'static str,
    domain_tags: Vec<String>,
}

impl AiToolDefinition for TaggedTool {
    fn name(&self) -> &str {
        self.name
    }

    fn description(&self) -> &str {
        self.description
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
            scope: self.scope.to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: self.domain_tags.clone(),
        }
    }

    fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::allowed(vec![])
    }
}

#[tokio::test]
async fn tool_discovery_groups_tools() {
    let mut registry = ToolRegistry::new();
    registry.register(TaggedTool {
        name: "load_pet_diet_context",
        description: "加载宠物饮食上下文",
        scope: "pet.diet.read",
        domain_tags: vec!["diet".to_owned()],
    });
    registry.register(TaggedTool {
        name: "load_pet_vaccine_context",
        description: "加载宠物疫苗上下文",
        scope: "pet.vaccine.read",
        domain_tags: vec!["vaccine".to_owned(), "health".to_owned()],
    });
    registry.register(TaggedTool {
        name: "explain_app_feature",
        description: "解释应用功能",
        scope: "app.help.read",
        domain_tags: vec!["app_help".to_owned()],
    });

    let groups = registry.list_tool_groups();
    let diet = groups.iter().find(|group| group.group == "diet").unwrap();
    let vaccine = groups
        .iter()
        .find(|group| group.group == "vaccine")
        .unwrap();
    let schema = registry.expand_tool_group("vaccine").unwrap();

    assert_eq!(diet.tool_count, 1);
    assert_eq!(diet.tool_names, vec!["load_pet_diet_context"]);
    assert_eq!(vaccine.tool_names, vec!["load_pet_vaccine_context"]);
    assert_eq!(schema.group, "vaccine");
    assert_eq!(schema.tools.len(), 1);
    assert_eq!(schema.tools[0].name, "load_pet_vaccine_context");
    assert_eq!(schema.tools[0].parameters["required"], json!(["pet_id"]));
}

#[tokio::test]
async fn tool_discovery_deduplicates_duplicate_domain_tags() {
    let mut registry = ToolRegistry::new();
    registry.register(TaggedTool {
        name: "load_pet_diet_context",
        description: "加载宠物饮食上下文",
        scope: "pet.diet.read",
        domain_tags: vec!["diet".to_owned(), "diet".to_owned()],
    });

    let groups = registry.list_tool_groups();
    let diet = groups.iter().find(|group| group.group == "diet").unwrap();

    assert_eq!(diet.tool_count, 1);
    assert_eq!(diet.tool_names, vec!["load_pet_diet_context"]);
}
