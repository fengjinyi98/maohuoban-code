// runtime_regression_cases Agent Runtime 回归 case 套件
// 核心职责：
// - 覆盖 8 类核心 runtime 场景
// - 固定自研 AgentRuntimeLoopEngine 的用户可见事件顺序和内部请求边界
use std::sync::Arc;

use maohuoban_ai_application::ai::tools::ToolRegistry;
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentToolStatus, AiFactEntry, AiFactPackage, AiFactStrength, AiMessageRole,
    LlmChatResponse, LlmFinishReason, LlmMessage, LlmRole, LlmToolCall, LlmUsage,
    RecentConversationEntry,
};
use serde_json::json;

mod support;

use support::{
    AlwaysFailTool, EchoIdentityTool, ScriptedProvider, authorized_context, build_engine,
    build_engine_with_fact_package, final_text, final_text_response, has_tool_finished,
    has_tool_started, json_response, private_pet_workbench, run_prompt, think_response,
    tool_call_response, unauthorized_context, workbench_with_history,
};

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

#[tokio::test]
async fn case_emotional_followup_is_planned_by_model_with_verified_facts() {
    let provider = Arc::new(ScriptedProvider::new(vec![final_text_response(
        "是啊，今年生日已经过了 15 天。下次生日是 2027-06-17，可以提前留个提醒。",
    )]));
    let mut fact_package = AiFactPackage::empty();
    fact_package.computed.push(AiFactEntry {
        key: "pet_identity.birthday_passed_this_year".to_owned(),
        value: "今年生日 6月17日 已经过了 15 天".to_owned(),
        strength: AiFactStrength::Strong,
        citation_id: None,
    });
    fact_package.computed.push(AiFactEntry {
        key: "pet_identity.next_birthday".to_owned(),
        value: "下次生日是 2027-06-17".to_owned(),
        strength: AiFactStrength::Strong,
        citation_id: None,
    });
    let engine = build_engine_with_fact_package(
        provider.clone(),
        ToolRegistry::new(),
        authorized_context(),
        fact_package,
    );

    let history = vec![
        RecentConversationEntry {
            role: AiMessageRole::User,
            content: "我的宠物今年的生日过了吗".to_owned(),
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        RecentConversationEntry {
            role: AiMessageRole::Assistant,
            content: "梅录今年的生日是 6月17日，已经过了，到今天是 15 天前。".to_owned(),
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
    ];

    let events = run_prompt(
        engine,
        "遗憾我都忘了",
        Some(workbench_with_history(history)),
    )
    .await;

    assert_has_turn_finished(&events);
    let text = final_text(&events);
    assert!(
        text.contains("已经过了 15 天") && text.contains("2027-06-17"),
        "emotional follow-up should carry verified birthday facts forward, got: {text}"
    );
    assert!(
        !text.contains("没查到")
            && !text.contains("无法确认")
            && !text.contains("不准确")
            && !text.contains("忽略"),
        "emotional follow-up must not retract verified facts, got: {text}"
    );
    assert!(
        provider.take_requests().len() == 1,
        "emotional follow-up should still go through model planning"
    );
    let requests = provider.take_requests();
    let projected_prompt = requests[0]
        .messages
        .iter()
        .map(|message| message.content.as_str())
        .collect::<Vec<_>>()
        .join("\n");
    assert!(projected_prompt.contains("遗憾我都忘了"));
    assert!(projected_prompt.contains("梅录今年的生日是 6月17日"));
    assert!(projected_prompt.contains("今年生日 6月17日 已经过了 15 天"));
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
    assert_eq!(requests.len(), 1);
    assert_has_turn_failed(&real_events);
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
