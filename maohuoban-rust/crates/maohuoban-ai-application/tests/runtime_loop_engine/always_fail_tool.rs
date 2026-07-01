//! `always_fail_tool` 总是返回结构化失败的工具
//! 核心职责：
//! - 验证 guardrail `hard_stop` 在连续失败时触发 `TurnFailed`
//! - 验证 structured failure 的 `error_code` / recoverable 回灌模型

use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{ToolFailure, ToolProgressText, Toolset};
use serde_json::json;

pub(super) struct AlwaysFailTool;

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
        AiToolResult::failed_with_failure(ToolFailure::new(
            "tool.internal_error",
            false,
            "工具执行失败",
            "upstream provider timeout",
        ))
    }
}
