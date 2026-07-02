// pet_resolver AiPetResolver 测试
// 核心职责：
// - 验证 selected pet、宠物名、同名歧义、未授权名字、无宠物上下文的解析结果
// - 遵循 TDD：先写失败测试（red），再实现解析器（green）

use maohuoban_ai_application::ai::pet_resolver::AiPetResolver;
use maohuoban_ai_application::ai::ports::InMemoryPetCatalog;
use maohuoban_ai_domain::ai::{AiPetCandidate, AiPetResolution};
use uuid::Uuid;

fn candidate(pet_id: Uuid, name: &str, species: &str) -> AiPetCandidate {
    AiPetCandidate {
        pet_id,
        name: name.to_owned(),
        avatar_url: None,
        species: species.to_owned(),
        profile_number: format!("P-{pet_id}"),
    }
}

#[tokio::test]
async fn selected_pet_resolves_when_no_name_in_message() {
    let maoqiu_id = Uuid::new_v4();
    let candidates = vec![candidate(maoqiu_id, "毛球", "cat")];
    let catalog = InMemoryPetCatalog::new(candidates);
    let resolver = AiPetResolver::new(catalog);

    let resolution = resolver
        .resolve("今天天气怎么样", Some(maoqiu_id), Uuid::new_v4())
        .await
        .expect("resolve");

    assert!(resolution.is_resolved());
    assert_eq!(resolution.resolved_pet_id(), Some(maoqiu_id));
}

#[tokio::test]
async fn unique_name_in_message_resolves_to_matching_pet() {
    let maoqiu_id = Uuid::new_v4();
    let doudou_id = Uuid::new_v4();
    let candidates = vec![
        candidate(maoqiu_id, "毛球", "cat"),
        candidate(doudou_id, "豆豆", "dog"),
    ];
    let catalog = InMemoryPetCatalog::new(candidates);
    let resolver = AiPetResolver::new(catalog);

    let resolution = resolver
        .resolve("毛球今天拉肚子了", None, Uuid::new_v4())
        .await
        .expect("resolve");

    assert!(resolution.is_resolved());
    assert_eq!(resolution.resolved_pet_id(), Some(maoqiu_id));
}

#[tokio::test]
async fn named_pet_reference_is_detected_from_authorized_catalog_without_pet_keyword() {
    let meilu_id = Uuid::new_v4();
    let candidates = vec![candidate(meilu_id, "梅录", "cat")];
    let catalog = InMemoryPetCatalog::new(candidates);
    let resolver = AiPetResolver::new(catalog);

    let has_reference = resolver
        .has_authorized_pet_name_reference("梅录多大了", Uuid::new_v4())
        .await
        .expect("detect authorized pet reference");

    assert!(has_reference);
}

#[tokio::test]
async fn app_support_question_without_pet_name_does_not_trigger_pet_reference() {
    let meilu_id = Uuid::new_v4();
    let candidates = vec![candidate(meilu_id, "梅录", "cat")];
    let catalog = InMemoryPetCatalog::new(candidates);
    let resolver = AiPetResolver::new(catalog);

    let has_reference = resolver
        .has_authorized_pet_name_reference("毛伙伴怎么修改昵称", Uuid::new_v4())
        .await
        .expect("detect authorized pet reference");

    assert!(!has_reference);
}

#[tokio::test]
async fn ambiguous_same_name_returns_needs_selection() {
    let pet_a = Uuid::new_v4();
    let pet_b = Uuid::new_v4();
    let candidates = vec![
        candidate(pet_a, "毛球", "cat"),
        candidate(pet_b, "毛球", "dog"),
    ];
    let catalog = InMemoryPetCatalog::new(candidates);
    let resolver = AiPetResolver::new(catalog);

    let resolution = resolver
        .resolve("毛球不爱吃东西", None, Uuid::new_v4())
        .await
        .expect("resolve");

    match resolution {
        AiPetResolution::NeedsSelection { candidates } => {
            assert_eq!(candidates.len(), 2);
        }
        other => panic!("expected NeedsSelection, got {other:?}"),
    }
}

#[tokio::test]
async fn unauthorized_name_returns_unauthorized_or_not_found() {
    let maoqiu_id = Uuid::new_v4();
    let candidates = vec![candidate(maoqiu_id, "毛球", "cat")];
    let catalog = InMemoryPetCatalog::new(candidates);
    let resolver = AiPetResolver::new(catalog);

    let resolution = resolver
        .resolve("花花今天怎么样", None, Uuid::new_v4())
        .await
        .expect("resolve");

    assert_eq!(resolution, AiPetResolution::UnauthorizedOrNotFound);
}

#[tokio::test]
async fn no_pet_candidates_returns_no_pet_context() {
    let catalog = InMemoryPetCatalog::new(vec![]);
    let resolver = AiPetResolver::new(catalog);

    let resolution = resolver
        .resolve("帮我看看宠物", None, Uuid::new_v4())
        .await
        .expect("resolve");

    assert_eq!(resolution, AiPetResolution::NoPetContext);
}

#[tokio::test]
async fn message_mentions_other_authorized_pet_switches_target() {
    let maoqiu_id = Uuid::new_v4();
    let doudou_id = Uuid::new_v4();
    let candidates = vec![
        candidate(maoqiu_id, "毛球", "cat"),
        candidate(doudou_id, "豆豆", "dog"),
    ];
    let catalog = InMemoryPetCatalog::new(candidates);
    let resolver = AiPetResolver::new(catalog);

    let resolution = resolver
        .resolve("豆豆今天精神不好", Some(maoqiu_id), Uuid::new_v4())
        .await
        .expect("resolve");

    assert!(resolution.is_resolved());
    assert_eq!(resolution.resolved_pet_id(), Some(doudou_id));
}

#[tokio::test]
async fn selected_pet_not_in_authorized_returns_unauthorized() {
    let maoqiu_id = Uuid::new_v4();
    let other_id = Uuid::new_v4();
    let candidates = vec![candidate(maoqiu_id, "毛球", "cat")];
    let catalog = InMemoryPetCatalog::new(candidates);
    let resolver = AiPetResolver::new(catalog);

    let resolution = resolver
        .resolve("今天怎么样", Some(other_id), Uuid::new_v4())
        .await
        .expect("resolve");

    assert_eq!(resolution, AiPetResolution::UnauthorizedOrNotFound);
}

#[tokio::test]
async fn single_pet_auto_resolves_without_name() {
    let maoqiu_id = Uuid::new_v4();
    let candidates = vec![candidate(maoqiu_id, "毛球", "cat")];
    let catalog = InMemoryPetCatalog::new(candidates);
    let resolver = AiPetResolver::new(catalog);

    let resolution = resolver
        .resolve("拉肚子怎么办", None, Uuid::new_v4())
        .await
        .expect("resolve");

    assert!(resolution.is_resolved());
    assert_eq!(resolution.resolved_pet_id(), Some(maoqiu_id));
}
