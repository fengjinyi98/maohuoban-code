use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{AiToolConfirmationRequirement, ToolProgressText, Toolset};
use serde_json::json;
use uuid::Uuid;

use crate::helpers::AUTHORIZED_PET_ID;

/// `WriteObservationTool` 写入观察记录测试工具
/// 核心职责：
/// - 模拟高风险写入工具需要确认
/// - 验证写入类请求由模型规划控制
#[derive(Clone)]
pub struct WriteObservationTool;

#[async_trait]
impl AiToolDefinition for WriteObservationTool {
    fn name(&self) -> &'static str {
        "write_pet_observation"
    }

    fn description(&self) -> &'static str {
        "写入宠物观察记录"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "pet_id": { "type": "string", "format": "uuid" },
                "note": { "type": "string" }
            },
            "required": ["pet_id", "note"]
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.observation.write".to_owned(),
            read_only: false,
            concurrency_safe: false,
            risk_level: AiToolRiskLevel::High,
            requires_confirmation: true,
            domain_tags: vec!["observation".to_owned()],
            toolset: Toolset::Confirmation,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::requires_confirmation(AiToolConfirmationRequirement {
            confirmation_task_id: Uuid::new_v4().to_string(),
            tool_name: "write_pet_observation".to_owned(),
            question_text: "是否确认写入这条观察记录？".to_owned(),
            args: json!({
                "pet_id": AUTHORIZED_PET_ID,
                "note": "今天拉稀"
            }),
        })
    }
}
