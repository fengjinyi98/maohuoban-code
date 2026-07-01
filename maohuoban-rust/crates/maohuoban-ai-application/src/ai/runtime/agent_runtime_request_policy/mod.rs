// AgentRuntimeRequestPolicy Runtime 请求策略
// 核心职责：
// - 根据 Workbench 决定本轮可见工具集合
// - 根据模型阶段选择 Provider 兼容的输出约束

use maohuoban_ai_domain::ai::{
    AgentSessionState, AgentSessionWorkbench, LlmToolSchema, ToolFactSchema, Toolset,
};
use uuid::Uuid;

use crate::ai::skill::{
    BuiltinSkillRuntime, SkillBundle, SkillDiagnosticsSnapshot, SkillRuntimeDiagnostics,
};
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
        let base_visible_tools = Self::base_visible_tool_definitions(registry, state);
        let skill_bundle = state.workbench.as_ref().map_or_else(
            || SkillBundle::from_active_skills(Vec::new()),
            |workbench| {
                let available_toolsets = base_visible_tools
                    .iter()
                    .map(|tool| tool.toolset)
                    .collect::<Vec<_>>();
                BuiltinSkillRuntime::match_workbench(workbench, available_toolsets)
            },
        );
        Self::record_skill_match(state, &skill_bundle);

        Self::visible_tool_schemas_for_bundle(base_visible_tools, &skill_bundle)
    }

    /// base_visible_tool_definitions 返回 Workbench 基础授权后的工具定义
    /// 核心职责：
    /// - 先按 Runtime 上下文收缩工具集合
    /// - 为 skill 匹配和最终 schema 投影提供同一组基础输入
    pub(crate) fn base_visible_tool_definitions(
        registry: &ToolRegistry,
        state: &AgentSessionState,
    ) -> Vec<ToolDefinitionInfo> {
        registry
            .list_definitions()
            .into_iter()
            .filter(|tool| Self::tool_visible_for_workbench(tool, state.workbench.as_ref()))
            .collect()
    }

    /// visible_tool_schemas_for_bundle 用同一个 SkillBundle 投影工具 schema
    /// 核心职责：
    /// - 让 prompt skill 匹配与工具可见性共享同一轮匹配结果
    /// - 保持 skill policy 只能收缩或排序基础可见工具
    pub(crate) fn visible_tool_schemas_for_bundle(
        base_visible_tools: Vec<ToolDefinitionInfo>,
        skill_bundle: &SkillBundle,
    ) -> Vec<LlmToolSchema> {
        skill_bundle
            .toolset_policy
            .apply_to_tool_definitions(base_visible_tools)
            .into_iter()
            .map(|tool| LlmToolSchema {
                name: tool.name,
                description: Self::model_visible_tool_description(
                    &tool.description,
                    tool.result_fact_schema.as_ref(),
                ),
                parameters: tool.parameters,
            })
            .collect()
    }

    /// record_skill_match 记录本轮 skill 匹配诊断
    /// 核心职责：
    /// - 统一记录 active skill、toolset policy 和 workflow policy
    /// - 允许 runtime 在无模型工具投影阶段也记录 workflow skill
    pub(crate) fn record_skill_match(state: &AgentSessionState, bundle: &SkillBundle) {
        Self::record_skill_match_internal(state, bundle);
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

        if Self::is_private_toolset(tool) {
            return false;
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

    fn is_private_toolset(tool: &ToolDefinitionInfo) -> bool {
        matches!(tool.toolset, Toolset::PrivatePetContext)
    }

    fn model_visible_tool_description(
        description: &str,
        fact_schema: Option<&ToolFactSchema>,
    ) -> String {
        let Some(schema) = fact_schema else {
            return description.to_owned();
        };

        let mut parts = vec![description.to_owned()];
        if !schema.description.is_empty() {
            parts.push(format!("可返回事实: {}", schema.description));
        }
        if !schema.natural_language_summary.is_empty() {
            parts.push(schema.natural_language_summary.clone());
        }
        for field in &schema.fields {
            let mut field_text = format!("{}: {}", field.label, field.meaning);
            if !field.example_queries.is_empty() {
                field_text.push_str("；典型问法: ");
                field_text.push_str(&field.example_queries.join("、"));
            }
            parts.push(field_text);
        }
        parts.join("。")
    }

    fn record_skill_match_internal(state: &AgentSessionState, bundle: &SkillBundle) {
        let Some(turn_id) = state.current_turn_id else {
            return;
        };
        let message_id = state
            .current_turn_diagnostics_message_id
            .unwrap_or_else(Uuid::nil);
        let snapshot =
            SkillDiagnosticsSnapshot::new(state.chat_session_id, turn_id, message_id, bundle);
        SkillRuntimeDiagnostics::record_matched(&snapshot);
    }
}
