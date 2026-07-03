use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{
    ToolFactField, ToolFactSchema, ToolFailure, ToolProgressText, Toolset,
};
use serde_json::json;

/// `FailingIdentityFactTool` 失败身份事实测试工具
/// 核心职责：
/// - 返回结构化 tool failure
/// - 验证 Runtime 会把失败证据回灌给后续模型
#[derive(Clone)]
pub struct FailingIdentityFactTool;

#[async_trait]
impl AiToolDefinition for FailingIdentityFactTool {
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
            domain_tags: vec!["identity".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: Some(ToolFactSchema {
                fact_keys: vec!["pet_identity.world_days".to_owned()],
                description: "宠物基础档案事实".to_owned(),
                natural_language_summary: "可回答宠物多大了、几岁了、出生多久了等问题".to_owned(),
                fields: vec![ToolFactField {
                    key: "pet_identity.world_days".to_owned(),
                    label: "年龄/出生至今天数".to_owned(),
                    meaning: "宠物从出生到今天经过的天数，可用于回答多大了、几岁了".to_owned(),
                    example_queries: vec!["多大了".to_owned(), "几岁了".to_owned()],
                }],
                default_strength: None,
            }),
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::failed_with_failure(ToolFailure::new(
            "tool.internal_error",
            false,
            "工具执行失败",
            "identity store unavailable",
        ))
    }
}
