use maohuoban_ai_domain::ai::{AgentSessionState, LlmToolCall, ToolFactSchema, Toolset};
use serde_json::{Map, Value};

use crate::ai::tools::{ToolDefinitionInfo, ToolRegistry};

/// EvidencePlanner 私域事实证据规划器
/// 核心职责：
/// - 基于工具事实 schema 判断用户问题需要的私域事实
/// - 在模型回答前预取只读事实工具，降低无依据回答概率
pub(crate) struct EvidencePlanner;

impl EvidencePlanner {
    /// plan 返回本轮需要预取的工具调用
    /// 核心职责：
    /// - 只处理已选中宠物的私域上下文问题
    /// - 只选择只读、低风险、带事实 schema 的 PrivatePetContext 工具
    #[must_use]
    pub(crate) fn plan(state: &AgentSessionState, registry: &ToolRegistry) -> Vec<LlmToolCall> {
        let Some(workbench) = state.workbench.as_ref() else {
            return Vec::new();
        };
        let Some(selected_pet) = workbench.context_pack.selected_pet.as_ref() else {
            return Vec::new();
        };
        let Some(user_input) = state.user_inputs.last() else {
            return Vec::new();
        };

        registry
            .list_definitions()
            .into_iter()
            .filter(Self::is_prefetchable_fact_tool)
            .filter(|tool| {
                tool.result_fact_schema
                    .as_ref()
                    .is_some_and(|schema| schema_matches_user_input(schema, user_input))
            })
            .take(1)
            .map(|tool| LlmToolCall {
                id: format!("evidence_{}", tool.name),
                name: tool.name.clone(),
                arguments: evidence_arguments(&tool, selected_pet.pet_id).to_string(),
            })
            .collect()
    }

    fn is_prefetchable_fact_tool(tool: &ToolDefinitionInfo) -> bool {
        tool.read_only
            && tool.risk_level == crate::ai::tools::AiToolRiskLevel::Low
            && tool.toolset == Toolset::PrivatePetContext
            && tool.result_fact_schema.is_some()
    }
}

fn schema_matches_user_input(schema: &ToolFactSchema, user_input: &str) -> bool {
    let normalized_input = normalize(user_input);
    let mut candidates = Vec::new();

    candidates.extend(schema.fact_keys.iter().cloned());
    candidates.push(schema.description.clone());
    candidates.push(schema.natural_language_summary.clone());
    for field in &schema.fields {
        candidates.push(field.label.clone());
        candidates.push(field.meaning.clone());
        candidates.extend(field.example_queries.iter().cloned());
    }

    candidates
        .into_iter()
        .map(|candidate| normalize(&candidate))
        .filter(|candidate| !candidate.is_empty())
        .any(|candidate| {
            normalized_input.contains(&candidate) || candidate.contains(&normalized_input)
        })
}

fn evidence_arguments(tool: &ToolDefinitionInfo, selected_pet_id: uuid::Uuid) -> Value {
    let required_pet_id = tool
        .parameters
        .get("required")
        .and_then(Value::as_array)
        .is_some_and(|required| required.iter().any(|item| item.as_str() == Some("pet_id")));

    if !required_pet_id {
        return Value::Object(Map::new());
    }

    let mut args = Map::new();
    args.insert(
        "pet_id".to_owned(),
        Value::String(selected_pet_id.to_string()),
    );
    Value::Object(args)
}

fn normalize(text: &str) -> String {
    text.chars()
        .filter(|ch| !ch.is_whitespace() && !is_punctuation(*ch))
        .collect::<String>()
        .to_ascii_lowercase()
}

fn is_punctuation(ch: char) -> bool {
    matches!(
        ch,
        '，' | '。'
            | '？'
            | '！'
            | '、'
            | '；'
            | '：'
            | ','
            | '.'
            | '?'
            | '!'
            | ';'
            | ':'
            | '"'
            | '\''
            | '“'
            | '”'
            | '‘'
            | '’'
    )
}
