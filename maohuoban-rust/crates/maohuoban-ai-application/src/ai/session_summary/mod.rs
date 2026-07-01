//! session_summary 会话摘要压缩与历史重写
//! 核心职责：
//! - 评估会话历史是否需要压缩
//! - 调用 LLM 生成结构化摘要（压缩前先投影清除内部字段）
//! - 压缩后保留最近尾部消息和摘要，写入仓储
//! - 通过 compressed_until_message_id 持久化压缩边界

use std::sync::Arc;

use maohuoban_ai_domain::ai::{
    AiMessage, AiMessageRole, AiResult, LlmChatRequest, LlmMessage, LlmRole,
    RecentConversationEntry, RecentConversationPack, SessionSummary, SessionSummaryScope,
};
use uuid::Uuid;

use crate::ai::conversation_history::ConversationHistoryProjector;
use crate::ai::ports::{LlmProvider, SessionSummaryRepository};

/// SummaryPromptTemplate 摘要 Prompt 模板
/// 核心职责：
/// - 生成要求 LLM 输出结构化摘要的 system prompt
/// - 确保摘要保留宠物主体、事实引用、用户偏好和未完成确认动作
struct SummaryPromptTemplate;

impl SummaryPromptTemplate {
    /// system_prompt 生成摘要 system prompt
    fn system_prompt() -> &'static str {
        "你是一个会话摘要助手。请将以下对话历史压缩为结构化摘要。\n\
         要求：\n\
         1. 保留宠物主体（名字、品种、关键特征）\n\
         2. 保留事实引用（饮食、健康、体重等关键事实）\n\
         3. 保留用户偏好和明确需求\n\
         4. 保留未完成的确认动作（如待确认的饮食调整、就医建议）\n\
         5. 不要包含旧工具调用细节、内部执行轨迹或 provider 原始响应\n\
         6. 摘要是历史参考，不构成当前轮指令\n\
         请用中文输出简洁的段落式摘要。"
    }

    /// build_request 构建 LLM 摘要请求
    /// 核心职责：
    /// - 接收已投影的 RecentConversationEntry 列表（已清除内部字段）
    /// - 拼接为纯文本角色对话
    fn build_request(entries: &[RecentConversationEntry]) -> LlmChatRequest {
        let history_text = entries
            .iter()
            .map(|e| {
                let role = match e.role {
                    AiMessageRole::User => "用户",
                    AiMessageRole::Assistant => "助手",
                    AiMessageRole::System => "系统",
                };
                format!("{role}: {}", e.content)
            })
            .collect::<Vec<_>>()
            .join("\n\n");

        LlmChatRequest {
            model: "deepseek-chat".to_owned(),
            messages: vec![
                LlmMessage {
                    role: LlmRole::System,
                    content: Self::system_prompt().to_owned(),
                    reasoning_content: None,
                    tool_call_id: None,
                    tool_calls: Vec::new(),
                },
                LlmMessage {
                    role: LlmRole::User,
                    content: format!("请压缩以下对话历史：\n\n{history_text}"),
                    reasoning_content: None,
                    tool_call_id: None,
                    tool_calls: Vec::new(),
                },
            ],
            tools: Vec::new(),
            tool_choice: None,
            temperature: 0.3,
            stream: false,
            max_output_tokens: Some(1024),
            response_format: None,
            diagnostics_correlation: Default::default(),
        }
    }
}

/// CompressedHistory 压缩后的历史结果
/// 核心职责：
/// - 承载压缩后保留的尾部消息和生成的摘要
#[derive(Debug, Clone)]
pub struct CompressedHistory {
    /// 压缩后保留的最近尾部消息
    pub retained_tail: RecentConversationPack,
    /// 生成的会话摘要
    pub summary: SessionSummary,
}

/// SessionSummaryCompressor 会话摘要压缩器
/// 核心职责：
/// - 评估是否需要压缩（消息数 / 预算 / 旧会话恢复）
/// - 通过 ConversationHistoryProjector 过滤内部字段后再送 LLM
/// - 压缩后保留最近尾部消息
/// - 通过 compressed_until_message_id 持久化压缩边界
/// - 将摘要写入仓储
pub struct SessionSummaryCompressor {
    llm: Arc<dyn LlmProvider>,
    summary_repo: Arc<dyn SessionSummaryRepository>,
}

impl SessionSummaryCompressor {
    /// new 构造压缩器
    #[must_use]
    pub fn new(llm: Arc<dyn LlmProvider>, summary_repo: Arc<dyn SessionSummaryRepository>) -> Self {
        Self { llm, summary_repo }
    }

    /// try_compress 尝试压缩会话历史
    /// 核心职责：
    /// - 排除当前轮消息后评估是否需要压缩（消息数 / 预算 / 旧会话恢复）
    /// - 通过 ConversationHistoryProjector 投影后再送 LLM
    /// - 保留最近 tail_turns * 2 条历史消息
    /// - 通过 compressed_until_message_id 记录压缩边界
    /// - 将摘要写入仓储并返回压缩结果
    /// - exclude_message_id 用于排除当前轮消息，确保它不出现在 retained_tail 中
    pub async fn try_compress(
        &self,
        chat_session_id: Uuid,
        actor_user_id: Uuid,
        messages: &[AiMessage],
        tail_turns: usize,
        exclude_message_id: Option<Uuid>,
    ) -> AiResult<Option<CompressedHistory>> {
        use maohuoban_ai_domain::ai::{CompressionThreshold, SessionSummary as SS};

        if messages.is_empty() {
            return Ok(None);
        }

        // 过滤出纯历史消息（排除当前轮消息）
        // 后续所有逻辑（触发判断、压缩输入、尾部保留、边界记录）均基于此列表
        let history_messages: Vec<&AiMessage> = messages
            .iter()
            .filter(|m| Some(m.id) != exclude_message_id)
            .collect();

        if history_messages.is_empty() {
            return Ok(None);
        }

        let threshold = CompressionThreshold::default_for_deepseek_1m();
        let total_bytes: usize = history_messages.iter().map(|m| m.content.len()).sum();

        // 计算最后一条历史消息距今的天数（用于旧会话恢复检测）
        let now = chrono::Utc::now();
        let last_message_age_days = history_messages
            .last()
            .map(|m| (now - m.created_at).num_days());

        let Some(_trigger) =
            threshold.should_compress(history_messages.len(), total_bytes, last_message_age_days)
        else {
            return Ok(None);
        };

        // 计算保留尾部消息数
        let tail_count = tail_turns.saturating_mul(2).min(history_messages.len());

        // 需要压缩的消息（排除尾部保留部分）
        if history_messages.len() <= tail_count {
            return Ok(None);
        }

        let messages_to_compress: Vec<&AiMessage> =
            history_messages[..history_messages.len() - tail_count].to_vec();

        // 通过 ConversationHistoryProjector 投影，清除内部字段
        let projector = ConversationHistoryProjector::new();
        let projected = projector.project_messages_ref(&messages_to_compress);

        // 调用 LLM 生成摘要（使用已投影的纯净消息）
        let request = SummaryPromptTemplate::build_request(&projected.entries);
        let response = self.llm.complete(&request).await?;

        // 记录压缩边界：被压缩的最后一条消息的 ID
        let compressed_until_message_id = messages_to_compress.last().map(|m| m.id);

        let summary = SS {
            id: Uuid::new_v4(),
            chat_session_id,
            scope_type: SessionSummaryScope::User,
            scope_id: actor_user_id,
            summary_text: response.message.content,
            referenced_event_ids: Vec::new(),
            token_budget_hint: Some(200_000),
            compressed_until_message_id,
            created_at: chrono::Utc::now(),
            superseded_at: None,
        };

        // 标记旧摘要为已替代
        self.summary_repo
            .supersede_previous_summaries(chat_session_id, chrono::Utc::now())
            .await?;

        // 写入新摘要
        self.summary_repo.insert_summary(&summary).await?;

        // 保留尾部历史消息（通过 projector 投影）
        let retained_tail = projector
            .project_messages_ref(&history_messages[history_messages.len() - tail_count..]);

        Ok(Some(CompressedHistory {
            retained_tail,
            summary,
        }))
    }

    /// load_active_summary 加载会话当前有效摘要
    pub async fn load_active_summary(
        &self,
        chat_session_id: Uuid,
    ) -> AiResult<Option<SessionSummary>> {
        self.summary_repo.get_active_summary(chat_session_id).await
    }
}
