use super::{AiToolContext, AiToolMetadata, AiToolResult};

/// AiToolDefinition 工具定义端口
/// 核心职责：
/// - 声明工具名、描述、参数 schema 和风险 metadata
/// - 执行时接收上下文和参数，返回裁剪后的事实和引用
pub trait AiToolDefinition: Send + Sync {
    /// name 工具名
    fn name(&self) -> &str;

    /// description 工具描述
    fn description(&self) -> &str;

    /// parameters_schema 参数 JSON Schema
    fn parameters_schema(&self) -> serde_json::Value;

    /// metadata 工具风险与执行约束元数据
    fn metadata(&self) -> AiToolMetadata;

    /// execute 执行工具
    fn execute(&self, ctx: &AiToolContext, args: &serde_json::Value) -> AiToolResult;
}
