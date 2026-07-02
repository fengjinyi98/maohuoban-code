use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::{
    AiAnswerVerification, AiBlockedReason, AiCitation, AiPetDisplaySnapshot, AiPetResolution,
    AiProposedAction, LlmFinishReason, LlmUsage,
};

/// AiContentBlock AI 回复原生渲染内容块
/// 核心职责：
/// - 承载前端可稳定渲染的语义化 UI 片段
/// - 将标题、段落和宠物资料卡从普通文本协议中分离
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum AiContentBlock {
    SectionHeading {
        id: String,
        text: String,
    },
    Paragraph {
        id: String,
        text: String,
    },
    PetProfileCardSkeleton {
        id: String,
        title: String,
    },
    PetProfileCard {
        id: String,
        pet: Box<AiPetProfileFactBlock>,
        computed: Box<AiPetProfileComputedBlock>,
        narrative: Box<AiPetProfileNarrativeBlock>,
    },
}

/// AiPetProfileFactBlock 宠物资料卡事实字段
/// 核心职责：
/// - 表达来自数据库和事实工具的宠物基础字段
/// - 为 iOS 原生宠物资料 UI 提供稳定字段契约
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AiPetProfileFactBlock {
    pub id: String,
    pub name: String,
    pub species: AiPetProfileSpecies,
    pub species_text: String,
    pub sex: AiPetProfileSex,
    pub sex_text: String,
    pub breed: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub avatar_url: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub birth_date: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub arrival_date: Option<String>,
}

/// AiPetProfileComputedBlock 宠物资料卡确定性计算字段
/// 核心职责：
/// - 承载后端计算出的年龄和陪伴时长文案
/// - 避免模型在日期计算中产生事实漂移
#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct AiPetProfileComputedBlock {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub age_text: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub companionship_text: Option<String>,
}

/// AiPetProfileNarrativeBlock 宠物资料卡叙事文案
/// 核心职责：
/// - 承载可由偏好记忆或模板生成的暖心短文案
/// - 与事实字段保持分离，避免把表达当作事实来源
#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct AiPetProfileNarrativeBlock {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub birth: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub arrival: Option<String>,
}

/// AiPetProfileSpecies 宠物资料卡物种枚举
/// 核心职责：
/// - 约束前端头像和资料卡可识别的物种值
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiPetProfileSpecies {
    Dog,
    Cat,
    Other,
}

/// AiPetProfileSex 宠物资料卡性别枚举
/// 核心职责：
/// - 约束前端头像和资料卡可识别的性别值
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiPetProfileSex {
    Male,
    Female,
    Unknown,
}

/// AiStreamEvent 毛伙伴对 iOS 输出的稳定 SSE 事件
/// 核心职责：
/// - 屏蔽后端 Provider 差异，定义固定事件顺序
/// - iOS 只消费自家事件协议
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "event", rename_all = "snake_case")]
pub enum AiStreamEvent {
    MessageStarted {
        chat_session_id: Uuid,
        message_id: Uuid,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        target_pet: Option<AiPetDisplaySnapshot>,
        title: String,
    },
    PetResolution {
        resolution: AiPetResolution,
    },
    ToolCall {
        tool_name: String,
        status: AiToolCallStatus,
        citation_count: u32,
    },
    AgentActivity {
        display_text: String,
        status: AiAgentActivityStatus,
    },
    ExecutionTraceStarted {
        display_text: String,
    },
    ExecutionTraceCompleted {
        display_text: String,
        status: AiAgentActivityStatus,
        citation_count: u32,
    },
    Delta {
        text: String,
    },
    AnswerDelta {
        text: String,
    },
    Citation {
        citation: AiCitation,
    },
    ProposedAction {
        action: AiProposedAction,
    },
    ConfirmationTask {
        confirmation_task_id: Uuid,
        question_text: String,
    },
    MessageCompleted {
        message_id: Uuid,
        final_text: String,
        #[serde(default, skip_serializing_if = "Vec::is_empty")]
        content_blocks: Vec<AiContentBlock>,
        usage: LlmUsage,
        finish_reason: LlmFinishReason,
        citations: Vec<AiCitation>,
        verification: AiAnswerVerification,
    },
    AnswerCompleted {
        message_id: Uuid,
        final_text: String,
        #[serde(default, skip_serializing_if = "Vec::is_empty")]
        content_blocks: Vec<AiContentBlock>,
        usage: LlmUsage,
        finish_reason: LlmFinishReason,
        citations: Vec<AiCitation>,
        verification: AiAnswerVerification,
    },
    Error {
        code: String,
        message: String,
        retryable: bool,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        blocked_reason: Option<AiBlockedReason>,
        #[serde(default, skip_serializing_if = "Option::is_none")]
        safe_fallback_text: Option<String>,
    },
}

/// AiToolCallStatus 工具调用状态
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiToolCallStatus {
    Started,
    Allowed,
    Denied,
    Failed,
}

/// AiAgentActivityStatus Agent UI 安全进度状态
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum AiAgentActivityStatus {
    Started,
    Completed,
    Failed,
}

impl AiStreamEvent {
    /// event_name 返回 SSE 事件名
    pub fn event_name(&self) -> &'static str {
        match self {
            Self::MessageStarted { .. } => "message_started",
            Self::PetResolution { .. } => "pet_resolution",
            Self::ToolCall { .. } => "tool_call",
            Self::AgentActivity { .. } => "agent_activity",
            Self::ExecutionTraceStarted { .. } => "execution_trace_started",
            Self::ExecutionTraceCompleted { .. } => "execution_trace_completed",
            Self::Delta { .. } => "delta",
            Self::AnswerDelta { .. } => "answer_delta",
            Self::Citation { .. } => "citation",
            Self::ProposedAction { .. } => "proposed_action",
            Self::ConfirmationTask { .. } => "confirmation_task",
            Self::MessageCompleted { .. } => "message_completed",
            Self::AnswerCompleted { .. } => "answer_completed",
            Self::Error { .. } => "error",
        }
    }
}
