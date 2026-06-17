use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, Diagnostics, DiagnosticsConfig, EventKind, FileSegmentStore,
    PrivacyPolicy, Severity,
};
use maohuoban_pet_application::pet::{
    HomeDashboardDiagnosticSnapshot, MediaBindingDiagnostics, MediaUploadDiagnostics,
    PetProfileDiagnostics, record_home_dashboard_snapshot, record_media_binding,
    record_media_upload, record_pet_profile,
};
use maohuoban_pet_domain::pet::MediaUsageKind;
use serde_json::json;
use tempfile::tempdir;
use uuid::Uuid;

static DIAGNOSTICS_TEST_LOCK: std::sync::Mutex<()> = std::sync::Mutex::new(());

#[test]
fn pet_profile_diagnostics_records_breed_state_without_sensitive_text() {
    let _guard = DIAGNOSTICS_TEST_LOCK.lock().expect("diagnostics test lock");
    let diagnostics = install_test_diagnostics();
    let user_id = Uuid::parse_str("491756f0-262e-4027-960f-d811b5378c73").expect("user id");
    let pet_id = Uuid::parse_str("26e149eb-4f64-4163-aba3-e43ba2eef3fe").expect("pet id");

    record_pet_profile(PetProfileDiagnostics {
        stage: "http.request",
        action: "create",
        user_id,
        pet_id: Some(pet_id),
        breed: Some(" 英短 蓝猫 "),
        success: true,
    });
    diagnostics.flush().expect("flush diagnostics");

    let events = diagnostics.read_events().expect("events");
    let event = events
        .iter()
        .find(|event| event.message == "pet.profile.create.http.request")
        .expect("pet profile event");
    assert_eq!(event.kind, EventKind::Analytics);
    assert_eq!(event.severity, Severity::Info);
    assert_eq!(event.metadata["user_id_prefix"], json!("491756f0"));
    assert_eq!(event.metadata["pet_id_prefix"], json!("26e149eb"));
    assert_eq!(event.metadata["breed_present"], json!(true));
    assert_eq!(event.metadata["breed_length_non_whitespace"], json!(4));
    assert_eq!(event.metadata.get("breed"), None);
}

#[test]
fn media_upload_and_binding_diagnostics_record_dimensions_and_status() {
    let _guard = DIAGNOSTICS_TEST_LOCK.lock().expect("diagnostics test lock");
    let diagnostics = install_test_diagnostics();
    let user_id = Uuid::parse_str("491756f0-262e-4027-960f-d811b5378c73").expect("user id");
    let pet_id = Uuid::parse_str("26e149eb-4f64-4163-aba3-e43ba2eef3fe").expect("pet id");
    let asset_id = Uuid::parse_str("54e4abb1-3c72-493c-8fa1-a3fc0b4673b8").expect("asset id");

    record_media_upload(MediaUploadDiagnostics {
        stage: "prepared",
        user_id,
        asset_id: Some(asset_id),
        usage_kind: MediaUsageKind::PetBackgroundVideo,
        mime_type: "video/mp4",
        byte_size: 3_134_871,
        width: Some(704),
        height: Some(954),
        derivative_count: 2,
        success: true,
        error_kind: None,
    });
    record_media_binding(MediaBindingDiagnostics {
        stage: "bound",
        user_id,
        pet_id,
        asset_id,
        usage_kind: Some(MediaUsageKind::PetBackgroundVideo),
        width: Some(704),
        height: Some(954),
        derivative_count: 2,
        success: true,
        error_kind: None,
    });
    diagnostics.flush().expect("flush diagnostics");

    let events = diagnostics.read_events().expect("events");
    assert!(events.iter().any(|event| {
        event.message == "pet.media.upload.prepared"
            && event.metadata["usage_kind"] == json!("pet.background.video")
            && event.metadata["asset_id_prefix"] == json!("54e4abb1")
            && event.metadata["mime_type"] == json!("video/mp4")
            && event.metadata["byte_size"] == json!(3_134_871)
            && event.metadata["width"] == json!(704)
            && event.metadata["height"] == json!(954)
            && event.metadata["derivative_count"] == json!(2)
    }));
    assert!(events.iter().any(|event| {
        event.message == "pet.media.binding.bound"
            && event.metadata["pet_id_prefix"] == json!("26e149eb")
            && event.metadata["success"] == json!(true)
    }));
}

#[test]
fn home_dashboard_diagnostics_records_hero_media_output_contract() {
    let _guard = DIAGNOSTICS_TEST_LOCK.lock().expect("diagnostics test lock");
    let diagnostics = install_test_diagnostics();
    let user_id = Uuid::parse_str("491756f0-262e-4027-960f-d811b5378c73").expect("user id");
    let pet_id = Uuid::parse_str("26e149eb-4f64-4163-aba3-e43ba2eef3fe").expect("pet id");
    let asset_id = Uuid::parse_str("54e4abb1-3c72-493c-8fa1-a3fc0b4673b8").expect("asset id");

    record_home_dashboard_snapshot(HomeDashboardDiagnosticSnapshot {
        stage: "selected_pet.output",
        user_id: Some(user_id),
        selected_pet_id: Some(pet_id),
        pet_count: 1,
        background_asset_id: Some(asset_id),
        background_media_kind: Some("video"),
        metadata_present: true,
        hero_image_present: false,
        hero_video_present: true,
        hero_video_width: Some(704),
        hero_video_height: Some(954),
        hero_theme_color_hex: Some("#B3C2CE"),
    });
    diagnostics.flush().expect("flush diagnostics");

    let events = diagnostics.read_events().expect("events");
    let event = events
        .iter()
        .find(|event| event.message == "home.dashboard.selected_pet.output")
        .expect("home dashboard event");
    assert_eq!(event.metadata["user_id_prefix"], json!("491756f0"));
    assert_eq!(event.metadata["selected_pet_id_prefix"], json!("26e149eb"));
    assert_eq!(
        event.metadata["background_asset_id_prefix"],
        json!("54e4abb1")
    );
    assert_eq!(event.metadata["background_media_kind"], json!("video"));
    assert_eq!(event.metadata["hero_video_present"], json!(true));
    assert_eq!(event.metadata["hero_video_width"], json!(704));
    assert_eq!(event.metadata["hero_video_height"], json!(954));
    assert_eq!(event.metadata["hero_theme_color_hex"], json!("#B3C2CE"));
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
