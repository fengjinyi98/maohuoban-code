use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{AiToolConfirmationRequirement, ToolProgressText, Toolset};
use serde_json::json;

/// `PrepareObservationWriteTool` 测试用写提案工具
/// 核心职责：
/// - 固定 `requires_confirmation` 工具 metadata
/// - 返回观察记录写入确认任务
pub struct PrepareObservationWriteTool;

#[async_trait]
impl AiToolDefinition for PrepareObservationWriteTool {
    fn name(&self) -> &'static str {
        "prepare_pet_observation_write"
    }

    fn description(&self) -> &'static str {
        "准备写入宠物观察记录"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "pet_id": { "type": "string", "format": "uuid" },
                "note": { "type": "string" }
            },
            "required": ["pet_id", "note"]
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.observation.write_prepare".to_owned(),
            read_only: false,
            concurrency_safe: false,
            risk_level: AiToolRiskLevel::High,
            requires_confirmation: true,
            domain_tags: vec!["observation".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::requires_confirmation(AiToolConfirmationRequirement {
            confirmation_task_id: "confirmation-prepare".to_owned(),
            tool_name: "prepare_pet_observation_write".to_owned(),
            question_text: "确认写入观察记录？".to_owned(),
            args: json!({ "note": "今天拉稀" }),
        })
    }
}
