//! stream Runtime 输出 DTO 模块
//! 核心职责：
//! - 定义 HTTP 流式桥接需要的运行上下文
//! - 定义 HTTP 非流式聚合需要的完成结果
//! - 避免 application 层保留 provider-to-SSE 旧 pipeline

use maohuoban_ai_domain::ai::{
    AiAnswerVerification, AiCitation, AiContentBlock, AiFactPackage, AiPetDisplaySnapshot,
    AiStreamEvent, LlmFinishReason, LlmUsage,
};

/// AiStreamRunContext 流式运行上下文
/// 核心职责：
/// - 汇总稳定 SSE 所需的会话、消息、宠物和初始事件参数
/// - 携带真实事实包供回答校验器使用
pub struct AiStreamRunContext {
    pub chat_session_id: uuid::Uuid,
    pub message_id: uuid::Uuid,
    pub title: String,
    pub target_pet: Option<AiPetDisplaySnapshot>,
    pub initial_events: Vec<AiStreamEvent>,
    pub fact_package: Option<AiFactPackage>,
}

/// AiCompleteResult 非流式聊天完成结果
/// 核心职责：
/// - 汇总 Provider 完整回答和回答校验结果
/// - 为 HTTP 非流式响应与消息持久化提供稳定数据
pub struct AiCompleteResult {
    pub final_text: String,
    pub content_blocks: Vec<AiContentBlock>,
    pub usage: LlmUsage,
    pub finish_reason: LlmFinishReason,
    pub provider: String,
    pub model: String,
    pub citations: Vec<AiCitation>,
    pub verification: AiAnswerVerification,
}
