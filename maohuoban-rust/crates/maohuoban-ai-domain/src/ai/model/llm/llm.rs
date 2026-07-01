use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// LlmRole LLM 消息角色
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LlmRole {
    System,
    User,
    Assistant,
    Tool,
}

/// LlmMessage LLM 消息
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LlmMessage {
    pub role: LlmRole,
    pub content: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub reasoning_content: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub tool_call_id: Option<String>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tool_calls: Vec<LlmToolCall>,
}

/// LlmToolCall LLM 工具调用意图
/// 核心职责：
/// - 表达模型申请的工具调用，真实执行由 Agent Gateway 完成
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LlmToolCall {
    pub id: String,
    pub name: String,
    pub arguments: String,
}

/// LlmToolSchema 工具声明
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LlmToolSchema {
    pub name: String,
    pub description: String,
    pub parameters: serde_json::Value,
}

/// LlmDiagnosticsCorrelation LLM 请求诊断关联上下文
/// 核心职责：
/// - 承载 Runtime 到 Provider 的 session、turn、message 和 tool 关联键
/// - 只服务 diagnostics 链路，不进入上游 Provider 请求体
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct LlmDiagnosticsCorrelation {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub session_id: Option<Uuid>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub turn_id: Option<Uuid>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub message_id: Option<Uuid>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub tool_call_id: Option<String>,
}

/// LlmChatRequest 内部稳定 LLM 请求
/// 核心职责：
/// - 屏蔽厂商差异，由 Provider 适配为 OpenAI 兼容格式
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LlmChatRequest {
    pub model: String,
    pub messages: Vec<LlmMessage>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tools: Vec<LlmToolSchema>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub tool_choice: Option<String>,
    pub temperature: f32,
    pub stream: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub max_output_tokens: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub response_format: Option<serde_json::Value>,
    #[serde(default, skip_serializing)]
    pub diagnostics_correlation: LlmDiagnosticsCorrelation,
}

/// LlmUsage token 用量
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct LlmUsage {
    pub input_tokens: u32,
    pub output_tokens: u32,
    pub total_tokens: u32,
}

/// LlmFinishReason LLM 完成原因
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LlmFinishReason {
    Stop,
    Length,
    ToolCalls,
    ContentFilter,
    Error,
}

/// LlmChatResponse 内部稳定 LLM 非流式响应
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct LlmChatResponse {
    pub message: LlmMessage,
    pub tool_calls: Vec<LlmToolCall>,
    pub usage: LlmUsage,
    pub finish_reason: LlmFinishReason,
    pub provider: String,
    pub model: String,
}

/// LlmStreamEvent Provider 流式事件内部模型
/// 核心职责：
/// - 屏蔽厂商 chunk 差异，由 stream pipeline 转换为毛伙伴稳定 SSE 事件
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum LlmStreamEvent {
    Delta {
        content: String,
    },
    ReasoningDelta {
        content: String,
    },
    ToolCall {
        tool_call: LlmToolCall,
    },
    Finish {
        finish_reason: LlmFinishReason,
        usage: LlmUsage,
    },
    Error {
        message: String,
    },
}

/// LlmRequestReceipt Provider 请求回执
/// 核心职责：
/// - 记录请求 ID、模型和估算输入 token，用于观测，不含密钥
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LlmRequestReceipt {
    pub request_id: Uuid,
    pub model: String,
    pub provider: String,
    pub message_count: usize,
    pub tool_count: usize,
    pub estimated_input_tokens: u32,
    pub stream: bool,
}
