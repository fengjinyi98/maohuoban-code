use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{ToolProgressText, Toolset};
use serde_json::json;

#[derive(Clone)]
pub struct LoopEchoTool;

#[async_trait]
impl AiToolDefinition for LoopEchoTool {
    fn name(&self) -> &'static str {
        "loop_echo_tool"
    }

    fn description(&self) -> &'static str {
        "循环工具测试"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "value": { "type": "string" }
            }
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "test.loop".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["test".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(
        &self,
        _context: &AiToolContext,
        arguments: &serde_json::Value,
    ) -> AiToolResult {
        AiToolResult::allowed(vec![arguments.to_string()])
    }
}
