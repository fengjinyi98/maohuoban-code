use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{ToolProgressText, Toolset};
use serde_json::json;

/// `AlwaysFailTool` Runtime 回归测试用失败工具桩
/// 核心职责：
/// - 固定返回失败结果
/// - 验证重复工具失败触发 guardrail hard stop
pub struct AlwaysFailTool;

#[async_trait]
impl AiToolDefinition for AlwaysFailTool {
    fn name(&self) -> &'static str {
        "load_pet_identity_context"
    }
    fn description(&self) -> &'static str {
        "加载宠物身份上下文"
    }
    fn parameters_schema(&self) -> serde_json::Value {
        json!({"type": "object", "properties": {}, "required": []})
    }
    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.identity.read".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["identity".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }
    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::failed("upstream_timeout")
    }
}
