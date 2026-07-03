use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{ToolProgressText, Toolset};
use serde_json::json;

/// `CommitObservationWriteTool` 测试用确认后提交工具
/// 核心职责：
/// - 固定 confirmation toolset 写工具 metadata
/// - 验证缺少确认上下文时 Gateway 拒绝提交
pub struct CommitObservationWriteTool;

#[async_trait]
impl AiToolDefinition for CommitObservationWriteTool {
    fn name(&self) -> &'static str {
        "commit_pet_observation_write"
    }

    fn description(&self) -> &'static str {
        "确认后提交宠物观察记录写入"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "confirmation_task_id": { "type": "string" }
            },
            "required": ["confirmation_task_id"]
        })
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
        AiToolResult::allowed(vec![])
    }
}
