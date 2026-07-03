use super::*;

#[tokio::test]
async fn pet_weight_records_support_initial_create_update_and_delete() {
    let app = maohuoban_rust::test_support::spawn_auth_test_app().await;
    app.reset().await;
    let user_id = login_user_id(&app, "13800139201").await;

    let create_pet_response = app
        .router()
        .oneshot(json_request(
            "POST",
            "/api/v1/pets",
            json!({
                "name": "糯米",
                "species": "dog",
                "sex": "female",
                "weight_grams": 4200
            }),
            Some(&user_id),
        ))
        .await
        .expect("create pet with initial weight");
    let create_pet_status = create_pet_response.status();
    let create_pet_body = response_json(create_pet_response).await;
    assert_eq!(
        create_pet_status,
        StatusCode::CREATED,
        "create pet body: {create_pet_body}"
    );
    let pet_id = create_pet_body["data"]["id"].as_str().expect("pet id");

    let initial_list = load_weight_records(&app, pet_id, &user_id).await;
    assert_eq!(initial_list["data"]["items"].as_array().unwrap().len(), 1);
    assert_eq!(initial_list["data"]["items"][0]["weight_grams"], 4200);
    assert_eq!(
        initial_list["data"]["items"][0]["note"],
        "创建宠物时记录的初始体重"
    );
    assert_eq!(
        initial_list["data"]["items"][0]["source"],
        "profile_initial"
    );

    let create_record_response = app
        .router()
        .oneshot(json_request(
            "POST",
            &format!("/api/v1/pets/{pet_id}/weight-records"),
            json!({
                "weight_grams": 4350,
                "note": "晚饭后称重",
                "occurred_at": "2026-07-04T10:30:00Z"
            }),
            Some(&user_id),
        ))
        .await
        .expect("create weight record");
    assert_eq!(create_record_response.status(), StatusCode::CREATED);
    let create_record_body = response_json(create_record_response).await;
    assert_eq!(create_record_body["data"]["weight_grams"], 4350);
    assert_eq!(create_record_body["data"]["note"], "晚饭后称重");
    assert_eq!(create_record_body["data"]["source"], "manual");
    let record_id = create_record_body["data"]["id"]
        .as_str()
        .expect("record id");

    let update_response = app
        .router()
        .oneshot(json_request(
            "PATCH",
            &format!("/api/v1/pet-weight-records/{record_id}"),
            json!({
                "weight_grams": 4400,
                "note": "复称后修正",
                "occurred_at": "2026-07-04T11:00:00Z"
            }),
            Some(&user_id),
        ))
        .await
        .expect("update weight record");
    assert_eq!(update_response.status(), StatusCode::OK);
    let update_body = response_json(update_response).await;
    assert_eq!(update_body["data"]["id"], record_id);
    assert_eq!(update_body["data"]["weight_grams"], 4400);
    assert_eq!(update_body["data"]["note"], "复称后修正");
    assert_eq!(update_body["data"]["record_revision"], 2);

    let detail_response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pet-weight-records/{record_id}"),
            Some(&user_id),
        ))
        .await
        .expect("load weight detail");
    assert_eq!(detail_response.status(), StatusCode::OK);
    let detail_body = response_json(detail_response).await;
    assert_eq!(detail_body["data"]["weight_grams"], 4400);
    assert_eq!(detail_body["data"]["note"], "复称后修正");

    let delete_response = app
        .router()
        .oneshot(empty_request(
            "DELETE",
            &format!("/api/v1/pet-weight-records/{record_id}"),
            Some(&user_id),
        ))
        .await
        .expect("delete weight record");
    assert_eq!(delete_response.status(), StatusCode::OK);
    let delete_body = response_json(delete_response).await;
    assert_eq!(delete_body["data"]["id"], record_id);
    assert_eq!(delete_body["data"]["deleted"], true);

    let list_after_delete = load_weight_records(&app, pet_id, &user_id).await;
    let items = list_after_delete["data"]["items"].as_array().unwrap();
    assert_eq!(items.len(), 1);
    assert_eq!(items[0]["source"], "profile_initial");
}

async fn load_weight_records(
    app: &maohuoban_rust::test_support::AuthTestApp,
    pet_id: &str,
    user_id: &str,
) -> serde_json::Value {
    let response = app
        .router()
        .oneshot(empty_request(
            "GET",
            &format!("/api/v1/pets/{pet_id}/weight-records"),
            Some(user_id),
        ))
        .await
        .expect("load weight records");
    assert_eq!(response.status(), StatusCode::OK);
    response_json(response).await
}
