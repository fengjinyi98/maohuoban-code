// runtime_regression_cases Agent Runtime 回归 case 套件
// 核心职责：
// - 覆盖 8 类核心 runtime 场景
// - 固定自研 AgentRuntimeLoopEngine 的用户可见事件顺序和内部请求边界
//
// 文件超 500 行原因：8 个 case + 共享测试基础设施（ScriptedProvider、
// 工具桩、workbench 构造器），拆分需引入 common 模块且破坏 case 内聚性。

use std::collections::VecDeque;
use std::sync::{Arc, Mutex};

use async_trait::async_trait;
use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession, LoopEngine};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel, ToolRegistry,
};
use maohuoban_ai_domain::ai::{
    AgentCapability, AgentDefinition, AgentEvent, AgentId, AgentSessionWorkbench, AgentToolStatus,
    AiConversationSurface, AiFactEntry, AiFactStrength, AiMessageRole, CapabilityCatalog,
    CapabilityDomain, ContextPack, ContextPetSummary, LlmChatRequest, LlmChatResponse,
    LlmFinishReason, LlmMessage, LlmRole, LlmStreamEvent, LlmToolCall, LlmUsage, MemoryPack,
    ModelLabel, RecentConversationEntry, RecentConversationPack, ToolProgressText, Toolset,
};
use serde_json::json;
use uuid::Uuid;

const AUTHORIZED_PET_ID: &str = "11111111-1111-1111-1111-111111111111";

// ===========================================================================
// 共享测试基础设施
// ===========================================================================

#[derive(Clone)]
struct ScriptedProvider {
    requests: Arc<Mutex<Vec<LlmChatRequest>>>,
    responses: Arc<Mutex<VecDeque<LlmChatResponse>>>,
}

impl ScriptedProvider {
    fn new(responses: Vec<LlmChatResponse>) -> Self {
        Self {
            requests: Arc::new(Mutex::new(Vec::new())),
            responses: Arc::new(Mutex::new(VecDeque::from(responses))),
        }
    }

    fn take_requests(&self) -> Vec<LlmChatRequest> {
        self.requests.lock().expect("requests").clone()
    }
}

impl LlmProvider for ScriptedProvider {
    fn complete<'a>(
        &'a self,
        request: &'a LlmChatRequest,
    ) -> std::pin::Pin<
        Box<
            dyn std::future::Future<Output = maohuoban_ai_domain::ai::AiResult<LlmChatResponse>>
                + Send
                + 'a,
        >,
    > {
        let response = self.responses.clone();
        let requests = self.requests.clone();
        let request = request.clone();
        Box::pin(async move {
            requests.lock().expect("requests").push(request);
            response
                .lock()
                .expect("responses")
                .pop_front()
                .ok_or_else(|| {
                    maohuoban_ai_domain::ai::AiError::Infrastructure(
                        "missing scripted response".to_owned(),
                    )
                })
        })
    }

    fn stream<'a>(
        &'a self,
        request: &'a LlmChatRequest,
    ) -> futures_util::stream::BoxStream<
        'a,
        maohuoban_ai_domain::ai::AiResult<maohuoban_ai_domain::ai::LlmStreamEvent>,
    > {
        self.requests
            .lock()
            .expect("requests")
            .push(request.clone());
        let events = self
            .responses
            .lock()
            .expect("responses")
            .pop_front()
            .map_or_else(
                || {
                    vec![Err(maohuoban_ai_domain::ai::AiError::Infrastructure(
                        "missing scripted response".to_owned(),
                    ))]
                },
                response_to_stream_events,
            );
        futures_util::stream::iter(events).boxed()
    }
}

fn response_to_stream_events(
    response: LlmChatResponse,
) -> Vec<maohuoban_ai_domain::ai::AiResult<LlmStreamEvent>> {
    let mut events = Vec::new();
    for tool_call in response.tool_calls {
        events.push(Ok(LlmStreamEvent::ToolCall { tool_call }));
    }
    if !response.message.content.is_empty() {
        events.push(Ok(LlmStreamEvent::Delta {
            content: response.message.content,
        }));
    }
    events.push(Ok(LlmStreamEvent::Finish {
        finish_reason: response.finish_reason,
        usage: response.usage,
    }));
    events
}

fn final_text_response(text: &str) -> LlmChatResponse {
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: text.to_owned(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![],
        usage: LlmUsage::default(),
        finish_reason: LlmFinishReason::Stop,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

#[allow(clippy::needless_pass_by_value)]
fn tool_call_response(tool_name: &str, args: serde_json::Value) -> LlmChatResponse {
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: String::new(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![LlmToolCall {
            id: "call_1".to_owned(),
            name: tool_name.to_owned(),
            arguments: args.to_string(),
        }],
        usage: LlmUsage::default(),
        finish_reason: LlmFinishReason::ToolCalls,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

fn json_response(answer_text: &str) -> LlmChatResponse {
    let content = serde_json::json!({"answer_text": answer_text}).to_string();
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content,
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![],
        usage: LlmUsage::default(),
        finish_reason: LlmFinishReason::Stop,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

fn think_response(inner: &str, visible: &str) -> LlmChatResponse {
    let content = format!("<think>{inner}</think>{visible}");
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content,
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![],
        usage: LlmUsage::default(),
        finish_reason: LlmFinishReason::Stop,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

struct EchoIdentityTool;

#[async_trait]
impl AiToolDefinition for EchoIdentityTool {
    fn name(&self) -> &'static str {
        "load_pet_identity_context"
    }
    fn description(&self) -> &'static str {
        "加载宠物身份上下文"
    }
    fn parameters_schema(&self) -> serde_json::Value {
        json!({"type": "object", "properties": {}, "required": []})
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
            result_fact_schema: None,
        }
    }
    async fn execute(&self, ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        if ctx.authorized_pet_id == Uuid::nil() {
            return AiToolResult::denied("pet not authorized");
        }
        AiToolResult::allowed_with_facts(
            vec![AiFactEntry {
                key: "pet_name".to_owned(),
                value: "饭团".to_owned(),
                strength: AiFactStrength::Strong,
                citation_id: None,
            }],
            Vec::new(),
        )
    }
}

struct AlwaysFailTool;

#[async_trait]
impl AiToolDefinition for AlwaysFailTool {
    fn name(&self) -> &'static str {
        "load_pet_identity_context"
    }
    fn description(&self) -> &'static str {
        "加载宠物身份上下文"
    }
    fn parameters_schema(&self) -> serde_json::Value {
        json!({"type": "object", "properties": {}, "required": []})
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
            result_fact_schema: None,
        }
    }
    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::failed("upstream_timeout")
    }
}

fn public_pet_domain_workbench() -> AgentSessionWorkbench {
    AgentSessionWorkbench {
        agent_definition: AgentDefinition {
            agent_id: AgentId::main_pet_care_agent(),
            name: "毛球".to_owned(),
            purpose: "宠物垂直照护与用户宠物私域助手".to_owned(),
            default_model_label: ModelLabel::Primary,
            capability_domains: vec![CapabilityDomain::PublicPetDomain],
        },
        capability_catalog: CapabilityCatalog {
            capabilities: vec![AgentCapability {
                code: "public_pet_care".to_owned(),
                domain: CapabilityDomain::PublicPetDomain,
                title: "公共养宠咨询".to_owned(),
                when_to_use: "用户咨询通用照护、饮食、行为或常见症状观察时使用".to_owned(),
                requires_private_context: false,
            }],
        },
        context_pack: ContextPack {
            surface: AiConversationSurface::HomePrivate,
            locale: "zh-Hans".to_owned(),
            timezone: "Asia/Shanghai".to_owned(),
            selected_pet: None,
            authorized_pets: Vec::new(),
            session_summary: None,
        },
        memory_pack: MemoryPack {
            entries: Vec::new(),
        },
        recent_conversation_pack: None,
    }
}

fn private_pet_workbench() -> AgentSessionWorkbench {
    let mut wb = public_pet_domain_workbench();
    wb.context_pack.selected_pet = Some(ContextPetSummary {
        pet_id: Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id"),
        name: "饭团".to_owned(),
        species: "cat".to_owned(),
    });
    wb
}

fn workbench_with_history(history: Vec<RecentConversationEntry>) -> AgentSessionWorkbench {
    let mut wb = public_pet_domain_workbench();
    wb.recent_conversation_pack = Some(RecentConversationPack { entries: history });
    wb
}

fn authorized_context() -> AiToolContext {
    AiToolContext {
        actor_user_id: Uuid::new_v4(),
        authorized_pet_id: Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id"),
    }
}

fn unauthorized_context() -> AiToolContext {
    AiToolContext {
        actor_user_id: Uuid::new_v4(),
        authorized_pet_id: Uuid::nil(),
    }
}

fn build_engine(
    provider: Arc<ScriptedProvider>,
    registry: ToolRegistry,
    ctx: AiToolContext,
) -> AgentRuntimeLoopEngine {
    AgentRuntimeLoopEngine::new(provider, Arc::new(registry), ctx, None)
}

// ---- 通用 prompt runner ----

/// `run_prompt` 使用任意 `LoopEngine` 运行 prompt 并收集事件
async fn run_prompt<E: LoopEngine>(
    engine: E,
    input: &str,
    workbench: Option<AgentSessionWorkbench>,
) -> Vec<AgentEvent> {
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );
    match workbench {
        Some(wb) => session
            .prompt_with_workbench(input, wb)
            .await
            .expect("prompt"),
        None => session.prompt(input).await.expect("prompt"),
    }
}

// ---- 断言辅助 ----

fn assert_has_turn_finished(events: &[AgentEvent]) {
    assert!(
        events
            .iter()
            .any(|e| matches!(e, AgentEvent::TurnFinished { .. })),
        "should have TurnFinished event"
    );
}

fn assert_has_turn_failed(events: &[AgentEvent]) {
    assert!(
        events
            .iter()
            .any(|e| matches!(e, AgentEvent::TurnFailed { .. })),
        "should have TurnFailed event"
    );
}

fn final_text(events: &[AgentEvent]) -> String {
    events
        .iter()
        .find_map(|e| match e {
            AgentEvent::TurnFinished { final_text, .. } => Some(final_text.clone()),
            _ => None,
        })
        .unwrap_or_default()
}

fn has_tool_started(events: &[AgentEvent], tool_name: &str) -> bool {
    events
        .iter()
        .any(|e| matches!(e, AgentEvent::ToolStarted { tool_name: name, .. } if name == tool_name))
}

fn has_tool_finished(events: &[AgentEvent], status: AgentToolStatus) -> bool {
    events
        .iter()
        .any(|e| matches!(e, AgentEvent::ToolFinished { status: s, .. } if *s == status))
}

// ===========================================================================
// Case 1: 无宠物公共问答
// ===========================================================================

#[tokio::test]
async fn case_public_qa_without_pet() {
    let provider = ScriptedProvider::new(vec![final_text_response("猫拉肚子要观察精神和食欲")]);
    let real_engine = build_engine(
        Arc::new(provider.clone()),
        ToolRegistry::new(),
        unauthorized_context(),
    );
    let real_events = run_prompt(real_engine, "猫拉肚子怎么办", None).await;

    assert_has_turn_finished(&real_events);
    assert_eq!(final_text(&real_events), "猫拉肚子要观察精神和食欲");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 1);
    assert!(
        requests[0].tools.is_empty(),
        "public QA without pet should not expose private tools"
    );
}

// ===========================================================================
// Case 2: 私域工具调用
// ===========================================================================

#[tokio::test]
async fn case_private_tool_call_with_authorized_pet() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response("load_pet_identity_context", json!({})),
        final_text_response("饭团是一只猫"),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);
    let real_engine = build_engine(Arc::new(provider.clone()), registry, authorized_context());
    let real_events = run_prompt(real_engine, "毛球是谁", Some(private_pet_workbench())).await;

    assert_has_turn_finished(&real_events);

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 2);
    let tool_msg = requests[1]
        .messages
        .iter()
        .find(|m| m.role == LlmRole::Tool)
        .expect("followup should have tool message");
    assert!(
        tool_msg.content.contains("饭团"),
        "tool result should contain pet name, got: {}",
        tool_msg.content
    );
}

// ===========================================================================
// Case 3: 工具进度事件
// ===========================================================================

#[tokio::test]
async fn case_tool_progress_events() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response("load_pet_identity_context", json!({})),
        final_text_response("饭团档案已加载"),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);
    let real_engine = build_engine(Arc::new(provider), registry, authorized_context());
    let real_events = run_prompt(real_engine, "毛球是谁", Some(private_pet_workbench())).await;

    assert!(has_tool_started(&real_events, "load_pet_identity_context"));
    assert!(has_tool_finished(&real_events, AgentToolStatus::Succeeded));
    assert_has_turn_finished(&real_events);
}

// ===========================================================================
// Case 4: 思考过滤
// ===========================================================================

#[tokio::test]
async fn case_thinking_content_filtered() {
    let provider = ScriptedProvider::new(vec![think_response(
        "internal reasoning about pet diet",
        "建议减少零食，观察食欲",
    )]);
    let real_engine = build_engine(
        Arc::new(provider),
        ToolRegistry::new(),
        authorized_context(),
    );
    let real_events = run_prompt(real_engine, "毛球不吃饭", None).await;

    assert_has_turn_finished(&real_events);
    let text = final_text(&real_events);
    assert!(
        !text.contains("internal reasoning"),
        "thinking content should be filtered, got: {text}"
    );
    assert!(
        text.contains("建议减少零食"),
        "visible content should be preserved, got: {text}"
    );
}

// ===========================================================================
// Case 5: JSON 过滤
// ===========================================================================

#[tokio::test]
async fn case_json_output_filtered() {
    let provider = ScriptedProvider::new(vec![json_response("猫粮换粮需要7天过渡期")]);
    let real_engine = build_engine(
        Arc::new(provider),
        ToolRegistry::new(),
        authorized_context(),
    );
    let real_events = run_prompt(real_engine, "怎么换粮", None).await;

    assert_has_turn_finished(&real_events);
    let text = final_text(&real_events);
    assert_eq!(
        text, "猫粮换粮需要7天过渡期",
        "should extract answer_text from JSON output"
    );
    assert!(
        !text.contains("answer_text"),
        "JSON field name should not appear in visible text"
    );
}

// ===========================================================================
// Case 6: 连续追问（同会话历史注入）
// ===========================================================================

#[tokio::test]
async fn case_followup_question_with_history() {
    let provider = ScriptedProvider::new(vec![final_text_response("可以适当减少罐头")]);
    let real_engine = build_engine(
        Arc::new(provider.clone()),
        ToolRegistry::new(),
        authorized_context(),
    );

    let history = vec![
        RecentConversationEntry {
            role: AiMessageRole::User,
            content: "豆包今天拉肚子怎么办".to_owned(),
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        RecentConversationEntry {
            role: AiMessageRole::Assistant,
            content: "先观察精神和食欲".to_owned(),
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
    ];

    let real_events = run_prompt(
        real_engine,
        "那要不要停罐头",
        Some(workbench_with_history(history)),
    )
    .await;

    assert_has_turn_finished(&real_events);

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 1);
    let messages = &requests[0].messages;
    assert!(
        messages
            .iter()
            .any(|m| m.content.contains("豆包今天拉肚子")),
        "history should be injected into model request"
    );
    assert!(
        messages
            .iter()
            .any(|m| m.content.contains("那要不要停罐头")),
        "current question should be in request"
    );
}

// ===========================================================================
// Case 7: 越权拒绝
// ===========================================================================

#[tokio::test]
async fn case_unauthorized_pet_denied() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response("load_pet_identity_context", json!({})),
        final_text_response("无法获取宠物信息"),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);
    let real_engine = build_engine(Arc::new(provider.clone()), registry, unauthorized_context());
    let real_events = run_prompt(real_engine, "毛球是谁", Some(private_pet_workbench())).await;

    assert!(
        has_tool_finished(&real_events, AgentToolStatus::Denied),
        "should emit ToolFinished with Denied status"
    );

    let requests = provider.take_requests();
    assert!(requests.len() >= 2);
    let tool_msg = requests[1]
        .messages
        .iter()
        .find(|m| m.role == LlmRole::Tool)
        .expect("followup should have tool message");
    assert!(
        !tool_msg.content.contains("饭团"),
        "denied tool should not expose pet name"
    );
    assert!(
        tool_msg.content.contains("工具无法执行"),
        "denied tool should return safe message"
    );
}

// ===========================================================================
// Case 8: 工具重复失败 → guardrail HardStop
// ===========================================================================

#[tokio::test]
async fn case_repeated_tool_failure_guardrail() {
    let provider = ScriptedProvider::new(vec![LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: String::new(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: (0..3)
            .map(|i| LlmToolCall {
                id: format!("call_{i}"),
                name: "load_pet_identity_context".to_owned(),
                arguments: "{}".to_owned(),
            })
            .collect(),
        usage: LlmUsage::default(),
        finish_reason: LlmFinishReason::ToolCalls,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }]);
    let mut registry = ToolRegistry::new();
    registry.register(AlwaysFailTool);
    let real_engine = build_engine(Arc::new(provider), registry, authorized_context());
    let real_events = run_prompt(real_engine, "毛球是谁", None).await;

    assert_has_turn_failed(&real_events);
}
