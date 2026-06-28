// runtime_loop_engine Agent Runtime 闭环测试
// 核心职责：
// - 验证 AgentSession / LoopEngine / Tool Gateway 串联后可完成模型 -> 工具 -> 再生成
// - 验证工具 schema 会注入模型请求

use std::collections::VecDeque;
use std::sync::{Arc, Mutex};

use async_trait::async_trait;
use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel, ToolRegistry,
};
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AiConversationSurface, AiToolConfirmationRequirement, LlmChatRequest,
    LlmChatResponse, LlmFinishReason, LlmMessage, LlmRole, LlmToolCall, LlmUsage,
};
use serde_json::json;
use uuid::Uuid;

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
        _request: &'a LlmChatRequest,
    ) -> futures_util::stream::BoxStream<
        'a,
        maohuoban_ai_domain::ai::AiResult<maohuoban_ai_domain::ai::LlmStreamEvent>,
    > {
        futures_util::stream::empty().boxed()
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
        }
    }

    async fn execute(&self, ctx: &AiToolContext, args: &serde_json::Value) -> AiToolResult {
        let pet_id = args
            .get("pet_id")
            .and_then(|value| value.as_str())
            .and_then(|value| Uuid::parse_str(value).ok());

        match pet_id {
            Some(id) if id == ctx.authorized_pet_id => AiToolResult::allowed(vec![]),
            Some(_) => AiToolResult::denied("pet not authorized"),
            None => AiToolResult::failed("missing pet_id"),
        }
    }
}

fn tool_response() -> LlmChatResponse {
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: String::new(),
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![LlmToolCall {
            id: "call_1".to_owned(),
            name: "load_pet_identity_context".to_owned(),
            arguments: json!({
                "pet_id": "11111111-1111-1111-1111-111111111111"
            })
            .to_string(),
        }],
        usage: LlmUsage {
            input_tokens: 8,
            output_tokens: 2,
            total_tokens: 10,
        },
        finish_reason: LlmFinishReason::ToolCalls,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

fn final_response() -> LlmChatResponse {
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: "毛球当前状态正常".to_owned(),
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

#[tokio::test]
async fn agent_runtime_executes_tool_loop() {
    let provider = ScriptedProvider::new(vec![tool_response(), final_response()]);
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

    let events = session.prompt("查看毛球档案").await.expect("prompt");
    let names: Vec<&'static str> = events.iter().map(AgentEvent::event_name).collect();

    assert_eq!(
        names,
        vec![
            "turn_started",
            "model_call_started",
            "model_call_finished",
            "tool_started",
            "tool_finished",
            "model_call_started",
            "model_call_finished",
            "turn_finished",
        ]
    );

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 2);
    assert_eq!(requests[0].tools.len(), 1);
    assert_eq!(requests[0].tools[0].name, "load_pet_identity_context");
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
            "needs_confirmation",
        ]
    );
}
