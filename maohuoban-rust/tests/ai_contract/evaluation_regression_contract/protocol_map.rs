use super::{
    REQUIRED_CHANGE_LAYERS, REQUIRED_FROZEN_OBJECTS, REQUIRED_LAYER_NAMES, REQUIRED_MINIMUM_GATES,
    REQUIRED_PROTOCOL_IDS, parse_protocol_contract,
};

#[test]
fn regression_contract_maps_protocol_documents_to_layers_tests_and_commands() {
    let contract = parse_protocol_contract();

    assert_eq!(contract.schema_version, 1);

    let document_ids = contract
        .protocol_documents
        .iter()
        .map(|document| document.id.as_str())
        .collect::<Vec<_>>();
    assert_eq!(document_ids, REQUIRED_PROTOCOL_IDS);

    let layer_names = contract
        .contract_layers
        .iter()
        .map(|layer| layer.name.as_str())
        .collect::<Vec<_>>();
    assert_eq!(layer_names, REQUIRED_LAYER_NAMES);

    for document in &contract.protocol_documents {
        assert!(
            !document.title.is_empty(),
            "missing title for {}",
            document.id
        );
        assert!(
            document
                .document_path
                .starts_with("docs/engineering/ai-agent-runtime/"),
            "document {} has invalid path {}",
            document.id,
            document.document_path
        );
        assert!(
            REQUIRED_LAYER_NAMES.contains(&document.contract_layer.as_str()),
            "document {} maps to unknown layer {}",
            document.id,
            document.contract_layer
        );
        assert!(
            !document.test_entries.is_empty(),
            "document {} missing test entries",
            document.id
        );
        assert!(
            !document.gate_commands.is_empty(),
            "document {} missing gate commands",
            document.id
        );
        for entry in &document.test_entries {
            assert!(
                entry.starts_with("maohuoban-rust/"),
                "document {} has invalid test entry {entry}",
                document.id
            );
        }
        for command in &document.gate_commands {
            assert!(
                command.starts_with("cargo test "),
                "document {} has non-test gate command {command}",
                document.id
            );
        }
    }

    for layer in &contract.contract_layers {
        assert!(
            !layer.primary_tests.is_empty(),
            "layer {} missing primary tests",
            layer.name
        );
        assert!(
            !layer.frozen_objects.is_empty(),
            "layer {} missing frozen objects",
            layer.name
        );
    }
}

#[test]
fn regression_contract_freezes_gate_commands_and_change_layer_matrix() {
    let contract = parse_protocol_contract();

    for stage in ["minimum", "wave", "integration", "workspace"] {
        let commands = contract
            .gate_commands
            .get(stage)
            .unwrap_or_else(|| panic!("missing gate stage {stage}"));
        assert!(!commands.is_empty(), "gate stage {stage} is empty");
    }

    let minimum = contract.gate_commands.get("minimum").expect("minimum gate");
    for command in REQUIRED_MINIMUM_GATES {
        assert!(
            minimum.iter().any(|candidate| candidate == command),
            "minimum gate missing command: {command}"
        );
    }

    let workspace = contract
        .gate_commands
        .get("workspace")
        .expect("workspace gate");
    for command in [
        "cargo fmt --all --check",
        "cargo check --workspace --all-targets",
        "cargo clippy --workspace --all-targets -- -D warnings",
        "cargo test --workspace",
    ] {
        assert!(
            workspace.iter().any(|candidate| candidate == command),
            "workspace gate missing command: {command}"
        );
    }

    let change_layers = contract
        .change_layer_gates
        .iter()
        .map(|gate| gate.change_layer.as_str())
        .collect::<Vec<_>>();
    assert_eq!(change_layers, REQUIRED_CHANGE_LAYERS);

    for gate in &contract.change_layer_gates {
        assert!(
            gate.required_tests
                .iter()
                .all(|command| command.starts_with("cargo test ")),
            "change layer {} contains non-test gate",
            gate.change_layer
        );
        assert!(
            gate.required_tests.len() >= 2,
            "change layer {} should require layered tests",
            gate.change_layer
        );
    }
}

#[test]
fn regression_contract_freezes_protocol_objects_and_fixture_directories() {
    let contract = parse_protocol_contract();

    let frozen_objects = contract
        .frozen_objects
        .iter()
        .map(|object| object.object.as_str())
        .collect::<Vec<_>>();
    assert_eq!(frozen_objects, REQUIRED_FROZEN_OBJECTS);

    for object in &contract.frozen_objects {
        assert!(
            !object.guard_tests.is_empty(),
            "frozen object {} missing guard tests",
            object.object
        );
        assert!(
            !object.frozen_values.is_empty(),
            "frozen object {} missing frozen values",
            object.object
        );
    }

    let fixture_kinds = contract
        .fixture_directories
        .iter()
        .map(|fixture| fixture.kind.as_str())
        .collect::<Vec<_>>();
    assert_eq!(
        fixture_kinds,
        vec![
            "eval_cases",
            "regression_contract",
            "replay_cases",
            "diagnostics_assertions"
        ]
    );

    for fixture in &contract.fixture_directories {
        assert!(
            fixture
                .path
                .starts_with("docs/engineering/ai-agent-runtime/worktree-goals/eval-cases/"),
            "fixture {} has invalid path {}",
            fixture.kind,
            fixture.path
        );
        assert!(
            !fixture.purpose.is_empty(),
            "fixture {} missing purpose",
            fixture.kind
        );
        assert!(
            !fixture.guard_tests.is_empty(),
            "fixture {} missing guard tests",
            fixture.kind
        );
    }
}
