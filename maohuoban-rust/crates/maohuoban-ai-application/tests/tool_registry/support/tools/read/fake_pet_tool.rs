use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{ToolProgressText, Toolset};
use serde_json::json;
use uuid::Uuid;

/// `FakePetTool` 测试用假宠物工具
/// 核心职责：
/// - 验证授权宠物 ID 通过工具参数校验
/// - 模拟宠物身份读取工具的 metadata
pub struct FakePetTool;

#[async_trait]
impl AiToolDefinition for FakePetTool {
    fn name(&self) -> &'static str {
        "load_pet_identity_context"
    }

    fn description(&self) -> &'static str {
        "加载宠物身份上下文"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "pet_id": { "type": "string", "format": "uuid" }
            },
            "required": ["pet_id"]
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.identity.read".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["identity".to_owned(), "pet_profile".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, ctx: &AiToolContext, args: &serde_json::Value) -> AiToolResult {
        let pet_id = args
            .get("pet_id")
            .and_then(|v| v.as_str())
            .and_then(|s| Uuid::parse_str(s).ok());

        match pet_id {
            Some(id) if id == ctx.authorized_pet_id => AiToolResult::allowed(vec![]),
            Some(_) => AiToolResult::denied("pet not authorized"),
            None => AiToolResult::failed("missing pet_id"),
        }
    }
}
