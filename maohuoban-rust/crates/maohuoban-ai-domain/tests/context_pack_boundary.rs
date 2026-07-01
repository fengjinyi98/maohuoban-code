// context_pack_boundary ContextPack 字段边界测试
// 核心职责：
// - 验证 ContextPack 不包含数据库字段、权限字段、UI 展示字段、内部状态字段
// - 验证 has_private_context 正确反映是否有已选宠物

use maohuoban_ai_domain::ai::{AiConversationSurface, ContextPack, ContextPetSummary};
use uuid::Uuid;

fn pet_id() -> Uuid {
    Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("pet id")
}

fn pet_summary() -> ContextPetSummary {
    ContextPetSummary {
        pet_id: pet_id(),
        name: "豆包".to_owned(),
        species: "cat".to_owned(),
    }
}

#[test]
fn context_pack_without_selected_pet_has_no_private_context() {
    let pack = ContextPack {
        surface: AiConversationSurface::HomePrivate,
        locale: "zh-Hans".to_owned(),
        timezone: "Asia/Shanghai".to_owned(),
        temporal_context: None,
        selected_pet: None,
        authorized_pets: Vec::new(),
        session_summary: None,
    };
    assert!(!pack.has_private_context());
}

#[test]
fn context_pack_with_selected_pet_has_private_context() {
    let pack = ContextPack {
        surface: AiConversationSurface::HomePrivate,
        locale: "zh-Hans".to_owned(),
        timezone: "Asia/Shanghai".to_owned(),
        temporal_context: None,
        selected_pet: Some(pet_summary()),
        authorized_pets: vec![pet_summary()],
        session_summary: None,
    };
    assert!(pack.has_private_context());
}

#[test]
fn context_pack_serialization_does_not_contain_forbidden_markers() {
    let pack = ContextPack {
        surface: AiConversationSurface::HomePrivate,
        locale: "zh-Hans".to_owned(),
        timezone: "Asia/Shanghai".to_owned(),
        temporal_context: Some(maohuoban_ai_domain::ai::TemporalContext {
            local_date: "2026-07-02".to_owned(),
            local_datetime: "2026-07-02T04:30:29+08:00".to_owned(),
            timezone: "Asia/Shanghai".to_owned(),
        }),
        selected_pet: Some(pet_summary()),
        authorized_pets: vec![pet_summary()],
        session_summary: Some("用户正在询问豆包近期饮食变化".to_owned()),
    };

    let encoded = serde_json::to_string(&pack).expect("serialize context pack");

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
        "profile_number",
        "avatar_url",
        "status",
        "alive",
    ] {
        assert!(
            !encoded.contains(forbidden),
            "ContextPack must not expose forbidden field marker: {forbidden}; payload: {encoded}"
        );
    }
}

#[test]
fn context_pack_roundtrip_preserves_all_fields() {
    let pack = ContextPack {
        surface: AiConversationSurface::HomePrivate,
        locale: "zh-Hans".to_owned(),
        timezone: "Asia/Shanghai".to_owned(),
        temporal_context: Some(maohuoban_ai_domain::ai::TemporalContext {
            local_date: "2026-07-02".to_owned(),
            local_datetime: "2026-07-02T04:30:29+08:00".to_owned(),
            timezone: "Asia/Shanghai".to_owned(),
        }),
        selected_pet: Some(pet_summary()),
        authorized_pets: vec![pet_summary()],
        session_summary: Some("会话摘要".to_owned()),
    };

    let encoded = serde_json::to_string(&pack).expect("serialize");
    let decoded: ContextPack = serde_json::from_str(&encoded).expect("deserialize");
    assert_eq!(decoded, pack);
}
