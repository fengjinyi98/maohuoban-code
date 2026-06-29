// AgentRuntimeRequestPolicy Runtime 请求策略
// 核心职责：
// - 根据 Workbench 决定本轮可见工具集合
// - 根据模型阶段选择结构化输出约束

use maohuoban_ai_domain::ai::{AgentSessionState, AgentSessionWorkbench, LlmToolSchema};

use crate::ai::tools::{ToolDefinitionInfo, ToolRegistry};

/// AgentRuntimeRequestPolicy Runtime 请求策略
/// 核心职责：
/// - 隔离工具可见性和 response_format 选择规则
/// - 避免 LoopEngine 主流程继续膨胀
pub(super) struct AgentRuntimeRequestPolicy;

impl AgentRuntimeRequestPolicy {
    /// visible_tool_schemas 返回本轮可投影给模型的工具 schema
    /// 核心职责：
    /// - 无私域上下文时隐藏宠物私域读取工具
    /// - 保留未携带 Workbench 的旧路径兼容行为
    pub(super) fn visible_tool_schemas(
        registry: &ToolRegistry,
        state: &AgentSessionState,
    ) -> Vec<LlmToolSchema> {
        registry
            .list_definitions()
            .into_iter()
            .filter(|tool| Self::tool_visible_for_workbench(tool, state.workbench.as_ref()))
            .map(|tool| LlmToolSchema {
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters,
            })
            .collect()
    }

    /// response_format_for_model_phase 选择本轮模型输出约束
    /// 核心职责：
    /// - 工具规划阶段保留模型原生 tool calling 能力
    /// - 最终回答阶段才要求结构化 JSON，供 UI 稳定消费
    pub(super) fn response_format_for_model_phase(
        is_followup_answer: bool,
        no_visible_tools: bool,
    ) -> Option<serde_json::Value> {
        if is_followup_answer || no_visible_tools {
            Some(serde_json::json!({ "type": "json_object" }))
        } else {
            None
        }
    }

    fn tool_visible_for_workbench(
        tool: &ToolDefinitionInfo,
        workbench: Option<&AgentSessionWorkbench>,
    ) -> bool {
        let Some(workbench) = workbench else {
            return true;
        };

        if Self::workbench_has_private_context(workbench) {
            return true;
        }

        !Self::is_private_pet_tool(tool)
    }

    fn workbench_has_private_context(workbench: &AgentSessionWorkbench) -> bool {
        workbench.context_pack.has_private_context()
    }

    fn is_private_pet_tool(tool: &ToolDefinitionInfo) -> bool {
        tool.scope.starts_with("pet.")
            || tool.domain_tags.iter().any(|tag| {
                matches!(
                    tag.as_str(),
                    "identity" | "diet" | "inventory" | "diet_confirmation"
                )
            })
    }
}
