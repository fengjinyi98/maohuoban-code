//! `output_guard_tests` Runtime 输出校验测试
//! 核心职责：
//! - 验证最终回答校验失败时回灌模型修正
//! - 防止 verifier fallback 文案作为用户可见终态泄漏

use std::sync::Arc;

use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::tools::ToolRegistry;
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AiConversationSurface, AiFactEntry, AiFactPackage, AiFactStrength,
    AiPetCandidate, LlmChatResponse, LlmFinishReason, LlmMessage, LlmRole, LlmUsage,
};
use uuid::Uuid;

use super::helpers::{AUTHORIZED_PET_ID, test_tool_context};
use super::provider::ScriptedProvider;
use super::workbenches::private_pet_context_workbench;

#[tokio::test]
async fn invalid_final_answer_is_repaired_inside_runtime_before_turn_finished() {
    let provider = ScriptedProvider::new(vec![
        response_text("目前档案里没有生日记录，所以还不知道梅录多大。"),
        response_text("梅录的生日是 2024-06-17，当前年龄约 2岁15天。"),
    ]);
    let registry = ToolRegistry::new();
    let fact_package = pet_identity_fact_package();
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        test_tool_context(Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id")),
        Some(fact_package),
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
        .expect("runtime should repair invalid answer");

    let requests = provider.take_requests();
    assert_eq!(
        requests.len(),
        2,
        "output guard should send a repair request after invalid final answer"
    );
    let repair_request = requests.get(1).expect("repair request");
    let repair_prompt = repair_request
        .messages
        .iter()
        .map(|message| message.content.as_str())
        .collect::<Vec<_>>()
        .join("\n");
    assert!(
        repair_prompt.contains("档案中已有宠物生日或年龄事实")
            && repair_prompt.contains("2024-06-17"),
        "repair request should include verifier feedback and confirmed facts: {repair_prompt}"
    );

    let turn_finished = events
        .iter()
        .find_map(|event| match event {
            AgentEvent::TurnFinished { final_text, .. } => Some(final_text),
            _ => None,
        })
        .expect("runtime should finish with repaired answer");
    assert_eq!(
        turn_finished,
        "梅录的生日是 2024-06-17，当前年龄约 2岁15天。"
    );

    let visible_text = events
        .iter()
        .filter_map(|event| match event {
            AgentEvent::MessageDelta { text, .. } => Some(text.as_str()),
            AgentEvent::TurnFinished { final_text, .. } => Some(final_text.as_str()),
            _ => None,
        })
        .collect::<Vec<_>>()
        .join("");
    assert!(!visible_text.contains("请基于已确认事实回答"));
    assert!(!visible_text.contains("不知道梅录多大"));
}

#[tokio::test]
async fn invalid_repair_result_fails_turn_without_user_visible_fallback() {
    let provider = ScriptedProvider::new(vec![
        response_text("目前档案里没有生日记录，所以还不知道梅录多大。"),
        response_text("档案里没有记录梅录生日，所以无法计算年龄。"),
    ]);
    let registry = ToolRegistry::new();
    let fact_package = pet_identity_fact_package();
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        test_tool_context(Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id")),
        Some(fact_package),
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
        .expect("runtime should stop failed output after repair budget");

    let requests = provider.take_requests();
    assert_eq!(
        requests.len(),
        2,
        "output guard should stop after one repair attempt"
    );
    assert!(
        events.iter().any(|event| matches!(
            event,
            AgentEvent::TurnFailed {
                error_code,
                retryable: false,
                ..
            } if error_code == "ai.output_guard.unrepaired"
        )),
        "unrepaired output should produce output guard failure: {events:?}"
    );
    assert!(
        events
            .iter()
            .all(|event| !matches!(event, AgentEvent::TurnFinished { .. })),
        "unrepaired output must not produce a completed turn: {events:?}"
    );

    let visible_text = events
        .iter()
        .filter_map(|event| match event {
            AgentEvent::MessageDelta { text, .. } => Some(text.as_str()),
            AgentEvent::TurnFinished { final_text, .. } => Some(final_text.as_str()),
            _ => None,
        })
        .collect::<Vec<_>>()
        .join("");
    assert!(!visible_text.contains("请基于已确认事实回答"));
    assert!(!visible_text.contains("无法计算年龄"));
}

fn response_text(text: &str) -> LlmChatResponse {
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: text.to_owned(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: Vec::new(),
        usage: LlmUsage {
            input_tokens: 12,
            output_tokens: 8,
            total_tokens: 20,
        },
        finish_reason: LlmFinishReason::Stop,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

fn pet_identity_fact_package() -> AiFactPackage {
    let pet_id = Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id");
    let candidate = AiPetCandidate {
        pet_id,
        name: "梅录".to_owned(),
        avatar_url: None,
        species: "cat".to_owned(),
        profile_number: "P001".to_owned(),
    };
    let mut package = AiFactPackage::empty();
    package.target_pet = Some((&candidate).into());
    package.facts = vec![
        strong_fact("pet_identity.name", "梅录"),
        strong_fact("pet_identity.birthday", "2024-06-17"),
        strong_fact("pet_identity.species", "猫"),
    ];
    package.computed = vec![strong_fact(
        "pet_identity.age_display",
        "当前年龄约 2岁15天",
    )];
    package.fact_strength = AiFactStrength::Strong;
    package
}

fn strong_fact(key: &str, value: &str) -> AiFactEntry {
    AiFactEntry {
        key: key.to_owned(),
        value: value.to_owned(),
        strength: AiFactStrength::Strong,
        citation_id: None,
    }
}
