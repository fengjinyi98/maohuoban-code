use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::MemoryScope;

/// MemoryCandidateKind 记忆候选分类
/// 核心职责：
/// - 区分不同类型的可记忆信息
/// - 决定后续校验路径（用户确认或业务工具确认）
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MemoryCandidateKind {
    /// 用户明确表达的偏好
    PreferenceCandidate,
    /// 模型推断的用户画像
    ProfileCandidate,
    /// 宠物强事实（饮食、健康、档案等）
    PetFactCandidate,
    /// 会话摘要候选
    SessionSummaryCandidate,
    /// 风险信号
    RiskSignal,
}

/// MemoryCandidateStatus 记忆候选状态
/// 核心职责：
/// - 管理候选生命周期
/// - 只有 Confirmed 状态才升级为活跃记忆
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MemoryCandidateStatus {
    /// 待确认
    Pending,
    /// 已确认，升级为活跃记忆
    Confirmed,
    /// 已拒绝
    Rejected,
    /// 已过期
    Expired,
}

/// MemoryCandidate 记忆候选值对象
/// 核心职责：
/// - 承载从对话中抽取的可记忆信息
/// - 标记作用域、归属和分类
/// - 通过状态管理确认流程
/// - 宠物强事实必须经过用户确认或业务工具确认才能升级
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct MemoryCandidate {
    pub id: Uuid,
    /// 作用域类型
    pub scope_type: MemoryScope,
    /// 作用域 ID（User=actor_user_id, Pet=pet_id, Household=household_id, Session=session_id）
    pub scope_id: Uuid,
    /// 创建者用户 ID
    pub actor_user_id: Uuid,
    /// 候选分类
    pub candidate_kind: MemoryCandidateKind,
    /// 候选摘要文本
    pub summary: String,
    /// 来源消息 ID
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source_message_id: Option<Uuid>,
    /// 置信度（0.0-1.0）
    pub confidence: f32,
    /// 候选状态
    pub status: MemoryCandidateStatus,
    pub created_at: DateTime<Utc>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub confirmed_at: Option<DateTime<Utc>>,
}

impl MemoryCandidate {
    /// requires_user_confirmation 判断该候选是否需要用户确认
    /// 核心职责：
    /// - 宠物强事实必须经过用户确认
    /// - 风险信号需要用户确认
    #[must_use]
    pub fn requires_user_confirmation(&self) -> bool {
        matches!(
            self.candidate_kind,
            MemoryCandidateKind::PetFactCandidate | MemoryCandidateKind::RiskSignal
        )
    }

    /// is_pending 判断候选是否仍在待确认状态
    #[must_use]
    pub fn is_pending(&self) -> bool {
        self.status == MemoryCandidateStatus::Pending
    }

    /// confirm 确认候选，返回确认后的新候选
    /// 核心职责：
    /// - 将状态改为 Confirmed
    /// - 记录确认时间
    #[must_use]
    pub fn confirm(self, at: DateTime<Utc>) -> Self {
        Self {
            status: MemoryCandidateStatus::Confirmed,
            confirmed_at: Some(at),
            ..self
        }
    }

    /// reject 拒绝候选，返回拒绝后的新候选
    #[must_use]
    pub fn reject(self) -> Self {
        Self {
            status: MemoryCandidateStatus::Rejected,
            ..self
        }
    }
}
