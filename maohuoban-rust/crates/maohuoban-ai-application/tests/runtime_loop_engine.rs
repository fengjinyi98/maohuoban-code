// runtime_loop_engine Agent Runtime 闭环测试
// 核心职责：
// - 验证 AgentSession / LoopEngine / Tool Gateway 串联后可完成模型 -> 工具 -> 再生成
// - 验证工具 schema 会注入模型请求

use std::collections::VecDeque;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use async_trait::async_trait;
use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel, ToolRegistry,
};
use maohuoban_ai_domain::ai::{
    AgentCapability, AgentDefinition, AgentEvent, AgentId, AgentSessionWorkbench,
    AiConversationSurface, AiFactEntry, AiFactStrength, AiMessageRole,
    AiToolConfirmationRequirement, CapabilityCatalog, CapabilityDomain, ContextPack,
    ContextPetSummary, LlmChatRequest, LlmChatResponse, LlmFinishReason, LlmMessage, LlmRole,
    LlmStreamEvent, LlmToolCall, LlmUsage, MemoryPack, ModelLabel, RecentConversationEntry,
    RecentConversationPack, ToolFactField, ToolFactSchema, ToolFailure, ToolProgressText, Toolset,
};
use serde_json::json;
use uuid::Uuid;

/// `tool_call_response` 构造包含工具调用的脚本响应
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

/// `find_tool_message` 从请求列表中找到 followup 请求的 tool role 消息
fn find_tool_message(requests: &[LlmChatRequest]) -> &LlmMessage {
    requests
        .iter()
        .find(|req| req.messages.iter().any(|m| m.role == LlmRole::Tool))
        .and_then(|req| req.messages.iter().find(|m| m.role == LlmRole::Tool))
        .expect("followup request should contain a tool message")
}

const AUTHORIZED_PET_ID: &str = "11111111-1111-1111-1111-111111111111";

#[derive(Clone)]
struct ScriptedProvider {
    requests: Arc<Mutex<Vec<LlmChatRequest>>>,
    responses: Arc<Mutex<VecDeque<LlmChatResponse>>>,
    delays: Arc<Mutex<VecDeque<Duration>>>,
}

impl ScriptedProvider {
    fn new(responses: Vec<LlmChatResponse>) -> Self {
        Self::with_delays(responses, Vec::new())
    }

    fn with_delays(responses: Vec<LlmChatResponse>, delays: Vec<Duration>) -> Self {
        Self {
            requests: Arc::new(Mutex::new(Vec::new())),
            responses: Arc::new(Mutex::new(VecDeque::from(responses))),
            delays: Arc::new(Mutex::new(VecDeque::from(delays))),
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
        let delays = self.delays.clone();
        let request = request.clone();

        Box::pin(async move {
            requests.lock().expect("requests").push(request);
            let delay = delays
                .lock()
                .expect("delays")
                .pop_front()
                .unwrap_or_default();
            if !delay.is_zero() {
                tokio::time::sleep(delay).await;
            }
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
        let _ = self.delays.lock().expect("delays").pop_front();
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
                fact_keys: vec![
                    "pet_identity.name".to_owned(),
                    "pet_identity.world_days".to_owned(),
                    "pet_identity.companionship_days".to_owned(),
                ],
                description: "宠物基础档案事实".to_owned(),
                natural_language_summary:
                    "可回答宠物多大了、几岁了、来到世界多少天、生日、陪伴多久等问题".to_owned(),
                fields: vec![
                    ToolFactField {
                        key: "pet_identity.world_days".to_owned(),
                        label: "年龄/出生至今天数".to_owned(),
                        meaning: "宠物从出生到今天经过的天数，可用于回答多大了、几岁了、出生多久了"
                            .to_owned(),
                        example_queries: vec![
                            "多大了".to_owned(),
                            "几岁了".to_owned(),
                            "出生多久了".to_owned(),
                        ],
                    },
                    ToolFactField {
                        key: "pet_identity.companionship_days".to_owned(),
                        label: "陪伴天数".to_owned(),
                        meaning: "宠物从到家日期到今天陪伴用户的天数".to_owned(),
                        example_queries: vec!["陪伴我多久了".to_owned(), "到家多久了".to_owned()],
                    },
                ],
            }),
        }
    }

    async fn execute(&self, ctx: &AiToolContext, args: &serde_json::Value) -> AiToolResult {
        let pet_id = args
            .get("pet_id")
            .and_then(|value| value.as_str())
            .and_then(|value| Uuid::parse_str(value).ok());

        match pet_id {
            Some(id) if id == ctx.authorized_pet_id => AiToolResult::allowed_with_facts(
                vec![
                    AiFactEntry {
                        key: "current_staple".to_owned(),
                        value: "渴望六种鱼".to_owned(),
                        strength: AiFactStrength::Strong,
                        citation_id: Some(Uuid::new_v4()),
                    },
                    AiFactEntry {
                        key: "pet_identity.name".to_owned(),
                        value: "梅录".to_owned(),
                        strength: AiFactStrength::Strong,
                        citation_id: None,
                    },
                    AiFactEntry {
                        key: "pet_identity.world_days".to_owned(),
                        value: "420".to_owned(),
                        strength: AiFactStrength::Strong,
                        citation_id: None,
                    },
                    AiFactEntry {
                        key: "pet_identity.companionship_days".to_owned(),
                        value: "378".to_owned(),
                        strength: AiFactStrength::Strong,
                        citation_id: None,
                    },
                ],
                Vec::new(),
            ),
            Some(_) => AiToolResult::denied("pet not authorized"),
            None => AiToolResult::failed("missing pet_id"),
        }
    }
}

fn final_response() -> LlmChatResponse {
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: "毛球当前状态正常".to_owned(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![],
        usage: LlmUsage {
            input_tokens: 12,
            output_tokens: 6,
            total_tokens: 18,
        },
        finish_reason: LlmFinishReason::Stop,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

fn json_final_response() -> LlmChatResponse {
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: serde_json::json!({
                "answer_text": "毛球当前状态正常，可以继续观察精神和食欲。",
                "display_blocks": [
                    {
                        "type": "paragraph",
                        "text": "毛球当前状态正常，可以继续观察精神和食欲。"
                    }
                ],
                "follow_up_questions": [],
                "safety_notes": []
            })
            .to_string(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![],
        usage: LlmUsage {
            input_tokens: 12,
            output_tokens: 20,
            total_tokens: 32,
        },
        finish_reason: LlmFinishReason::Stop,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
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

fn private_pet_context_workbench() -> AgentSessionWorkbench {
    let mut workbench = public_pet_domain_workbench();
    workbench
        .agent_definition
        .capability_domains
        .push(CapabilityDomain::PrivatePetContext);
    workbench
        .capability_catalog
        .capabilities
        .push(AgentCapability {
            code: "private_pet_context".to_owned(),
            domain: CapabilityDomain::PrivatePetContext,
            title: "授权宠物私域上下文".to_owned(),
            when_to_use: "用户询问已选宠物的档案、年龄、生日、陪伴、饮食或记录事实时使用"
                .to_owned(),
            requires_private_context: true,
        });
    workbench.context_pack.selected_pet = Some(ContextPetSummary {
        pet_id: Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id"),
        name: "梅录".to_owned(),
        species: "cat".to_owned(),
    });
    workbench
}

#[tokio::test]
async fn public_pet_domain_without_private_tools() {
    let provider = ScriptedProvider::new(vec![final_response()]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::parse_str("11111111-1111-1111-1111-111111111111")
                .expect("pet id"),
        },
        None,
    );

    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session
        .prompt_with_workbench("猫拉肚子一般要观察什么？", public_pet_domain_workbench())
        .await
        .expect("prompt public pet domain");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 1);
    assert!(
        requests[0].tools.is_empty(),
        "public pet domain without selected pet must not expose private tools, got {:?}",
        requests[0]
            .tools
            .iter()
            .map(|tool| tool.name.as_str())
            .collect::<Vec<_>>()
    );
    assert!(
        requests[0].response_format.is_none(),
        "direct answer request should avoid DeepSeek JSON Output empty content risk"
    );
}

#[tokio::test]
async fn private_identity_question_prefetches_fact_tool_before_model() {
    let provider = ScriptedProvider::new(vec![final_response()]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id"),
        },
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
        .expect("prompt with private context");

    let names: Vec<&'static str> = events.iter().map(AgentEvent::event_name).collect();
    assert_eq!(
        names,
        vec![
            "turn_started",
            "tool_started",
            "tool_finished",
            "message_delta",
            "model_call_started",
            "model_call_finished",
            "turn_finished",
        ],
        "private fact question should execute evidence tool before model"
    );

    let requests = provider.take_requests();
    assert_eq!(
        requests.len(),
        1,
        "prefetch should call provider once after tool evidence is available"
    );
    assert!(
        requests[0]
            .messages
            .iter()
            .all(|message| message.role != LlmRole::Tool),
        "prefetched evidence must not be sent as OpenAI tool-role history"
    );
    assert!(
        requests[0]
            .messages
            .iter()
            .all(|message| message.tool_calls.is_empty()),
        "prefetched evidence must not be sent as assistant tool_calls"
    );
    let tool_message = requests[0]
        .messages
        .iter()
        .find(|message| {
            message.role == LlmRole::System && message.content.contains("prefetched_tool_context")
        })
        .expect("model request should include prefetched tool result as system context");
    assert!(
        tool_message.content.contains("梅录"),
        "prefetched tool result should include identity facts, got: {}",
        tool_message.content
    );
    assert!(
        tool_message.content.contains("420"),
        "prefetched tool result should include age/world-days fact, got: {}",
        tool_message.content
    );
}

#[tokio::test]
async fn agent_runtime_uses_answer_text_from_json_output() {
    let provider = ScriptedProvider::new(vec![json_final_response()]);
    let registry = ToolRegistry::new();

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::parse_str("11111111-1111-1111-1111-111111111111")
                .expect("pet id"),
        },
        None,
    );

    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session.prompt("毛球今天怎么样").await.expect("prompt");
    let final_text = events.iter().find_map(|event| match event {
        AgentEvent::TurnFinished { final_text, .. } => Some(final_text.as_str()),
        _ => None,
    });

    assert_eq!(
        final_text,
        Some("毛球当前状态正常，可以继续观察精神和食欲。")
    );
}

#[tokio::test]
async fn agent_runtime_reports_confirmation_requests() {
    #[derive(Clone)]
    struct ConfirmTool;

    #[async_trait]
    impl AiToolDefinition for ConfirmTool {
        fn name(&self) -> &'static str {
            "create_pet_reminder"
        }

        fn description(&self) -> &'static str {
            "创建宠物提醒"
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
                scope: "pet.reminder.write".to_owned(),
                read_only: false,
                concurrency_safe: false,
                risk_level: AiToolRiskLevel::High,
                requires_confirmation: true,
                domain_tags: vec!["reminder".to_owned()],
                toolset: Toolset::Confirmation,
                progress_text: ToolProgressText::default(),
                result_fact_schema: None,
            }
        }

        async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
            AiToolResult::requires_confirmation(AiToolConfirmationRequirement {
                confirmation_task_id: "confirmation-1".to_owned(),
                tool_name: "create_pet_reminder".to_owned(),
                question_text: "是否确认创建提醒？".to_owned(),
                args: json!({ "pet_id": "11111111-1111-1111-1111-111111111111" }),
            })
        }
    }

    let provider = ScriptedProvider::new(vec![LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: String::new(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![LlmToolCall {
            id: "call_1".to_owned(),
            name: "create_pet_reminder".to_owned(),
            arguments: json!({
                "pet_id": "11111111-1111-1111-1111-111111111111"
            })
            .to_string(),
        }],
        usage: LlmUsage::default(),
        finish_reason: LlmFinishReason::ToolCalls,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }]);
    let mut registry = ToolRegistry::new();
    registry.register(ConfirmTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::parse_str("11111111-1111-1111-1111-111111111111")
                .expect("pet id"),
        },
        None,
    );

    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session.prompt("给毛球建个提醒").await.expect("prompt");
    let names: Vec<&'static str> = events.iter().map(AgentEvent::event_name).collect();

    assert_eq!(
        names,
        vec![
            "turn_started",
            "model_call_started",
            "model_call_finished",
            "tool_started",
            "tool_finished",
            "needs_confirmation",
        ]
    );
}

// ===== ToolFactProjector 接入验证 =====

/// 工具成功结果应通过 `ToolFactProjector` 投影，输出 `reference_ids` 并隐藏内部字段
#[tokio::test]
async fn tool_success_projects_reference_ids_and_hides_internal_fields() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response(
            "load_pet_identity_context",
            json!({ "pet_id": AUTHORIZED_PET_ID }),
        ),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id"),
        },
        None,
    );

    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session.prompt("毛球吃什么").await.expect("prompt");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 2, "should have initial + followup requests");

    let tool_message = find_tool_message(&requests);
    let content = &tool_message.content;

    // 应包含 reference_ids（来自 ToolFactProjector）
    assert!(
        content.contains("reference_ids"),
        "tool result should contain reference_ids, got: {content}"
    );

    // 不应暴露内部 key
    assert!(
        !content.contains("current_staple"),
        "tool result should not expose internal key, got: {content}"
    );

    // 不应暴露 citation_id 字段名
    assert!(
        !content.contains("citation_id"),
        "tool result should not expose citation_id field, got: {content}"
    );
}

/// 工具拒绝结果应通过 `ToolFactProjector::project_denied` 投影为通用安全文案
#[tokio::test]
async fn tool_denied_projects_safe_message_not_raw_reason() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response(
            "load_pet_identity_context",
            json!({ "pet_id": "22222222-2222-2222-2222-222222222222" }),
        ),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id"),
        },
        None,
    );

    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session.prompt("毛球吃什么").await.expect("prompt");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 2);

    let tool_message = find_tool_message(&requests);
    let content = &tool_message.content;

    // 应包含通用安全文案
    assert!(
        content.contains("工具无法执行"),
        "denied tool result should contain safe message, got: {content}"
    );

    // 不应暴露原始拒绝原因
    assert!(
        !content.contains("pet not authorized"),
        "denied tool result should not expose raw reason, got: {content}"
    );
}

/// 工具失败结果应通过 `ToolFactProjector::project_failed` 投影为通用安全文案
#[tokio::test]
async fn tool_failed_projects_safe_message_not_raw_reason() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response("load_pet_identity_context", json!({})),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id"),
        },
        None,
    );

    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session.prompt("毛球吃什么").await.expect("prompt");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 2);

    let tool_message = find_tool_message(&requests);
    let content = &tool_message.content;

    // 应包含通用安全文案
    assert!(
        content.contains("工具执行失败"),
        "failed tool result should contain safe message, got: {content}"
    );

    // 不应暴露原始失败原因
    assert!(
        !content.contains("missing pet_id"),
        "failed tool result should not expose raw reason, got: {content}"
    );
}

#[tokio::test]
async fn build_messages_includes_recent_conversation_history() {
    let provider = ScriptedProvider::new(vec![final_response()]);
    let registry = ToolRegistry::new();

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id"),
        },
        None,
    );

    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let workbench = workbench_with_recent_history();

    session
        .prompt_with_workbench("那要不要停罐头？", workbench)
        .await
        .expect("prompt with history");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 1);

    let messages = &requests[0].messages;

    // 历史用户消息必须出现在请求中
    let history_user = messages
        .iter()
        .find(|m| m.role == LlmRole::User && m.content == "豆包今天拉肚子怎么办");
    assert!(
        history_user.is_some(),
        "request must include previous user message from history"
    );

    // 历史助手消息必须出现在请求中
    let history_assistant = messages
        .iter()
        .find(|m| m.role == LlmRole::Assistant && m.content.contains("先观察精神和食欲"));
    assert!(
        history_assistant.is_some(),
        "request must include previous assistant message from history"
    );

    // 当前用户消息必须出现在请求中
    let current_msg = messages
        .iter()
        .find(|m| m.role == LlmRole::User && m.content == "那要不要停罐头？");
    assert!(
        current_msg.is_some(),
        "request must include current user message"
    );

    // 历史消息必须出现在当前用户消息之前
    let history_index = messages
        .iter()
        .position(|m| m.role == LlmRole::User && m.content == "豆包今天拉肚子怎么办");
    let current_index = messages
        .iter()
        .position(|m| m.role == LlmRole::User && m.content == "那要不要停罐头？");
    assert!(
        history_index.expect("history index") < current_index.expect("current index"),
        "history must appear before current user message"
    );
}

// ---------------------------------------------------------------------------
// guardrail 集成测试
// ---------------------------------------------------------------------------

/// `AlwaysFailTool` 总是返回结构化失败的工具
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
        AiToolResult::failed_with_failure(ToolFailure::new(
            "tool.internal_error",
            false,
            "工具执行失败",
            "upstream provider timeout",
        ))
    }
}

/// `multi_tool_call_response` 构造包含多个工具调用的脚本响应
fn multi_tool_call_response(tool_name: &str, count: usize) -> LlmChatResponse {
    let tool_calls = (0..count)
        .map(|i| LlmToolCall {
            id: format!("call_{i}"),
            name: tool_name.to_owned(),
            arguments: "{}".to_owned(),
        })
        .collect();
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: String::new(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls,
        usage: LlmUsage::default(),
        finish_reason: LlmFinishReason::ToolCalls,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

/// guardrail 在同工具连续失败 3 次时应 `HardStop` 终止 turn
#[tokio::test]
async fn guardrail_hard_stops_repeated_tool_failures() {
    let provider = ScriptedProvider::new(vec![multi_tool_call_response(
        "load_pet_identity_context",
        3,
    )]);
    let mut registry = ToolRegistry::new();
    registry.register(AlwaysFailTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id"),
        },
        None,
    );

    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session.prompt("毛球吃什么").await.expect("prompt");

    let has_turn_failed = events
        .iter()
        .any(|event| matches!(event, AgentEvent::TurnFailed { .. }));
    assert!(
        has_turn_failed,
        "guardrail hard stop should produce TurnFailed event"
    );
}

/// 结构化失败信息应回灌到模型消息，包含 `error_code` 和 `recoverable`
#[tokio::test]
async fn structured_failure_propagates_to_model_message() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response("load_pet_identity_context", json!({})),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(AlwaysFailTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id"),
        },
        None,
    );

    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session.prompt("毛球吃什么").await.expect("prompt");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 2);

    let tool_message = find_tool_message(&requests);
    let content = &tool_message.content;

    assert!(
        content.contains("error_code"),
        "model message should contain error_code, got: {content}"
    );
    assert!(
        content.contains("recoverable"),
        "model message should contain recoverable, got: {content}"
    );
    assert!(
        content.contains("tool.internal_error"),
        "model message should contain structured error_code value, got: {content}"
    );
}

/// `EmptyFactsTool` 成功返回但 `facts` 为空，用于验证 `produced_facts` 检测
struct EmptyFactsTool;

#[async_trait]
impl AiToolDefinition for EmptyFactsTool {
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
        AiToolResult::allowed_with_facts(Vec::new(), Vec::new())
    }
}

/// 空事实成功工具连续调用 3 次后，guardrail 应检测到无进展并触发 `SoftReminder`；
/// `SoftReminder` 注入的 `_guardrail_reminder` 字段不破坏原始 output JSON 结构。
#[tokio::test]
async fn empty_facts_tool_triggers_soft_reminder_with_valid_json() {
    let provider = ScriptedProvider::new(vec![
        multi_tool_call_response("load_pet_identity_context", 3),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EmptyFactsTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id"),
        },
        None,
    );

    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session.prompt("毛球吃什么").await.expect("prompt");

    let requests = provider.take_requests();
    assert!(
        requests.len() >= 2,
        "expected at least 2 requests, got {}",
        requests.len()
    );

    // 收集 followup 请求中所有 tool role 消息
    let tool_messages: Vec<&LlmMessage> = requests
        .iter()
        .flat_map(|req| req.messages.iter())
        .filter(|m| m.role == LlmRole::Tool)
        .collect();
    assert!(
        !tool_messages.is_empty(),
        "followup request should contain tool messages"
    );

    // 每个 tool message 都必须是合法 JSON
    for msg in &tool_messages {
        serde_json::from_str::<serde_json::Value>(&msg.content).unwrap_or_else(|e| {
            panic!("tool message must be valid JSON: {e}, got: {}", msg.content)
        });
    }

    // 同参重复 ≥2 次后第 3 个工具调用应触发 SoftReminder，其 tool message 包含 _guardrail_reminder
    let has_reminder = tool_messages
        .iter()
        .any(|msg| msg.content.contains("_guardrail_reminder"));
    assert!(
        has_reminder,
        "at least one tool message should contain _guardrail_reminder after repeated empty-facts calls"
    );
}

/// `workbench_with_recent_history` 构造带同会话历史的 workbench
fn workbench_with_recent_history() -> AgentSessionWorkbench {
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
        recent_conversation_pack: Some(RecentConversationPack {
            entries: vec![
                RecentConversationEntry {
                    role: AiMessageRole::User,
                    content: "豆包今天拉肚子怎么办".to_owned(),
                    tool_call_id: None,
                    tool_calls: Vec::new(),
                },
                RecentConversationEntry {
                    role: AiMessageRole::Assistant,
                    content: "先观察精神和食欲，如果持续超过24小时需要就医".to_owned(),
                    tool_call_id: None,
                    tool_calls: Vec::new(),
                },
            ],
        }),
    }
}
