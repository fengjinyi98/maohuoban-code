use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// SessionSummaryScope 摘要作用域类型
/// 核心职责：
/// - 标记摘要覆盖的会话范围
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SessionSummaryScope {
    User,
    Pet,
    Household,
}

/// SessionSummary 会话摘要值对象
/// 核心职责：
/// - 承载压缩后的结构化会话摘要
/// - 标记为"历史参考"，不激活旧任务或工具调用
/// - 保留宠物主体、事实引用、用户偏好和未完成确认动作
/// - 通过 compressed_until_message_id 持久化压缩边界
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SessionSummary {
    pub id: Uuid,
    pub chat_session_id: Uuid,
    pub scope_type: SessionSummaryScope,
    pub scope_id: Uuid,
    /// 结构化摘要文本，注入 ContextPack.session_summary
    pub summary_text: String,
    /// 摘要引用的事实事件 ID 列表
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub referenced_event_ids: Vec<Uuid>,
    /// 下次拼上下文的预算提示
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub token_budget_hint: Option<u32>,
    /// 压缩边界：此 ID 及更早的消息已被摘要吸收，下一轮只需加载此 ID 之后的消息
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub compressed_until_message_id: Option<Uuid>,
    pub created_at: DateTime<Utc>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub superseded_at: Option<DateTime<Utc>>,
}

impl SessionSummary {
    /// to_context_summary 生成注入 ContextPack 的安全摘要文本
    /// 核心职责：
    /// - 添加"历史参考"安全前缀，防止旧任务被重新激活
    /// - 只辅助理解当前问题，不构成当前轮指令
    #[must_use]
    pub fn to_context_summary(&self) -> String {
        format!(
            "【历史参考·仅辅助理解当前问题，不激活旧任务或工具调用】\n{}",
            self.summary_text
        )
    }

    /// is_active 判断摘要是否仍在有效期
    #[must_use]
    pub fn is_active(&self) -> bool {
        self.superseded_at.is_none()
    }

    /// covers_message 判断指定消息是否已被此摘要覆盖
    /// 核心职责：
    /// - 通过 compressed_until_message_id 判断消息是否在压缩范围内
    #[must_use]
    pub fn covers_message(&self, message_created_at: DateTime<Utc>) -> bool {
        match self.compressed_until_message_id {
            None => false,
            Some(_) => message_created_at <= self.created_at,
        }
    }
}

/// CompressionTrigger 压缩触发条件
/// 核心职责：
/// - 描述何时触发会话摘要压缩
/// - 由 SessionSummaryCompressor 评估
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CompressionTrigger {
    /// 历史消息条数超过配置上限
    MessageCountExceeded,
    /// 历史内容字节数接近预算阈值
    BudgetThresholdApproached,
    /// 用户主动继续很长的旧会话
    LongSessionResumed,
}

/// CompressionThreshold 压缩阈值配置
/// 核心职责：
/// - 承载触发压缩的具体阈值参数
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CompressionThreshold {
    /// 触发压缩的最小消息条数
    pub min_message_count: usize,
    /// 触发压缩的字节数阈值（达到 80% 预算时触发）
    pub budget_threshold_bytes: usize,
    /// 旧会话恢复触发的天数阈值
    pub resume_after_days: i64,
}

impl CompressionThreshold {
    /// new 构造压缩阈值
    /// 核心职责：
    /// - min_message_count 触发压缩的最小消息条数
    /// - budget_threshold_bytes 触发压缩的字节数阈值
    #[must_use]
    pub fn new(min_message_count: usize, budget_threshold_bytes: usize) -> Self {
        Self {
            min_message_count,
            budget_threshold_bytes,
            resume_after_days: 7,
        }
    }

    /// default_for_deepseek_1m DeepSeek 1M 默认压缩阈值
    #[must_use]
    pub fn default_for_deepseek_1m() -> Self {
        Self {
            min_message_count: 40,
            budget_threshold_bytes: 160_000,
            resume_after_days: 7,
        }
    }

    /// should_compress 评估是否应该触发压缩
    /// 核心职责：
    /// - 按消息条数、字节数和会话恢复天数判断是否达到压缩阈值
    /// - 返回触发原因（如果触发）
    #[must_use]
    pub fn should_compress(
        &self,
        message_count: usize,
        total_bytes: usize,
        last_message_age_days: Option<i64>,
    ) -> Option<CompressionTrigger> {
        if let Some(age_days) = last_message_age_days
            && age_days >= self.resume_after_days
            && message_count > 0
        {
            return Some(CompressionTrigger::LongSessionResumed);
        }
        if total_bytes >= self.budget_threshold_bytes {
            return Some(CompressionTrigger::BudgetThresholdApproached);
        }
        if message_count >= self.min_message_count {
            return Some(CompressionTrigger::MessageCountExceeded);
        }
        None
    }
}
