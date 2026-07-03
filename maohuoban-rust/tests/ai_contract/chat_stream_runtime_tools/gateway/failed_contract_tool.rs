use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{ToolFailure, ToolProgressText, Toolset};
use serde_json::json;

/// `FailedContractTool` 合同测试用失败工具
/// 核心职责：
/// - 固定返回结构化失败
/// - 验证 Tool Gateway 失败审计字段
pub struct FailedContractTool;

#[async_trait]
impl AiToolDefinition for FailedContractTool {
    fn name(&self) -> &'static str {
        "load_pet_current_diet_context"
    }

    fn description(&self) -> &'static str {
        "加载宠物饮食上下文"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({"type": "object", "properties": {}, "required": []})
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
        AiToolResult::failed_with_failure(ToolFailure::new(
            "ai.provider_not_configured",
            false,
            "工具执行失败",
            "provider is not configured",
        ))
    }
}
