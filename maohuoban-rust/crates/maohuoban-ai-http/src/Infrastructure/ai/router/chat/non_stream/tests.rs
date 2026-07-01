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
        AgentEvent, AgentTurnId, AgentTurnStatus, AiAnswerVerification, AiCitation, AiError,
        AiMessage, AiProposedAction, AiResult, AiSessionTurnStatus, LlmFinishReason, LlmUsage,
        ModelLabel,
    };
    use uuid::Uuid;

    use super::super::complete::complete_from_runtime_events;
    use super::super::persistence::finalize_complete_turn;

    #[test]
    fn non_stream_completion_blocks_missing_identity_claim_without_tool_success() {
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
            },
        ];

        let complete = complete_from_runtime_events(events, None, true).expect("complete result");

        assert_eq!(complete.finish_reason, LlmFinishReason::ContentFilter);
        assert!(complete.verification.is_blocked());
        assert!(!complete.final_text.contains("没有生日记录"));
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
}
