// tool_disclosure 渐进工具披露策略测试
// 核心职责：
// - 验证核心工具常驻 schema，长尾工具按需描述
// - 验证 tool_search 按关键词搜索长尾工具
// - 验证 tool_describe 返回指定工具完整 schema
// - 验证未注册工具搜索/describe 返回空或错误

use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
    DisclosureConfig, DisclosureReason, ToolDisclosurePolicy, ToolRegistry,
};
use maohuoban_ai_domain::ai::{ToolProgressText, Toolset};
use serde_json::json;

// ---- 测试用桩工具 ----

struct CoreTool;

#[async_trait]
impl AiToolDefinition for CoreTool {
    fn name(&self) -> &'static str {
        "load_pet_identity_context"
    }
    fn description(&self) -> &'static str {
        "加载宠物身份上下文"
    }
    fn parameters_schema(&self) -> serde_json::Value {
        json!({"type": "object", "properties": {}, "required": []})
    }
    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.identity.read".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["identity".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }
    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::allowed_with_facts(Vec::new(), Vec::new())
    }
}

struct LongTailDietTool;

#[async_trait]
impl AiToolDefinition for LongTailDietTool {
    fn name(&self) -> &'static str {
        "search_diet_recommendations"
    }
    fn description(&self) -> &'static str {
        "搜索饮食推荐"
    }
    fn parameters_schema(&self) -> serde_json::Value {
        json!({"type": "object", "properties": {"query": {"type": "string"}}, "required": ["query"]})
    }
    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.diet.search".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["diet".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }
    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::allowed_with_facts(Vec::new(), Vec::new())
    }
}

struct LongTailHealthTool;

#[async_trait]
impl AiToolDefinition for LongTailHealthTool {
    fn name(&self) -> &'static str {
        "check_health_symptoms"
    }
    fn description(&self) -> &'static str {
        "检查健康症状"
    }
    fn parameters_schema(&self) -> serde_json::Value {
        json!({"type": "object", "properties": {"symptom": {"type": "string"}}, "required": ["symptom"]})
    }
    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.health.check".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Medium,
            requires_confirmation: false,
            domain_tags: vec!["health".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }
    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::allowed_with_facts(Vec::new(), Vec::new())
    }
}

fn registry_with_mixed_tools() -> ToolRegistry {
    let mut registry = ToolRegistry::new();
    registry.register(CoreTool);
    registry.register(LongTailDietTool);
    registry.register(LongTailHealthTool);
    registry
}

fn registry_with_many_tools(count: usize) -> ToolRegistry {
    let mut registry = ToolRegistry::new();
    for i in 0..count {
        registry.register(StubTool::new(
            &format!("tool_{i}"),
            &format!("pet.domain_{i}.read"),
        ));
    }
    registry
}

struct StubTool {
    name: String,
    scope: String,
}

impl StubTool {
    fn new(name: &str, scope: &str) -> Self {
        Self {
            name: name.to_owned(),
            scope: scope.to_owned(),
        }
    }
}

#[async_trait]
impl AiToolDefinition for StubTool {
    fn name(&self) -> &'static str {
        Box::leak(self.name.clone().into_boxed_str())
    }
    fn description(&self) -> &'static str {
        "stub tool for disclosure evaluation"
    }
    fn parameters_schema(&self) -> serde_json::Value {
        json!({"type": "object", "properties": {}, "required": []})
    }
    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: self.scope.clone(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["stub".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }
    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::allowed_with_facts(Vec::new(), Vec::new())
    }
}

// ---- RED 测试 ----

#[test]
fn core_tools_are_always_in_visible_schemas() {
    let registry = registry_with_mixed_tools();
    let policy = ToolDisclosurePolicy::new(&registry);

    let core = policy.core_tool_schemas();

    // 核心工具 load_pet_identity_context 应常驻
    assert!(
        core.iter().any(|t| t.name == "load_pet_identity_context"),
        "core tool should be in visible schemas"
    );
}

#[test]
fn long_tail_tools_are_not_in_default_visible_schemas() {
    let registry = registry_with_mixed_tools();
    let policy = ToolDisclosurePolicy::new(&registry);

    let core = policy.core_tool_schemas();

    // 长尾工具不应出现在默认 schema 中
    assert!(
        !core.iter().any(|t| t.name == "search_diet_recommendations"),
        "long-tail diet tool should not be in default schemas"
    );
    assert!(
        !core.iter().any(|t| t.name == "check_health_symptoms"),
        "long-tail health tool should not be in default schemas"
    );
}

#[test]
fn tool_search_finds_long_tail_by_keyword() {
    let registry = registry_with_mixed_tools();
    let policy = ToolDisclosurePolicy::new(&registry);

    // 搜索 "diet" 应找到饮食推荐工具
    let results = policy.search_tools("diet");
    assert!(
        results
            .iter()
            .any(|t| t.name == "search_diet_recommendations"),
        "search 'diet' should find diet tool"
    );
    // 核心工具不应出现在搜索结果中
    assert!(
        !results
            .iter()
            .any(|t| t.name == "load_pet_identity_context"),
        "search should not return core tools"
    );
}

#[test]
fn tool_search_finds_by_domain_tag() {
    let registry = registry_with_mixed_tools();
    let policy = ToolDisclosurePolicy::new(&registry);

    let results = policy.search_tools("health");
    assert!(
        results.iter().any(|t| t.name == "check_health_symptoms"),
        "search 'health' should find health tool"
    );
}

#[test]
fn tool_search_returns_empty_for_no_match() {
    let registry = registry_with_mixed_tools();
    let policy = ToolDisclosurePolicy::new(&registry);

    let results = policy.search_tools("nonexistent_domain");
    assert!(
        results.is_empty(),
        "search with no match should return empty"
    );
}

#[test]
fn tool_describe_returns_full_schema_for_registered_tool() {
    let registry = registry_with_mixed_tools();
    let policy = ToolDisclosurePolicy::new(&registry);

    let schema = policy.describe_tool("search_diet_recommendations");
    assert!(
        schema.is_some(),
        "describe should return schema for registered tool"
    );

    let schema = schema.unwrap();
    assert_eq!(schema.name, "search_diet_recommendations");
    assert_eq!(schema.description, "搜索饮食推荐");
    assert!(schema.parameters.get("properties").is_some());
}

#[test]
fn tool_describe_returns_none_for_unknown_tool() {
    let registry = registry_with_mixed_tools();
    let policy = ToolDisclosurePolicy::new(&registry);

    let schema = policy.describe_tool("nonexistent_tool");
    assert!(
        schema.is_none(),
        "describe should return None for unknown tool"
    );
}

// ---- 披露评估测试 ----

#[test]
fn evaluate_disclosure_not_activated_when_few_tools() {
    let registry = registry_with_mixed_tools();
    let policy = ToolDisclosurePolicy::new(&registry);

    let decision = policy.evaluate_disclosure();

    assert!(
        !decision.activated,
        "3 tools should not activate disclosure"
    );
    assert_eq!(decision.reason, DisclosureReason::NotActivated);
    assert_eq!(decision.total_tools, 3);
    assert_eq!(decision.core_tools, 1);
    assert_eq!(decision.long_tail_tools, 2);
    assert!(decision.estimated_schema_tokens > 0);
}

#[test]
fn evaluate_disclosure_activated_when_tool_count_exceeds_threshold() {
    let registry = registry_with_many_tools(10);
    let config = DisclosureConfig {
        max_core_tools: 4,
        schema_token_budget: 100_000,
        ..Default::default()
    };
    let policy = ToolDisclosurePolicy::with_config(&registry, config);

    let decision = policy.evaluate_disclosure();

    assert!(
        decision.activated,
        "10 tools > max_core_tools(4) should activate"
    );
    assert_eq!(decision.reason, DisclosureReason::ToolCountExceedsThreshold);
    assert_eq!(decision.total_tools, 10);
}

#[test]
fn evaluate_disclosure_activated_when_token_budget_exceeded() {
    let registry = registry_with_mixed_tools();
    let config = DisclosureConfig {
        max_core_tools: 100,
        schema_token_budget: 1,
        ..Default::default()
    };
    let policy = ToolDisclosurePolicy::with_config(&registry, config);

    let decision = policy.evaluate_disclosure();

    assert!(decision.activated, "token budget=1 should be exceeded");
    assert_eq!(decision.reason, DisclosureReason::TokenBudgetExceeded);
}

#[test]
fn evaluate_disclosure_activated_when_both_thresholds_exceeded() {
    let registry = registry_with_many_tools(12);
    let config = DisclosureConfig {
        max_core_tools: 4,
        schema_token_budget: 1,
        ..Default::default()
    };
    let policy = ToolDisclosurePolicy::with_config(&registry, config);

    let decision = policy.evaluate_disclosure();

    assert!(decision.activated);
    assert_eq!(
        decision.reason,
        DisclosureReason::BothToolCountAndTokenBudget
    );
}

#[test]
fn with_config_custom_core_names_override_scope_suffix() {
    let registry = registry_with_mixed_tools();
    let config = DisclosureConfig {
        always_core_names: vec!["search_diet_recommendations".to_owned()],
        ..Default::default()
    };
    let policy = ToolDisclosurePolicy::with_config(&registry, config);

    let core = policy.core_tool_schemas();

    // 显式命名的长尾工具应进入核心列表
    assert!(
        core.iter().any(|t| t.name == "search_diet_recommendations"),
        "explicitly named tool should be core"
    );
    // scope 后缀匹配的工具仍在核心列表
    assert!(
        core.iter().any(|t| t.name == "load_pet_identity_context"),
        "scope-suffix-matched tool should still be core"
    );
}

#[test]
fn with_config_custom_scope_suffixes() {
    let registry = registry_with_mixed_tools();
    let config = DisclosureConfig {
        core_scope_suffixes: vec![".search".to_owned()],
        ..Default::default()
    };
    let policy = ToolDisclosurePolicy::with_config(&registry, config);

    let core = policy.core_tool_schemas();

    // .search 后缀的工具进入核心
    assert!(
        core.iter().any(|t| t.name == "search_diet_recommendations"),
        ".search suffix tool should be core"
    );
    // .read 后缀的工具不再匹配
    assert!(
        !core.iter().any(|t| t.name == "load_pet_identity_context"),
        ".read suffix tool should not be core with custom suffixes"
    );
}
