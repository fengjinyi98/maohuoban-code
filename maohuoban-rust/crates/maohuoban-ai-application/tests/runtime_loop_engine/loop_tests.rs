//! `loop_tests` 核心 Runtime Loop 测试
//! 核心职责：
//! - 验证 public domain 不暴露私域工具
//! - 验证 private context 预取事实工具再调模型
//! - 验证 JSON output `answer_text` 提取
//! - 验证 confirmation 请求链路
//! - 验证历史消息注入

use std::sync::Arc;

use async_trait::async_trait;
use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel, ToolRegistry,
};
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AiConversationSurface, AiError, AiResult, AiToolConfirmationRequirement,
    LlmChatRequest, LlmChatResponse, LlmFinishReason, LlmMessage, LlmRole, LlmStreamEvent,
    LlmToolCall, LlmUsage, ProviderError, ProviderErrorCategory, ToolFactField, ToolFactSchema,
    ToolProgressText, Toolset,
};
use serde_json::json;
use uuid::Uuid;

use super::echo_tool::EchoIdentityTool;
use super::helpers::{AUTHORIZED_PET_ID, test_tool_context, tool_call_response};
use super::provider::ScriptedProvider;
use super::workbenches::{
    final_response, json_final_response, private_pet_context_workbench,
    public_pet_domain_workbench, workbench_with_recent_history,
};

#[tokio::test]
async fn public_pet_domain_without_private_tools() {
    let provider = ScriptedProvider::new(vec![final_response()]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        test_tool_context(Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("pet id")),
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
        "public pet domain without selected pet must not expose private tools"
    );
    assert!(
        requests[0].response_format.is_none(),
        "direct answer request should avoid DeepSeek JSON Output empty content risk"
    );
}

#[tokio::test]
async fn private_identity_question_uses_model_planned_fact_tool_before_answer() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response(
            "load_pet_identity_context",
            &serde_json::json!({ "pet_id": AUTHORIZED_PET_ID }),
        ),
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
        .prompt_with_workbench("梅录多大了？", private_pet_context_workbench())
        .await
        .expect("prompt with private context");

    let names: Vec<&'static str> = events.iter().map(AgentEvent::event_name).collect();
    assert_eq!(
        names,
        vec![
            "turn_started",
            "model_call_started",
            "model_call_finished",
            "tool_started",
            "tool_finished",
            "message_delta",
            "model_call_started",
            "model_call_finished",
            "turn_finished",
        ],
        "private fact question should execute the model-planned evidence tool before final answer"
    );

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 2);
    assert!(
        requests[0]
            .messages
            .iter()
            .all(|message| message.role != LlmRole::Tool),
        "initial model planning request must not contain tool-role history"
    );
    let tool_message = requests[1]
        .messages
        .iter()
        .find(|message| message.role == LlmRole::Tool)
        .expect("followup model request should include model-planned tool result");
    assert!(tool_message.content.contains("梅录"));
    assert!(tool_message.content.contains("420"));
}

#[tokio::test]
async fn followup_model_can_chain_second_tool_call_before_final_answer() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response(
            "load_pet_identity_context",
            &serde_json::json!({ "pet_id": AUTHORIZED_PET_ID }),
        ),
        tool_call_response(
            "load_pet_current_diet_context",
            &serde_json::json!({ "pet_id": AUTHORIZED_PET_ID }),
        ),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(EchoIdentityTool);
    registry.register(EchoDietTool);

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
        .prompt_with_workbench(
            "梅录现在吃的粮和年龄一起告诉我",
            private_pet_context_workbench(),
        )
        .await
        .expect("prompt with chained fact tools");

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
            "tool_started",
            "tool_finished",
            "message_delta",
            "model_call_started",
            "model_call_finished",
            "turn_finished",
        ],
        "runtime should allow followup model to issue another tool call before final answer"
    );

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 3);
    let second_followup_tool_call = requests[1]
        .messages
        .iter()
        .find(|message| message.role == LlmRole::Tool)
        .expect("second request should include first tool result");
    assert!(second_followup_tool_call.content.contains("梅录"));
    let final_followup_tool_call = requests[2]
        .messages
        .iter()
        .find(|message| message.role == LlmRole::Tool)
        .expect("final request should include second tool result");
    assert!(final_followup_tool_call.content.contains("渴望六种鱼"));
    let termination_reason = events.iter().find_map(|event| match event {
        AgentEvent::TurnFinished {
            termination_reason, ..
        } => *termination_reason,
        _ => None,
    });
    assert_eq!(
        termination_reason,
        Some(maohuoban_ai_domain::ai::AgentTurnTerminationReason::ModelStop)
    );
}

#[tokio::test]
async fn runtime_stops_tool_chain_at_configured_round_limit() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response("loop_echo_tool", &serde_json::json!({ "value": "r1" })),
        tool_call_response("loop_echo_tool", &serde_json::json!({ "value": "r2" })),
        tool_call_response("loop_echo_tool", &serde_json::json!({ "value": "r3" })),
        final_response(),
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(LoopEchoTool);

    let mut engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        test_tool_context(Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id")),
        None,
    );
    engine.set_max_tool_rounds(2);

    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session
        .prompt_with_workbench("连续取证直到超出上限", private_pet_context_workbench())
        .await
        .expect("prompt with tool chain limit");

    let requests = provider.take_requests();
    assert_eq!(
        requests.len(),
        3,
        "runtime should stop after initial + 2 followup model rounds"
    );
    assert!(
        events
            .iter()
            .any(|event| matches!(event, AgentEvent::TurnFinished { .. })),
        "runtime should terminate the turn when max tool rounds is reached"
    );
    let termination_reason = events.iter().find_map(|event| match event {
        AgentEvent::TurnFinished {
            termination_reason, ..
        } => *termination_reason,
        _ => None,
    });
    assert_eq!(
        termination_reason,
        Some(maohuoban_ai_domain::ai::AgentTurnTerminationReason::MaxToolRounds)
    );
}

#[tokio::test]
async fn runtime_completes_answer_after_high_token_tool_planning() {
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
                id: "call_budget".to_owned(),
                name: "loop_echo_tool".to_owned(),
                arguments: serde_json::json!({ "value": "r1" }).to_string(),
            }],
            usage: LlmUsage {
                input_tokens: 3000,
                output_tokens: 302,
                total_tokens: 3302,
            },
            finish_reason: LlmFinishReason::ToolCalls,
            provider: "scripted".to_owned(),
            model: "primary".to_owned(),
        },
        LlmChatResponse {
            message: LlmMessage {
                role: LlmRole::Assistant,
                content: "梅录今年的生日已经过啦。".to_owned(),
                reasoning_content: None,
                tool_call_id: None,
                tool_calls: Vec::new(),
            },
            tool_calls: Vec::new(),
            usage: LlmUsage {
                input_tokens: 3000,
                output_tokens: 814,
                total_tokens: 3814,
            },
            finish_reason: LlmFinishReason::Stop,
            provider: "scripted".to_owned(),
            model: "primary".to_owned(),
        },
    ]);
    let mut registry = ToolRegistry::new();
    registry.register(LoopEchoTool);

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider),
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
        .prompt_with_workbench("高 token 观测测试", private_pet_context_workbench())
        .await
        .expect("prompt with high token usage");

    let final_text = events.iter().find_map(|event| match event {
        AgentEvent::TurnFinished {
            final_text,
            termination_reason,
            ..
        } if *termination_reason
            == Some(maohuoban_ai_domain::ai::AgentTurnTerminationReason::ModelStop) =>
        {
            Some(final_text.as_str())
        }
        _ => None,
    });
    assert_eq!(
        final_text,
        Some("梅录今年的生日已经过啦。"),
        "runtime should deliver the model answer even when observed token usage is high"
    );
}

#[tokio::test]
async fn ambiguous_pet_context_text_is_sent_to_model_for_planning() {
    let provider = ScriptedProvider::new(vec![final_response()]);
    let registry = ToolRegistry::new();

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
        .prompt_with_workbench("它今天不舒服", private_pet_context_workbench())
        .await
        .expect("ambiguous private context text");

    let names: Vec<&'static str> = events.iter().map(AgentEvent::event_name).collect();
    assert_eq!(
        names,
        vec![
            "turn_started",
            "message_delta",
            "model_call_started",
            "model_call_finished",
            "turn_finished"
        ]
    );
    assert!(
        provider.take_requests().len() == 1,
        "runtime should let model decide whether to answer, ask, or call tools"
    );
}

#[tokio::test]
async fn provider_timeout_retries_same_model_step_before_failing_turn() {
    let provider = RetryOnceStreamProvider::new();
    let registry = ToolRegistry::new();

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
        .expect("provider timeout should retry and then succeed");

    assert!(
        events
            .iter()
            .any(|event| matches!(event, AgentEvent::TurnFinished { .. })),
        "retry should allow turn to finish"
    );
    assert_eq!(
        provider.take_requests().len(),
        2,
        "timeout should retry the same model step once"
    );
}

#[tokio::test]
async fn agent_runtime_uses_answer_text_from_json_output() {
    let provider = ScriptedProvider::new(vec![json_final_response()]);
    let registry = ToolRegistry::new();

    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider),
        Arc::new(registry),
        test_tool_context(Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("pet id")),
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

#[derive(Clone)]
struct RetryOnceStreamProvider {
    requests: Arc<std::sync::Mutex<Vec<LlmChatRequest>>>,
    attempts: Arc<std::sync::Mutex<u32>>,
}

#[derive(Clone)]
struct EchoDietTool;

#[async_trait]
impl AiToolDefinition for EchoDietTool {
    fn name(&self) -> &'static str {
        "load_pet_current_diet_context"
    }

    fn description(&self) -> &'static str {
        "返回当前饮食信息"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "pet_id": { "type": "string" }
            },
            "required": ["pet_id"]
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "pet.diet.read".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["diet".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: Some(ToolFactSchema {
                fact_keys: vec!["diet.current_food".to_owned()],
                description: "宠物当前饮食事实".to_owned(),
                natural_language_summary: "可回答当前吃什么粮".to_owned(),
                fields: vec![ToolFactField {
                    key: "diet.current_food".to_owned(),
                    label: "当前主粮".to_owned(),
                    meaning: "宠物当前正在吃的主粮".to_owned(),
                    example_queries: vec!["现在吃什么".to_owned()],
                }],
                default_strength: None,
            }),
        }
    }

    async fn execute(
        &self,
        _context: &AiToolContext,
        _arguments: &serde_json::Value,
    ) -> AiToolResult {
        AiToolResult::allowed_with_facts(
            vec![maohuoban_ai_domain::ai::AiFactEntry {
                key: "diet.current_food".to_owned(),
                value: "渴望六种鱼".to_owned(),
                strength: maohuoban_ai_domain::ai::AiFactStrength::Strong,
                citation_id: None,
            }],
            Vec::new(),
        )
    }
}

#[derive(Clone)]
struct LoopEchoTool;

#[async_trait]
impl AiToolDefinition for LoopEchoTool {
    fn name(&self) -> &'static str {
        "loop_echo_tool"
    }

    fn description(&self) -> &'static str {
        "循环工具测试"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "value": { "type": "string" }
            }
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "test.loop".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["test".to_owned()],
            toolset: Toolset::PrivatePetContext,
            progress_text: ToolProgressText::default(),
            result_fact_schema: None,
        }
    }

    async fn execute(
        &self,
        _context: &AiToolContext,
        arguments: &serde_json::Value,
    ) -> AiToolResult {
        AiToolResult::allowed(vec![arguments.to_string()])
    }
}

impl RetryOnceStreamProvider {
    fn new() -> Self {
        Self {
            requests: Arc::new(std::sync::Mutex::new(Vec::new())),
            attempts: Arc::new(std::sync::Mutex::new(0)),
        }
    }

    fn take_requests(&self) -> Vec<LlmChatRequest> {
        self.requests.lock().expect("requests").clone()
    }
}

impl LlmProvider for RetryOnceStreamProvider {
    fn complete<'a>(
        &'a self,
        _request: &'a LlmChatRequest,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = AiResult<LlmChatResponse>> + Send + 'a>>
    {
        Box::pin(async {
            Err(AiError::Provider(ProviderError::new(
                ProviderErrorCategory::Timeout,
                "complete should not be used",
            )))
        })
    }

    fn stream<'a>(
        &'a self,
        request: &'a LlmChatRequest,
    ) -> futures_util::stream::BoxStream<'a, AiResult<LlmStreamEvent>> {
        self.requests
            .lock()
            .expect("requests")
            .push(request.clone());
        let mut attempts = self.attempts.lock().expect("attempts");
        *attempts += 1;
        let events = if *attempts == 1 {
            vec![Err(AiError::Provider(ProviderError::new(
                ProviderErrorCategory::Timeout,
                "provider timeout",
            )))]
        } else {
            vec![
                Ok(LlmStreamEvent::Delta {
                    content: "先观察精神、食欲和便便频次。".to_owned(),
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
            arguments: json!({ "pet_id": "11111111-1111-1111-1111-111111111111" }).to_string(),
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
        test_tool_context(Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("pet id")),
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

#[tokio::test]
async fn unconfirmed_write_tool_stops_at_confirmation_without_final_answer() {
    let provider = ScriptedProvider::new(vec![
        tool_call_response(
            "write_pet_observation",
            &serde_json::json!({
                "pet_id": AUTHORIZED_PET_ID,
                "note": "体重 5kg"
            }),
        ),
        final_response(),
    ]);
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
        .prompt_with_workbench(
            "帮我直接把体重改成 5kg 不用问我",
            private_pet_context_workbench(),
        )
        .await
        .expect("prompt unconfirmed write");

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
        ],
        "unconfirmed write must stop at confirmation boundary: {events:?}"
    );
    assert_eq!(
        provider.take_requests().len(),
        1,
        "runtime must not ask the model for a final answer after a confirmation request"
    );
    assert!(
        events
            .iter()
            .all(|event| !matches!(event, AgentEvent::TurnFinished { .. })),
        "confirmation boundary must not be projected as a completed turn: {events:?}"
    );
}

#[tokio::test]
async fn build_messages_includes_recent_conversation_history() {
    let provider = ScriptedProvider::new(vec![final_response()]);
    let registry = ToolRegistry::new();

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

    let workbench = workbench_with_recent_history();

    session
        .prompt_with_workbench("那要不要停罐头？", workbench)
        .await
        .expect("prompt with history");

    let requests = provider.take_requests();
    assert_eq!(requests.len(), 1);

    let messages = &requests[0].messages;

    let history_user = messages
        .iter()
        .find(|m| m.role == LlmRole::User && m.content == "豆包今天拉肚子怎么办");
    assert!(
        history_user.is_some(),
        "request must include previous user message"
    );

    let history_assistant = messages
        .iter()
        .find(|m| m.role == LlmRole::Assistant && m.content.contains("先观察精神和食欲"));
    assert!(
        history_assistant.is_some(),
        "request must include previous assistant message"
    );

    let current_msg = messages
        .iter()
        .find(|m| m.role == LlmRole::User && m.content == "那要不要停罐头？");
    assert!(
        current_msg.is_some(),
        "request must include current user message"
    );

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
        AiToolResult::allowed(vec!["should not execute before confirmation".to_owned()])
    }
}
