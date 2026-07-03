// runtime_loop_engine_streaming Agent Runtime 流式模型闭环测试
// 核心职责：
// - 验证工具调用后的二次模型也走 Provider stream
// - 验证工具进度先于延迟的二次模型内容到达

mod stream_cases;
mod support;
