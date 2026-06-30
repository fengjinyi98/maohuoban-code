// workbench_contract AgentSession Workbench 领域契约测试
// 核心职责：
// - 验证 Workbench 上下文可稳定序列化与反序列化
// - 证明投影给模型的 payload 不包含内部字段

use maohuoban_ai_domain::ai::{
    AgentCapability, AgentDefinition, AgentId, AgentSessionWorkbench, AiConversationSurface,
    CapabilityCatalog, CapabilityDomain, ContextPack, ContextPetSummary, MemoryEntry, MemoryPack,
    MemoryScope, ModelLabel,
};
use uuid::Uuid;

fn pet_id() -> Uuid {
    Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("pet id")
}

#[test]
fn workbench_contract_roundtrip_preserves_agent_context_and_capabilities() {
    let workbench = AgentSessionWorkbench {
        agent_definition: AgentDefinition {
            agent_id: AgentId::main_pet_care_agent(),
            name: "毛球".to_owned(),
            purpose: "宠物垂直照护与用户宠物私域助手".to_owned(),
            default_model_label: ModelLabel::Primary,
            capability_domains: vec![
                CapabilityDomain::PublicPetDomain,
                CapabilityDomain::PrivatePetContext,
                CapabilityDomain::AppProductSupport,
                CapabilityDomain::AssistantIdentity,
            ],
        },
        capability_catalog: CapabilityCatalog {
            capabilities: vec![
                AgentCapability {
                    code: "public_pet_care".to_owned(),
                    domain: CapabilityDomain::PublicPetDomain,
                    title: "公共养宠咨询".to_owned(),
                    when_to_use: "用户咨询通用照护、饮食、行为或常见症状观察时使用".to_owned(),
                    requires_private_context: false,
                },
                AgentCapability {
                    code: "private_pet_context".to_owned(),
                    domain: CapabilityDomain::PrivatePetContext,
                    title: "授权宠物上下文".to_owned(),
                    when_to_use: "用户询问自己宠物档案、饮食或已授权上下文时使用".to_owned(),
                    requires_private_context: true,
                },
            ],
        },
        context_pack: ContextPack {
            surface: AiConversationSurface::HomePrivate,
            locale: "zh-Hans".to_owned(),
            timezone: "Asia/Shanghai".to_owned(),
            selected_pet: Some(ContextPetSummary {
                pet_id: pet_id(),
                name: "豆包".to_owned(),
                species: "cat".to_owned(),
            }),
            authorized_pets: vec![ContextPetSummary {
                pet_id: pet_id(),
                name: "豆包".to_owned(),
                species: "cat".to_owned(),
            }],
            session_summary: Some("用户正在询问豆包近期饮食变化".to_owned()),
        },
        memory_pack: MemoryPack {
            entries: vec![MemoryEntry {
                scope: MemoryScope::Pet,
                subject_id: Some(pet_id()),
                summary: "豆包对突然换粮比较敏感".to_owned(),
            }],
        },
        recent_conversation_pack: None,
    };

    let encoded = serde_json::to_string(&workbench).expect("serialize workbench");
    let decoded: AgentSessionWorkbench =
        serde_json::from_str(&encoded).expect("deserialize workbench");

    assert_eq!(decoded, workbench);
    assert!(encoded.contains("\"public_pet_domain\""));
    assert!(encoded.contains("\"private_pet_context\""));
    assert!(encoded.contains("\"capability_catalog\""));
}

#[test]
fn workbench_contract_does_not_expose_internal_fields() {
    let workbench = AgentSessionWorkbench {
        agent_definition: AgentDefinition {
            agent_id: AgentId::main_pet_care_agent(),
            name: "毛球".to_owned(),
            purpose: "宠物垂直照护与用户宠物私域助手".to_owned(),
            default_model_label: ModelLabel::Lite,
            capability_domains: vec![CapabilityDomain::PublicPetDomain],
        },
        capability_catalog: CapabilityCatalog {
            capabilities: vec![AgentCapability {
                code: "assistant_identity".to_owned(),
                domain: CapabilityDomain::AssistantIdentity,
                title: "助手身份说明".to_owned(),
                when_to_use: "用户询问毛球是谁、能做什么、能力边界是什么时使用".to_owned(),
                requires_private_context: false,
            }],
        },
        context_pack: ContextPack {
            surface: AiConversationSurface::HomePrivate,
            locale: "zh-Hans".to_owned(),
            timezone: "Asia/Shanghai".to_owned(),
            selected_pet: None,
            authorized_pets: Vec::new(),
            session_summary: None,
        },
        memory_pack: MemoryPack {
            entries: Vec::new(),
        },
        recent_conversation_pack: None,
    };

    let encoded = serde_json::to_string(&workbench).expect("serialize workbench");

    for forbidden in [
        "database",
        "table",
        "column",
        "display",
        "permission",
        "actor_user_id",
        "owner_user_id",
        "risk",
        "policy",
        "internal",
        "debug",
    ] {
        assert!(
            !encoded.contains(forbidden),
            "workbench payload must not expose forbidden field marker: {forbidden}; payload: {encoded}"
        );
    }
}
