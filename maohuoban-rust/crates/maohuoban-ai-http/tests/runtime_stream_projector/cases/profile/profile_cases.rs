use maohuoban_ai_domain::ai::{
    AgentEvent, AgentToolStatus, AgentTurnId, AgentTurnStatus, AiContentBlock,
    AiConversationSurface, AiFactPackage, AiPetProfileSpecies, AiStreamEvent,
};
use uuid::Uuid;

use crate::runtime_stream_projector::AgentEventSseProjector;
use crate::support::{diet_fact_package, identity_fact_package, pet_display_snapshot};
use crate::visible_output_plan::{VisibleOutputPlan, plan_visible_output};

#[test]
fn projector_emits_pet_profile_content_blocks_from_identity_fact_package() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let package = identity_fact_package("梅录");
    let mut projector = AgentEventSseProjector::new(
        message_id,
        Some(package),
        "梅录",
        true,
        VisibleOutputPlan::pet_profile_card(),
    );

    let events = projector.project(AgentEvent::TurnFinished {
        turn_id,
        message_id,
        final_text: "梅录的基本信息如下：".to_owned(),
        status: AgentTurnStatus::Completed,
        termination_reason: None,
    });

    let content_blocks = events
        .iter()
        .find_map(|event| match event {
            AiStreamEvent::AnswerCompleted { content_blocks, .. } => Some(content_blocks),
            _ => None,
        })
        .expect("answer_completed should include content blocks");

    assert!(
        matches!(
            content_blocks.first(),
            Some(AiContentBlock::SectionHeading { text, .. }) if text == "这是梅录的宠物信息"
        ),
        "first block should be semantic section heading, got {content_blocks:?}"
    );
    assert!(
        matches!(
            content_blocks.get(1),
            Some(AiContentBlock::PetProfileCard {
                pet,
                computed,
                narrative,
                ..
            }) if pet.name == "梅录"
                && pet.species == AiPetProfileSpecies::Cat
                && pet.species_text == "猫"
                && pet.sex_text == "母猫"
                && pet.breed == "英短"
                && pet.birth_date.as_deref() == Some("2024-06-17")
                && pet.arrival_date.as_deref() == Some("2025-06-17")
                && computed.age_text.as_deref() == Some("当前年龄约 2岁15天")
                && computed.companionship_text.as_deref() == Some("到家陪伴 380 天")
                && narrative.birth.is_none()
                && narrative.arrival.is_none()
        ),
        "second block should be pet profile card, got {content_blocks:?}"
    );

    let payload = serde_json::to_value(
        events
            .iter()
            .find(|event| matches!(event, AiStreamEvent::AnswerCompleted { .. }))
            .expect("answer_completed event"),
    )
    .expect("serialize answer_completed");
    assert_eq!(
        payload["content_blocks"][0]["type"],
        serde_json::json!("section_heading")
    );
    assert_eq!(
        payload["content_blocks"][1]["type"],
        serde_json::json!("pet_profile_card")
    );
    assert_eq!(
        payload["content_blocks"][1]["narrative"],
        serde_json::json!({})
    );
    let serialized = serde_json::to_string(&payload).expect("serialize payload");
    assert!(!serialized.contains("来到这个世界"));
    assert!(!serialized.contains("这段陪伴"));
}

#[test]
fn projector_emits_paragraph_content_block_with_inline_strong_spans() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let mut projector = AgentEventSseProjector::new(
        message_id,
        Some(AiFactPackage::empty()),
        "梅录",
        false,
        VisibleOutputPlan::empty(),
    );

    let events = projector.project(AgentEvent::TurnFinished {
        turn_id,
        message_id,
        final_text: "梅录今年的生日是 **6月17日**，已经过啦～".to_owned(),
        status: AgentTurnStatus::Completed,
        termination_reason: None,
    });

    let content_blocks = events
        .iter()
        .find_map(|event| match event {
            AiStreamEvent::AnswerCompleted { content_blocks, .. } => Some(content_blocks),
            _ => None,
        })
        .expect("answer_completed should include paragraph block");
    let completed_text = events
        .iter()
        .find_map(|event| match event {
            AiStreamEvent::AnswerCompleted { final_text, .. } => Some(final_text),
            _ => None,
        })
        .expect("answer_completed should include final_text");

    assert_eq!(completed_text, "梅录今年的生日是 6月17日，已经过啦～");
    assert!(
        matches!(
            content_blocks.as_slice(),
            [AiContentBlock::Paragraph { text, spans, .. }]
                if text == "梅录今年的生日是 6月17日，已经过啦～"
                    && spans.len() == 3
                    && spans[1].text == "6月17日"
                    && spans[1].style == maohuoban_ai_domain::ai::AiInlineTextStyle::Strong
        ),
        "final text should be normalized to a rich paragraph block: {content_blocks:?}"
    );
}

#[test]
fn projector_emits_pet_profile_heading_and_skeleton_when_identity_tool_starts() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let mut projector = AgentEventSseProjector::new(
        message_id,
        None,
        "梅录",
        true,
        VisibleOutputPlan::pet_profile_card(),
    );

    let events = projector.project(AgentEvent::ToolStarted {
        turn_id,
        tool_call_id: "identity_call_1".to_owned(),
        tool_name: "load_pet_identity_context".to_owned(),
    });

    assert_eq!(
        events.len(),
        1,
        "identity tool start should emit content blocks without duplicate activity: {events:?}"
    );
    assert!(
        matches!(
            &events[0],
            AiStreamEvent::ContentBlockDelta { content_blocks, .. }
                if matches!(
                    content_blocks.as_slice(),
                    [
                        AiContentBlock::SectionHeading { text, .. },
                        AiContentBlock::PetProfileCardSkeleton { title, .. },
                    ] if text == "这是梅录的宠物信息"
                        && title == "正在整理梅录的宠物档案"
                )
        ),
        "first event should render heading and pet profile skeleton blocks: {events:?}"
    );
    assert!(
        events
            .iter()
            .all(|event| !matches!(event, AiStreamEvent::ExecutionTraceStarted { .. })),
        "visible content block plan should suppress duplicate started activity: {events:?}"
    );
}

#[test]
fn projector_emits_pet_profile_skeleton_when_identity_tool_starts_without_visible_plan() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let mut projector =
        AgentEventSseProjector::new(message_id, None, "梅录", true, VisibleOutputPlan::empty());

    let events = projector.project(AgentEvent::ToolStarted {
        turn_id,
        tool_call_id: "identity_call_1".to_owned(),
        tool_name: "load_pet_identity_context".to_owned(),
    });

    assert!(
        matches!(
            events.as_slice(),
            [AiStreamEvent::ContentBlockDelta { content_blocks }]
                if matches!(
                    content_blocks.as_slice(),
                    [
                        AiContentBlock::SectionHeading { text, .. },
                        AiContentBlock::PetProfileCardSkeleton { title, .. },
                    ] if text == "这是梅录的宠物信息"
                        && title == "正在整理梅录的宠物档案"
                )
        ),
        "identity tool start should create pet profile skeleton without preloaded plan: {events:?}"
    );
}

#[test]
fn visible_output_plan_does_not_preload_pet_profile_card_on_home_private() {
    let target_pet = pet_display_snapshot("豆包");

    let plan = plan_visible_output(AiConversationSurface::HomePrivate, Some(&target_pet));

    assert_eq!(plan, VisibleOutputPlan::empty());
}

#[test]
fn visible_output_plan_uses_pet_profile_surface_for_pet_profile_card() {
    let target_pet = pet_display_snapshot("豆包");

    let plan = plan_visible_output(AiConversationSurface::PetProfile, Some(&target_pet));

    assert_eq!(plan, VisibleOutputPlan::pet_profile_card());
}

#[test]
fn visible_output_plan_does_not_create_pet_profile_card_without_target_pet() {
    let plan = plan_visible_output(AiConversationSurface::HomePrivate, None);

    assert_eq!(plan, VisibleOutputPlan::empty());
}

#[test]
fn projector_does_not_emit_pet_profile_card_for_home_private_diet_answer() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let target_pet = pet_display_snapshot("梅录");
    let mut projector = AgentEventSseProjector::new(
        message_id,
        Some(diet_fact_package("梅录")),
        "梅录",
        true,
        plan_visible_output(AiConversationSurface::HomePrivate, Some(&target_pet)),
    );

    let events = projector.project(AgentEvent::TurnFinished {
        turn_id,
        message_id,
        final_text: "梅录最近吃的是渴望六种鱼全期猫粮。".to_owned(),
        status: AgentTurnStatus::Completed,
        termination_reason: None,
    });

    let content_blocks = events
        .iter()
        .find_map(|event| match event {
            AiStreamEvent::AnswerCompleted { content_blocks, .. } => Some(content_blocks),
            _ => None,
        })
        .expect("home private diet answer should complete");

    assert!(
        matches!(
            content_blocks.as_slice(),
            [AiContentBlock::Paragraph { .. }]
        ),
        "diet answer should not render pet profile card: {content_blocks:?}"
    );
}

#[test]
fn projector_emits_final_pet_profile_blocks_after_identity_tool_without_visible_plan() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let mut projector =
        AgentEventSseProjector::new(message_id, None, "梅录", true, VisibleOutputPlan::empty());

    let mut events = Vec::new();
    events.extend(projector.project(AgentEvent::ToolStarted {
        turn_id,
        tool_call_id: "identity_call_1".to_owned(),
        tool_name: "load_pet_identity_context".to_owned(),
    }));
    events.extend(projector.project(AgentEvent::ToolFinished {
        turn_id,
        tool_call_id: "identity_call_1".to_owned(),
        status: AgentToolStatus::Succeeded,
        citation_count: 1,
        fact_package: Some(Box::new(identity_fact_package("梅录"))),
    }));
    events.extend(projector.project(AgentEvent::TurnFinished {
        turn_id,
        message_id,
        final_text: "梅录状态稳定。".to_owned(),
        status: AgentTurnStatus::Completed,
        termination_reason: None,
    }));

    let content_blocks = events
        .iter()
        .find_map(|event| match event {
            AiStreamEvent::AnswerCompleted { content_blocks, .. } => Some(content_blocks),
            _ => None,
        })
        .expect("identity tool turn should complete with profile UI blocks");

    assert!(
        content_blocks
            .iter()
            .any(|block| matches!(block, AiContentBlock::PetProfileCard { .. })),
        "final pet profile UI blocks should be triggered by identity tool success: {content_blocks:?}"
    );
}

#[test]
fn projector_rejects_identity_tool_success_without_profile_content_blocks() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let mut projector = AgentEventSseProjector::new(
        message_id,
        None,
        "梅录",
        true,
        VisibleOutputPlan::pet_profile_card(),
    );

    let mut events = Vec::new();
    events.extend(projector.project(AgentEvent::ToolStarted {
        turn_id,
        tool_call_id: "identity_call_1".to_owned(),
        tool_name: "load_pet_identity_context".to_owned(),
    }));
    events.extend(projector.project(AgentEvent::ToolFinished {
        turn_id,
        tool_call_id: "identity_call_1".to_owned(),
        status: AgentToolStatus::Succeeded,
        citation_count: 1,
        fact_package: None,
    }));
    events.extend(projector.project(AgentEvent::TurnFinished {
        turn_id,
        message_id,
        final_text: "这是梅录的宠物信息。".to_owned(),
        status: AgentTurnStatus::Completed,
        termination_reason: None,
    }));

    let terminal_event = events
        .last()
        .expect("identity profile turn should emit terminal event");
    assert!(
        matches!(
            terminal_event,
            AiStreamEvent::Error {
                code,
                retryable: false,
                safe_fallback_text: None,
                ..
            } if code == "ai.profile_content_blocks.missing"
        ),
        "identity profile turn must not complete with empty content blocks: {terminal_event:?}"
    );
}

#[test]
fn projector_emits_pet_profile_content_blocks_from_identity_tool_package() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let mut projector = AgentEventSseProjector::new(
        message_id,
        None,
        "梅录",
        true,
        VisibleOutputPlan::pet_profile_card(),
    );

    let mut events = Vec::new();
    events.extend(projector.project(AgentEvent::ToolStarted {
        turn_id,
        tool_call_id: "identity_call_1".to_owned(),
        tool_name: "load_pet_identity_context".to_owned(),
    }));
    events.extend(projector.project(AgentEvent::ToolFinished {
        turn_id,
        tool_call_id: "identity_call_1".to_owned(),
        status: AgentToolStatus::Succeeded,
        citation_count: 1,
        fact_package: Some(Box::new(identity_fact_package("梅录"))),
    }));
    events.extend(projector.project(AgentEvent::TurnFinished {
        turn_id,
        message_id,
        final_text: "这是梅录的宠物信息。".to_owned(),
        status: AgentTurnStatus::Completed,
        termination_reason: None,
    }));

    let content_blocks = events
        .iter()
        .find_map(|event| match event {
            AiStreamEvent::AnswerCompleted { content_blocks, .. } => Some(content_blocks),
            _ => None,
        })
        .expect("identity tool package should produce answer_completed");

    assert!(
        matches!(
            content_blocks.as_slice(),
            [
                AiContentBlock::SectionHeading { text, .. },
                AiContentBlock::PetProfileCard { pet, .. },
                AiContentBlock::Paragraph { text: paragraph_text, .. },
            ] if text == "这是梅录的宠物信息"
                && pet.name == "梅录"
                && paragraph_text == "这是梅录的宠物信息。"
        ),
        "identity tool package should project typed pet profile blocks: {content_blocks:?}"
    );
}

#[test]
fn projector_emits_pet_profile_content_blocks_on_home_private_identity_tool() {
    let message_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let target_pet = pet_display_snapshot("梅录");
    let mut projector = AgentEventSseProjector::new(
        message_id,
        None,
        "梅录",
        true,
        plan_visible_output(AiConversationSurface::HomePrivate, Some(&target_pet)),
    );

    let mut events = Vec::new();
    events.extend(projector.project(AgentEvent::ToolStarted {
        turn_id,
        tool_call_id: "identity_call_home_private".to_owned(),
        tool_name: "load_pet_identity_context".to_owned(),
    }));
    events.extend(projector.project(AgentEvent::ToolFinished {
        turn_id,
        tool_call_id: "identity_call_home_private".to_owned(),
        status: AgentToolStatus::Succeeded,
        citation_count: 1,
        fact_package: Some(Box::new(identity_fact_package("梅录"))),
    }));
    events.extend(projector.project(AgentEvent::TurnFinished {
        turn_id,
        message_id,
        final_text: "好的，这是梅录的档案信息。".to_owned(),
        status: AgentTurnStatus::Completed,
        termination_reason: None,
    }));

    assert!(
        matches!(
            events.first(),
            Some(AiStreamEvent::ContentBlockDelta { content_blocks })
                if matches!(
                    content_blocks.as_slice(),
                    [
                        AiContentBlock::SectionHeading { text, .. },
                        AiContentBlock::PetProfileCardSkeleton { .. }
                    ] if text == "这是梅录的宠物信息"
                )
        ),
        "home_private identity tool should emit heading plus skeleton first: {events:?}"
    );

    let completed_blocks = events
        .iter()
        .find_map(|event| match event {
            AiStreamEvent::AnswerCompleted { content_blocks, .. } => Some(content_blocks),
            _ => None,
        })
        .expect("home_private identity tool should produce answer_completed");
    assert!(
        matches!(
            completed_blocks.as_slice(),
            [
                AiContentBlock::SectionHeading { text, .. },
                AiContentBlock::PetProfileCard { pet, .. },
                AiContentBlock::Paragraph { text: paragraph_text, .. },
            ] if text == "这是梅录的宠物信息"
                && pet.name == "梅录"
                && paragraph_text == "好的，这是梅录的档案信息。"
        ),
        "home_private answer should include typed pet profile blocks: {completed_blocks:?}"
    );
}
