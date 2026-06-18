use super::*;

#[tokio::test]
async fn home_dashboard_uses_public_pet_events_for_new_user_recommended_content() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let content_owner_id = login_user_id(&app, "13800138225").await;
    let pet_id = create_named_home_test_pet(&app, &content_owner_id, "小满").await;
    append_home_test_event(
        &app,
        &content_owner_id,
        &pet_id,
        json!({
            "event_kind": "daily",
            "event_subkind": "adaptation",
            "title": "到家第三天开始主动吃饭",
            "summary": "幼猫适应新家的公开记录",
            "visibility": "public",
            "occurred_at": "2026-06-13T12:00:00Z",
            "event_payload": {
                "value_text": "稳定"
            }
        }),
    )
    .await;
    let new_user_id = login_user_id(&app, "13800138226").await;

    let dashboard_body = load_user_home_dashboard(&app, &new_user_id).await;

    assert_eq!(dashboard_body["data"]["identity"]["kind"], "new_user");
    assert_eq!(
        dashboard_body["data"]["empty_state"]["kind"],
        "create_first_pet"
    );
    assert_eq!(
        dashboard_body["data"]["recommended_content"][0]["kind"],
        "ugc"
    );
    assert_eq!(
        dashboard_body["data"]["recommended_content"][0]["title"],
        "到家第三天开始主动吃饭"
    );
    let source_text = dashboard_body["data"]["recommended_content"][0]["source_text"]
        .as_str()
        .expect("source text");
    assert!(source_text.contains("小满"));
    assert!(source_text.contains("宠物世界"));
}
