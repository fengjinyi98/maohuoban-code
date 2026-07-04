use super::*;

#[tokio::test]
async fn preventive_care_event_can_be_updated_and_deleted() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139301").await;
    let pet_id = create_pet(&app, &user_id).await;
    let first_asset_id = upload_event_attachment(&app, &user_id).await;
    let second_asset_id = upload_event_attachment(&app, &user_id).await;

    let event_id = create_preventive_care_event(&app, &user_id, &pet_id, &first_asset_id).await;
    update_preventive_care_event(&app, &user_id, &event_id, &second_asset_id).await;
    load_updated_preventive_care_event(&app, &user_id, &event_id).await;
    preserve_preventive_care_attachment(&app, &user_id, &event_id, &second_asset_id).await;
    delete_preventive_care_event(&app, &user_id, &event_id).await;
}

#[tokio::test]
async fn preventive_care_event_update_rejects_cross_user_attachment_asset() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let owner_user_id = login_user_id(&app, "13800139302").await;
    let other_user_id = login_user_id(&app, "13800139303").await;
    let pet_id = create_pet(&app, &owner_user_id).await;
    let owner_asset_id = upload_event_attachment(&app, &owner_user_id).await;
    let other_asset_id = upload_event_attachment(&app, &other_user_id).await;

    let event_id =
        create_deworming_preventive_care_event(&app, &owner_user_id, &pet_id, &owner_asset_id)
            .await;

    let update_response = app
        .router()
        .oneshot(json_request(
            "PATCH",
            &format!("/api/v1/pet-events/{event_id}"),
            preventive_event_payload(
                "deworming",
                "大宠爱",
                "已完成体内外驱虫",
                "2026-06-20T09:00:00Z",
                "2026-07-20",
                &other_asset_id,
            ),
            Some(&owner_user_id),
        ))
        .await
        .expect("update with cross user attachment");

    assert_eq!(update_response.status(), StatusCode::NOT_FOUND);
}

async fn create_preventive_care_event(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    pet_id: &str,
    asset_id: &str,
) -> String {
    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            preventive_event_payload(
                "vaccine",
                "妙三多",
                "妙三多首针",
                "2026-06-20T09:00:00Z",
                "2026-07-20",
                asset_id,
            ),
            Some(user_id),
        ))
        .await
        .expect("create vaccine event");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    let event_id = create_body["data"]["id"]
        .as_str()
        .expect("event id")
        .to_owned();
    assert_eq!(create_body["data"]["record_revision"], 1);
    event_id
}

async fn update_preventive_care_event(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    event_id: &str,
    asset_id: &str,
) {
    let update_response = app
        .router()
        .oneshot(json_request(
            "PATCH",
            &format!("/api/v1/pet-events/{event_id}"),
            preventive_event_payload(
                "vaccine",
                "妙三多加强针",
                "妙三多加强针已完成",
                "2026-06-21T10:30:00Z",
                "2027-06-21",
                asset_id,
            ),
            Some(user_id),
        ))
        .await
        .expect("update vaccine event");
    assert_eq!(update_response.status(), StatusCode::OK);
    let update_body = response_json(update_response).await;
    assert_eq!(update_body["code"], "pet.event_updated");
    assert_eq!(update_body["data"]["id"], event_id);
    assert_eq!(update_body["data"]["title"], "妙三多加强针");
    assert_eq!(update_body["data"]["summary"], "妙三多加强针已完成");
    assert_eq!(update_body["data"]["record_revision"], 2);
    assert_eq!(
        update_body["data"]["event_payload"]["next_due_at"],
        "2027-06-21"
    );
    assert_eq!(
        update_body["data"]["event_payload"]["attachment_asset_ids"][0],
        asset_id
    );
}

async fn load_updated_preventive_care_event(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    event_id: &str,
) {
    let load_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pet-events/{event_id}"),
            Some(user_id),
        ))
        .await
        .expect("load updated vaccine event");
    assert_eq!(load_response.status(), StatusCode::OK);
    let load_body = response_json(load_response).await;
    assert_eq!(load_body["data"]["title"], "妙三多加强针");
    assert_eq!(load_body["data"]["record_revision"], 2);
}

async fn preserve_preventive_care_attachment(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    event_id: &str,
    asset_id: &str,
) {
    let preserve_attachment_response = app
        .router()
        .oneshot(json_request(
            "PATCH",
            &format!("/api/v1/pet-events/{event_id}"),
            preventive_event_payload(
                "vaccine",
                "妙三多加强针",
                "保留原照片再次保存",
                "2026-06-21T10:30:00Z",
                "2027-06-21",
                asset_id,
            ),
            Some(user_id),
        ))
        .await
        .expect("update vaccine event preserving attachment");
    assert_eq!(preserve_attachment_response.status(), StatusCode::OK);
    let preserve_attachment_body = response_json(preserve_attachment_response).await;
    assert_eq!(preserve_attachment_body["data"]["record_revision"], 3);
    assert_eq!(
        preserve_attachment_body["data"]["event_payload"]["attachment_asset_ids"][0],
        asset_id
    );
}

async fn delete_preventive_care_event(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
    event_id: &str,
) {
    let delete_response = app
        .router()
        .oneshot(empty_request(
            "DELETE",
            &format!("/api/v1/pet-events/{event_id}"),
            Some(user_id),
        ))
        .await
        .expect("delete vaccine event");
    assert_eq!(delete_response.status(), StatusCode::OK);

    let deleted_load_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pet-events/{event_id}"),
            Some(user_id),
        ))
        .await
        .expect("load deleted vaccine event");
    assert_eq!(deleted_load_response.status(), StatusCode::NOT_FOUND);
}

async fn create_deworming_preventive_care_event(
    app: &maohuoban_rust::test_support::AuthTestApp,
    owner_user_id: &str,
    pet_id: &str,
    owner_asset_id: &str,
) -> String {
    let create_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/events"),
            preventive_event_payload(
                "deworming",
                "大宠爱",
                "已完成体内外驱虫",
                "2026-06-20T09:00:00Z",
                "2026-07-20",
                owner_asset_id,
            ),
            Some(owner_user_id),
        ))
        .await
        .expect("create deworming event");
    assert_eq!(create_response.status(), StatusCode::CREATED);
    let create_body = response_json(create_response).await;
    create_body["data"]["id"]
        .as_str()
        .expect("event id")
        .to_owned()
}

fn preventive_event_payload(
    event_subkind: &str,
    title: &str,
    summary: &str,
    occurred_at: &str,
    next_due_at: &str,
    asset_id: &str,
) -> Value {
    json!({
        "event_kind": "health",
        "event_subkind": event_subkind,
        "title": title,
        "summary": summary,
        "visibility": "private",
        "occurred_at": occurred_at,
        "event_payload": {
            "name": title,
            "execution_method": "hospital",
            "execution_name": "瑞派宠物医院",
            "completed_at": occurred_at,
            "next_due_at": next_due_at,
            "due_text": "待提醒",
            "note": "测试备注",
            "attachment_asset_ids": [asset_id]
        }
    })
}

async fn upload_event_attachment(
    app: &maohuoban_rust::test_support::AuthTestApp,
    user_id: &str,
) -> String {
    let upload_body = upload_pending_media(
        app,
        "/api/v1/pet-event-media",
        "preventive-photo.png",
        "image/png",
        &tiny_png(),
        user_id,
    )
    .await;
    assert_eq!(upload_body["code"], "pet.event_attachment_uploaded");
    upload_body["data"]["asset"]["id"]
        .as_str()
        .expect("event attachment asset id")
        .to_owned()
}

async fn create_pet(app: &maohuoban_rust::test_support::AuthTestApp, user_id: &str) -> String {
    let response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "饭团",
                "species": "cat",
                "sex": "male"
            }),
            Some(user_id),
        ))
        .await
        .expect("create pet");
    assert_eq!(response.status(), StatusCode::CREATED);
    let body = response_json(response).await;
    body["data"]["id"].as_str().expect("pet id").to_owned()
}
