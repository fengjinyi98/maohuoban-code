// AttentionHint 首页轻提示合约测试
// 核心职责：
// - 验证首页聚合快照返回 attention_hints 字段（空数组）
// - 验证无 active hint 时不展示轻提示

use super::*;

#[tokio::test]
async fn home_dashboard_returns_attention_hints_field() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.seed_new_user_home().await;
    let user_id = login_user_id(&app, "13800138212").await;
    let pet_id = create_home_test_pet(&app, &user_id).await;

    let body = load_user_home_dashboard_for_pet(&app, &user_id, &pet_id).await;
    let data = body.get("data").unwrap();
    let hints = data.get("attention_hints").unwrap();

    // 合约强制：home dashboard 必须返回 attention_hints 字段
    assert!(
        hints.is_array(),
        "attention_hints must be an array, got: {hints}"
    );
    // 无写入 hint 时返回空数组
    assert!(
        hints.as_array().unwrap().is_empty(),
        "expected empty attention_hints"
    );
}
