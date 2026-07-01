use axum::response::{
    IntoResponse, Response,
    sse::{Event, KeepAlive, Sse},
};
use futures_util::stream;
use maohuoban_ai_application::ai::finalizer::{
    FinalizationReceipt, FinalizerStore, TurnFinalizer, TurnTerminalOutput,
};
use maohuoban_ai_domain::ai::{
    AiAnswerVerification, AiGateDecision, AiResult, AiSessionTurnStatus, AiStreamEvent,
    LlmFinishReason, LlmUsage,
};
use uuid::Uuid;

use super::super::super::diagnostics::{
    record_chat_finalizer_completed, record_chat_stream_event_emitted,
};
use crate::ai::response::ai_error_response;

/// gated_stream_response 构建不进入主 Agent 的安全 SSE 响应
/// 核心职责：
/// - 对 off-topic、app support 和风险请求跳过 Provider
/// - 通过 Finalizer 持久化边界消息和 turn 终态
/// - 输出稳定 message_started/message_completed 事件
pub(crate) async fn gated_stream_response(
    finalizer_store: std::sync::Arc<dyn FinalizerStore>,
    session_id: Uuid,
    actor_user_id: Uuid,
    turn_id: Uuid,
    message_id: Uuid,
    title: String,
    gate_decision: &AiGateDecision,
) -> Response {
    let final_text = gated_message_text(gate_decision).to_owned();
    let receipt = finalize_boundary_turn(
        finalizer_store,
        session_id,
        actor_user_id,
        turn_id,
        message_id,
        final_text.clone(),
        "gate_skipped_main_agent",
    )
    .await;
    let receipt = match receipt {
        Ok(receipt) => receipt,
        Err(error) => return ai_error_response(&error),
    };
    record_chat_finalizer_completed(session_id, turn_id, Some(message_id), &receipt);

    let events = vec![
        AiStreamEvent::MessageStarted {
            chat_session_id: session_id,
            message_id,
            target_pet: None,
            title,
        },
        AiStreamEvent::MessageCompleted {
            message_id,
            final_text,
            usage: LlmUsage::default(),
            finish_reason: LlmFinishReason::Stop,
            citations: vec![],
            verification: AiAnswerVerification::passed(),
        },
    ];
    let sse_stream = stream::iter(events.into_iter().map(move |event| {
        record_chat_stream_event_emitted(session_id, &event);
        let json = serde_json::to_string(&event).unwrap_or_else(|_| "{}".to_owned());
        Ok::<Event, std::convert::Infallible>(Event::default().event(event.event_name()).data(json))
    }));

    Sse::new(sse_stream)
        .keep_alive(KeepAlive::default())
        .into_response()
}

/// gated_message_text 返回 gate 分支安全提示
/// 核心职责：
/// - 委托 AiGateDecision::gate_message() 提供边界文案
/// - 不直接匹配 intent 枚举，保持展示层与领域解耦
pub(crate) fn gated_message_text(gate_decision: &AiGateDecision) -> &'static str {
    gate_decision.gate_message()
}

/// finalize_boundary_turn 在返回边界 SSE 前同步持久化消息和 turn 终态
/// 核心职责：
/// - 在 gate / pet_resolution 分支统一收口 Finalizer 事务
/// - 将关键写入错误返回给调用方，保持 fail-closed
pub(crate) async fn finalize_boundary_turn(
    finalizer_store: std::sync::Arc<dyn FinalizerStore>,
    session_id: Uuid,
    actor_user_id: Uuid,
    turn_id: Uuid,
    message_id: Uuid,
    final_text: String,
    _finish_reason: &str,
) -> AiResult<FinalizationReceipt> {
    TurnFinalizer::new(finalizer_store)
        .finalize(TurnTerminalOutput {
            turn_id,
            session_id,
            actor_user_id,
            assistant_message_id: message_id,
            status: AiSessionTurnStatus::Completed,
            final_text: Some(final_text),
            safe_failure_text: None,
            failure_code: None,
            retryable: None,
            provider: None,
            model: None,
            finish_reason: Some(LlmFinishReason::Stop),
            usage: LlmUsage::default(),
            verification: Some(AiAnswerVerification::passed()),
            citations: Vec::new(),
            proposed_actions: Vec::new(),
            async_jobs: Vec::new(),
        })
        .await
}

#[cfg(test)]
mod tests {
    use std::sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    };

    use async_trait::async_trait;
    use maohuoban_ai_application::ai::finalizer::{
        FinalizerAsyncJob, FinalizerSessionHeaderUpdate,
    };
    use maohuoban_ai_domain::ai::{
        AiCitation, AiError, AiMessage, AiProposedAction, AiResult, AiSessionTurnStatus,
    };

    use super::*;

    #[tokio::test]
    async fn gated_stream_response_waits_for_finalizer_before_returning_response() {
        let store = Arc::new(RecordingFinalizerStore::new());

        let _response = gated_stream_response(
            store.clone(),
            Uuid::new_v4(),
            Uuid::new_v4(),
            Uuid::new_v4(),
            Uuid::new_v4(),
            "新对话".to_owned(),
            &AiGateDecision {
                intent: maohuoban_ai_domain::ai::AiIntent::CostAbuse,
                context_loaded: false,
                risk_signal: Some("cost_abuse".to_owned()),
                reason: "测试成本滥用拦截".to_owned(),
            },
        )
        .await;

        assert_eq!(
            store.sync_writes.load(Ordering::SeqCst),
            5,
            "gate boundary response must complete finalizer synchronous writes before returning"
        );
    }

    struct RecordingFinalizerStore {
        sync_writes: AtomicUsize,
    }

    impl RecordingFinalizerStore {
        fn new() -> Self {
            Self {
                sync_writes: AtomicUsize::new(0),
            }
        }
    }

    #[async_trait]
    impl FinalizerStore for RecordingFinalizerStore {
        async fn write_assistant_message(&self, _message: &AiMessage) -> AiResult<()> {
            self.sync_writes.fetch_add(1, Ordering::SeqCst);
            Ok(())
        }

        async fn write_citations(
            &self,
            _message_id: Uuid,
            _session_id: Uuid,
            _citations: &[AiCitation],
        ) -> AiResult<()> {
            self.sync_writes.fetch_add(1, Ordering::SeqCst);
            Ok(())
        }

        async fn write_proposed_actions(
            &self,
            _session_id: Uuid,
            _actions: &[AiProposedAction],
        ) -> AiResult<()> {
            self.sync_writes.fetch_add(1, Ordering::SeqCst);
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
            self.sync_writes.fetch_add(1, Ordering::SeqCst);
            Ok(())
        }

        async fn update_session_header(
            &self,
            _update: &FinalizerSessionHeaderUpdate,
        ) -> AiResult<()> {
            self.sync_writes.fetch_add(1, Ordering::SeqCst);
            Ok(())
        }

        async fn trigger_async_job(&self, _job: &FinalizerAsyncJob) -> AiResult<()> {
            Err(AiError::Infrastructure(
                "async jobs are not expected in gate boundary test".to_owned(),
            ))
        }
    }
}
