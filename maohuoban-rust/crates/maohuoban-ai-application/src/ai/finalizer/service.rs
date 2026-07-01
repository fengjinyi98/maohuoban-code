use std::sync::Arc;

use chrono::Utc;
use maohuoban_ai_domain::ai::{
    AiError, AiMessage, AiMessageRole, AiMessageStatus, AiResult, AiSessionTurnStatus,
};
use uuid::Uuid;

use super::{
    FinalizationReceipt, FinalizerAsyncFailure, FinalizerSessionHeaderUpdate, FinalizerStore,
    FinalizerSynchronousWrite, TurnTerminalOutput,
};

/// TurnFinalizer Turn 终态收口服务
/// 核心职责：
/// - 固定四类终态分支的同步写入顺序
/// - 对关键同步写入 fail-closed，对派生后处理 fail-open
pub struct TurnFinalizer {
    store: Arc<dyn FinalizerStore>,
}

impl TurnFinalizer {
    /// new 构造 TurnFinalizer
    #[must_use]
    pub fn new(store: Arc<dyn FinalizerStore>) -> Self {
        Self { store }
    }

    /// finalize 执行 turn 终态收口
    pub async fn finalize(&self, output: TurnTerminalOutput) -> AiResult<FinalizationReceipt> {
        let mut receipt = FinalizationReceipt {
            terminal_status: output.status,
            synchronous_writes: Vec::new(),
            async_triggers: Vec::new(),
            async_failures: Vec::new(),
        };

        match output.status {
            AiSessionTurnStatus::Completed => {
                self.finalize_completed(&output, &mut receipt).await?;
            }
            AiSessionTurnStatus::Failed => {
                self.finalize_failed(&output, &mut receipt).await?;
            }
            AiSessionTurnStatus::Interrupted => {
                self.finalize_interrupted(&output, &mut receipt).await?;
            }
            AiSessionTurnStatus::RequiresConfirmation => {
                self.finalize_requires_confirmation(&output, &mut receipt)
                    .await?;
            }
            AiSessionTurnStatus::Running => {
                return Err(AiError::InvalidInput(
                    "finalizer requires terminal turn status".to_owned(),
                ));
            }
        }

        self.trigger_async_jobs(&output, &mut receipt).await;
        Ok(receipt)
    }

    async fn finalize_completed(
        &self,
        output: &TurnTerminalOutput,
        receipt: &mut FinalizationReceipt,
    ) -> AiResult<()> {
        let final_text = output.final_text.clone().ok_or_else(|| {
            AiError::InvalidInput("completed finalizer requires final_text".to_owned())
        })?;
        let message = Self::assistant_message(output, final_text, AiMessageStatus::Completed);
        self.write_message_attached_outputs(output, &message, receipt)
            .await?;
        self.write_turn_and_session(output, Some(output.assistant_message_id), receipt)
            .await
    }

    async fn finalize_failed(
        &self,
        output: &TurnTerminalOutput,
        receipt: &mut FinalizationReceipt,
    ) -> AiResult<()> {
        let final_text = output
            .safe_failure_text
            .clone()
            .or_else(|| output.final_text.clone())
            .unwrap_or_else(|| "暂时无法获取回答，请稍后重试。".to_owned());
        let message = Self::assistant_message(output, final_text, AiMessageStatus::Failed);
        self.write_message_attached_outputs(output, &message, receipt)
            .await?;
        self.write_turn_and_session(output, Some(output.assistant_message_id), receipt)
            .await
    }

    async fn finalize_interrupted(
        &self,
        output: &TurnTerminalOutput,
        receipt: &mut FinalizationReceipt,
    ) -> AiResult<()> {
        let final_text = output
            .final_text
            .clone()
            .unwrap_or_else(|| "已停止本次回答。".to_owned());
        let message = Self::assistant_message(output, final_text, AiMessageStatus::Failed);
        self.write_message_attached_outputs(output, &message, receipt)
            .await?;
        self.write_turn_and_session(output, Some(output.assistant_message_id), receipt)
            .await
    }

    async fn finalize_requires_confirmation(
        &self,
        output: &TurnTerminalOutput,
        receipt: &mut FinalizationReceipt,
    ) -> AiResult<()> {
        self.store
            .write_proposed_actions(output.session_id, &output.proposed_actions)
            .await?;
        receipt
            .synchronous_writes
            .push(FinalizerSynchronousWrite::ProposedActions);
        self.write_turn_and_session(output, None, receipt).await
    }

    async fn write_message_attached_outputs(
        &self,
        output: &TurnTerminalOutput,
        message: &AiMessage,
        receipt: &mut FinalizationReceipt,
    ) -> AiResult<()> {
        self.store.write_assistant_message(message).await?;
        receipt
            .synchronous_writes
            .push(FinalizerSynchronousWrite::AssistantMessage);

        self.store
            .write_citations(message.id, message.session_id, &output.citations)
            .await?;
        receipt
            .synchronous_writes
            .push(FinalizerSynchronousWrite::Citations);

        self.store
            .write_proposed_actions(output.session_id, &output.proposed_actions)
            .await?;
        receipt
            .synchronous_writes
            .push(FinalizerSynchronousWrite::ProposedActions);
        Ok(())
    }

    async fn write_turn_and_session(
        &self,
        output: &TurnTerminalOutput,
        last_message_id: Option<Uuid>,
        receipt: &mut FinalizationReceipt,
    ) -> AiResult<()> {
        let finish_reason = output.finish_reason.map(|reason| format!("{reason:?}"));
        self.store
            .update_turn_status(
                output.turn_id,
                output.status,
                last_message_id,
                finish_reason.as_deref(),
                output.failure_code.as_deref(),
                output.retryable,
            )
            .await?;
        receipt
            .synchronous_writes
            .push(FinalizerSynchronousWrite::TurnStatus);

        let header_update = FinalizerSessionHeaderUpdate {
            session_id: output.session_id,
            actor_user_id: output.actor_user_id,
            last_turn_id: output.turn_id,
            last_message_id,
            last_message_at: Utc::now(),
        };
        self.store.update_session_header(&header_update).await?;
        receipt
            .synchronous_writes
            .push(FinalizerSynchronousWrite::SessionHeader);
        Ok(())
    }

    async fn trigger_async_jobs(
        &self,
        output: &TurnTerminalOutput,
        receipt: &mut FinalizationReceipt,
    ) {
        for job in &output.async_jobs {
            receipt.async_triggers.push(job.kind);
            if let Err(error) = self.store.trigger_async_job(job).await {
                receipt.async_failures.push(FinalizerAsyncFailure {
                    job_kind: job.kind,
                    error_code: error.stable_code().to_owned(),
                });
            }
        }
    }

    fn assistant_message(
        output: &TurnTerminalOutput,
        content: String,
        status: AiMessageStatus,
    ) -> AiMessage {
        AiMessage {
            id: output.assistant_message_id,
            session_id: output.session_id,
            turn_id: Some(output.turn_id),
            role: AiMessageRole::Assistant,
            content,
            content_blocks: output.content_blocks.clone(),
            status,
            citations: output
                .citations
                .iter()
                .map(|citation| citation.source_id)
                .collect(),
            model: output.model.clone(),
            provider: output.provider.clone(),
            finish_reason: output.finish_reason.map(|reason| format!("{reason:?}")),
            usage_input_tokens: Some(output.usage.input_tokens),
            usage_output_tokens: Some(output.usage.output_tokens),
            verification: output.verification.clone(),
            created_at: Utc::now(),
        }
    }
}
