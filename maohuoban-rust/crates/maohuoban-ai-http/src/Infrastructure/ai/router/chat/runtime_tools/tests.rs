//! runtime_tools 测试模块
//! 核心职责：
//! - 验证工具 schema 不要求模型传入 pet_id
//! - 验证身份事实 schema 字段声明完整性
//! - 验证工具执行使用已授权目标宠物

#[cfg(test)]
#[allow(clippy::module_inception)]
mod tests {
    use std::sync::Arc;

    use async_trait::async_trait;
    use maohuoban_ai_application::ai::ports::{
        AiRequestGateLog, AiSessionRepository, FoodInventoryHintProvider,
        PetDietConfirmationCandidateProvider, PetDietFactProvider, PetIdentityFactProvider,
    };
    use maohuoban_ai_application::ai::tools::{AiToolContext, AiToolDefinition};
    use maohuoban_ai_domain::ai::{
        AiChatSession, AiCitation, AiFactEntry, AiFactPackage, AiFactStrength, AiMessage,
        AiPetDisplaySnapshot, AiProposedAction, AiResult, Toolset,
    };
    use serde_json::json;
    use uuid::Uuid;

    use super::super::build_public_runtime_tool_registry;
    use super::super::kind::RuntimePetContextToolKind;
    use super::super::tool::RuntimePetContextTool;
    use crate::ai::router::AiPetContextProviders;

    struct EmptySessionRepository;

    #[async_trait]
    impl AiSessionRepository for EmptySessionRepository {
        async fn upsert_session(&self, _session: &AiChatSession) -> AiResult<()> {
            Ok(())
        }

        async fn update_session_header(
            &self,
            _session_id: Uuid,
            _actor_user_id: Uuid,
            _last_turn_id: Uuid,
            _last_message_at: chrono::DateTime<chrono::Utc>,
        ) -> AiResult<()> {
            Ok(())
        }

        async fn insert_message(&self, _message: &AiMessage) -> AiResult<()> {
            Ok(())
        }

        async fn list_sessions_by_actor(
            &self,
            _actor_user_id: Uuid,
            _limit: i64,
        ) -> AiResult<Vec<AiChatSession>> {
            Ok(Vec::new())
        }

        async fn list_messages_by_session(&self, _session_id: Uuid) -> AiResult<Vec<AiMessage>> {
            Ok(Vec::new())
        }

        async fn get_session(&self, _session_id: Uuid) -> AiResult<Option<AiChatSession>> {
            Ok(None)
        }

        async fn rename_session(
            &self,
            _session_id: Uuid,
            _actor_user_id: Uuid,
            _title: &str,
        ) -> AiResult<Option<AiChatSession>> {
            Ok(None)
        }

        async fn set_session_pinned(
            &self,
            _session_id: Uuid,
            _actor_user_id: Uuid,
            _is_pinned: bool,
        ) -> AiResult<Option<AiChatSession>> {
            Ok(None)
        }

        async fn archive_session(
            &self,
            _session_id: Uuid,
            _actor_user_id: Uuid,
        ) -> AiResult<Option<AiChatSession>> {
            Ok(None)
        }

        async fn insert_request_gate_log(&self, _log: &AiRequestGateLog) -> AiResult<()> {
            Ok(())
        }

        async fn insert_tool_access_log(
            &self,
            _log: &maohuoban_ai_application::ai::ports::AiToolAccessLog,
        ) -> AiResult<()> {
            Ok(())
        }

        async fn insert_message_citations(
            &self,
            _message_id: Uuid,
            _session_id: Uuid,
            _citations: &[AiCitation],
        ) -> AiResult<()> {
            Ok(())
        }

        async fn insert_proposed_action(
            &self,
            _session_id: Uuid,
            _action: &AiProposedAction,
        ) -> AiResult<()> {
            Ok(())
        }

        async fn update_message_turn_id(&self, _message_id: Uuid, _turn_id: Uuid) -> AiResult<()> {
            Ok(())
        }
    }

    struct EmptyPetContextProvider;

    #[async_trait]
    impl PetIdentityFactProvider for EmptyPetContextProvider {
        async fn load_identity_fact_package(
            &self,
            _actor_user_id: Uuid,
            target_pet: &AiPetDisplaySnapshot,
        ) -> AiResult<AiFactPackage> {
            Ok(fact_package_for(target_pet))
        }
    }

    #[async_trait]
    impl PetDietFactProvider for EmptyPetContextProvider {
        async fn load_current_diet_fact_package(
            &self,
            _actor_user_id: Uuid,
            target_pet: &AiPetDisplaySnapshot,
        ) -> AiResult<AiFactPackage> {
            Ok(fact_package_for(target_pet))
        }
    }

    #[async_trait]
    impl FoodInventoryHintProvider for EmptyPetContextProvider {
        async fn load_food_inventory_hint_package(
            &self,
            _actor_user_id: Uuid,
            target_pet: &AiPetDisplaySnapshot,
        ) -> AiResult<AiFactPackage> {
            Ok(fact_package_for(target_pet))
        }
    }

    #[async_trait]
    impl PetDietConfirmationCandidateProvider for EmptyPetContextProvider {
        async fn load_diet_confirmation_candidate_package(
            &self,
            _actor_user_id: Uuid,
            target_pet: &AiPetDisplaySnapshot,
        ) -> AiResult<AiFactPackage> {
            Ok(fact_package_for(target_pet))
        }
    }

    #[test]
    fn runtime_current_pet_tool_schema_does_not_require_model_pet_id() {
        let tool = runtime_identity_tool();

        assert_eq!(
            tool.parameters_schema(),
            json!({
                "type": "object",
                "properties": {},
                "required": []
            })
        );
    }

    #[test]
    fn runtime_identity_tool_schema_declares_life_day_facts() {
        let schema = RuntimePetContextToolKind::Identity.fact_schema();

        assert_eq!(
            schema.fact_keys,
            vec![
                "pet_identity.name",
                "pet_identity.species",
                "pet_identity.sex",
                "pet_identity.breed",
                "pet_identity.birthday",
                "pet_identity.arrival_date",
                "pet_identity.world_days",
                "pet_identity.companionship_days",
            ]
        );
    }

    #[tokio::test]
    async fn runtime_current_pet_tool_uses_authorized_target_without_model_pet_id() {
        let tool = runtime_identity_tool();
        let result = tool
            .execute(
                &AiToolContext {
                    actor_user_id: Uuid::new_v4(),
                    authorized_pet_id: tool.target_pet.pet_id,
                    gateway_context:
                        maohuoban_ai_application::ai::tools::ToolGatewayExecutionContext::default(),
                    gateway_observer: None,
                },
                &json!({}),
            )
            .await;

        assert!(result.is_success());
        assert!(result.denied_reason().is_none());
        assert!(result.failed_reason().is_none());
        assert_eq!(result.facts()[0].value, "当前目标宠物事实");
    }

    #[test]
    fn public_runtime_tool_registry_exposes_date_calculator_without_selected_pet() {
        let registry = build_public_runtime_tool_registry();
        let tools = registry.list_definitions();

        let date_tool = tools
            .iter()
            .find(|tool| tool.name == "date_calculator")
            .expect("date_calculator should be registered for public temporal turns");
        assert_eq!(date_tool.toolset, Toolset::Temporal);
        assert!(date_tool.read_only);
        assert!(!date_tool.requires_confirmation);
    }

    fn runtime_identity_tool() -> RuntimePetContextTool {
        let provider = Arc::new(EmptyPetContextProvider);
        RuntimePetContextTool {
            kind: RuntimePetContextToolKind::Identity,
            providers: AiPetContextProviders::new(
                provider.clone(),
                provider.clone(),
                provider.clone(),
                provider,
            ),
            session_repository: Arc::new(EmptySessionRepository),
            session_id: Uuid::new_v4(),
            target_pet: AiPetDisplaySnapshot {
                pet_id: Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("pet id"),
                pet_name: "饭团".to_owned(),
                pet_avatar_url: None,
                pet_species: "cat".to_owned(),
                profile_number: "MHB001".to_owned(),
            },
        }
    }

    fn fact_package_for(target_pet: &AiPetDisplaySnapshot) -> AiFactPackage {
        let mut package = AiFactPackage::empty();
        package.target_pet = Some(target_pet.clone());
        package.facts.push(AiFactEntry {
            key: "test.fact".to_owned(),
            value: "当前目标宠物事实".to_owned(),
            strength: AiFactStrength::Strong,
            citation_id: None,
        });
        package
    }
}
