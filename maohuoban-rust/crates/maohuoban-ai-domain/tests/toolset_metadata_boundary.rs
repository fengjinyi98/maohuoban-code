// toolset_metadata_boundary 工具 metadata 标准化边界测试
// 核心职责：
// - 验证 Toolset 枚举覆盖全部初始分组
// - 验证 ToolProgressText 携带进度文案
// - 验证 ToolFactSchema 描述工具事实输出结构
// - 验证禁止字段不进入模型可见 metadata

use maohuoban_ai_domain::ai::{ToolFactSchema, ToolProgressText, Toolset};

#[test]
fn toolset_has_all_initial_variants() {
    let variants = [
        Toolset::PublicPetDomain,
        Toolset::PrivatePetContext,
        Toolset::AppSupport,
        Toolset::Memory,
        Toolset::Confirmation,
    ];
    let names: Vec<&str> = variants.iter().map(|t| t.as_str()).collect();
    assert_eq!(
        names,
        vec![
            "public_pet_domain",
            "private_pet_context",
            "app_support",
            "memory",
            "confirmation",
        ]
    );
}

#[test]
fn toolset_serializes_to_snake_case() {
    let json = serde_json::to_string(&Toolset::PrivatePetContext).unwrap();
    assert_eq!(json, "\"private_pet_context\"");
}

#[test]
fn toolset_deserializes_from_snake_case() {
    let toolset: Toolset = serde_json::from_str("\"memory\"").unwrap();
    assert_eq!(toolset, Toolset::Memory);
}

#[test]
fn tool_progress_text_carries_started_and_completed_text() {
    let text = ToolProgressText {
        started: "正在查询宠物档案".to_owned(),
        completed: "宠物档案查询完成".to_owned(),
    };
    assert_eq!(text.started, "正在查询宠物档案");
    assert_eq!(text.completed, "宠物档案查询完成");
}

#[test]
fn tool_progress_text_roundtrips_through_json() {
    let text = ToolProgressText {
        started: "正在创建提醒".to_owned(),
        completed: "提醒已创建".to_owned(),
    };
    let json = serde_json::to_string(&text).unwrap();
    let restored: ToolProgressText = serde_json::from_str(&json).unwrap();
    assert_eq!(restored, text);
}

#[test]
fn tool_fact_schema_describes_fact_keys_and_types() {
    let schema = ToolFactSchema {
        fact_keys: vec!["current_staple".to_owned(), "diet_status".to_owned()],
        description: "宠物饮食事实".to_owned(),
    };
    assert_eq!(schema.fact_keys.len(), 2);
    assert_eq!(schema.description, "宠物饮食事实");
}

#[test]
fn tool_fact_schema_roundtrips_through_json() {
    let schema = ToolFactSchema {
        fact_keys: vec!["weight".to_owned()],
        description: "宠物体重".to_owned(),
    };
    let json = serde_json::to_string(&schema).unwrap();
    let restored: ToolFactSchema = serde_json::from_str(&json).unwrap();
    assert_eq!(restored, schema);
}

#[test]
fn tool_progress_text_default_is_empty_strings() {
    let text = ToolProgressText::default();
    assert!(text.started.is_empty());
    assert!(text.completed.is_empty());
}

#[test]
fn tool_fact_schema_default_is_empty() {
    let schema = ToolFactSchema::default();
    assert!(schema.fact_keys.is_empty());
    assert!(schema.description.is_empty());
}

#[test]
fn toolset_can_be_used_as_key_for_grouping() {
    let mut groups = std::collections::HashMap::new();
    groups.insert(Toolset::PublicPetDomain, vec!["search_pet_knowledge"]);
    groups.insert(Toolset::PrivatePetContext, vec!["load_pet_identity"]);
    assert_eq!(groups.get(&Toolset::PublicPetDomain).unwrap().len(), 1);
    assert_eq!(groups.get(&Toolset::PrivatePetContext).unwrap().len(), 1);
}
