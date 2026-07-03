use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{ToolFactField, ToolFactSchema, ToolProgressText, Toolset};
use serde_json::json;

#[derive(Clone)]
pub struct EchoDietTool;

#[async_trait]
impl AiToolDefinition for EchoDietTool {
    fn name(&self) -> &'static str {
        "load_pet_current_diet_context"
    }

    fn description(&self) -> &'static str {
        "返回当前饮食信息"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "pet_id": { "type": "string" }
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
            result_fact_schema: Some(ToolFactSchema {
                fact_keys: vec!["diet.current_food".to_owned()],
                description: "宠物当前饮食事实".to_owned(),
                natural_language_summary: "可回答当前吃什么粮".to_owned(),
                fields: vec![ToolFactField {
                    key: "diet.current_food".to_owned(),
                    label: "当前主粮".to_owned(),
                    meaning: "宠物当前正在吃的主粮".to_owned(),
                    example_queries: vec!["现在吃什么".to_owned()],
                }],
                default_strength: None,
            }),
        }
    }

    async fn execute(
        &self,
        _context: &AiToolContext,
        _arguments: &serde_json::Value,
    ) -> AiToolResult {
        AiToolResult::allowed_with_facts(
            vec![maohuoban_ai_domain::ai::AiFactEntry {
                key: "diet.current_food".to_owned(),
                value: "渴望六种鱼".to_owned(),
                strength: maohuoban_ai_domain::ai::AiFactStrength::Strong,
                citation_id: None,
            }],
            Vec::new(),
        )
    }
}
