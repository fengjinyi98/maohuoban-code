// runtime_contract Runtime 应用层契约测试
// 核心职责：
// - 验证 FakeLoopEngine 按脚本推进 LoopStep
// - 验证 AgentSession.prompt 输出稳定内部事件顺序

use maohuoban_ai_application::ai::runtime::{
    AgentSession, AgentSessionRuntime, FakeLoopEngine, LoopEngine,
};
use maohuoban_ai_domain::ai::{
    AgentCapability, AgentDefinition, AgentEvent, AgentId, AgentSessionState,
    AgentSessionWorkbench, AgentTurnStatus, AiConversationSurface, AiResult, CapabilityCatalog,
    CapabilityDomain, ContextPack, LlmFinishReason, LlmToolCall, LlmUsage, LoopStep,
    LoopToolResult, MemoryPack, ModelLabel, ProviderErrorCategory,
};
use uuid::Uuid;

fn usage() -> LlmUsage {
    LlmUsage {
        input_tokens: 10,
        output_tokens: 5,
        total_tokens: 15,
    }
}

fn workbench_with_capabilities(capability_count: usize) -> AgentSessionWorkbench {
    AgentSessionWorkbench {
        agent_definition: AgentDefinition {
            agent_id: AgentId::main_pet_care_agent(),
            name: "毛球".to_owned(),
            purpose: "宠物垂直照护与用户宠物私域助手".to_owned(),
            default_model_label: ModelLabel::Primary,
            capability_domains: vec![CapabilityDomain::PublicPetDomain],
        },
        capability_catalog: CapabilityCatalog {
            capabilities: (0..capability_count)
                .map(|index| AgentCapability {
                    code: format!("capability_{index}"),
                    domain: CapabilityDomain::PublicPetDomain,
                    title: format!("能力 {index}"),
                    when_to_use: "用于测试能力目录透传".to_owned(),
                    requires_private_context: false,
                })
                .collect(),
        },
        context_pack: ContextPack {
            surface: AiConversationSurface::HomePrivate,
            locale: "zh-Hans".to_owned(),
            timezone: "Asia/Shanghai".to_owned(),
            temporal_context: None,
            selected_pet: None,
            authorized_pets: Vec::new(),
            session_summary: None,
            pending_confirmation_task: None,
        },
        memory_pack: MemoryPack {
            entries: Vec::new(),
        },
        recent_conversation_pack: None,
    }
}

#[tokio::test]
async fn fake_loop_engine_outputs_scripted_steps() {
    let mut engine = FakeLoopEngine::new(vec![
        LoopStep::model_finished(ModelLabel::Primary, 1, LlmFinishReason::ToolCalls, usage()),
        LoopStep::call_tools(vec![LlmToolCall {
            id: "call_1".to_owned(),
            name: "load_pet_identity_context".to_owned(),
            arguments: "{}".to_owned(),
        }]),
        LoopStep::done(
            Uuid::parse_str("018f4f21-9f44-7a62-a14d-4e7465726e64").unwrap(),
            "已读取毛球档案".to_owned(),
            AgentTurnStatus::Completed,
        ),
    ]);
    let mut state = AgentSessionRuntime::<FakeLoopEngine>::initial_state(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
    );

    let mut step_names = Vec::new();
    while let Some(step) = engine.next(&mut state).await.expect("fake step") {
        step_names.push(step.step_name());
    }

    assert_eq!(step_names, vec!["call_model", "call_tools", "done"]);
}

#[tokio::test]
async fn agent_session_emits_turn_events() {
    let chat_session_id = Uuid::new_v4();
    let message_id = Uuid::new_v4();
    let engine = FakeLoopEngine::new(vec![
        LoopStep::model_finished(ModelLabel::Primary, 0, LlmFinishReason::Stop, usage()),
        LoopStep::done(
            message_id,
            "毛球今天可以少量加餐".to_owned(),
            AgentTurnStatus::Completed,
        ),
    ]);
    let mut session = AgentSession::new(
        chat_session_id,
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session.prompt("毛球今天吃什么?").await.expect("prompt");
    let names: Vec<&'static str> = events.iter().map(AgentEvent::event_name).collect();

    assert_eq!(
        names,
        vec![
            "turn_started",
            "model_call_started",
            "model_call_finished",
            "turn_finished"
        ]
    );
}

#[tokio::test]
async fn agent_session_emits_tool_events() {
    let engine = FakeLoopEngine::new(vec![
        LoopStep::call_tools(vec![LlmToolCall {
            id: "call_1".to_owned(),
            name: "load_pet_identity_context".to_owned(),
            arguments: "{}".to_owned(),
        }]),
        LoopStep::call_tool_results(vec![LoopToolResult::succeeded(
            LlmToolCall {
                id: "call_1".to_owned(),
                name: "load_pet_identity_context".to_owned(),
                arguments: "{}".to_owned(),
            },
            "{}",
        )]),
        LoopStep::done(
            Uuid::new_v4(),
            "已读取毛球档案".to_owned(),
            AgentTurnStatus::Completed,
        ),
    ]);
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session.prompt("读取毛球档案").await.expect("prompt");
    let names: Vec<&'static str> = events.iter().map(AgentEvent::event_name).collect();

    assert_eq!(
        names,
        vec![
            "turn_started",
            "tool_started",
            "tool_finished",
            "turn_finished"
        ]
    );
}

#[tokio::test]
async fn agent_session_emits_provider_error_and_turn_failed() {
    let engine = FakeLoopEngine::new(vec![LoopStep::provider_error(
        ModelLabel::Primary,
        0,
        ProviderErrorCategory::NotConfigured,
        false,
        "ai.provider.not_configured".to_owned(),
    )]);
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    let events = session.prompt("毛球今天吃什么?").await.expect("prompt");
    let names: Vec<&'static str> = events.iter().map(AgentEvent::event_name).collect();

    assert_eq!(
        names,
        vec![
            "turn_started",
            "model_call_started",
            "provider_error",
            "turn_failed"
        ]
    );
}

#[tokio::test]
async fn agent_session_uses_workbench_context() {
    struct WorkbenchCountingEngine {
        emitted_model: bool,
    }

    #[async_trait::async_trait]
    impl LoopEngine for WorkbenchCountingEngine {
        async fn next(&mut self, state: &mut AgentSessionState) -> AiResult<Option<LoopStep>> {
            if self.emitted_model {
                return Ok(Some(LoopStep::done(
                    Uuid::new_v4(),
                    "已读取能力目录".to_owned(),
                    AgentTurnStatus::Completed,
                )));
            }

            self.emitted_model = true;
            let capability_count = state
                .workbench
                .as_ref()
                .expect("workbench should be attached to state")
                .capability_catalog
                .capabilities
                .len();

            Ok(Some(LoopStep::model_finished(
                ModelLabel::Primary,
                u32::try_from(capability_count).expect("capability count"),
                LlmFinishReason::Stop,
                usage(),
            )))
        }
    }

    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        WorkbenchCountingEngine {
            emitted_model: false,
        },
    );

    let events = session
        .prompt_with_workbench("猫拉肚子一般要观察什么？", workbench_with_capabilities(2))
        .await
        .expect("prompt with workbench");

    let tool_count = events.iter().find_map(|event| match event {
        AgentEvent::ModelCallStarted { tool_count, .. } => Some(tool_count.to_owned()),
        _ => None,
    });

    assert_eq!(tool_count, Some(2));
}
