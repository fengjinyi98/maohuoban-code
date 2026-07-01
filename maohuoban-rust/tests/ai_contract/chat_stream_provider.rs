// chat_stream_provider OpenAI 兼容 Provider 流式合同测试
// 核心职责：
// - 挂载 Provider 流式合同测试场景模块
// - 将场景用例与测试支撑代码拆分到分层目录

#[path = "chat_stream_provider/support/app.rs"]
mod app;
#[path = "chat_stream_provider/support/diagnostics.rs"]
mod diagnostics;
#[path = "chat_stream_provider/support/sse.rs"]
mod sse;

#[path = "chat_stream_provider/scenarios/provider.rs"]
mod provider;
#[path = "chat_stream_provider/scenarios/safety.rs"]
mod safety;
#[path = "chat_stream_provider/scenarios/workbench.rs"]
mod workbench;
