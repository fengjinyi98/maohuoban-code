use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, Diagnostics, DiagnosticsConfig, EventKind, FileSegmentStore,
    PrivacyPolicy, Severity,
};
use maohuoban_profile_application::profile::{
    ProfileMediaKind, ProfileMediaUploadDiagnostics, record_profile_media_upload,
};
use serde_json::json;
use tempfile::tempdir;
use uuid::Uuid;

static DIAGNOSTICS_TEST_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());

#[test]
fn profile_media_upload_diagnostics_records_safe_upload_context() {
    let _guard = DIAGNOSTICS_TEST_LOCK.lock().expect("diagnostics test lock");
    let diagnostics = install_test_diagnostics();
    let user_id = Uuid::parse_str("491756f0-262e-4027-960f-d811b5378c73").expect("user id");

    record_profile_media_upload(ProfileMediaUploadDiagnostics {
        stage: "http.request",
        user_id,
        asset_id: None,
        kind: ProfileMediaKind::Avatar,
        declared_mime_type: "image/png",
        byte_size: 42_817,
        content_signature: Some("png"),
        width: None,
        height: None,
        success: true,
        error_kind: None,
        decoder_error_kind: None,
    });
    record_profile_media_upload(ProfileMediaUploadDiagnostics {
        stage: "repository.decode_failed",
        user_id,
        asset_id: None,
        kind: ProfileMediaKind::Cover,
        declared_mime_type: "image/png",
        byte_size: 57_013,
        content_signature: Some("png"),
        width: None,
        height: None,
        success: false,
        error_kind: Some("profile.media_decode_failed"),
        decoder_error_kind: Some("format"),
    });
    diagnostics.flush().expect("flush diagnostics");

    let events = diagnostics.read_events().expect("events");
    let request_event = events
        .iter()
        .find(|event| event.message == "profile.media.upload.http.request")
        .expect("profile media request event");
    assert_eq!(request_event.kind, EventKind::Analytics);
    assert_eq!(request_event.severity, Severity::Info);
    assert_eq!(request_event.metadata["user_id_prefix"], json!("491756f0"));
    assert_eq!(request_event.metadata["media_kind"], json!("avatar"));
    assert_eq!(request_event.metadata["usage_kind"], json!("user.avatar"));
    assert_eq!(
        request_event.metadata["declared_mime_type"],
        json!("image/png")
    );
    assert_eq!(request_event.metadata["byte_size"], json!(42_817));
    assert_eq!(request_event.metadata["content_signature"], json!("png"));
    assert_eq!(request_event.metadata.get("file_name"), None);
    assert_eq!(request_event.metadata.get("content_prefix_hex"), None);

    let failure_event = events
        .iter()
        .find(|event| event.message == "profile.media.upload.repository.decode_failed")
        .expect("profile media failure event");
    assert_eq!(failure_event.severity, Severity::Error);
    assert_eq!(
        failure_event.metadata["error_kind"],
        json!("profile.media_decode_failed")
    );
    assert_eq!(
        failure_event.metadata["decoder_error_kind"],
        json!("format")
    );
}

fn install_test_diagnostics() -> Diagnostics {
    let root = tempdir().expect("temp dir").keep();
    let store = FileSegmentStore::new(root.join("segments"), 1024 * 1024).expect("store");
    Diagnostics::install(DiagnosticsConfig {
        service_name: "maohuoban-rust".to_owned(),
        environment: "test".to_owned(),
        privacy: PrivacyPolicy::default(),
        capture: CapturePolicy::default(),
        cleanup: CleanupPolicy::default(),
        store: Box::new(store),
    })
    .expect("install diagnostics")
}
