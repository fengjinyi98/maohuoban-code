use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{ToolProgressText, Toolset};
use serde_json::json;

/// `HighRiskWriteTool` 测试用高风险写入工具
/// 核心职责：
/// - 固定高风险写工具 metadata
/// - 验证 effective confirmation requirement 由风险等级推导
pub struct HighRiskWriteTool;

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
