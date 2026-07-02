//! `planning_runtime_tests` WT08 Runtime 规划执行测试
//! 核心职责：
//! - 验证模型规划、ReplanPolicy 和规划诊断进入真实 Runtime 路径
//! - 固定工具确认、重规划和 step transition 的可观测行为

use std::sync::{Arc, LazyLock, Mutex};

use async_trait::async_trait;
use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel, ToolRegistry,
};
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AgentTurnId, AiConversationSurface, AiError,
    AiToolConfirmationRequirement, LlmChatRequest, LlmChatResponse, LlmFinishReason, LlmMessage,
    LlmRole, LlmStreamEvent, LlmToolCall, LlmUsage, ProviderError, ProviderErrorCategory,
    ToolFactField, ToolFactSchema, ToolFailure, ToolProgressText, Toolset,
};
use maohuoban_diagnostics::{
    CapturePolicy, CleanupPolicy, Diagnostics, DiagnosticsConfig, FileSegmentStore, PrivacyPolicy,
};
use serde_json::json;
use uuid::Uuid;

use super::echo_tool::EchoIdentityTool;
use super::helpers::{AUTHORIZED_PET_ID, test_tool_context, tool_call_response};
use super::provider::ScriptedProvider;
use super::workbenches::{
    final_response, private_pet_context_workbench, public_pet_domain_workbench,
    workbench_with_recent_history,
};

static DIAGNOSTICS_TEST_LOCK: LazyLock<tokio::sync::Mutex<()>> =
    LazyLock::new(|| tokio::sync::Mutex::new(()));

#[tokio::test]
async fn write_like_text_without_tool_call_is_model_answer() {
    let provider = ScriptedProvider::new(vec![LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: "我需要先确认要写入的宠物和记录内容，然后再帮你记录。".to_owned(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: Vec::new(),
        usage: LlmUsage::default(),
        finish_reason: LlmFinishReason::Stop,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }]);
    let mut registry = ToolRegistry::new();
    registry.register(WriteObservationTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        test_tool_context(Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id")),
        None,
    );
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session
        .prompt_with_workbench("帮我记录今天拉稀", private_pet_context_workbench())
        .await
        .expect("write-like model answer");

    assert!(
        events
            .iter()
            .any(|event| matches!(event, AgentEvent::MessageDelta { .. })),
        "runtime should not suppress model text through keyword planning: {events:?}"
    );
    assert!(
        events
            .iter()
            .any(|event| matches!(event, AgentEvent::TurnFinished { .. })),
        "model-planned answer without tool call should finish normally: {events:?}"
    );
    assert_eq!(provider.take_requests().len(), 1);
}

#[tokio::test]
async fn tool_unauthorized_terminates_via_replan_policy_without_followup_model() {
    let provider = ScriptedProvider::new(vec![
        LlmChatResponse {
            message: LlmMessage {
                role: LlmRole::Assistant,
                content: String::new(),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
            tool_calls: vec![LlmToolCall {
                id: "call_denied".to_owned(),
                name: "load_pet_identity_context".to_owned(),
                arguments: json!({
                    "pet_id": "22222222-2222-2222-2222-222222222222"
                })
                .to_string(),
            }],
            usage: LlmUsage::default(),
            finish_reason: LlmFinishReason::ToolCalls,
            provider: "scripted".to_owned(),
            model: "primary".to_owned(),
        },
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        test_tool_context(Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id")),
        None,
    );
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session
        .prompt_with_workbench("猫拉肚子一般要观察什么？", public_pet_domain_workbench())
        .await
        .expect("tool unauthorized");

    assert_eq!(
        provider.take_requests().len(),
        1,
        "tool unauthorized should terminate before followup model: {events:?}"
    );
    assert!(
        events
            .iter()
            .any(|event| matches!(event, AgentEvent::TurnFailed { .. })),
        "tool unauthorized should produce failed turn: {events:?}"
    );
    assert!(
        events
            .iter()
            .all(|event| !matches!(event, AgentEvent::TurnFinished { .. })),
        "tool unauthorized must not complete as a normal answer: {events:?}"
    );
}

#[tokio::test]
async fn model_planned_evidence_failure_is_returned_to_followup_model() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response(
            "load_pet_identity_context",
            &json!({ "pet_id": AUTHORIZED_PET_ID }),
        ),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(FailingIdentityFactTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        test_tool_context(Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id")),
        None,
    );
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session
        .prompt_with_workbench("梅录多大了？", private_pet_context_workbench())
        .await
        .expect("evidence failure followup");

    assert!(
        events
            .iter()
            .any(|event| matches!(event, AgentEvent::TurnFinished { .. })),
        "model-planned evidence failure should be returned to followup model: {events:?}"
    );
    let requests = provider.take_requests();
    assert_eq!(requests.len(), 2);
    assert!(
        requests[1].messages.iter().any(|message| {
            message.role == LlmRole::Tool && message.content.contains("tool.internal_error")
        }),
        "followup model should receive structured tool failure: {requests:?}"
    );
}

#[tokio::test]
async fn tool_invalid_arguments_replans_to_clarification_without_followup_model() {
    let provider = ScriptedProvider::new(vec![
        LlmChatResponse {
            message: LlmMessage {
                role: LlmRole::Assistant,
                content: String::new(),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
            tool_calls: vec![LlmToolCall {
                id: "call_invalid_args".to_owned(),
                name: "load_pet_identity_context".to_owned(),
                arguments: "{bad json".to_owned(),
            }],
            usage: LlmUsage::default(),
            finish_reason: LlmFinishReason::ToolCalls,
            provider: "scripted".to_owned(),
            model: "primary".to_owned(),
        },
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        test_tool_context(Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id")),
        None,
    );
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session
        .prompt_with_workbench("猫拉肚子一般要观察什么？", public_pet_domain_workbench())
        .await
        .expect("tool invalid arguments");

    assert_eq!(
        provider.take_requests().len(),
        1,
        "invalid tool arguments should stop before followup model: {events:?}"
    );
    assert!(
        events
            .iter()
            .any(|event| matches!(event, AgentEvent::NeedsClarification { .. })),
        "invalid tool arguments should replan to clarification: {events:?}"
    );
}

#[tokio::test]
async fn context_limit_provider_error_compresses_context_then_retries() {
    let _diagnostics_guard = DIAGNOSTICS_TEST_LOCK.lock().await;
    let diagnostics = install_test_diagnostics();
    let provider = ContextLimitProvider::new();
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(ToolRegistry::new()),
        test_tool_context(Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id")),
        None,
    );
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session
        .prompt_with_workbench("那要不要停罐头？", workbench_with_recent_history())
        .await
        .expect("context limit should compress context and retry");

    assert!(
        events
            .iter()
            .any(|event| matches!(event, AgentEvent::TurnFinished { .. })),
        "context limit retry should finish turn: {events:?}"
    );
    let requests = provider.take_requests();
    assert_eq!(requests.len(), 2);
    assert!(
        requests[1].messages.len() < requests[0].messages.len(),
        "retry request should use compressed context: {requests:?}"
    );
    diagnostics.flush().expect("flush diagnostics");
    let events = diagnostics.read_events().expect("read diagnostics");
    assert!(
        events.iter().any(|event| {
            event.message == "ai.runtime.planning.decided"
                && event.metadata["replan_reason"] == json!("context_limit_exceeded")
        }),
        "context limit error should be recorded as replan decision: {events:?}"
    );
}

#[tokio::test]
async fn planning_diagnostics_records_real_step_transition() {
    let _diagnostics_guard = DIAGNOSTICS_TEST_LOCK.lock().await;
    let diagnostics = install_test_diagnostics();
    let provider = ScriptedProvider::new(vec![
        tool_call_response(
            "load_pet_identity_context",
            &json!({ "pet_id": AUTHORIZED_PET_ID }),
        ),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);

    let session_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let message_id = Uuid::new_v4();
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider),
        Arc::new(registry),
        test_tool_context(Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id")),
        None,
    );
    let mut session = AgentSession::new(
        session_id,
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session
        .prompt_with_workbench_turn_and_diagnostics_message_id(
            "梅录多大了？",
            private_pet_context_workbench(),
            turn_id,
            message_id,
        )
        .await
        .expect("prompt with diagnostics");

    diagnostics.flush().expect("flush diagnostics");
    let events = diagnostics.read_events().expect("read diagnostics");
    let planning_events: Vec<_> = events
        .iter()
        .filter(|event| {
            event.message == "ai.runtime.planning.decided"
                && event.metadata["session_id"] == json!(session_id)
                && event.metadata["turn_id"] == json!(turn_id.as_uuid())
                && event.metadata["message_id"] == json!(message_id)
        })
        .collect();

    assert!(
        planning_events.iter().any(|event| {
            event.metadata["current_step"] == json!("tool_read")
                && event.metadata["step_transition"] == json!("model_reason->tool_read")
        }),
        "planning diagnostics should include real step transition: {planning_events:?}"
    );
}

#[derive(Clone)]
struct WriteObservationTool;

#[async_trait]
impl AiToolDefinition for WriteObservationTool {
    fn name(&self) -> &'static str {
        "write_pet_observation"
    }

    fn description(&self) -> &'static str {
        "写入宠物观察记录"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "pet_id": { "type": "string", "format": "uuid" },
                "note": { "type": "string" }
            },
            "required": ["pet_id", "note"]
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.observation.write".to_owned(),
            read_only: false,
            concurrency_safe: false,
            risk_level: AiToolRiskLevel::High,
            requires_confirmation: true,
            domain_tags: vec!["observation".to_owned()],
            toolset: Toolset::Confirmation,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::requires_confirmation(AiToolConfirmationRequirement {
            confirmation_task_id: Uuid::new_v4().to_string(),
            tool_name: "write_pet_observation".to_owned(),
            question_text: "是否确认写入这条观察记录？".to_owned(),
            args: json!({
                "pet_id": AUTHORIZED_PET_ID,
                "note": "今天拉稀"
            }),
        })
    }
}

#[derive(Clone)]
struct FailingIdentityFactTool;

#[async_trait]
impl AiToolDefinition for FailingIdentityFactTool {
    fn name(&self) -> &'static str {
        "load_pet_identity_context"
    }

    fn description(&self) -> &'static str {
        "加载宠物身份上下文"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "pet_id": { "type": "string", "format": "uuid" }
            },
            "required": ["pet_id"]
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.identity.read".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["identity".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: Some(ToolFactSchema {
                fact_keys: vec!["pet_identity.world_days".to_owned()],
                description: "宠物基础档案事实".to_owned(),
                natural_language_summary: "可回答宠物多大了、几岁了、出生多久了等问题".to_owned(),
                fields: vec![ToolFactField {
                    key: "pet_identity.world_days".to_owned(),
                    label: "年龄/出生至今天数".to_owned(),
                    meaning: "宠物从出生到今天经过的天数，可用于回答多大了、几岁了".to_owned(),
                    example_queries: vec!["多大了".to_owned(), "几岁了".to_owned()],
                }],
                default_strength: None,
            }),
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::failed_with_failure(ToolFailure::new(
            "tool.internal_error",
            false,
            "工具执行失败",
            "identity store unavailable",
        ))
    }
}

#[derive(Clone)]
struct ContextLimitProvider {
    requests: Arc<Mutex<Vec<LlmChatRequest>>>,
    attempts: Arc<Mutex<u32>>,
}

impl ContextLimitProvider {
    fn new() -> Self {
        Self {
            requests: Arc::new(Mutex::new(Vec::new())),
            attempts: Arc::new(Mutex::new(0)),
        }
    }

    fn take_requests(&self) -> Vec<LlmChatRequest> {
        self.requests.lock().expect("requests").clone()
    }
}

impl LlmProvider for ContextLimitProvider {
    fn complete<'a>(
        &'a self,
        _request: &'a LlmChatRequest,
    ) -> std::pin::Pin<
        Box<
            dyn std::future::Future<Output = maohuoban_ai_domain::ai::AiResult<LlmChatResponse>>
                + Send
                + 'a,
        >,
    > {
        Box::pin(async {
            Err(AiError::Provider(ProviderError::new(
                ProviderErrorCategory::InvalidResponse,
                "maximum context length exceeded",
            )))
        })
    }

    fn stream<'a>(
        &'a self,
        request: &'a LlmChatRequest,
    ) -> futures_util::stream::BoxStream<'a, maohuoban_ai_domain::ai::AiResult<LlmStreamEvent>>
    {
        self.requests
            .lock()
            .expect("requests")
            .push(request.clone());
        let mut attempts = self.attempts.lock().expect("attempts");
        *attempts += 1;
        let events = if *attempts == 1 {
            vec![Err(AiError::Provider(ProviderError::new(
                ProviderErrorCategory::InvalidResponse,
                "maximum context length exceeded",
            )))]
        } else {
            vec![
                Ok(LlmStreamEvent::Delta {
                    content: "压缩上下文后回答。".to_owned(),
                }),
                Ok(LlmStreamEvent::Finish {
                    finish_reason: LlmFinishReason::Stop,
                    usage: LlmUsage::default(),
                }),
            ]
        };
        futures_util::stream::iter(events).boxed()
    }
}

fn install_test_diagnostics() -> Diagnostics {
    let root = std::env::temp_dir().join(format!(
        "maohuoban-planning-runtime-diagnostics-{}",
        Uuid::new_v4()
    ));
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
