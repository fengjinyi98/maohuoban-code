// AgentRuntimeRequestPolicy Runtime 请求策略
// 核心职责：
// - 根据 Workbench 决定本轮可见工具集合
// - 根据模型阶段选择 Provider 兼容的输出约束

use maohuoban_ai_domain::ai::{AgentSessionState, AgentSessionWorkbench, LlmToolSchema, Toolset};

use crate::ai::tools::{ToolDefinitionInfo, ToolRegistry};

/// AgentRuntimeRequestPolicy Runtime 请求策略
/// 核心职责：
/// - 隔离工具可见性和 response_format 选择规则
/// - 避免 LoopEngine 主流程继续膨胀
pub(crate) struct AgentRuntimeRequestPolicy;

impl AgentRuntimeRequestPolicy {
    /// visible_tool_schemas 返回本轮可投影给模型的工具 schema
    /// 核心职责：
    /// - 无私域上下文时隐藏宠物私域读取工具
    /// - 保留未携带 Workbench 的旧路径兼容行为
    pub(crate) fn visible_tool_schemas(
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
    /// - 最终回答阶段避免触发 DeepSeek JSON Output 空 content 风险
    pub(crate) fn response_format_for_model_phase(
        _is_followup_answer: bool,
        _no_visible_tools: bool,
    ) -> Option<serde_json::Value> {
        None
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

        // 优先按 toolset 判断：PrivatePetContext 工具在无私域上下文时隐藏
        if Self::is_private_toolset(tool) {
            return false;
        }

        // 兼容旧路径：scope/domain_tags 仍可过滤未声明 toolset 的工具
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

    /// is_private_toolset 按 toolset 枚举判断是否私域工具
    /// 核心职责：
    /// - PrivatePetContext 分组在无已选宠物时全部隐藏
    /// - Memory 和 Confirmation 分组在有宠物上下文时由上层控制
    fn is_private_toolset(tool: &ToolDefinitionInfo) -> bool {
        matches!(tool.toolset, Toolset::PrivatePetContext)
    }
}
