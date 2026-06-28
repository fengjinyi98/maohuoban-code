// rig_loop_engine Rig adapter POC 契约测试
// 核心职责：
// - 验证 RigLoopEngineAdapter 实现既有 LoopEngine trait
// - 固定 fake Rig step 到 Runtime LoopStep 的映射顺序

use maohuoban_ai_application::ai::runtime::{
    FakeRigState, FakeRigStep, LoopEngine, RigLoopEngineAdapter,
};
use maohuoban_ai_domain::ai::{
    AgentId, AgentSessionState, AgentTurnStatus, AiConversationSurface, LlmFinishReason,
    LlmToolCall, LlmUsage, ModelLabel,
};
use uuid::Uuid;

fn usage() -> LlmUsage {
    LlmUsage {
        input_tokens: 4,
        output_tokens: 2,
        total_tokens: 6,
    }
}

#[tokio::test]
async fn rig_loop_engine_contract() {
    let mut engine = RigLoopEngineAdapter::new(FakeRigState::new(vec![
        FakeRigStep::CallModel {
            model_label: ModelLabel::Primary,
            tool_count: 1,
            finish_reason: LlmFinishReason::ToolCalls,
            usage: usage(),
        },
        FakeRigStep::CallTools {
            tool_calls: vec![LlmToolCall {
                id: "call_1".to_owned(),
                name: "load_pet_identity_context".to_owned(),
                arguments: "{}".to_owned(),
            }],
        },
        FakeRigStep::Done {
            message_id: Uuid::parse_str("018f4f21-9f44-7a62-a14d-4e7465726e64")
                .expect("message id"),
            final_text: "已读取毛球档案".to_owned(),
            status: AgentTurnStatus::Completed,
        },
    ]));
    let mut state = AgentSessionState::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
    );

    let mut step_names = Vec::new();
    while let Some(step) = engine.next(&mut state).await.expect("rig step") {
        step_names.push(step.step_name());
    }

    assert_eq!(step_names, vec!["call_model", "call_tools", "done"]);
}
