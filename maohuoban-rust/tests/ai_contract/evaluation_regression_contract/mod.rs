use serde::Deserialize;
use std::collections::BTreeMap;

mod fixture_contract;
mod protocol_map;

const PROTOCOL_GATE_MAP_JSON: &str = include_str!(
    "../../../../docs/engineering/ai-agent-runtime/worktree-goals/eval-cases/regression_contract/protocol_gate_map.json"
);
const EVAL_CASES_JSON: &str = include_str!(
    "../../../../docs/engineering/ai-agent-runtime/worktree-goals/eval-cases/ai_eval_cases.json"
);
const REPLAY_CASE_JSON: &str = include_str!(
    "../../../../docs/engineering/ai-agent-runtime/worktree-goals/eval-cases/replay_cases/provider_failure_turn.json"
);
const DIAGNOSTICS_ASSERTIONS_JSON: &str = include_str!(
    "../../../../docs/engineering/ai-agent-runtime/worktree-goals/eval-cases/diagnostics_assertions/ai_chat_diagnostics.json"
);

const REQUIRED_PROTOCOL_IDS: [&str; 12] = [
    "01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12",
];
const REQUIRED_LAYER_NAMES: [&str; 6] = [
    "Domain Contract",
    "Runtime Contract",
    "Provider Contract",
    "HTTP Contract",
    "Replay / Diagnostics",
    "Eval Cases",
];
const REQUIRED_MINIMUM_GATES: [&str; 11] = [
    "cargo test -p maohuoban-ai-domain runtime_event_roundtrip --tests",
    "cargo test -p maohuoban-ai-domain session_event_roundtrip --tests",
    "cargo test -p maohuoban-ai-application --test runtime_loop_engine",
    "cargo test -p maohuoban-ai-application --test runtime_regression_cases",
    "cargo test -p maohuoban-ai-application --test runtime_loop_engine_streaming",
    "cargo test -p maohuoban-ai-application --test eval_case",
    "cargo test --test ai_eval",
    "cargo test -p maohuoban-ai-http --test runtime_stream_projector",
    "cargo test -p maohuoban-ai-infrastructure --test openai_request_policy",
    "cargo test -p maohuoban-ai-infrastructure --test deepseek",
    "cargo test --test ai_contract",
];
const REQUIRED_CHANGE_LAYERS: [&str; 6] = [
    "AiIntent / Gate",
    "Turn / Event / LoopStep",
    "Tool Contract",
    "Provider Capability",
    "Finalizer / Persistence",
    "Memory / Retrieval / Summary",
];
const REQUIRED_FROZEN_OBJECTS: [&str; 7] = [
    "AgentEvent.event_name()",
    "InternalTurnEvent.event_name()",
    "UserVisibleTurnEvent.event_name()",
    "LoopStep.step_name()",
    "AiIntent",
    "AiStreamEvent.event_name()",
    "Tool / Fact / Provider key protocol objects",
];
const REQUIRED_DIAGNOSTICS_FAMILIES: [&str; 9] = [
    "request",
    "response",
    "tool",
    "event",
    "finalizer",
    "planning",
    "skill",
    "provider",
    "redaction",
];

// ProtocolRegressionContract WT10 协议回归总合同
// 核心职责：
// - 固定 01-12 协议文档和测试入口映射
// - 固定分层门禁、改动层门禁和冻结对象清单
#[derive(Debug, Deserialize)]
struct ProtocolRegressionContract {
    schema_version: u32,
    protocol_documents: Vec<ProtocolDocument>,
    contract_layers: Vec<ContractLayer>,
    gate_commands: BTreeMap<String, Vec<String>>,
    change_layer_gates: Vec<ChangeLayerGate>,
    fixture_directories: Vec<FixtureDirectory>,
    frozen_objects: Vec<FrozenObject>,
}

// ProtocolDocument 单份协议文档的守护入口
// 核心职责：
// - 记录协议所属合同层
// - 记录该协议必须运行的测试和命令
#[derive(Debug, Deserialize)]
struct ProtocolDocument {
    id: String,
    title: String,
    document_path: String,
    contract_layer: String,
    test_entries: Vec<String>,
    gate_commands: Vec<String>,
}

// ContractLayer WT10 分层门禁定义
// 核心职责：
// - 固定合同层名称
// - 固定主要测试和冻结对象
#[derive(Debug, Deserialize)]
struct ContractLayer {
    name: String,
    primary_tests: Vec<String>,
    frozen_objects: Vec<String>,
}

// ChangeLayerGate 改动层到必跑测试的映射
// 核心职责：
// - 固化改哪层必须跑哪些测试
// - 防止协议变更只跑窄测试
#[derive(Debug, Deserialize)]
struct ChangeLayerGate {
    change_layer: String,
    required_tests: Vec<String>,
}

// FixtureDirectory WT10 fixture 目录声明
// 核心职责：
// - 固定 fixture 文件落点
// - 固定每类 fixture 的守护测试
#[derive(Debug, Deserialize)]
struct FixtureDirectory {
    kind: String,
    path: String,
    purpose: String,
    guard_tests: Vec<String>,
}

// FrozenObject 协议冻结对象定义
// 核心职责：
// - 固定对象名称和值域
// - 固定守护测试入口
#[derive(Debug, Deserialize)]
struct FrozenObject {
    object: String,
    guard_tests: Vec<String>,
    frozen_values: Vec<String>,
}

// EvalCase Agent eval 固定样例
// 核心职责：
// - 固定 intent/workbench/context/terminal state 期望
// - 固定失败码、宠物解析和脱敏文本期望
#[derive(Debug, Deserialize)]
struct EvalCase {
    name: String,
    message: String,
    surface: String,
    expected_intent: String,
    expected_gate_decision: String,
    expected_workbench: String,
    expected_context_loaded: bool,
    expected_enters_workbench: bool,
    expected_terminal_state: String,
    expected_error_code: Option<String>,
    expected_pet_resolution: Option<String>,
    forbidden_text: Vec<String>,
}

// ReplayCase 回放固定样例
// 核心职责：
// - 固定事件序列
// - 固定回放读取和终态期望
#[derive(Debug, Deserialize)]
struct ReplayCase {
    schema_version: u32,
    name: String,
    case_type: String,
    description: String,
    session_surface: String,
    expected_terminal_state: String,
    event_sequence: Vec<String>,
    expected_replay_read: ExpectedReplayRead,
}

// ExpectedReplayRead 回放读取期望
// 核心职责：
// - 固定按 turn 读取
// - 固定排序与 projector 终态事件
#[derive(Debug, Deserialize)]
struct ExpectedReplayRead {
    by_turn: bool,
    preserve_order: bool,
    projector_terminal_event: String,
}

// DiagnosticsAssertionFixture 诊断断言 fixture
// 核心职责：
// - 固定诊断断言族
// - 固定脱敏禁用文本
#[derive(Debug, Deserialize)]
struct DiagnosticsAssertionFixture {
    schema_version: u32,
    name: String,
    assertion_families: Vec<DiagnosticsAssertionFamily>,
    forbidden_text: Vec<String>,
}

// DiagnosticsAssertionFamily 单个诊断断言族
// 核心职责：
// - 固定事件名
// - 固定必备 metadata 字段
#[derive(Debug, Deserialize)]
struct DiagnosticsAssertionFamily {
    family: String,
    event: String,
    required_fields: Vec<String>,
}

fn parse_protocol_contract() -> ProtocolRegressionContract {
    serde_json::from_str(PROTOCOL_GATE_MAP_JSON).expect("parse protocol gate map")
}

fn parse_eval_cases() -> Vec<EvalCase> {
    serde_json::from_str(EVAL_CASES_JSON).expect("parse eval cases")
}

fn parse_replay_case() -> ReplayCase {
    serde_json::from_str(REPLAY_CASE_JSON).expect("parse replay case")
}

fn parse_diagnostics_assertions() -> DiagnosticsAssertionFixture {
    serde_json::from_str(DIAGNOSTICS_ASSERTIONS_JSON).expect("parse diagnostics assertions")
}
