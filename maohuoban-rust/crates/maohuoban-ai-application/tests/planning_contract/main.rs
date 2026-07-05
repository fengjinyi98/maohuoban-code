// planning_contract WT08 轻规划协议合同测试
// 核心职责：
// - 固定 TaskType、StepKind、ExecutionPolicy 和 ReplanPolicy 行为
// - 验证 Runtime 不把用户文案分词成领域任务规划

use async_trait::async_trait;
use maohuoban_ai_application::ai::planning::{
    ExecutionPolicy, PlanningDiagnosticsSnapshot, ReplanAction, ReplanCause, ReplanPolicy,
    StepKind, StepPlanner, TaskClassificationInput, TaskClassifier, TaskType,
};
use maohuoban_ai_application::ai::runtime::EvidencePlanner;
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel, ToolRegistry,
};
use maohuoban_ai_domain::ai::{
    AgentTurnId, AiFactStrength, AiGateDecision, AiIntent, ToolFactField, ToolFactSchema,
    ToolProgressText, Toolset,
};
use serde_json::json;
use uuid::Uuid;

#[test]
fn task_type_only_uses_gate_and_runtime_context_boundaries() {
    let reject = TaskClassifier::classify(&TaskClassificationInput {
        gate_decision: gate(AiIntent::InvalidInput, false),
        user_input: "",
        selected_pet_present: false,
        evidence_tool_count: 0,
        write_tool_visible: false,
        confirmation_task_present: false,
    });
    assert_eq!(reject, TaskType::RejectTask);

    let private_context = TaskClassifier::classify(&TaskClassificationInput {
        gate_decision: gate(AiIntent::Allowed, false),
        user_input: "它今天不舒服",
        selected_pet_present: true,
        evidence_tool_count: 0,
        write_tool_visible: false,
        confirmation_task_present: false,
    });
    assert_eq!(private_context, TaskType::ContextAnswer);

    let write_like_text = TaskClassifier::classify(&TaskClassificationInput {
        gate_decision: gate(AiIntent::Allowed, false),
        user_input: "帮我把今天拉稀记下来",
        selected_pet_present: true,
        evidence_tool_count: 0,
        write_tool_visible: true,
        confirmation_task_present: false,
    });
    assert_eq!(write_like_text, TaskType::ContextAnswer);

    let evidence_like_runtime_signal = TaskClassifier::classify(&TaskClassificationInput {
        gate_decision: gate(AiIntent::Allowed, false),
        user_input: "豆包最近是不是换粮了",
        selected_pet_present: true,
        evidence_tool_count: 1,
        write_tool_visible: false,
        confirmation_task_present: false,
    });
    assert_eq!(evidence_like_runtime_signal, TaskType::ContextAnswer);

    let context = TaskClassifier::classify(&TaskClassificationInput {
        gate_decision: gate(AiIntent::Allowed, false),
        user_input: "豆包最近精神怎么样",
        selected_pet_present: true,
        evidence_tool_count: 0,
        write_tool_visible: false,
        confirmation_task_present: false,
    });
    assert_eq!(context, TaskType::ContextAnswer);

    let direct = TaskClassifier::classify(&TaskClassificationInput {
        gate_decision: gate(AiIntent::Allowed, false),
        user_input: "毛伙伴怎么修改昵称",
        selected_pet_present: false,
        evidence_tool_count: 0,
        write_tool_visible: false,
        confirmation_task_present: false,
    });
    assert_eq!(direct, TaskType::DirectAnswer);

    let commit = TaskClassifier::classify(&TaskClassificationInput {
        gate_decision: gate(AiIntent::Allowed, false),
        user_input: "确认写入这条观察记录",
        selected_pet_present: true,
        evidence_tool_count: 0,
        write_tool_visible: true,
        confirmation_task_present: true,
    });
    assert_eq!(commit, TaskType::ConfirmationCommit);
}

#[test]
fn step_planner_generates_terminal_boundaries_for_each_task_type() {
    let direct = StepPlanner::plan(TaskType::DirectAnswer);
    assert_eq!(
        direct.step_kinds(),
        &[StepKind::ModelReason, StepKind::FinalizeAnswer]
    );
    assert_eq!(direct.terminal_step(), StepKind::FinalizeAnswer);

    let context = StepPlanner::plan(TaskType::ContextAnswer);
    assert_eq!(
        context.step_kinds(),
        &[
            StepKind::LoadContext,
            StepKind::ModelReason,
            StepKind::FinalizeAnswer
        ]
    );
    assert_eq!(context.terminal_step(), StepKind::FinalizeAnswer);

    let commit = StepPlanner::plan(TaskType::ConfirmationCommit);
    assert_eq!(
        commit.step_kinds(),
        &[
            StepKind::LoadContext,
            StepKind::ToolRead,
            StepKind::ModelReason,
            StepKind::FinalizeAnswer
        ]
    );
    assert_eq!(commit.terminal_step(), StepKind::FinalizeAnswer);
}

#[test]
fn abnormal_episode_followup_planning_is_explicit_runtime_task_type() {
    let plan = StepPlanner::plan(TaskType::AbnormalEpisodeFollowupPlanning);

    assert_eq!(
        TaskType::AbnormalEpisodeFollowupPlanning.as_str(),
        "abnormal_episode_followup_planning"
    );
    assert_eq!(
        plan.step_kinds(),
        &[
            StepKind::LoadContext,
            StepKind::ToolRead,
            StepKind::ModelReason,
            StepKind::FinalizeAnswer
        ]
    );
    assert_eq!(plan.terminal_step(), StepKind::FinalizeAnswer);
    assert!(plan.policy().allows_direct_model_answer());
    assert_eq!(
        plan.policy().policy_decision(),
        "allow_abnormal_episode_followup_planning"
    );
}

#[test]
fn abnormal_episode_followup_planning_comes_from_runtime_context_not_user_text() {
    let from_context = TaskClassifier::classify_runtime_with_context(true, false, true);
    assert_eq!(
        from_context,
        TaskType::AbnormalEpisodeFollowupPlanning,
        "abnormal followup planning must be driven by restored runtime context"
    );

    let from_text_only = TaskClassifier::classify(&TaskClassificationInput {
        gate_decision: gate(AiIntent::Allowed, false),
        user_input: "我想更新异常追踪，便便还有点稀",
        selected_pet_present: true,
        evidence_tool_count: 0,
        write_tool_visible: false,
        confirmation_task_present: false,
    });
    assert_eq!(
        from_text_only,
        TaskType::ContextAnswer,
        "user text must not be tokenized into abnormal planning task type"
    );

    let confirmation = TaskClassifier::classify_runtime_with_context(true, true, true);
    assert_eq!(
        confirmation,
        TaskType::ConfirmationCommit,
        "confirmation commit keeps write boundary priority"
    );
}

#[test]
fn execution_policy_allows_model_answers_and_blocks_reject_tasks() {
    let direct = ExecutionPolicy::for_task(TaskType::DirectAnswer);
    assert!(direct.allows_direct_model_answer());
    assert_eq!(direct.policy_decision(), "allow_direct_answer");

    let context = ExecutionPolicy::for_task(TaskType::ContextAnswer);
    assert!(context.allows_direct_model_answer());
    assert_eq!(context.policy_decision(), "allow_context_answer");

    let reject = ExecutionPolicy::for_task(TaskType::RejectTask);
    assert!(reject.rejects_task());
    assert_eq!(reject.policy_decision(), "reject");
}

#[test]
fn replan_policy_distinguishes_retry_replan_and_terminal_causes() {
    let policy = ReplanPolicy;

    assert_eq!(
        policy.decide(ReplanCause::ProviderTimeout).action,
        ReplanAction::RetrySameStep
    );
    assert_eq!(
        policy.decide(ReplanCause::StreamInterrupted).action,
        ReplanAction::RecoverOrRetryStep
    );
    assert_eq!(
        policy.decide(ReplanCause::ToolInvalidArguments).action,
        ReplanAction::CorrectArgumentsAndRetry
    );
    assert_eq!(
        policy.decide(ReplanCause::ToolUnauthorized).action,
        ReplanAction::Terminate
    );
    assert_eq!(
        policy.decide(ReplanCause::EvidenceInsufficient).action,
        ReplanAction::ReplanToTask
    );
    assert_eq!(
        policy.decide(ReplanCause::ContextLimitExceeded).action,
        ReplanAction::CompressContextAndRetry
    );
    assert_eq!(
        policy.decide(ReplanCause::GuardrailHardStop).action,
        ReplanAction::Terminate
    );
}

#[test]
fn evidence_planner_does_not_prefetch_from_schema_keyword_match() {
    let pet_id = Uuid::new_v4();
    let mut registry = ToolRegistry::new();
    registry.register(IdentityFactTool);

    let calls = EvidencePlanner::plan_for_input("豆包多大了", pet_id, &registry);

    assert!(
        calls.is_empty(),
        "EvidencePlanner must not use schema/example text as a keyword router"
    );
}

#[test]
fn planning_diagnostics_snapshot_contains_required_correlation_and_policy_fields() {
    let session_id = Uuid::new_v4();
    let turn_id = AgentTurnId::new();
    let message_id = Uuid::new_v4();
    let plan = StepPlanner::plan(TaskType::ContextAnswer);

    let metadata = PlanningDiagnosticsSnapshot::new(session_id, turn_id, message_id, &plan)
        .with_current_step(StepKind::ModelReason)
        .with_step_transition(StepKind::LoadContext, StepKind::ModelReason)
        .to_metadata();

    assert_eq!(metadata["session_id"], json!(session_id));
    assert_eq!(metadata["turn_id"], json!(turn_id.as_uuid()));
    assert_eq!(metadata["message_id"], json!(message_id));
    assert_eq!(metadata["task_type"], json!("context_answer"));
    assert_eq!(
        metadata["step_list"],
        json!(["load_context", "model_reason", "finalize_answer"])
    );
    assert_eq!(metadata["current_step"], json!("model_reason"));
    assert_eq!(
        metadata["step_transition"],
        json!("load_context->model_reason")
    );
    assert_eq!(metadata["terminal_step"], json!("finalize_answer"));
    assert_eq!(metadata["policy_decision"], json!("allow_context_answer"));
}

fn gate(intent: AiIntent, context_loaded: bool) -> AiGateDecision {
    AiGateDecision {
        intent,
        context_loaded,
        risk_signal: None,
        reason: "test gate".to_owned(),
    }
}

#[derive(Clone)]
struct IdentityFactTool;

#[async_trait]
impl AiToolDefinition for IdentityFactTool {
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
                fact_keys: vec!["pet_identity.age".to_owned()],
                description: "宠物身份事实".to_owned(),
                natural_language_summary: "可回答宠物多大、生日和到家多久".to_owned(),
                fields: vec![ToolFactField {
                    key: "age".to_owned(),
                    label: "年龄".to_owned(),
                    meaning: "宠物当前年龄".to_owned(),
                    example_queries: vec!["多大了".to_owned()],
                }],
                default_strength: Some(AiFactStrength::Strong),
            }),
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        AiToolResult::allowed(Vec::new())
    }
}
