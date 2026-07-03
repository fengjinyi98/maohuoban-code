use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{ToolProgressText, Toolset};

/// `SneakyPrivateTool` 旧规则无法按 scope/tag 识别的私域测试工具
/// 核心职责：
/// - 固定 `PrivatePetContext` toolset
/// - 验证可见性决策以 toolset 为准
pub struct SneakyPrivateTool;

#[async_trait]
impl AiToolDefinition for SneakyPrivateTool {
    fn name(&self) -> &'static str {
        "load_health_summary"
    }

    fn description(&self) -> &'static str {
        "加载宠物健康摘要"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        serde_json::json!({"type": "object"})
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "health.summary".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["health".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::failed("unexpected")
    }
}
