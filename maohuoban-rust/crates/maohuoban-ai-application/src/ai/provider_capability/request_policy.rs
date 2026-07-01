//! request_policy Provider 请求裁剪策略
//! 核心职责：
//! - 根据 ProviderCapability 决定请求体字段是否发送
//! - 所有裁剪规则集中在此，禁止散落在 body builder / HTTP / Runtime 中

use maohuoban_ai_domain::ai::{LlmChatRequest, LlmRole, ProviderCapability};

/// ProviderRequestPolicy Provider 请求裁剪策略
/// 核心职责：
/// - 根据 ProviderCapability 决定请求体字段是否发送
/// - 所有裁剪规则集中在此，禁止散落在 body builder / HTTP / Runtime 中
#[derive(Debug, Clone)]
pub struct ProviderRequestPolicy;

impl ProviderRequestPolicy {
    /// should_send_response_format 判断是否应将 response_format 写入请求体
    /// 核心职责：
    /// - 只有 capability 声明支持且请求明确携带时才发送
    /// - 防止 provider 默认 JSON 输出导致空 content 等兼容问题
    #[must_use]
    pub fn should_send_response_format(
        capability: &ProviderCapability,
        request: &LlmChatRequest,
    ) -> bool {
        capability.supports_response_format && request.response_format.is_some()
    }

    /// should_send_json_output 判断是否应启用 JSON 结构化输出
    /// 核心职责：
    /// - 需要同时满足 capability 支持 JSON 输出且请求携带 json_object 格式
    #[must_use]
    pub fn should_send_json_output(
        capability: &ProviderCapability,
        request: &LlmChatRequest,
    ) -> bool {
        if !capability.supports_json_output {
            return false;
        }
        request
            .response_format
            .as_ref()
            .and_then(|format| format.get("type"))
            .and_then(|t| t.as_str())
            .is_some_and(|t| t == "json_object")
    }

    /// should_send_tools 判断是否应发送工具列表
    #[must_use]
    pub fn should_send_tools(capability: &ProviderCapability, request: &LlmChatRequest) -> bool {
        capability.supports_tool_calls && !request.tools.is_empty()
    }

    /// should_send_tool_choice 判断是否应发送 tool_choice
    #[must_use]
    pub fn should_send_tool_choice(
        capability: &ProviderCapability,
        request: &LlmChatRequest,
    ) -> bool {
        capability.supports_tool_calls && request.tool_choice.is_some()
    }

    /// should_send_parallel_tool_calls 判断是否允许并行工具调用
    #[must_use]
    pub fn should_send_parallel_tool_calls(capability: &ProviderCapability) -> bool {
        capability.supports_parallel_tool_calls
    }

    /// should_send_reasoning_content 判断消息中是否应保留 reasoning_content
    #[must_use]
    pub fn should_send_reasoning_content(capability: &ProviderCapability) -> bool {
        capability.supports_reasoning_content
    }

    /// should_backfill_assistant_reasoning_content 判断是否补齐 assistant reasoning_content
    /// 核心职责：
    /// - 只在 Provider 明确要求时对 assistant replay 补空字符串
    /// - 防止 DeepSeek thinking 工具调用后续轮次缺失协议字段
    #[must_use]
    pub fn should_backfill_assistant_reasoning_content(
        capability: &ProviderCapability,
        role: LlmRole,
    ) -> bool {
        capability.requires_assistant_reasoning_content() && role == LlmRole::Assistant
    }

    /// should_send_message_tool_calls 判断 replay 消息是否应保留 tool_calls
    /// 核心职责：
    /// - assistant/tool replay 属于消息历史，不依赖本轮是否重新下发 tools 列表
    /// - 保持 OpenAI 兼容多轮工具调用协议完整
    #[must_use]
    pub fn should_send_message_tool_calls(capability: &ProviderCapability) -> bool {
        capability.supports_tool_calls
    }

    /// default_reasoning_effort 返回 Provider 内部固定 reasoning effort
    /// 核心职责：
    /// - 让产品型 Agent 后端固定 thinking 策略
    /// - 避免前端用户理解或选择厂商参数
    #[must_use]
    pub fn default_reasoning_effort(capability: &ProviderCapability) -> Option<&'static str> {
        capability.default_reasoning_effort()
    }

    /// should_send_deepseek_thinking_control 判断是否发送 DeepSeek thinking 控制字段
    /// 核心职责：
    /// - 仅对 DeepSeek thinking 协议模型注入内部固定 payload
    /// - 防止 deepseek-chat 等非 thinking 模型被扰动
    #[must_use]
    pub fn should_send_deepseek_thinking_control(capability: &ProviderCapability) -> bool {
        capability.uses_deepseek_thinking_wire()
    }

    /// should_normalize_tool_schema_unions 判断工具 schema 是否需要 union 规整
    /// 核心职责：
    /// - 将 Provider schema 兼容策略集中在请求策略层
    /// - 由基础设施层执行 JSON Schema 转换
    #[must_use]
    pub fn should_normalize_tool_schema_unions(capability: &ProviderCapability) -> bool {
        capability.requires_tool_schema_union_normalization()
    }

    /// should_send_max_tokens 判断是否应发送 max_tokens
    #[must_use]
    pub fn should_send_max_tokens(
        _capability: &ProviderCapability,
        request: &LlmChatRequest,
    ) -> bool {
        request.max_output_tokens.is_some()
    }

    /// should_send_system_prompt 判断是否允许 system role 消息
    #[must_use]
    pub fn should_send_system_prompt(capability: &ProviderCapability) -> bool {
        capability.supports_system_prompt
    }
}
