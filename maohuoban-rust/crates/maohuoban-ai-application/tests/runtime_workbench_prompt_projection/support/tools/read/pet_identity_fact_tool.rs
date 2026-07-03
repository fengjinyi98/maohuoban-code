use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{ToolFactField, ToolFactSchema, ToolProgressText, Toolset};

pub struct PetIdentityFactTool;

#[async_trait]
impl AiToolDefinition for PetIdentityFactTool {
    fn name(&self) -> &'static str {
        "load_pet_identity_context"
    }

    fn description(&self) -> &'static str {
        "读取目标宠物基础档案事实"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        serde_json::json!({
            "type": "object",
            "properties": {},
            "required": []
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
                    "pet_identity.birthday".to_owned(),
                    "pet_identity.world_days".to_owned(),
                    "pet_identity.companionship_days".to_owned(),
                ],
                description: "宠物基础档案事实".to_owned(),
                natural_language_summary:
                    "可回答宠物多大了、几岁了、生日、来到世界多少天、陪伴多久等问题".to_owned(),
                fields: vec![
                    ToolFactField {
                        key: "pet_identity.world_days".to_owned(),
                        label: "年龄/出生至今天数".to_owned(),
                        meaning: "宠物从生日到今天经过的天数，可用于回答多大了、几岁了、出生多久了"
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

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::allowed(Vec::new())
    }
}
