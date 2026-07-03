use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{AiToolConfirmationRequirement, ToolProgressText, Toolset};
use serde_json::json;

#[derive(Clone)]
pub struct ConfirmTool;

#[async_trait]
impl AiToolDefinition for ConfirmTool {
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
                "pet_id": { "type": "string", "format": "uuid" }
            },
            "required": ["pet_id"]
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
        AiToolResult::requires_confirmation(AiToolConfirmationRequirement {
            confirmation_task_id: "confirmation-1".to_owned(),
            tool_name: "create_pet_reminder".to_owned(),
            question_text: "是否确认创建提醒？".to_owned(),
            args: json!({ "pet_id": "11111111-1111-1111-1111-111111111111" }),
        })
    }
}
