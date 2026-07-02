//! non_stream 非流式 handler 测试

#[cfg(test)]
#[allow(clippy::module_inception)]
mod tests {
    use std::sync::Arc;

    use async_trait::async_trait;
    use maohuoban_ai_application::ai::finalizer::{
        FinalizerAsyncJob, FinalizerSessionHeaderUpdate, FinalizerStore,
    };
    use maohuoban_ai_application::ai::stream::AiCompleteResult;
    use maohuoban_ai_domain::ai::{
        AgentEvent, AgentToolStatus, AgentTurnId, AgentTurnStatus, AiAnswerVerification,
        AiCitation, AiContentBlock, AiError, AiFactEntry, AiFactPackage, AiFactStrength, AiMessage,
        AiPetCandidate, AiProposedAction, AiResult, AiSessionTurnStatus, LlmFinishReason, LlmUsage,
        ModelLabel,
    };
    use uuid::Uuid;

    use super::super::super::visible_output_plan::VisibleOutputPlan;
    use super::super::complete::complete_from_runtime_events;
    use super::super::persistence::finalize_complete_turn;

    #[test]
    fn non_stream_completion_rejects_unrepaired_invalid_final_answer() {
        let turn_id = AgentTurnId::new();
        let message_id = Uuid::new_v4();
        let events = vec![
            AgentEvent::ModelCallFinished {
                turn_id,
                finish_reason: LlmFinishReason::Stop,
                usage: LlmUsage::default(),
                provider: "test".to_owned(),
                model: ModelLabel::Primary.as_str().to_owned(),
                engine_mode: "self_hosted".to_owned(),
            },
            AgentEvent::TurnFinished {
                turn_id,
                message_id,
                final_text: "目前档案里没有生日记录，所以还不知道梅录多大。".to_owned(),
                status: AgentTurnStatus::Completed,
                termination_reason: None,
            },
        ];

        let Err(err) = complete_from_runtime_events(events, None, true, VisibleOutputPlan::empty())
        else {
            panic!("non-stream aggregation must reject unrepaired invalid answer");
        };

        assert_eq!(err.stable_code(), "ai.infrastructure");
    }

    #[test]
    fn non_stream_completion_rejects_failed_runtime_turn() {
        let turn_id = AgentTurnId::new();
        let message_id = Uuid::new_v4();
        let events = vec![AgentEvent::TurnFinished {
            turn_id,
            message_id,
            final_text: String::new(),
            status: AgentTurnStatus::Failed,
            termination_reason: None,
        }];

        let Err(err) = complete_from_runtime_events(events, None, true, VisibleOutputPlan::empty())
        else {
            panic!("non-stream aggregation must reject failed runtime turn");
        };

        assert_eq!(err.stable_code(), "ai.infrastructure");
    }

    #[test]
    fn non_stream_completion_projects_pet_profile_blocks_from_identity_tool_package() {
        let turn_id = AgentTurnId::new();
        let message_id = Uuid::new_v4();
        let events = vec![
            AgentEvent::ToolStarted {
                turn_id,
                tool_call_id: "identity_call_1".to_owned(),
                tool_name: "load_pet_identity_context".to_owned(),
            },
            AgentEvent::ToolFinished {
                turn_id,
                tool_call_id: "identity_call_1".to_owned(),
                status: AgentToolStatus::Succeeded,
                citation_count: 1,
                fact_package: Some(Box::new(identity_fact_package("梅录"))),
            },
            AgentEvent::ModelCallFinished {
                turn_id,
                finish_reason: LlmFinishReason::Stop,
                usage: LlmUsage::default(),
                provider: "test".to_owned(),
                model: ModelLabel::Primary.as_str().to_owned(),
                engine_mode: "self_hosted".to_owned(),
            },
            AgentEvent::TurnFinished {
                turn_id,
                message_id,
                final_text: "这是梅录的宠物信息。".to_owned(),
                status: AgentTurnStatus::Completed,
                termination_reason: None,
            },
        ];

        let complete =
            complete_from_runtime_events(events, None, true, VisibleOutputPlan::pet_profile_card())
                .expect("complete result");

        assert!(
            matches!(
                complete.content_blocks.as_slice(),
                [
                    AiContentBlock::SectionHeading { text, .. },
                    AiContentBlock::PetProfileCard { pet, .. },
                    AiContentBlock::Paragraph { text: paragraph_text, .. },
                ] if text == "这是梅录的宠物信息"
                    && pet.name == "梅录"
                    && paragraph_text == "这是梅录的宠物信息。"
            ),
            "non-stream completion should project typed pet profile blocks: {:?}",
            complete.content_blocks
        );
    }

    #[tokio::test]
    async fn non_stream_finalizer_failure_is_returned_to_handler() {
        let complete = AiCompleteResult {
            final_text: "毛球今天可以继续观察精神和食欲。".to_owned(),
            content_blocks: Vec::new(),
            usage: LlmUsage::default(),
            finish_reason: LlmFinishReason::Stop,
            provider: "test-provider".to_owned(),
            model: ModelLabel::Primary.as_str().to_owned(),
            citations: Vec::new(),
            verification: AiAnswerVerification::passed(),
        };

        let err = finalize_complete_turn(
            Arc::new(FailingFinalizerStore),
            Uuid::new_v4(),
            Uuid::new_v4(),
            Uuid::new_v4(),
            Uuid::new_v4(),
            &complete,
        )
        .await
        .expect_err("non-stream finalizer failure must be surfaced");

        assert_eq!(err.stable_code(), "ai.infrastructure");
    }

    struct FailingFinalizerStore;

    #[async_trait]
    impl FinalizerStore for FailingFinalizerStore {
        async fn write_assistant_message(&self, _message: &AiMessage) -> AiResult<()> {
            Err(AiError::Infrastructure(
                "forced assistant write failure".to_owned(),
            ))
        }

        async fn write_citations(
            &self,
            _message_id: Uuid,
            _session_id: Uuid,
            _citations: &[AiCitation],
        ) -> AiResult<()> {
            Ok(())
        }

        async fn write_proposed_actions(
            &self,
            _session_id: Uuid,
            _actions: &[AiProposedAction],
        ) -> AiResult<()> {
            Ok(())
        }

        async fn update_turn_status(
            &self,
            _turn_id: Uuid,
            _status: AiSessionTurnStatus,
            _assistant_message_id: Option<Uuid>,
            _finish_reason: Option<&str>,
            _error_code: Option<&str>,
            _retryable: Option<bool>,
        ) -> AiResult<()> {
            Ok(())
        }

        async fn update_session_header(
            &self,
            _update: &FinalizerSessionHeaderUpdate,
        ) -> AiResult<()> {
            Ok(())
        }

        async fn trigger_async_job(&self, _job: &FinalizerAsyncJob) -> AiResult<()> {
            Ok(())
        }
    }

    fn identity_fact_package(name: &str) -> AiFactPackage {
        let mut package = AiFactPackage::empty();
        let candidate = AiPetCandidate {
            pet_id: Uuid::new_v4(),
            name: name.to_owned(),
            avatar_url: Some("/uploads/pets/meilu.png".to_owned()),
            species: "cat".to_owned(),
            profile_number: "P001".to_owned(),
        };
        package.target_pet = Some((&candidate).into());
        package.facts = vec![
            strong_fact("pet_identity.name", name),
            strong_fact("pet_identity.species", "猫"),
            strong_fact("pet_identity.sex", "母猫"),
            strong_fact("pet_identity.breed", "英短"),
            strong_fact("pet_identity.birthday", "2024-06-17"),
            strong_fact("pet_identity.arrival_date", "2025-06-17"),
        ];
        package.computed = vec![strong_fact(
            "pet_identity.age_display",
            "当前年龄约 2岁15天",
        )];
        package.fact_strength = AiFactStrength::Strong;
        package
    }

    fn strong_fact(key: &str, value: &str) -> AiFactEntry {
        AiFactEntry {
            key: key.to_owned(),
            value: value.to_owned(),
            strength: AiFactStrength::Strong,
            citation_id: None,
        }
    }
}
