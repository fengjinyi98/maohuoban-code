//! tools Agent Gateway 工具注册与执行
//! 核心职责：
//! - 工具白名单管理，未注册工具调用被拒绝
//! - 工具执行时注入 actor_user_id 和 authorized_pet_id，强制权限校验
//! - 工具调用前执行风险策略裁决，写入和高风险动作返回确认需求
//! - 工具发现按 domain_tags 输出摘要并按需展开 schema

mod context;
mod date_calculator;
mod definition;
mod definition_info;
mod disclosure;
mod discovery;
mod gateway_execution_context;
mod gateway_observer;
mod gateway_result;
mod metadata;
mod registry;
mod result;
mod risk_level;
mod shared_gateway_observer;

pub use context::AiToolContext;
pub use date_calculator::DateCalculatorTool;
pub use definition::AiToolDefinition;
pub use definition_info::ToolDefinitionInfo;
pub use disclosure::{
    DisclosureConfig, DisclosureDecision, DisclosureReason, ToolDisclosurePolicy,
};
pub use discovery::{ToolGroupSchema, ToolGroupSummary, ToolsetGroupSummary};
pub use gateway_execution_context::ToolGatewayExecutionContext;
pub use gateway_observer::AiToolGatewayObserver;
pub use gateway_result::ToolGatewayResult;
pub use metadata::AiToolMetadata;
pub use registry::ToolRegistry;
pub use result::AiToolResult;
pub use risk_level::AiToolRiskLevel;
pub use shared_gateway_observer::SharedToolGatewayObserver;
