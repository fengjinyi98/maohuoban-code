use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{ToolProgressText, Toolset};

/// `PrepareObservationWriteTool` 高风险准备写入测试工具
/// 核心职责：
/// - 模拟需要确认前置步骤的私域写入工具
/// - 验证选中宠物上下文下准备写入工具可见
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
        serde_json::json!({"type": "object"})
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
        AiToolResult::failed("unexpected")
    }
}
