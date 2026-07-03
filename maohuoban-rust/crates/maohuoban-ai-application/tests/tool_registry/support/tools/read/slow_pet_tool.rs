use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{ToolProgressText, Toolset};
use serde_json::json;
use std::time::Duration;

/// `SlowPetTool` 测试用慢工具
/// 核心职责：
/// - 人为制造可观测耗时
/// - 验证 Gateway 审计记录真实 `duration_ms`
pub struct SlowPetTool;

#[async_trait]
impl AiToolDefinition for SlowPetTool {
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
        tokio::time::sleep(Duration::from_millis(5)).await;
        AiToolResult::allowed(vec![])
    }
}
