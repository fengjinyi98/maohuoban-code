use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{AiToolConfirmationRequirement, ToolProgressText, Toolset};
use serde_json::json;

/// `ConfirmationContractTool` 合同测试用确认工具
/// 核心职责：
/// - 固定返回确认需求
/// - 验证 Tool Gateway 确认审计字段
pub struct ConfirmationContractTool;

#[async_trait]
impl AiToolDefinition for ConfirmationContractTool {
    fn name(&self) -> &'static str {
        "create_pet_reminder"
    }

    fn description(&self) -> &'static str {
        "创建宠物提醒"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "title": { "type": "string" }
            },
            "required": ["title"]
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.reminder.write".to_owned(),
            read_only: false,
            concurrency_safe: false,
            risk_level: AiToolRiskLevel::High,
            requires_confirmation: true,
            domain_tags: vec!["reminder".to_owned()],
            toolset: Toolset::Confirmation,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::requires_confirmation(AiToolConfirmationRequirement {
            confirmation_task_id: "confirmation-contract".to_owned(),
            tool_name: "create_pet_reminder".to_owned(),
            question_text: "是否确认创建提醒？".to_owned(),
            args: json!({ "title": "吃药" }),
        })
    }
}
