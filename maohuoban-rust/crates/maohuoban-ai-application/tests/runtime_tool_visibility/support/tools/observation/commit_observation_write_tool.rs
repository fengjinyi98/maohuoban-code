use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{ToolProgressText, Toolset};

/// `CommitObservationWriteTool` 确认后提交写入测试工具
/// 核心职责：
/// - 模拟确认任务入口中的提交工具
/// - 验证 confirmation toolset 在正确上下文中可见
pub struct CommitObservationWriteTool;

#[async_trait]
impl AiToolDefinition for CommitObservationWriteTool {
    fn name(&self) -> &'static str {
        "commit_pet_observation_write"
    }

    fn description(&self) -> &'static str {
        "确认后写入宠物观察记录"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        serde_json::json!({"type": "object"})
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.observation.write_commit".to_owned(),
            read_only: false,
            concurrency_safe: false,
            risk_level: AiToolRiskLevel::High,
            requires_confirmation: false,
            domain_tags: vec!["observation".to_owned()],
            toolset: Toolset::Confirmation,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::failed("unexpected")
    }
}
