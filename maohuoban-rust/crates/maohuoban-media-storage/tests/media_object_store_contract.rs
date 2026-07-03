use std::{env, path::PathBuf};

use chrono::{TimeZone, Utc};
use maohuoban_media_storage::{
    MediaObjectKind, MediaObjectStore, MediaStorageConfig, traceable_media_object_key,
};
use uuid::Uuid;

#[tokio::test]
async fn local_store_puts_reads_and_deletes_bucket_objects() {
    let root = temp_store_root();
    let store = MediaObjectStore::new(MediaStorageConfig::local(
        root.clone(),
        "maohuoban-pet-media",
    ));

    store
        .put("maohuoban-pet-media", "pets/pet-1/avatar.jpg", b"avatar")
        .await
        .expect("put local object");

    assert_eq!(
        std::fs::read(root.join("maohuoban-pet-media/pets/pet-1/avatar.jpg"))
            .expect("read filesystem object"),
        b"avatar"
    );
    assert_eq!(
        store
            .get("maohuoban-pet-media", "pets/pet-1/avatar.jpg")
            .await
            .expect("get local object"),
        b"avatar"
    );

    store
        .delete("maohuoban-pet-media", "pets/pet-1/avatar.jpg")
        .await
        .expect("delete local object");
    store
        .delete("maohuoban-pet-media", "pets/pet-1/avatar.jpg")
        .await
        .expect("delete local object idempotently");
    assert!(
        !root
            .join("maohuoban-pet-media/pets/pet-1/avatar.jpg")
            .exists()
    );
}

#[test]
fn s3_config_declares_default_bucket_and_backend() {
    let config = MediaStorageConfig::s3(
        "http://127.0.0.1:9000",
        "rustfsadmin",
        "rustfsadmin",
        "us-east-1",
        "maohuoban-pet-media",
        true,
    );

    assert_eq!(config.default_bucket(), "maohuoban-pet-media");
    assert_eq!(
        config.cache_control(),
        Some("public, max-age=31536000, immutable")
    );
    assert!(config.is_s3());
}

#[test]
fn s3_config_allows_cache_control_override() {
    let config = MediaStorageConfig::s3(
        "http://127.0.0.1:9000",
        "rustfsadmin",
        "rustfsadmin",
        "us-east-1",
        "maohuoban-pet-media",
        true,
    )
    .with_cache_control(Some("public, max-age=60".to_owned()));

    assert_eq!(config.cache_control(), Some("public, max-age=60"));
}

#[test]
fn traceable_media_object_key_uses_user_date_asset_and_fixed_names() {
    let user_id = Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("user uuid");
    let asset_id = Uuid::parse_str("22222222-2222-2222-2222-222222222222").expect("asset uuid");
    let uploaded_at = Utc
        .with_ymd_and_hms(2026, 7, 3, 12, 30, 0)
        .single()
        .expect("uploaded at");

    assert_eq!(
        traceable_media_object_key(
            user_id,
            asset_id,
            uploaded_at,
            MediaObjectKind::Original {
                file_name: "猫猫封面.JPG"
            }
        ),
        "media/users/11111111-1111-1111-1111-111111111111/2026/07/22222222-2222-2222-2222-222222222222/original.jpg"
    );
    assert_eq!(
        traceable_media_object_key(user_id, asset_id, uploaded_at, MediaObjectKind::Thumbnail),
        "media/users/11111111-1111-1111-1111-111111111111/2026/07/22222222-2222-2222-2222-222222222222/thumbnail.png"
    );
    assert_eq!(
        traceable_media_object_key(user_id, asset_id, uploaded_at, MediaObjectKind::ThemeColor),
        "media/users/11111111-1111-1111-1111-111111111111/2026/07/22222222-2222-2222-2222-222222222222/theme-color.json"
    );
    assert_eq!(
        traceable_media_object_key(
            user_id,
            asset_id,
            uploaded_at,
            MediaObjectKind::PairedVideo {
                file_name: "live-motion.MOV"
            }
        ),
        "media/users/11111111-1111-1111-1111-111111111111/2026/07/22222222-2222-2222-2222-222222222222/paired-video.mov"
    );
    assert_eq!(
        traceable_media_object_key(
            user_id,
            asset_id,
            uploaded_at,
            MediaObjectKind::VideoCoverFrame
        ),
        "media/users/11111111-1111-1111-1111-111111111111/2026/07/22222222-2222-2222-2222-222222222222/video-cover-frame.png"
    );
}

#[tokio::test]
#[ignore = "requires a running RustFS/S3 endpoint configured with MAOHUOBAN_MEDIA_STORAGE_BACKEND=s3"]
async fn s3_store_round_trips_against_configured_rustfs() {
    let store = MediaObjectStore::from_env().expect("read s3 env config");
    let bucket = store.default_bucket().to_owned();
    let key = format!("contract/{}/round-trip.txt", Uuid::new_v4());

    store
        .put(&bucket, &key, b"rustfs-round-trip")
        .await
        .expect("put s3 object");
    assert_eq!(
        store.get(&bucket, &key).await.expect("get s3 object"),
        b"rustfs-round-trip"
    );
    store.delete(&bucket, &key).await.expect("delete s3 object");
    assert!(
        store.get(&bucket, &key).await.is_err(),
        "deleted RustFS object should be unavailable"
    );
}

fn temp_store_root() -> PathBuf {
    env::temp_dir().join(format!("maohuoban-media-store-test-{}", Uuid::new_v4()))
}
