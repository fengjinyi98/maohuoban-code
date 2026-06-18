use super::*;

#[tokio::test]
async fn home_dashboard_falls_back_when_selected_pet_belongs_to_another_user() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138228").await;
    let own_pet_id = create_named_home_test_pet(&app, &user_id, "糯米").await;
    let other_user_id = login_user_id(&app, "13800138229").await;
    let other_pet_id = create_named_home_test_pet(&app, &other_user_id, "奶油").await;

    let dashboard_body = load_user_home_dashboard_for_pet(&app, &user_id, &other_pet_id).await;

    assert_eq!(dashboard_body["data"]["selected_pet"]["id"], own_pet_id);
    assert_eq!(dashboard_body["data"]["selected_pet"]["name"], "糯米");
    assert_eq!(dashboard_body["data"]["pet_switcher"][0]["id"], own_pet_id);
    assert_eq!(
        dashboard_body["data"]["pet_switcher"][0]["is_selected"],
        true
    );
}

#[tokio::test]
async fn home_dashboard_derives_care_summary_and_reminders_from_pet_events() {
    let app = maohuoban_rust::test_support::spawn_home_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800138222").await;
    let pet_id = create_home_test_pet(&app, &user_id).await;

    for event in [
        json!({
            "event_kind": "daily",
            "event_subkind": "appetite",
            "title": "食欲记录",
            "summary": "早餐和晚餐都吃完了",
            "visibility": "private",
            "occurred_at": "2026-06-13T08:30:00Z",
            "event_payload": {
                "value_text": "旺盛",
                "status_text": "早餐和晚餐已记录"
            }
        }),
        json!({
            "event_kind": "health",
            "event_subkind": "weight",
            "title": "体重记录",
            "summary": "6.4kg，较上次增加",
            "visibility": "private",
            "occurred_at": "2026-06-13T09:20:00Z",
            "event_payload": {
                "weight_kg": 6.4
            }
        }),
        json!({
            "event_kind": "health",
            "event_subkind": "deworming",
            "title": "内外驱虫",
            "summary": "已完成本月驱虫",
            "visibility": "private",
            "occurred_at": "2026-06-13T10:30:00Z",
            "event_payload": {
                "next_due_at": "2026-07-01"
            }
        }),
    ] {
        append_home_test_event(&app, &user_id, &pet_id, event).await;
    }

    let dashboard_body = load_user_home_dashboard(&app, &user_id).await;

    assert_eq!(
        dashboard_body["data"]["care_summary"]["metrics"][0]["kind"],
        "appetite"
    );
    assert_eq!(
        dashboard_body["data"]["care_summary"]["metrics"][0]["value_text"],
        "旺盛"
    );
    assert_eq!(
        dashboard_body["data"]["care_summary"]["metrics"][0]["status_text"],
        "早餐和晚餐已记录"
    );
    assert_eq!(
        dashboard_body["data"]["care_summary"]["metrics"][3]["kind"],
        "weight"
    );
    assert_eq!(
        dashboard_body["data"]["care_summary"]["metrics"][3]["value_text"],
        "6.4kg"
    );
    assert_eq!(dashboard_body["data"]["reminders"][0]["kind"], "deworming");
    assert_eq!(dashboard_body["data"]["reminders"][0]["title"], "内外驱虫");
    assert_eq!(
        dashboard_body["data"]["reminders"][0]["subtitle"],
        "预计 2026-07-01 提醒"
    );
    assert_eq!(dashboard_body["data"]["reminders"][0]["due_text"], "待提醒");
    assert_eq!(
        dashboard_body["data"]["recent_timeline"][0]["event_kind"],
        "deworming"
    );
}
