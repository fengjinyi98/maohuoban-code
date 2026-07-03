use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{ToolProgressText, Toolset};

pub struct WriteObservationTool;

#[async_trait]
impl AiToolDefinition for WriteObservationTool {
    fn name(&self) -> &'static str {
        "prepare_pet_observation_write"
    }

    fn description(&self) -> &'static str {
        "准备写入宠物观察记录并等待用户确认"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        serde_json::json!({
            "type": "object",
            "properties": {},
            "required": []
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.observation.write".to_owned(),
            read_only: false,
            concurrency_safe: false,
            risk_level: AiToolRiskLevel::Medium,
            requires_confirmation: true,
            domain_tags: vec!["diet_confirmation".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::requires_confirmation(
            maohuoban_ai_domain::ai::AiToolConfirmationRequirement {
                confirmation_task_id: "confirm_observation_write".to_owned(),
                tool_name: "prepare_pet_observation_write".to_owned(),
                question_text: "确认写入本次观察记录？".to_owned(),
                args: serde_json::json!({}),
            },
        )
    }
}
