// tool_metadata_standardization 工具 metadata 标准化测试
// 核心职责：
// - 验证 AiToolMetadata 携带 toolset、progress_text、result_fact_schema
// - 验证 ToolDefinitionInfo 透传新字段
// - 验证 ToolRegistry 按 toolset 分组过滤
// - 验证前端不需要根据工具名映射进度文案

use async_trait::async_trait;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel, ToolRegistry,
};
use maohuoban_ai_domain::ai::{ToolFactSchema, ToolProgressText, Toolset};
use serde_json::json;

/// `FakeKnowledgeTool` 公共宠物知识查询工具
struct FakeKnowledgeTool;

#[async_trait]
impl AiToolDefinition for FakeKnowledgeTool {
    fn name(&self) -> &'static str {
        "search_pet_knowledge"
    }
    fn description(&self) -> &'static str {
        "搜索公共宠物知识库"
    }
    fn parameters_schema(&self) -> serde_json::Value {
        json!({"type": "object"})
    }
    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "public.knowledge.read".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["knowledge".to_owned()],
            toolset: Toolset::PublicPetDomain,
            progress_text: ToolProgressText {
                started: "正在搜索宠物知识".to_owned(),
                completed: "知识搜索完成".to_owned(),
            },
            result_fact_schema: Some(ToolFactSchema {
                fact_keys: vec!["knowledge_summary".to_owned()],
                description: "公共宠物知识摘要".to_owned(),
                ..Default::default()
            }),
        }
    }
    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::allowed(vec![])
    }
}

/// `FakePrivatePetTool` 私域宠物上下文工具
struct FakePrivatePetTool;

#[async_trait]
impl AiToolDefinition for FakePrivatePetTool {
    fn name(&self) -> &'static str {
        "load_pet_identity_context"
    }
    fn description(&self) -> &'static str {
        "加载宠物身份上下文"
    }
    fn parameters_schema(&self) -> serde_json::Value {
        json!({"type": "object"})
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
            progress_text: ToolProgressText {
                started: "正在加载宠物档案".to_owned(),
                completed: "宠物档案加载完成".to_owned(),
            },
            result_fact_schema: Some(ToolFactSchema {
                fact_keys: vec!["pet_name".to_owned(), "pet_species".to_owned()],
                description: "宠物身份事实".to_owned(),
                ..Default::default()
            }),
        }
    }
    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::allowed(vec![])
    }
}

/// `FakeMemoryTool` 记忆工具
struct FakeMemoryTool;

#[async_trait]
impl AiToolDefinition for FakeMemoryTool {
    fn name(&self) -> &'static str {
        "save_memory"
    }
    fn description(&self) -> &'static str {
        "保存用户偏好记忆"
    }
    fn parameters_schema(&self) -> serde_json::Value {
        json!({"type": "object"})
    }
    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "memory.write".to_owned(),
            read_only: false,
            concurrency_safe: false,
            risk_level: AiToolRiskLevel::Medium,
            requires_confirmation: false,
            domain_tags: vec!["memory".to_owned()],
            toolset: Toolset::Memory,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }
    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::allowed(vec![])
    }
}

#[test]
fn tool_metadata_carries_toolset_field() {
    let mut registry = ToolRegistry::new();
    registry.register(FakeKnowledgeTool);
    registry.register(FakePrivatePetTool);

    let tools = registry.list_definitions();
    let knowledge = tools
        .iter()
        .find(|t| t.name == "search_pet_knowledge")
        .unwrap();
    assert_eq!(knowledge.toolset, Toolset::PublicPetDomain);

    let pet = tools
        .iter()
        .find(|t| t.name == "load_pet_identity_context")
        .unwrap();
    assert_eq!(pet.toolset, Toolset::PrivatePetContext);
}

#[test]
fn tool_definition_info_exposes_progress_text() {
    let mut registry = ToolRegistry::new();
    registry.register(FakeKnowledgeTool);

    let tools = registry.list_definitions();
    let tool = &tools[0];
    assert_eq!(tool.progress_text.started, "正在搜索宠物知识");
    assert_eq!(tool.progress_text.completed, "知识搜索完成");
}

#[test]
fn tool_definition_info_exposes_result_fact_schema() {
    let mut registry = ToolRegistry::new();
    registry.register(FakePrivatePetTool);

    let tools = registry.list_definitions();
    let tool = &tools[0];
    let schema = tool.result_fact_schema.as_ref().unwrap();
    assert_eq!(schema.fact_keys, vec!["pet_name", "pet_species"]);
    assert_eq!(schema.description, "宠物身份事实");
}

#[test]
fn tool_definition_info_supports_none_result_fact_schema() {
    let mut registry = ToolRegistry::new();
    registry.register(FakeMemoryTool);

    let tools = registry.list_definitions();
    let tool = &tools[0];
    assert!(tool.result_fact_schema.is_none());
}

#[test]
fn registry_filters_tools_by_toolset() {
    let mut registry = ToolRegistry::new();
    registry.register(FakeKnowledgeTool);
    registry.register(FakePrivatePetTool);
    registry.register(FakeMemoryTool);

    let public_tools = registry.list_by_toolset(Toolset::PublicPetDomain);
    assert_eq!(public_tools.len(), 1);
    assert_eq!(public_tools[0].name, "search_pet_knowledge");

    let private_tools = registry.list_by_toolset(Toolset::PrivatePetContext);
    assert_eq!(private_tools.len(), 1);
    assert_eq!(private_tools[0].name, "load_pet_identity_context");

    let memory_tools = registry.list_by_toolset(Toolset::Memory);
    assert_eq!(memory_tools.len(), 1);
    assert_eq!(memory_tools[0].name, "save_memory");

    let confirmation_tools = registry.list_by_toolset(Toolset::Confirmation);
    assert!(confirmation_tools.is_empty());
}

#[test]
fn registry_lists_all_toolset_groups() {
    let mut registry = ToolRegistry::new();
    registry.register(FakeKnowledgeTool);
    registry.register(FakePrivatePetTool);
    registry.register(FakeMemoryTool);

    let groups = registry.list_toolset_groups();
    assert_eq!(groups.len(), 3);
    let toolsets: Vec<Toolset> = groups.iter().map(|g| g.toolset).collect();
    assert!(toolsets.contains(&Toolset::PublicPetDomain));
    assert!(toolsets.contains(&Toolset::PrivatePetContext));
    assert!(toolsets.contains(&Toolset::Memory));
}

#[test]
fn progress_text_comes_from_metadata_not_tool_name() {
    let mut registry = ToolRegistry::new();
    registry.register(FakeKnowledgeTool);
    registry.register(FakePrivatePetTool);

    let tools = registry.list_definitions();
    for tool in &tools {
        assert!(
            !tool.progress_text.started.is_empty() || !tool.progress_text.completed.is_empty(),
            "tool {} must have progress text from metadata",
            tool.name
        );
    }
}
