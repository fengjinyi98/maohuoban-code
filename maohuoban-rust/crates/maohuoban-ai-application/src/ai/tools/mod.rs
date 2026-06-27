//! tools Agent Gateway 工具注册与执行
//! 核心职责：
//! - 工具白名单管理，未注册工具调用被拒绝
//! - 工具执行时注入 actor_user_id 和 authorized_pet_id，强制权限校验
//! - 工具输出裁剪为事实条目和引用，不返回底层兼容字段

use std::collections::HashMap;
use std::sync::Arc;

use maohuoban_ai_domain::ai::{AiCitation, AiFactEntry};

/// AiToolContext 工具执行上下文
/// 核心职责：
/// - 注入认证后的 actor_user_id 和授权目标 pet_id
/// - 工具只能通过该上下文获取用户身份，不能信任请求体传入的 actor
#[derive(Debug, Clone)]
pub struct AiToolContext {
    pub actor_user_id: uuid::Uuid,
    pub authorized_pet_id: uuid::Uuid,
}

/// AiToolResult 工具执行结果
/// 核心职责：
/// - 表达工具调用的授权状态、返回事实条目和引用
/// - 未授权时不泄露宠物名、食品名或存在性细节
#[derive(Debug, Clone)]
pub struct AiToolResult {
    pub allowed: bool,
    pub denied_reason: Option<String>,
    pub failed_reason: Option<String>,
    pub facts: Vec<AiFactEntry>,
    pub citations: Vec<AiCitation>,
    pub returned_ref_ids: Vec<String>,
}

impl AiToolResult {
    /// allowed 构造允许且无事实返回的结果
    #[must_use]
    pub fn allowed(ref_ids: Vec<String>) -> Self {
        Self {
            allowed: true,
            denied_reason: None,
            failed_reason: None,
            facts: Vec::new(),
            citations: Vec::new(),
            returned_ref_ids: ref_ids,
        }
    }

    /// allowed_with_facts 构造允许且携带事实和引用的结果
    #[must_use]
    pub fn allowed_with_facts(facts: Vec<AiFactEntry>, citations: Vec<AiCitation>) -> Self {
        let ref_ids: Vec<String> = citations.iter().map(|c| c.source_id.to_string()).collect();
        Self {
            allowed: true,
            denied_reason: None,
            failed_reason: None,
            facts,
            citations,
            returned_ref_ids: ref_ids,
        }
    }

    /// denied 构造拒绝结果
    #[must_use]
    pub fn denied(reason: &str) -> Self {
        Self {
            allowed: false,
            denied_reason: Some(reason.to_owned()),
            failed_reason: None,
            facts: Vec::new(),
            citations: Vec::new(),
            returned_ref_ids: Vec::new(),
        }
    }

    /// failed 构造工具执行失败结果
    #[must_use]
    pub fn failed(reason: &str) -> Self {
        Self {
            allowed: false,
            denied_reason: None,
            failed_reason: Some(reason.to_owned()),
            facts: Vec::new(),
            citations: Vec::new(),
            returned_ref_ids: Vec::new(),
        }
    }
}

/// AiToolDefinition 工具定义端口
/// 核心职责：
/// - 声明工具名、描述和参数 schema
/// - 执行时接收上下文和参数，返回裁剪后的事实和引用
pub trait AiToolDefinition: Send + Sync {
    /// name 工具名
    fn name(&self) -> &str;

    /// description 工具描述
    fn description(&self) -> &str;

    /// parameters_schema 参数 JSON Schema
    fn parameters_schema(&self) -> serde_json::Value;

    /// execute 执行工具
    fn execute(&self, ctx: &AiToolContext, args: &serde_json::Value) -> AiToolResult;
}

/// ToolDefinitionInfo 工具定义信息
/// 核心职责：
/// - 用于 list_definitions 返回注册工具的元数据
#[derive(Debug, Clone)]
pub struct ToolDefinitionInfo {
    pub name: String,
    pub description: String,
    pub parameters: serde_json::Value,
}

/// ToolRegistry 工具注册表
/// 核心职责：
/// - 管理工具白名单，拒绝未注册工具调用
/// - 执行已注册工具并返回裁剪后结果
pub struct ToolRegistry {
    tools: HashMap<String, Arc<dyn AiToolDefinition>>,
}

impl ToolRegistry {
    /// new 构造空工具注册表
    #[must_use]
    pub fn new() -> Self {
        Self {
            tools: HashMap::new(),
        }
    }

    /// register 注册工具
    pub fn register(&mut self, tool: impl AiToolDefinition + 'static) {
        let name = tool.name().to_owned();
        self.tools.insert(name, Arc::new(tool));
    }

    /// call 调用已注册工具
    /// 核心职责：
    /// - 未注册工具返回 denied
    /// - 已注册工具执行并返回结果
    #[must_use]
    pub fn call(
        &self,
        tool_name: &str,
        ctx: &AiToolContext,
        args: &serde_json::Value,
    ) -> AiToolResult {
        match self.tools.get(tool_name) {
            Some(tool) => tool.execute(ctx, args),
            None => AiToolResult::denied(&format!("unknown tool: {tool_name}")),
        }
    }

    /// list_definitions 返回所有注册工具的元数据
    #[must_use]
    pub fn list_definitions(&self) -> Vec<ToolDefinitionInfo> {
        self.tools
            .values()
            .map(|t| ToolDefinitionInfo {
                name: t.name().to_owned(),
                description: t.description().to_owned(),
                parameters: t.parameters_schema(),
            })
            .collect()
    }
}

impl Default for ToolRegistry {
    fn default() -> Self {
        Self::new()
    }
}
