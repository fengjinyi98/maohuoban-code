//! echo_tool EchoIdentityTool 测试工具
//! 核心职责：
//! - 按 pet_id 授权返回身份事实或拒绝/失败
//! - 验证 ToolFactProjector 接入边界

use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{
    AiFactEntry, AiFactStrength, ToolFactField, ToolFactSchema, ToolProgressText, Toolset,
};
use serde_json::json;
use uuid::Uuid;

pub(super) struct EchoIdentityTool;

#[async_trait]
impl AiToolDefinition for EchoIdentityTool {
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
                fact_keys: vec![
                    "pet_identity.name".to_owned(),
                    "pet_identity.world_days".to_owned(),
                    "pet_identity.companionship_days".to_owned(),
                ],
                description: "宠物基础档案事实".to_owned(),
                natural_language_summary:
                    "可回答宠物多大了、几岁了、来到世界多少天、生日、陪伴多久等问题".to_owned(),
                fields: vec![
                    ToolFactField {
                        key: "pet_identity.world_days".to_owned(),
                        label: "年龄/出生至今天数".to_owned(),
                        meaning: "宠物从出生到今天经过的天数，可用于回答多大了、几岁了、出生多久了"
                            .to_owned(),
                        example_queries: vec![
                            "多大了".to_owned(),
                            "几岁了".to_owned(),
                            "出生多久了".to_owned(),
                        ],
                    },
                    ToolFactField {
                        key: "pet_identity.companionship_days".to_owned(),
                        label: "陪伴天数".to_owned(),
                        meaning: "宠物从到家日期到今天陪伴用户的天数".to_owned(),
                        example_queries: vec!["陪伴我多久了".to_owned(), "到家多久了".to_owned()],
                    },
                ],
                default_strength: None,
            }),
        }
    }

    async fn execute(&self, ctx: &AiToolContext, args: &serde_json::Value) -> AiToolResult {
        let pet_id = args
            .get("pet_id")
            .and_then(|value| value.as_str())
            .and_then(|value| Uuid::parse_str(value).ok());

        match pet_id {
            Some(id) if id == ctx.authorized_pet_id => AiToolResult::allowed_with_facts(
                vec![
                    AiFactEntry {
                        key: "current_staple".to_owned(),
                        value: "渴望六种鱼".to_owned(),
                        strength: AiFactStrength::Strong,
                        citation_id: Some(Uuid::new_v4()),
                    },
                    AiFactEntry {
                        key: "pet_identity.name".to_owned(),
                        value: "梅录".to_owned(),
                        strength: AiFactStrength::Strong,
                        citation_id: None,
                    },
                    AiFactEntry {
                        key: "pet_identity.world_days".to_owned(),
                        value: "420".to_owned(),
                        strength: AiFactStrength::Strong,
                        citation_id: None,
                    },
                    AiFactEntry {
                        key: "pet_identity.companionship_days".to_owned(),
                        value: "378".to_owned(),
                        strength: AiFactStrength::Strong,
                        citation_id: None,
                    },
                ],
                Vec::new(),
            ),
            Some(_) => AiToolResult::denied("pet not authorized"),
            None => AiToolResult::failed("missing pet_id"),
        }
    }
}
