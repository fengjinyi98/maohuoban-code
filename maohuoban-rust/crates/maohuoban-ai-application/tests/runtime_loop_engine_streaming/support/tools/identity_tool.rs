use std::time::Duration;

use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{
    AiFactEntry, AiFactPackage, AiFactStrength, AiPetCandidate, ToolProgressText, Toolset,
};
use serde_json::json;
use uuid::Uuid;

pub struct EchoIdentityTool {
    delay: Duration,
}

impl EchoIdentityTool {
    pub fn immediate() -> Self {
        Self {
            delay: Duration::ZERO,
        }
    }

    pub fn delayed(delay: Duration) -> Self {
        Self { delay }
    }
}

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
            result_fact_schema: None,
        }
    }

    async fn execute(&self, ctx: &AiToolContext, args: &serde_json::Value) -> AiToolResult {
        if !self.delay.is_zero() {
            tokio::time::sleep(self.delay).await;
        }

        let pet_id = args
            .get("pet_id")
            .and_then(|value| value.as_str())
            .and_then(|value| Uuid::parse_str(value).ok());

        match pet_id {
            Some(id) if id == ctx.authorized_pet_id => {
                AiToolResult::allowed_with_fact_package(identity_fact_package(id))
            }
            Some(_) => AiToolResult::denied("pet not authorized"),
            None => AiToolResult::failed("missing pet_id"),
        }
    }
}

fn identity_fact_package(pet_id: Uuid) -> AiFactPackage {
    let mut package = AiFactPackage::empty();
    package.target_pet = Some(
        (&AiPetCandidate {
            pet_id,
            name: "毛球".to_owned(),
            avatar_url: None,
            species: "cat".to_owned(),
            profile_number: "P001".to_owned(),
        })
            .into(),
    );
    package.facts = vec![AiFactEntry {
        key: "pet_identity.name".to_owned(),
        value: "毛球".to_owned(),
        strength: AiFactStrength::Strong,
        citation_id: Some(Uuid::new_v4()),
    }];
    package.fact_strength = AiFactStrength::Strong;
    package
}
