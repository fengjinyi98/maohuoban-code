use super::*;
use std::fs;
use std::time::{SystemTime, UNIX_EPOCH};

fn temp_repo() -> PathBuf {
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let root = std::env::temp_dir().join(format!("mhb-hook-test-{stamp}"));
    fs::create_dir_all(&root).unwrap();
    root
}

fn write_lines(path: &std::path::Path, lines: usize) {
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    let mut content = String::new();
    for _ in 0..lines {
        content.push_str("let value = 1\n");
    }
    fs::write(path, content).unwrap();
}

#[test]
fn extracts_file_path_from_post_tool_use_json() {
    let input = r#"{"hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"/repo/App/Domain/Pet.swift"}}"#;

    let paths = extract_touched_paths(input);

    assert_eq!(paths, vec![PathBuf::from("/repo/App/Domain/Pet.swift")]);
}

#[test]
fn extracts_paths_from_apply_patch_payload() {
    let input = r#"{"tool_name":"apply_patch","tool_input":"*** Begin Patch\n*** Add File: maohuoban/maohuoban/Features/Pet/Domain/NewPet.swift\n+struct NewPet {}\n*** End Patch"}"#;

    let paths = extract_touched_paths(input);

    assert_eq!(
        paths,
        vec![PathBuf::from(
            "maohuoban/maohuoban/Features/Pet/Domain/NewPet.swift"
        )]
    );
}

#[test]
fn blocks_swift_file_over_hard_limit() {
    let root = temp_repo();
    let path = root.join("maohuoban/maohuoban/Features/Pet/Presentation/LargeView.swift");
    write_lines(&path, 401);

    let findings = evaluate_file(&root, &path);

    assert!(findings.iter().any(|finding| {
        finding.severity == Severity::Violation && finding.rule == "swift_file_too_large"
    }));
}

#[test]
fn warns_swift_file_over_guideline_limit() {
    let root = temp_repo();
    let path = root.join("maohuoban/maohuoban/Features/Pet/Presentation/MediumView.swift");
    write_lines(&path, 251);

    let findings = evaluate_file(&root, &path);

    assert!(findings.iter().any(|finding| {
        finding.severity == Severity::Warning && finding.rule == "swift_file_should_split"
    }));
}

#[test]
fn blocks_rust_file_over_hard_limit() {
    let root = temp_repo();
    let path = root.join("maohuoban-rust/crates/maohuoban-pet-domain/src/pet/profile.rs");
    write_lines(&path, 501);

    let findings = evaluate_file(&root, &path);

    assert!(findings.iter().any(|finding| {
        finding.severity == Severity::Violation && finding.rule == "rust_file_too_large"
    }));
}

#[test]
fn blocks_multiple_swift_primary_types() {
    let root = temp_repo();
    let path = root.join("maohuoban/maohuoban/Features/Pet/Domain/ProfilePair.swift");
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(&path, "struct PetProfile {}\nfinal class PetMapper {}\n").unwrap();

    let findings = evaluate_file(&root, &path);

    assert!(findings.iter().any(|finding| {
        finding.severity == Severity::Violation && finding.rule == "multiple_primary_types"
    }));
}

#[test]
fn blocks_new_file_without_responsibility_directory() {
    let root = temp_repo();
    let path = root.join("maohuoban/maohuoban/Features/Pet/NewPetView.swift");
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(&path, "struct NewPetView {}\n").unwrap();

    let findings = evaluate_file(&root, &path);

    assert!(findings.iter().any(|finding| {
        finding.severity == Severity::Violation
            && finding.rule == "missing_responsibility_directory"
    }));
}
