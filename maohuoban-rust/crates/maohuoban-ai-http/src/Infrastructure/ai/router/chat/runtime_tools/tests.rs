//! runtime_tools 测试模块
//! 核心职责：
//! - 验证工具 schema 不要求模型传入 pet_id
//! - 验证身份事实 schema 字段声明完整性
//! - 验证工具执行使用已授权目标宠物

#[cfg(test)]
#[allow(clippy::module_inception)]
mod tests {
    use std::sync::{Arc, Mutex};

    use async_trait::async_trait;
    use maohuoban_ai_application::ai::ports::{
        AiRequestGateLog, AiSessionRepository, ChatTurnTransactionPort, CommittedObservationWrite,
        FinalizerTxInput, FoodInventoryHintProvider, IngressTxInput,
        PetAbnormalEpisodeFactProvider, PetDietConfirmationCandidateProvider, PetDietFactProvider,
        PetHealthQuickFactProvider, PetIdentityFactProvider, PetObservationWriteProvider,
        PreparedObservationWrite, SessionSummaryRepository, SessionTurnRepository,
    };
    use maohuoban_ai_application::ai::tools::{AiToolContext, AiToolDefinition};
    use maohuoban_ai_domain::ai::{
        AiChatSession, AiCitation, AiFactEntry, AiFactPackage, AiFactStrength, AiMessage,
        AiPetDisplaySnapshot, AiProposedAction, AiResult, AiSessionTurn,
        AiToolConfirmationRequirement, SessionSummary, Toolset,
    };
    use maohuoban_pet_domain::pet::PetResult;
    use serde_json::json;
    use uuid::Uuid;

    use super::super::build_public_runtime_tool_registry;
    use super::super::kind::RuntimePetContextToolKind;
    use super::super::tool::RuntimePetContextTool;
    use crate::ai::router::{AiHttpState, AiPetContextProviders};

    struct EmptySessionRepository;
    struct EmptySessionTurnRepository;
    struct EmptyChatTurnTransaction;
    struct EmptySessionSummaryRepository;

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

        async fn list_citations_by_session(
            &self,
            _session_id: Uuid,
        ) -> AiResult<std::collections::HashMap<Uuid, Vec<AiCitation>>> {
            Ok(std::collections::HashMap::new())
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

    #[async_trait]
    impl SessionTurnRepository for EmptySessionTurnRepository {
        async fn insert_turn(&self, _turn: &AiSessionTurn) -> AiResult<()> {
            Ok(())
        }

        async fn update_turn_status(
            &self,
            _turn_id: Uuid,
            _status: maohuoban_ai_domain::ai::AiSessionTurnStatus,
            _assistant_message_id: Option<Uuid>,
            _finish_reason: Option<&str>,
            _error_code: Option<&str>,
            _retryable: Option<bool>,
        ) -> AiResult<()> {
            Ok(())
        }

        async fn get_turn(&self, _turn_id: Uuid) -> AiResult<Option<AiSessionTurn>> {
            Ok(None)
        }

        async fn list_turns_by_session(&self, _session_id: Uuid) -> AiResult<Vec<AiSessionTurn>> {
            Ok(Vec::new())
        }
    }

    #[async_trait]
    impl ChatTurnTransactionPort for EmptyChatTurnTransaction {
        async fn persist_ingress_tx(&self, _input: &IngressTxInput<'_>) -> AiResult<()> {
            Ok(())
        }

        async fn persist_finalizer_tx(&self, _input: &FinalizerTxInput<'_>) -> AiResult<()> {
            Ok(())
        }
    }

    #[async_trait]
    impl SessionSummaryRepository for EmptySessionSummaryRepository {
        async fn insert_summary(&self, _summary: &SessionSummary) -> AiResult<()> {
            Ok(())
        }

        async fn get_active_summary(
            &self,
            _chat_session_id: Uuid,
        ) -> AiResult<Option<SessionSummary>> {
            Ok(None)
        }

        async fn supersede_previous_summaries(
            &self,
            _chat_session_id: Uuid,
            _superseded_at: chrono::DateTime<chrono::Utc>,
        ) -> AiResult<()> {
            Ok(())
        }
    }

    struct EmptyPetContextProvider;

    #[derive(Clone)]
    struct EmptyObservationWriteProvider;

    #[derive(Default)]
    struct CapturedAbnormalEpisodeCall {
        actor_user_id: Option<Uuid>,
        target_pet_id: Option<Uuid>,
        episode_id: Option<Uuid>,
    }

    #[derive(Clone)]
    struct CapturingAbnormalEpisodeProvider {
        captured: Arc<Mutex<CapturedAbnormalEpisodeCall>>,
    }

    impl CapturingAbnormalEpisodeProvider {
        fn new(captured: Arc<Mutex<CapturedAbnormalEpisodeCall>>) -> Self {
            Self { captured }
        }
    }

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
    impl PetAbnormalEpisodeFactProvider for EmptyPetContextProvider {
        async fn load_abnormal_episode_fact_package(
            &self,
            _actor_user_id: Uuid,
            target_pet: &AiPetDisplaySnapshot,
            _episode_id: Option<Uuid>,
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
    impl PetHealthQuickFactProvider for EmptyPetContextProvider {
        async fn load_recent_health_quick_fact_package(
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

    #[async_trait]
    impl PetAbnormalEpisodeFactProvider for CapturingAbnormalEpisodeProvider {
        async fn load_abnormal_episode_fact_package(
            &self,
            actor_user_id: Uuid,
            target_pet: &AiPetDisplaySnapshot,
            episode_id: Option<Uuid>,
        ) -> AiResult<AiFactPackage> {
            let mut captured = self.captured.lock().expect("capture abnormal call");
            captured.actor_user_id = Some(actor_user_id);
            captured.target_pet_id = Some(target_pet.pet_id);
            captured.episode_id = episode_id;
            Ok(fact_package_for(target_pet))
        }
    }

    #[async_trait]
    impl PetObservationWriteProvider for EmptyObservationWriteProvider {
        async fn prepare_observation_write(
            &self,
            _actor_user_id: Uuid,
            _pet_id: Uuid,
            _note: String,
        ) -> PetResult<PreparedObservationWrite> {
            let confirmation_task_id = Uuid::new_v4();
            Ok(PreparedObservationWrite {
                confirmation: AiToolConfirmationRequirement {
                    confirmation_task_id: confirmation_task_id.to_string(),
                    tool_name: "commit_pet_observation_write".to_owned(),
                    question_text: "确认写入观察记录？".to_owned(),
                    args: json!({ "confirmation_task_id": confirmation_task_id }),
                },
            })
        }

        async fn commit_observation_write(
            &self,
            _actor_user_id: Uuid,
            _pet_id: Uuid,
            confirmation_task_id: Uuid,
        ) -> PetResult<CommittedObservationWrite> {
            Ok(CommittedObservationWrite {
                confirmation_task_id,
                event_id: Uuid::new_v4(),
            })
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

    #[test]
    fn runtime_identity_tool_description_tells_model_profile_card_is_rendered_by_client() {
        let description = RuntimePetContextToolKind::Identity.description();

        assert!(description.contains("前端会基于工具结果渲染宠物资料卡"));
        assert!(description.contains("最终正文应避免重复列出"));
        assert!(description.contains("品种、性别、生日、年龄"));
    }

    #[test]
    fn runtime_health_tool_schema_declares_quick_fact_facts() {
        let schema = RuntimePetContextToolKind::RecentHealthFacts.fact_schema();

        assert_eq!(schema.fact_keys, vec!["health.recent_quick_fact"]);
        assert!(
            schema
                .natural_language_summary
                .contains("便便是否正常、精神状态是否正常、食欲是否正常")
        );
    }

    #[test]
    fn runtime_abnormal_episode_tool_schema_declares_only_episode_facts() {
        let schema = RuntimePetContextToolKind::AbnormalEpisodeFacts.fact_schema();

        assert_eq!(
            schema.fact_keys,
            vec![
                "health.abnormal_episode.status",
                "health.abnormal_episode.initial_event",
                "health.abnormal_episode.timeline",
                "health.abnormal_episode.attachments",
                "health.abnormal_episode.followup_gap",
            ]
        );
        assert!(
            schema
                .natural_language_summary
                .contains("异常 episode 的状态、父异常记录、追加观察、恢复和附件存在性")
        );
        assert!(
            !schema
                .natural_language_summary
                .contains("便便是否正常、精神状态是否正常、食欲是否正常"),
            "abnormal episode tool must not duplicate quick fact responsibilities"
        );
    }

    #[test]
    fn runtime_registry_registers_abnormal_episode_tool_as_readonly_private_context() {
        let state = runtime_state();
        let target_pet = test_pet();
        let registry =
            super::super::build_runtime_tool_registry(&state, Uuid::new_v4(), &target_pet);

        let tool = registry
            .list_definitions()
            .into_iter()
            .find(|tool| tool.name == "load_pet_abnormal_episode_facts")
            .expect("abnormal episode facts tool should be registered");

        assert_eq!(tool.toolset, Toolset::PrivatePetContext);
        assert!(tool.read_only);
        assert!(!tool.requires_confirmation);
        assert_eq!(tool.scope, "pet.abnormal_episode.read");
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

    #[tokio::test]
    async fn runtime_abnormal_episode_tool_uses_authorized_target_and_optional_episode_id() {
        let captured = Arc::new(Mutex::new(CapturedAbnormalEpisodeCall::default()));
        let actor_user_id = Uuid::new_v4();
        let episode_id = Uuid::new_v4();
        let tool = runtime_abnormal_episode_tool(captured.clone());

        let result = tool
            .execute(
                &AiToolContext {
                    actor_user_id,
                    authorized_pet_id: tool.target_pet.pet_id,
                    gateway_context:
                        maohuoban_ai_application::ai::tools::ToolGatewayExecutionContext::default(),
                    gateway_observer: None,
                },
                &json!({ "episode_id": episode_id }),
            )
            .await;

        assert!(result.is_success());
        let captured = captured.lock().expect("captured abnormal call");
        assert_eq!(captured.actor_user_id, Some(actor_user_id));
        assert_eq!(captured.target_pet_id, Some(tool.target_pet.pet_id));
        assert_eq!(captured.episode_id, Some(episode_id));
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

    #[tokio::test]
    async fn runtime_prepare_observation_write_tool_returns_confirmation() {
        let state = runtime_state();
        let target_pet = test_pet();
        let registry =
            super::super::build_runtime_tool_registry(&state, Uuid::new_v4(), &target_pet);

        let result = registry
            .call(
                "prepare_pet_observation_write",
                &AiToolContext {
                    actor_user_id: Uuid::new_v4(),
                    authorized_pet_id: target_pet.pet_id,
                    gateway_context:
                        maohuoban_ai_application::ai::tools::ToolGatewayExecutionContext::default(),
                    gateway_observer: None,
                },
                &json!({ "note": "今天拉稀" }),
            )
            .await;

        assert!(result.confirmation().is_some());
    }

    #[tokio::test]
    async fn runtime_commit_observation_write_tool_requires_matching_confirmation_task() {
        let state = runtime_state();
        let target_pet = test_pet();
        let registry =
            super::super::build_runtime_tool_registry(&state, Uuid::new_v4(), &target_pet);
        let confirmation_task_id = Uuid::new_v4();

        let result = registry
            .call(
                "commit_pet_observation_write",
                &AiToolContext {
                    actor_user_id: Uuid::new_v4(),
                    authorized_pet_id: target_pet.pet_id,
                    gateway_context:
                        maohuoban_ai_application::ai::tools::ToolGatewayExecutionContext {
                            session_id: None,
                            turn_id: None,
                            message_id: None,
                            confirmation_task_id: Some(confirmation_task_id.to_string()),
                        },
                    gateway_observer: None,
                },
                &json!({ "confirmation_task_id": confirmation_task_id }),
            )
            .await;

        assert!(
            result.is_success(),
            "commit tool should succeed after confirmation, got denied={:?} failed={:?}",
            result.denied_reason(),
            result.failed_reason()
        );
    }

    fn runtime_identity_tool() -> RuntimePetContextTool {
        let provider = Arc::new(EmptyPetContextProvider);
        RuntimePetContextTool {
            kind: RuntimePetContextToolKind::Identity,
            providers: AiPetContextProviders::new(
                provider.clone(),
                provider.clone(),
                provider.clone(),
                provider.clone(),
                provider.clone(),
                provider,
                Arc::new(EmptyObservationWriteProvider),
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

    fn runtime_abnormal_episode_tool(
        captured: Arc<Mutex<CapturedAbnormalEpisodeCall>>,
    ) -> RuntimePetContextTool {
        let provider = Arc::new(EmptyPetContextProvider);
        RuntimePetContextTool {
            kind: RuntimePetContextToolKind::AbnormalEpisodeFacts,
            providers: AiPetContextProviders::new(
                provider.clone(),
                Arc::new(CapturingAbnormalEpisodeProvider::new(captured)),
                provider.clone(),
                provider.clone(),
                provider.clone(),
                provider,
                Arc::new(EmptyObservationWriteProvider),
            ),
            session_repository: Arc::new(EmptySessionRepository),
            session_id: Uuid::new_v4(),
            target_pet: test_pet(),
        }
    }

    fn test_pet() -> AiPetDisplaySnapshot {
        AiPetDisplaySnapshot {
            pet_id: Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("pet id"),
            pet_name: "饭团".to_owned(),
            pet_avatar_url: None,
            pet_species: "cat".to_owned(),
            profile_number: "MHB001".to_owned(),
        }
    }

    fn runtime_state() -> AiHttpState {
        let provider = Arc::new(EmptyPetContextProvider);
        AiHttpState {
            llm_provider: Arc::new(maohuoban_ai_application::ai::ports::DisabledLlmProvider),
            runtime_engine_mode:
                maohuoban_ai_application::ai::runtime::AgentRuntimeEngineMode::SelfHosted,
            session_repository: Arc::new(EmptySessionRepository),
            session_turn_repository: Arc::new(EmptySessionTurnRepository),
            chat_turn_transaction: Arc::new(EmptyChatTurnTransaction),
            session_summary_repository: Arc::new(EmptySessionSummaryRepository),
            memory_repository: Arc::new(maohuoban_ai_application::ai::ports::NoopMemoryRepository),
            pet_resolver: Arc::new(
                maohuoban_ai_application::ai::pet_resolver::AiPetResolver::new(
                    maohuoban_ai_application::ai::ports::EmptyPetCatalog,
                ),
            ),
            pet_context_providers: AiPetContextProviders::new(
                provider.clone(),
                provider.clone(),
                provider.clone(),
                provider.clone(),
                provider.clone(),
                provider,
                Arc::new(EmptyObservationWriteProvider),
            ),
            observation_write_provider: Arc::new(EmptyObservationWriteProvider),
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
