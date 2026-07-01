use std::sync::Arc;

use maohuoban_ai_domain::ai::AiFactPackage;

use crate::ai::ports::LlmProvider;
use crate::ai::tools::{AiToolContext, ToolRegistry};

/// AgentRuntimeEngineInput 构造 LoopEngine 所需依赖
/// 核心职责：
/// - 汇总 provider、工具目录、工具上下文和事实包
/// - 让 HTTP handler 不感知具体 engine 构造细节
pub struct AgentRuntimeEngineInput {
    pub provider: Arc<dyn LlmProvider>,
    pub registry: Arc<ToolRegistry>,
    pub tool_context: AiToolContext,
    pub fact_package: Option<AiFactPackage>,
}
