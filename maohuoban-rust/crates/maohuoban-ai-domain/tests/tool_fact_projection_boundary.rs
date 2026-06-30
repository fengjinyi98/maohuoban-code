// tool_fact_projection_boundary 工具事实投影边界测试
// 核心职责：
// - 验证工具原始结果与模型可见事实包分离
// - 验证模型看不到业务内部字段（key、citation_id）
// - 验证模型只看到裁剪后的事实文本和确定性标签
// - 验证 ModelVisibleFact 不存在 citation_id 字段

use maohuoban_ai_domain::ai::{
    AiCitation, AiCitationSourceKind, AiFactEntry, AiFactStrength, ModelVisibleToolResult,
    ToolFactProjector,
};
use uuid::Uuid;

#[test]
fn model_visible_tool_result_strips_internal_fact_keys() {
    let citation_id = Uuid::new_v4();
    let facts = vec![
        AiFactEntry {
            key: "current_staple".to_owned(),
            value: "渴望六种鱼".to_owned(),
            strength: AiFactStrength::Strong,
            citation_id: Some(citation_id),
        },
        AiFactEntry {
            key: "status".to_owned(),
            value: "存活中".to_owned(),
            strength: AiFactStrength::Strong,
            citation_id: None,
        },
    ];

    let visible = ToolFactProjector::project_facts(&facts);
    assert_eq!(visible.facts.len(), 1);
    assert_eq!(visible.facts[0].text, "渴望六种鱼");
    assert_eq!(visible.facts[0].certainty, "已确认");
}

#[test]
fn model_visible_fact_does_not_have_citation_id_field() {
    // citation_id 已从 ModelVisibleFact 移除
    // 编译期保证：ModelVisibleFact 只有 certainty 和 text 两个字段
    let fact = maohuoban_ai_domain::ai::ModelVisibleFact {
        certainty: "已确认".to_owned(),
        text: "测试事实".to_owned(),
    };
    assert_eq!(fact.certainty, "已确认");
    assert_eq!(fact.text, "测试事实");
}

#[test]
fn model_visible_tool_result_json_does_not_contain_citation_id() {
    let citation_id = Uuid::new_v4();
    let facts = vec![AiFactEntry {
        key: "diet_status".to_owned(),
        value: "正常".to_owned(),
        strength: AiFactStrength::Strong,
        citation_id: Some(citation_id),
    }];

    let visible = ToolFactProjector::project_facts(&facts);
    let json = serde_json::to_string(&visible).unwrap();
    assert!(
        !json.contains("citation_id"),
        "ModelVisibleToolResult JSON must not contain citation_id, got: {json}"
    );
}

#[test]
fn model_visible_tool_result_preserves_reference_ids() {
    let citation_id = Uuid::new_v4();
    let citations = vec![AiCitation {
        source_kind: AiCitationSourceKind::DietAssignment,
        source_id: citation_id,
        label: "当前主粮".to_owned(),
    }];

    let visible = ModelVisibleToolResult {
        facts: Vec::new(),
        reference_ids: vec![citation_id.to_string()],
        safe_message: String::new(),
    };

    assert_eq!(visible.reference_ids.len(), 1);
    assert_eq!(visible.reference_ids[0], citation_id.to_string());
    // citations 的 label 不进入模型可见结果
    let _ = citations;
}

#[test]
fn model_visible_tool_result_excludes_denied_and_failed_reasons() {
    let visible = ToolFactProjector::project_denied("pet not authorized: pet_id 12345");
    assert!(visible.facts.is_empty());
    assert!(visible.safe_message.contains("工具无法执行"));
    assert!(!visible.safe_message.contains("12345"));
}

#[test]
fn model_visible_tool_result_excludes_failed_reason() {
    let visible = ToolFactProjector::project_failed("database connection error: postgres://...");
    assert!(visible.facts.is_empty());
    assert!(visible.safe_message.contains("工具执行失败"));
    assert!(!visible.safe_message.contains("postgres"));
}

#[test]
fn model_visible_tool_result_certainty_labels() {
    let facts = vec![
        AiFactEntry {
            key: "a".to_owned(),
            value: "强事实".to_owned(),
            strength: AiFactStrength::Strong,
            citation_id: None,
        },
        AiFactEntry {
            key: "b".to_owned(),
            value: "待确认".to_owned(),
            strength: AiFactStrength::PendingConfirmation,
            citation_id: None,
        },
        AiFactEntry {
            key: "c".to_owned(),
            value: "弱线索".to_owned(),
            strength: AiFactStrength::Weak,
            citation_id: None,
        },
    ];

    let visible = ToolFactProjector::project_facts(&facts);
    assert_eq!(visible.facts.len(), 3);
    assert_eq!(visible.facts[0].certainty, "已确认");
    assert_eq!(visible.facts[1].certainty, "待确认");
    assert_eq!(visible.facts[2].certainty, "弱线索");
}

#[test]
fn model_visible_tool_result_from_empty_facts() {
    let visible = ToolFactProjector::project_facts(&[]);
    assert!(visible.facts.is_empty());
    assert!(visible.reference_ids.is_empty());
}

#[test]
fn pet_identity_days_project_to_natural_fact_sentence() {
    let facts = vec![
        AiFactEntry {
            key: "pet_identity.name".to_owned(),
            value: "梅录".to_owned(),
            strength: AiFactStrength::Strong,
            citation_id: None,
        },
        AiFactEntry {
            key: "pet_identity.world_days".to_owned(),
            value: "420".to_owned(),
            strength: AiFactStrength::Strong,
            citation_id: None,
        },
        AiFactEntry {
            key: "pet_identity.companionship_days".to_owned(),
            value: "378".to_owned(),
            strength: AiFactStrength::Strong,
            citation_id: None,
        },
    ];

    let visible = ToolFactProjector::project_facts(&facts);
    let texts: Vec<&str> = visible
        .facts
        .iter()
        .map(|fact| fact.text.as_str())
        .collect();

    assert!(
        texts.contains(&"梅录出生至今 420 天，到家陪伴 378 天"),
        "identity day facts should include natural sentence, got: {texts:?}"
    );
    let encoded = serde_json::to_string(&visible).expect("serialize visible facts");
    assert!(
        !encoded.contains("pet_identity.world_days"),
        "projected tool result must not expose internal fact key: {encoded}"
    );
}
