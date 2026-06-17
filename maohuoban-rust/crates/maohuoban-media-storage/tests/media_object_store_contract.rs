use std::{env, path::PathBuf};

use maohuoban_media_storage::{MediaObjectStore, MediaStorageConfig};
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
