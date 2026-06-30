// runtime_engine_selector Runtime 引擎选择测试
// 核心职责：
// - 验证运行时只接受 self_hosted 引擎配置
// - 固定 HTTP 外层无需感知 LoopEngine 装配细节

use std::sync::{Arc, Mutex};

use futures_util::StreamExt;
use maohuoban_ai_application::ai::ports::LlmProvider;
use maohuoban_ai_application::ai::runtime::{
    AgentRuntimeEngineFactory, AgentRuntimeEngineInput, AgentRuntimeEngineMode, AgentSession,
};
use maohuoban_ai_application::ai::tools::{AiToolContext, ToolRegistry};
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AiConversationSurface, AiResult, LlmChatRequest, LlmChatResponse,
    LlmFinishReason, LlmStreamEvent, LlmUsage,
};
use uuid::Uuid;

#[derive(Clone)]
struct RecordingProvider {
    requests: Arc<Mutex<Vec<LlmChatRequest>>>,
}

impl RecordingProvider {
    fn new() -> Self {
        Self {
            requests: Arc::new(Mutex::new(Vec::new())),
        }
    }

    fn request_count(&self) -> usize {
        self.requests.lock().expect("requests").len()
    }
}

impl LlmProvider for RecordingProvider {
    fn complete<'a>(
        &'a self,
        _request: &'a LlmChatRequest,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = AiResult<LlmChatResponse>> + Send + 'a>>
    {
        Box::pin(async {
            Err(maohuoban_ai_domain::ai::AiError::Infrastructure(
                "selector test uses stream".to_owned(),
            ))
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
        futures_util::stream::iter(vec![
            Ok(LlmStreamEvent::Delta {
                content: "自研引擎回答".to_owned(),
            }),
            Ok(LlmStreamEvent::Finish {
                finish_reason: LlmFinishReason::Stop,
                usage: LlmUsage::default(),
            }),
        ])
        .boxed()
    }
}

fn engine_input(provider: Arc<dyn LlmProvider>) -> AgentRuntimeEngineInput {
    AgentRuntimeEngineInput {
        provider,
        registry: Arc::new(ToolRegistry::new()),
        tool_context: AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::nil(),
        },
        fact_package: None,
    }
}

async fn run_selected_engine(
    mode: AgentRuntimeEngineMode,
    provider: RecordingProvider,
) -> Vec<AgentEvent> {
    let engine = AgentRuntimeEngineFactory::new(mode).build(engine_input(Arc::new(provider)));
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session.prompt("你好").await.expect("selected engine")
}

fn finished_text(events: &[AgentEvent]) -> Option<String> {
    events.iter().find_map(|event| match event {
        AgentEvent::TurnFinished { final_text, .. } => Some(final_text.clone()),
        _ => None,
    })
}

fn observed_engine_modes(events: &[AgentEvent]) -> Vec<&str> {
    events
        .iter()
        .filter_map(|event| match event {
            AgentEvent::TurnStarted { engine_mode, .. }
            | AgentEvent::ModelCallStarted { engine_mode, .. }
            | AgentEvent::ModelCallFinished { engine_mode, .. } => Some(engine_mode.as_str()),
            _ => None,
        })
        .collect()
}

#[test]
fn engine_mode_parses_runtime_config_values() {
    assert_eq!(AgentRuntimeEngineMode::SelfHosted.as_str(), "self_hosted");
    assert_eq!(
        AgentRuntimeEngineMode::from_config_value("self_hosted"),
        Ok(AgentRuntimeEngineMode::SelfHosted)
    );
    assert!(AgentRuntimeEngineMode::from_config_value("rig_poc").is_err());
    assert!(AgentRuntimeEngineMode::from_config_value("unknown").is_err());
}

#[tokio::test]
async fn self_hosted_engine_uses_runtime_provider() {
    let provider = RecordingProvider::new();
    let observed = provider.clone();

    let events = run_selected_engine(AgentRuntimeEngineMode::SelfHosted, provider).await;

    assert_eq!(finished_text(&events).as_deref(), Some("自研引擎回答"));
    assert_eq!(
        observed_engine_modes(&events),
        vec!["self_hosted", "self_hosted", "self_hosted"]
    );
    assert_eq!(observed.request_count(), 1);
}
