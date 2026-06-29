use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::sync::Arc;

use maohuoban_ai_domain::ai::Toolset;

use crate::ai::policy::{PolicyDecision, PolicyGuard};

use super::{
    AiToolContext, AiToolDefinition, AiToolResult, ToolDefinitionInfo, ToolGroupSchema,
    ToolGroupSummary, ToolsetGroupSummary,
};

/// ToolRegistry 工具注册表
/// 核心职责：
/// - 管理工具白名单，拒绝未注册工具调用
/// - 工具调用前经过 PolicyGuard，再返回裁剪后结果或确认需求
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

    /// get 获取已注册工具
    pub(crate) fn get(&self, tool_name: &str) -> Option<Arc<dyn AiToolDefinition>> {
        self.tools.get(tool_name).cloned()
    }

    /// call 调用已注册工具
    /// 核心职责：
    /// - 未注册工具返回 denied
    /// - 已注册工具先通过 PolicyGuard 裁决，再执行或返回确认需求
    #[must_use]
    pub async fn call(
        &self,
        tool_name: &str,
        ctx: &AiToolContext,
        args: &serde_json::Value,
    ) -> AiToolResult {
        let Some(tool) = self.tools.get(tool_name) else {
            return AiToolResult::denied(&format!("unknown tool: {tool_name}"));
        };

        match PolicyGuard.evaluate_tool(tool_name, &tool.metadata(), ctx, args) {
            PolicyDecision::Allow => tool.execute(ctx, args).await,
            PolicyDecision::Deny { reason } => AiToolResult::denied(&reason),
            PolicyDecision::Transform { args } => tool.execute(ctx, &args).await,
            PolicyDecision::RequireConfirmation { confirmation } => {
                AiToolResult::requires_confirmation(confirmation)
            }
            PolicyDecision::Terminate { reason } => AiToolResult::failed(&reason),
        }
    }

    /// list_definitions 返回所有注册工具的元数据
    #[must_use]
    pub fn list_definitions(&self) -> Vec<ToolDefinitionInfo> {
        self.tools
            .values()
            .map(|tool| {
                let metadata = tool.metadata();
                let requires_confirmation =
                    effective_requires_confirmation(metadata.read_only, metadata.risk_level);
                ToolDefinitionInfo {
                    name: tool.name().to_owned(),
                    description: tool.description().to_owned(),
                    parameters: tool.parameters_schema(),
                    scope: metadata.scope,
                    declared_requires_confirmation: metadata.requires_confirmation,
                    read_only: metadata.read_only,
                    concurrency_safe: metadata.concurrency_safe,
                    risk_level: metadata.risk_level,
                    requires_confirmation,
                    domain_tags: metadata.domain_tags,
                    toolset: metadata.toolset,
                    progress_text: metadata.progress_text,
                    result_fact_schema: metadata.result_fact_schema,
                }
            })
            .collect()
    }

    /// list_by_toolset 按 toolset 分组过滤工具
    /// 核心职责：
    /// - 返回指定 toolset 下的全部工具定义
    /// - 供 TurnContextBuilder 按 toolset + 权限 + selected pet 组装工具清单
    #[must_use]
    pub fn list_by_toolset(&self, toolset: Toolset) -> Vec<ToolDefinitionInfo> {
        self.list_definitions()
            .into_iter()
            .filter(|tool| tool.toolset == toolset)
            .collect()
    }

    /// list_toolset_groups 返回按 toolset 分组的摘要
    /// 核心职责：
    /// - 汇总每个 toolset 下的工具数量和名称
    /// - 供模型工具目录展示和调试
    #[must_use]
    pub fn list_toolset_groups(&self) -> Vec<ToolsetGroupSummary> {
        let mut groups: BTreeMap<Toolset, Vec<String>> = BTreeMap::new();
        for tool in self.tools.values() {
            let toolset = tool.metadata().toolset;
            groups
                .entry(toolset)
                .or_default()
                .push(tool.name().to_owned());
        }

        groups
            .into_iter()
            .map(|(toolset, mut tool_names)| {
                tool_names.sort();
                ToolsetGroupSummary {
                    toolset,
                    tool_count: tool_names.len(),
                    tool_names,
                }
            })
            .collect()
    }

    /// list_tool_groups 返回按 domain_tags 汇总的工具组摘要
    #[must_use]
    pub fn list_tool_groups(&self) -> Vec<ToolGroupSummary> {
        let mut groups: BTreeMap<String, Vec<String>> = BTreeMap::new();
        for tool in self.tools.values() {
            let tags: BTreeSet<String> = tool.metadata().domain_tags.into_iter().collect();
            for tag in tags {
                groups.entry(tag).or_default().push(tool.name().to_owned());
            }
        }

        groups
            .into_iter()
            .map(|(group, mut tool_names)| {
                tool_names.sort();
                ToolGroupSummary {
                    group,
                    tool_count: tool_names.len(),
                    tool_names,
                }
            })
            .collect()
    }

    /// expand_tool_group 按需展开指定工具组 schema
    #[must_use]
    pub fn expand_tool_group(&self, group: &str) -> Option<ToolGroupSchema> {
        let mut tools: Vec<ToolDefinitionInfo> = self
            .list_definitions()
            .into_iter()
            .filter(|tool| tool.domain_tags.iter().any(|tag| tag == group))
            .collect();

        if tools.is_empty() {
            return None;
        }

        tools.sort_by(|lhs, rhs| lhs.name.cmp(&rhs.name));
        Some(ToolGroupSchema {
            group: group.to_owned(),
            tools,
        })
    }
}

/// effective_requires_confirmation 计算工具的有效确认门槛
/// 核心职责：
/// - 把声明值和执行规则折叠为统一的发现结果
/// - 让 discovery 和 execution 对确认门槛保持一致
#[must_use]
fn effective_requires_confirmation(read_only: bool, risk_level: super::AiToolRiskLevel) -> bool {
    !read_only
        || matches!(
            risk_level,
            super::AiToolRiskLevel::High | super::AiToolRiskLevel::Critical
        )
}

impl Default for ToolRegistry {
    fn default() -> Self {
        Self::new()
    }
}
