//! provider_capability Provider 能力声明领域模型
//! 核心职责：
//! - 声明每个 Provider/Profile 的固定能力集合
//! - 作为 Request Policy 裁剪请求字段的唯一依据
//! - 禁止在调用现场散写 provider 特判

use serde::{Deserialize, Serialize};

/// ProviderCapability Provider 固定能力声明
/// 核心职责：
/// - 描述 Provider 支持哪些协议能力和流式事件
/// - 驱动请求体字段的条件发放
/// - 所有 Provider 差异必须进入此模型，不得散落在 HTTP/Runtime 层
///
/// 每个 bool 代表一条独立的协议能力，无自然分组，保持平铺
#[allow(clippy::struct_excessive_bools)]
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProviderCapability {
    /// 提供商名称标识，如 "openai_compatible"、"deepseek"
    pub provider_name: String,
    /// 当前路由的模型名
    pub model_route: String,
    /// 上下文窗口上限（token 数）
    pub context_window: u32,
    /// 是否支持流式响应
    pub supports_stream: bool,
    /// 是否支持 reasoning_content 字段
    pub supports_reasoning_content: bool,
    /// 是否支持函数/工具调用
    pub supports_tool_calls: bool,
    /// 是否支持并行工具调用（不支持时必须显式 false）
    pub supports_parallel_tool_calls: bool,
    /// 是否支持 response_format 参数
    pub supports_response_format: bool,
    /// 是否支持 JSON 结构化输出
    pub supports_json_output: bool,
    /// 是否支持 system prompt 角色
    pub supports_system_prompt: bool,
}

impl ProviderCapability {
    /// openai_compatible 标准 OpenAI 兼容 Provider 能力
    /// 核心职责：
    /// - 声明 OpenAI 兼容协议族的完整能力集
    /// - 作为 openai_compatible profile 的默认能力基线
    #[must_use]
    pub fn openai_compatible(model: impl Into<String>) -> Self {
        Self {
            provider_name: "openai_compatible".to_owned(),
            model_route: model.into(),
            context_window: 128_000,
            supports_stream: true,
            supports_reasoning_content: true,
            supports_tool_calls: true,
            supports_parallel_tool_calls: true,
            supports_response_format: true,
            supports_json_output: true,
            supports_system_prompt: true,
        }
    }

    /// deepseek DeepSeek 厂商 Provider 能力
    /// 核心职责：
    /// - 声明 DeepSeek 相比标准 OpenAI 兼容协议的能力差异
    /// - 标记 JSON Output 不稳定、parallel_tool_calls 默认关闭等已知差异
    #[must_use]
    pub fn deepseek(model: impl Into<String>) -> Self {
        Self {
            provider_name: "deepseek".to_owned(),
            model_route: model.into(),
            context_window: 128_000,
            supports_stream: true,
            supports_reasoning_content: true,
            supports_tool_calls: true,
            // DeepSeek 并行工具调用行为不稳定，默认关闭
            supports_parallel_tool_calls: false,
            // DeepSeek JSON Output 存在空 content 风险，标记支持但需策略保护
            supports_response_format: true,
            supports_json_output: false,
            supports_system_prompt: true,
        }
    }

    /// uses_deepseek_thinking_wire 判断是否使用 DeepSeek thinking 协议形态
    /// 核心职责：
    /// - 将 DeepSeek thinking 模型识别收口在能力模型内
    /// - 避免调用现场散写模型名称判断
    #[must_use]
    pub fn uses_deepseek_thinking_wire(&self) -> bool {
        if self.provider_name != "deepseek" {
            return false;
        }
        let model = self.model_route.trim().to_ascii_lowercase();
        if model.is_empty() {
            return false;
        }
        (model.starts_with("deepseek-v") && !model.starts_with("deepseek-v3"))
            || model == "deepseek-reasoner"
    }

    /// default_reasoning_effort 返回内部固定 reasoning effort
    /// 核心职责：
    /// - 为产品型 Agent 提供后端固定 reasoning 策略
    /// - 不向前端暴露模型厂商参数
    #[must_use]
    pub fn default_reasoning_effort(&self) -> Option<&'static str> {
        if self.uses_deepseek_thinking_wire() {
            Some("high")
        } else {
            None
        }
    }

    /// requires_assistant_reasoning_content 判断 replay 是否要求 reasoning_content 字段
    /// 核心职责：
    /// - 避免 DeepSeek thinking 多轮工具调用 replay 触发 400
    /// - 将空 reasoning_content 补齐要求表达为 Provider 能力
    #[must_use]
    pub fn requires_assistant_reasoning_content(&self) -> bool {
        self.uses_deepseek_thinking_wire()
    }

    /// requires_tool_schema_union_normalization 判断工具 schema 是否需要 union 规整
    /// 核心职责：
    /// - 标记 DeepSeek 对 anyOf/oneOf 工具参数的兼容处理
    /// - 由基础设施序列化层执行实际 schema 转换
    #[must_use]
    pub fn requires_tool_schema_union_normalization(&self) -> bool {
        self.provider_name == "deepseek"
    }
}
