//! non_stream 非流式 handler 测试

#[cfg(test)]
mod tests {
    use maohuoban_ai_domain::ai::{
        AgentEvent, AgentTurnId, AgentTurnStatus, LlmFinishReason, LlmUsage, ModelLabel,
    };
    use uuid::Uuid;

    use super::super::complete::complete_from_runtime_events;

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
}
