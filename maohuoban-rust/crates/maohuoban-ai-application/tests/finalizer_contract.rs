// finalizer_contract Finalizer 合同测试
// 核心职责：
// - 固定 turn 终态后的同步写入顺序
// - 固定 completed / failed / interrupted / requires_confirmation 分支
// - 固定后处理 fail-open 与关键写入 fail-closed 边界

use std::sync::{Arc, Mutex};

use async_trait::async_trait;
use maohuoban_ai_application::ai::finalizer::{
    FinalizationReceipt, FinalizerAsyncJob, FinalizerAsyncJobKind, FinalizerSessionHeaderUpdate,
    FinalizerStore, FinalizerSynchronousWrite, TurnFinalizer, TurnTerminalOutput,
};
use maohuoban_ai_domain::ai::{
    AiAnswerVerification, AiCitation, AiCitationSourceKind, AiError, AiMessage, AiMessageStatus,
    AiProposedAction, AiProposedActionKind, AiProposedActionRisk, AiResult, AiSessionTurnStatus,
    LlmFinishReason, LlmUsage,
};
use uuid::Uuid;

fn session_id() -> Uuid {
    Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("session id")
}

fn actor_user_id() -> Uuid {
    Uuid::parse_str("22222222-2222-2222-2222-222222222222").expect("actor user id")
}

fn turn_id() -> Uuid {
    Uuid::parse_str("33333333-3333-3333-3333-333333333333").expect("turn id")
}

fn assistant_message_id() -> Uuid {
    Uuid::parse_str("44444444-4444-4444-4444-444444444444").expect("assistant message id")
}

fn target_pet_id() -> Uuid {
    Uuid::parse_str("55555555-5555-5555-5555-555555555555").expect("target pet id")
}

fn citation_id() -> Uuid {
    Uuid::parse_str("66666666-6666-6666-6666-666666666666").expect("citation id")
}

fn action_id() -> Uuid {
    Uuid::parse_str("77777777-7777-7777-7777-777777777777").expect("action id")
}

fn citation() -> AiCitation {
    AiCitation {
        source_kind: AiCitationSourceKind::PetEvent,
        source_id: citation_id(),
        label: "豆包体重记录".to_owned(),
    }
}

fn proposed_action() -> AiProposedAction {
    AiProposedAction {
        id: action_id(),
        action_kind: AiProposedActionKind::DietChangeConfirmation,
        target_pet_id: target_pet_id(),
        payload: serde_json::json!({ "food": "低脂主粮" }),
        confirm_text: "确认豆包已切换到低脂主粮".to_owned(),
        risk_level: AiProposedActionRisk::Medium,
        source_message_id: Some(assistant_message_id()),
        confirmation_task_id: Some(
            Uuid::parse_str("88888888-8888-8888-8888-888888888888").expect("confirmation id"),
        ),
    }
}

fn completed_output() -> TurnTerminalOutput {
    TurnTerminalOutput {
        turn_id: turn_id(),
        session_id: session_id(),
        actor_user_id: actor_user_id(),
        assistant_message_id: assistant_message_id(),
        status: AiSessionTurnStatus::Completed,
        final_text: Some("豆包最近饮食记录显示已换粮。".to_owned()),
        safe_failure_text: None,
        failure_code: None,
        retryable: None,
        provider: Some("deepseek".to_owned()),
        model: Some("deepseek-v4-flash".to_owned()),
        finish_reason: Some(LlmFinishReason::Stop),
        usage: LlmUsage {
            input_tokens: 11,
            output_tokens: 7,
            total_tokens: 18,
        },
        verification: Some(AiAnswerVerification::passed()),
        citations: vec![citation()],
        proposed_actions: vec![proposed_action()],
        async_jobs: vec![
            FinalizerAsyncJob::new(FinalizerAsyncJobKind::SessionSummary),
            FinalizerAsyncJob::new(FinalizerAsyncJobKind::MemoryCandidate),
        ],
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
enum StoreCall {
    AssistantMessage {
        content: String,
        status: AiMessageStatus,
    },
    Citations(usize),
    ProposedActions(usize),
    TurnStatus {
        status: AiSessionTurnStatus,
        error_code: Option<String>,
        retryable: Option<bool>,
    },
    SessionHeader {
        session_id: Uuid,
        last_turn_id: Uuid,
        last_message_id: Option<Uuid>,
    },
    AsyncJob(FinalizerAsyncJobKind),
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum FailurePoint {
    AssistantMessage,
    ProposedActions,
    AsyncJob,
}

/// `RecordingFinalizerStore` 记录型 Finalizer 存储
/// 核心职责：
/// - 为合同测试记录同步写入和异步触发顺序
/// - 按指定失败点模拟 fail-open / fail-closed 行为
struct RecordingFinalizerStore {
    calls: Mutex<Vec<StoreCall>>,
    failure_point: Option<FailurePoint>,
}

impl RecordingFinalizerStore {
    fn new() -> Self {
        Self {
            calls: Mutex::new(Vec::new()),
            failure_point: None,
        }
    }

    fn failing_at(failure_point: FailurePoint) -> Self {
        Self {
            calls: Mutex::new(Vec::new()),
            failure_point: Some(failure_point),
        }
    }

    fn calls(&self) -> Vec<StoreCall> {
        self.calls.lock().expect("lock").clone()
    }
}

#[async_trait]
impl FinalizerStore for RecordingFinalizerStore {
    async fn write_assistant_message(&self, message: &AiMessage) -> AiResult<()> {
        self.calls
            .lock()
            .expect("lock")
            .push(StoreCall::AssistantMessage {
                content: message.content.clone(),
                status: message.status,
            });
        if self.failure_point == Some(FailurePoint::AssistantMessage) {
            return Err(AiError::Infrastructure("assistant write failed".to_owned()));
        }
        Ok(())
    }

    async fn write_citations(
        &self,
        _message_id: Uuid,
        _session_id: Uuid,
        citations: &[AiCitation],
    ) -> AiResult<()> {
        self.calls
            .lock()
            .expect("lock")
            .push(StoreCall::Citations(citations.len()));
        Ok(())
    }

    async fn write_proposed_actions(
        &self,
        _session_id: Uuid,
        actions: &[AiProposedAction],
    ) -> AiResult<()> {
        self.calls
            .lock()
            .expect("lock")
            .push(StoreCall::ProposedActions(actions.len()));
        if self.failure_point == Some(FailurePoint::ProposedActions) {
            return Err(AiError::Infrastructure("actions write failed".to_owned()));
        }
        Ok(())
    }

    async fn update_turn_status(
        &self,
        _turn_id: Uuid,
        status: AiSessionTurnStatus,
        _assistant_message_id: Option<Uuid>,
        _finish_reason: Option<&str>,
        error_code: Option<&str>,
        retryable: Option<bool>,
    ) -> AiResult<()> {
        self.calls
            .lock()
            .expect("lock")
            .push(StoreCall::TurnStatus {
                status,
                error_code: error_code.map(ToOwned::to_owned),
                retryable,
            });
        Ok(())
    }

    async fn update_session_header(&self, update: &FinalizerSessionHeaderUpdate) -> AiResult<()> {
        self.calls
            .lock()
            .expect("lock")
            .push(StoreCall::SessionHeader {
                session_id: update.session_id,
                last_turn_id: update.last_turn_id,
                last_message_id: update.last_message_id,
            });
        Ok(())
    }

    async fn trigger_async_job(&self, job: &FinalizerAsyncJob) -> AiResult<()> {
        self.calls
            .lock()
            .expect("lock")
            .push(StoreCall::AsyncJob(job.kind));
        if self.failure_point == Some(FailurePoint::AsyncJob) {
            return Err(AiError::Infrastructure("async job failed".to_owned()));
        }
        Ok(())
    }
}

#[tokio::test]
async fn completed_finalizer_writes_snapshot_then_citations_actions_turn_and_session_header() {
    let store = Arc::new(RecordingFinalizerStore::new());
    let receipt = TurnFinalizer::new(store.clone())
        .finalize(completed_output())
        .await
        .expect("finalize completed");

    assert_eq!(
        store.calls(),
        vec![
            StoreCall::AssistantMessage {
                content: "豆包最近饮食记录显示已换粮。".to_owned(),
                status: AiMessageStatus::Completed,
            },
            StoreCall::Citations(1),
            StoreCall::ProposedActions(1),
            StoreCall::TurnStatus {
                status: AiSessionTurnStatus::Completed,
                error_code: None,
                retryable: None,
            },
            StoreCall::SessionHeader {
                session_id: session_id(),
                last_turn_id: turn_id(),
                last_message_id: Some(assistant_message_id()),
            },
            StoreCall::AsyncJob(FinalizerAsyncJobKind::SessionSummary),
            StoreCall::AsyncJob(FinalizerAsyncJobKind::MemoryCandidate),
        ]
    );
    assert_receipt(
        &receipt,
        AiSessionTurnStatus::Completed,
        &[
            FinalizerSynchronousWrite::AssistantMessage,
            FinalizerSynchronousWrite::Citations,
            FinalizerSynchronousWrite::ProposedActions,
            FinalizerSynchronousWrite::TurnStatus,
            FinalizerSynchronousWrite::SessionHeader,
        ],
        &[
            FinalizerAsyncJobKind::SessionSummary,
            FinalizerAsyncJobKind::MemoryCandidate,
        ],
    );
}

#[tokio::test]
async fn failed_finalizer_writes_safe_failure_text_and_marks_turn_failed() {
    let store = Arc::new(RecordingFinalizerStore::new());
    let mut output = completed_output();
    output.status = AiSessionTurnStatus::Failed;
    output.final_text = None;
    output.safe_failure_text = Some("暂时无法获取回答，请稍后重试。".to_owned());
    output.failure_code = Some("ai.provider.timeout".to_owned());
    output.retryable = Some(true);
    output.citations.clear();
    output.proposed_actions.clear();
    output.async_jobs.clear();

    TurnFinalizer::new(store.clone())
        .finalize(output)
        .await
        .expect("finalize failed status");

    assert_eq!(
        store.calls(),
        vec![
            StoreCall::AssistantMessage {
                content: "暂时无法获取回答，请稍后重试。".to_owned(),
                status: AiMessageStatus::Failed,
            },
            StoreCall::Citations(0),
            StoreCall::ProposedActions(0),
            StoreCall::TurnStatus {
                status: AiSessionTurnStatus::Failed,
                error_code: Some("ai.provider.timeout".to_owned()),
                retryable: Some(true),
            },
            StoreCall::SessionHeader {
                session_id: session_id(),
                last_turn_id: turn_id(),
                last_message_id: Some(assistant_message_id()),
            },
        ]
    );
}

#[tokio::test]
async fn requires_confirmation_writes_actions_and_turn_status_without_fake_completed_message() {
    let store = Arc::new(RecordingFinalizerStore::new());
    let mut output = completed_output();
    output.status = AiSessionTurnStatus::RequiresConfirmation;
    output.final_text = None;
    output.citations.clear();
    output.async_jobs.clear();

    TurnFinalizer::new(store.clone())
        .finalize(output)
        .await
        .expect("finalize confirmation status");

    assert_eq!(
        store.calls(),
        vec![
            StoreCall::ProposedActions(1),
            StoreCall::TurnStatus {
                status: AiSessionTurnStatus::RequiresConfirmation,
                error_code: None,
                retryable: None,
            },
            StoreCall::SessionHeader {
                session_id: session_id(),
                last_turn_id: turn_id(),
                last_message_id: None,
            },
        ]
    );
}

#[tokio::test]
async fn interrupted_finalizer_marks_interrupted_without_completed_status() {
    let store = Arc::new(RecordingFinalizerStore::new());
    let mut output = completed_output();
    output.status = AiSessionTurnStatus::Interrupted;
    output.final_text = Some("已停止本次回答。".to_owned());
    output.citations.clear();
    output.proposed_actions.clear();
    output.async_jobs.clear();

    TurnFinalizer::new(store.clone())
        .finalize(output)
        .await
        .expect("finalize interrupted status");

    assert!(
        store.calls().contains(&StoreCall::TurnStatus {
            status: AiSessionTurnStatus::Interrupted,
            error_code: None,
            retryable: None,
        }),
        "interrupted turn status must be explicit"
    );
    assert!(
        !store.calls().contains(&StoreCall::TurnStatus {
            status: AiSessionTurnStatus::Completed,
            error_code: None,
            retryable: None,
        }),
        "interrupted must not be persisted as completed"
    );
}

#[tokio::test]
async fn async_post_processing_failure_is_fail_open_and_recorded_in_receipt() {
    let store = Arc::new(RecordingFinalizerStore::failing_at(FailurePoint::AsyncJob));
    let receipt = TurnFinalizer::new(store.clone())
        .finalize(completed_output())
        .await
        .expect("async failure is fail-open");

    assert_eq!(receipt.terminal_status, AiSessionTurnStatus::Completed);
    assert_eq!(receipt.async_failures.len(), 2);
    assert_eq!(
        receipt.async_triggers,
        vec![
            FinalizerAsyncJobKind::SessionSummary,
            FinalizerAsyncJobKind::MemoryCandidate,
        ]
    );
}

#[tokio::test]
async fn critical_synchronous_write_failure_is_fail_closed() {
    let store = Arc::new(RecordingFinalizerStore::failing_at(
        FailurePoint::AssistantMessage,
    ));
    let err = TurnFinalizer::new(store.clone())
        .finalize(completed_output())
        .await
        .expect_err("assistant message write is fail-closed");

    assert_eq!(err.stable_code(), "ai.infrastructure");
    assert_eq!(
        store.calls(),
        vec![StoreCall::AssistantMessage {
            content: "豆包最近饮食记录显示已换粮。".to_owned(),
            status: AiMessageStatus::Completed,
        }]
    );
}

#[tokio::test]
async fn confirmation_action_write_failure_is_fail_closed() {
    let store = Arc::new(RecordingFinalizerStore::failing_at(
        FailurePoint::ProposedActions,
    ));
    let err = TurnFinalizer::new(store.clone())
        .finalize(completed_output())
        .await
        .expect_err("proposed action write is fail-closed");

    assert_eq!(err.stable_code(), "ai.infrastructure");
    assert_eq!(
        store.calls(),
        vec![
            StoreCall::AssistantMessage {
                content: "豆包最近饮食记录显示已换粮。".to_owned(),
                status: AiMessageStatus::Completed,
            },
            StoreCall::Citations(1),
            StoreCall::ProposedActions(1),
        ]
    );
}

fn assert_receipt(
    receipt: &FinalizationReceipt,
    terminal_status: AiSessionTurnStatus,
    synchronous_writes: &[FinalizerSynchronousWrite],
    async_triggers: &[FinalizerAsyncJobKind],
) {
    assert_eq!(receipt.terminal_status, terminal_status);
    assert_eq!(receipt.synchronous_writes, synchronous_writes);
    assert_eq!(receipt.async_triggers, async_triggers);
    assert!(receipt.async_failures.is_empty());
}
