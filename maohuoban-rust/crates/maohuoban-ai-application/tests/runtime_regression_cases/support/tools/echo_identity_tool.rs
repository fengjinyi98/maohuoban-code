use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{AiFactEntry, AiFactStrength, ToolProgressText, Toolset};
use serde_json::json;
use uuid::Uuid;

/// `EchoIdentityTool` Runtime 回归测试用身份工具桩
/// 核心职责：
/// - 验证授权宠物上下文后返回宠物名事实
/// - 模拟私域宠物身份读取工具 metadata
pub struct EchoIdentityTool;

#[async_trait]
impl AiToolDefinition for EchoIdentityTool {
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
    async fn execute(&self, ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        if ctx.authorized_pet_id == Uuid::nil() {
            return AiToolResult::denied("pet not authorized");
        }
        AiToolResult::allowed_with_facts(
            vec![AiFactEntry {
                key: "pet_name".to_owned(),
                value: "饭团".to_owned(),
                strength: AiFactStrength::Strong,
                citation_id: None,
            }],
            Vec::new(),
        )
    }
}
