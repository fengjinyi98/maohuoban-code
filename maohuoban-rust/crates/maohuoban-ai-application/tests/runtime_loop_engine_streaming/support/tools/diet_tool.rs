use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{AiFactEntry, AiFactStrength, ToolProgressText, Toolset};
use serde_json::json;
use uuid::Uuid;

pub struct EchoDietTool;

#[async_trait]
impl AiToolDefinition for EchoDietTool {
    fn name(&self) -> &'static str {
        "load_pet_current_diet_context"
    }

    fn description(&self) -> &'static str {
        "加载宠物当前饮食上下文"
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
        AiToolResult::allowed_with_facts(
            vec![AiFactEntry {
                key: "diet.current_food".to_owned(),
                value: "渴望六种鱼".to_owned(),
                strength: AiFactStrength::Strong,
                citation_id: Some(Uuid::new_v4()),
            }],
            Vec::new(),
        )
    }
}
