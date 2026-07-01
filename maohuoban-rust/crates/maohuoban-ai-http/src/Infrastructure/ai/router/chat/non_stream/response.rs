//! ChatCompleteResponse 非流式聊天完成响应
//! 核心职责：
//! - 对齐流式完成后的聚合结果，返回前端渲染和调试所需的最小字段

use serde::Serialize;
use uuid::Uuid;

use maohuoban_ai_domain::ai::{
    AiAnswerVerification, AiCitation, AiPetDisplaySnapshot, LlmFinishReason, LlmUsage,
};

#[derive(Serialize)]
pub(super) struct ChatCompleteResponse {
    pub(super) chat_session_id: Uuid,
    pub(super) message_id: Uuid,
    pub(super) title: String,
    pub(super) target_pet: Option<AiPetDisplaySnapshot>,
    pub(super) final_text: String,
    pub(super) citations: Vec<AiCitation>,
    pub(super) usage: LlmUsage,
    pub(super) finish_reason: LlmFinishReason,
    pub(super) verification: AiAnswerVerification,
}
