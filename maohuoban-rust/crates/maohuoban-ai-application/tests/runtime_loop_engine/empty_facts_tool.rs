//! `empty_facts_tool` 成功返回但 facts 为空
//! 核心职责：
//! - 验证 guardrail `soft_reminder` 在空事实重复调用时触发
//! - 验证 _`guardrail_reminder` 不破坏 output JSON 结构

use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{ToolProgressText, Toolset};
use serde_json::json;

pub(super) struct EmptyFactsTool;

#[async_trait]
impl AiToolDefinition for EmptyFactsTool {
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
        AiToolResult::allowed_with_facts(Vec::new(), Vec::new())
    }
}
