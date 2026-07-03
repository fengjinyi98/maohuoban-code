// openai_compatible OpenAI 兼容 Provider 请求序列化测试
// 核心职责：
// - 验证内部 LlmChatRequest 被正确序列化为 OpenAI 兼容 HTTP 请求
// - 断言 path、headers、model、messages、tools、temperature、stream 字段
// - 确认日志不包含 API key
// - 遵循 TDD：先写失败测试（red），再实现 Provider（green）

#[path = "openai_compatible/cases/config/config_cases.rs"]
mod config_cases;
#[path = "openai_compatible/cases/deepseek/deepseek_cases.rs"]
mod deepseek_cases;
#[path = "openai_compatible/cases/error/error_cases.rs"]
mod error_cases;
#[path = "openai_compatible/cases/non_stream/non_stream_cases.rs"]
mod non_stream_cases;
#[path = "openai_compatible/cases/stream/stream_cases.rs"]
mod stream_cases;
#[path = "openai_compatible/support.rs"]
mod support;
