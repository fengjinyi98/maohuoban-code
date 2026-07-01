//! `loop_tests` 核心 Runtime Loop 测试
//! 核心职责：
//! - 验证 public domain 不暴露私域工具
//! - 验证 private context 预取事实工具再调模型
//! - 验证 JSON output `answer_text` 提取
//! - 验证 confirmation 请求链路
//! - 验证历史消息注入

use std::sync::Arc;

use async_trait::async_trait;
use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel, ToolRegistry,
};
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AiConversationSurface, AiToolConfirmationRequirement, LlmChatResponse,
    LlmFinishReason, LlmMessage, LlmRole, LlmToolCall, LlmUsage, ToolProgressText, Toolset,
};
use serde_json::json;
use uuid::Uuid;

use super::echo_tool::EchoIdentityTool;
use super::helpers::{AUTHORIZED_PET_ID, test_tool_context};
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
async fn private_identity_question_prefetches_fact_tool_before_model() {
    let provider = ScriptedProvider::new(vec![final_response()]);
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
    assert_eq!(requests.len(), 1);
    assert!(
        requests[0]
            .messages
            .iter()
            .all(|message| message.role != LlmRole::Tool),
        "prefetched evidence must not be sent as OpenAI tool-role history"
    );
    let tool_message = requests[0]
        .messages
        .iter()
        .find(|message| {
            message.role == LlmRole::System && message.content.contains("prefetched_tool_context")
        })
        .expect("model request should include prefetched tool result as system context");
    assert!(tool_message.content.contains("梅录"));
    assert!(tool_message.content.contains("420"));
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
