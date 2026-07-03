use std::sync::Arc;

use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, ToolGatewayExecutionContext, ToolRegistry,
};
use maohuoban_ai_domain::ai::{AgentId, AiConversationSurface};
use uuid::Uuid;

use super::support::{
    AppHelpTool, CapturingProvider, CommitObservationWriteTool, PetIdentityFactTool,
    ToolCallProvider, WriteObservationTool, private_pet_context_workbench,
    public_pet_domain_workbench, test_tool_context,
};

#[tokio::test]
async fn workbench_prompt_hides_domain_struct_field_names() {
    let provider = CapturingProvider::new();
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(ToolRegistry::new()),
        test_tool_context(Uuid::nil()),
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
        .expect("prompt public workbench");

    let requests = provider.take_requests();
    let workbench_prompt = requests[0]
        .messages
        .iter()
        .find(|message| message.content.contains("AgentSession Workbench"))
        .expect("workbench prompt should be present")
        .content
        .as_str();

    assert!(workbench_prompt.contains("公共养宠咨询"));
    assert!(workbench_prompt.contains("日期与时间计算"));
    assert!(workbench_prompt.contains("相差天数"));
    assert!(
        workbench_prompt.contains("当前本地日期: 2026-07-02")
            && workbench_prompt.contains("当前本地时间: 2026-07-02T04:30:29+08:00"),
        "workbench prompt should disclose trusted temporal context: {workbench_prompt}"
    );
    for forbidden in [
        "agent_definition",
        "context_pack",
        "capability_catalog",
        "default_model_label",
    ] {
        assert!(
            !workbench_prompt.contains(forbidden),
            "workbench prompt must not expose domain struct field {forbidden}: {workbench_prompt}"
        );
    }
}

#[tokio::test]
async fn write_tool_is_visible_without_keyword_workflow_skill() {
    let provider = ToolCallProvider::new();
    let mut registry = ToolRegistry::new();
    registry.register(WriteObservationTool);
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
        .prompt_with_workbench("帮我记录今天拉稀", private_pet_context_workbench())
        .await
        .expect("prompt write workbench");

    let requests = provider.take_requests();
    let workbench_prompt = requests[0]
        .messages
        .iter()
        .find(|message| message.content.contains("AgentSession Workbench"))
        .expect("workbench prompt should be present")
        .content
        .as_str();

    assert!(workbench_prompt.contains("prepare_pet_observation_write"));
    assert!(workbench_prompt.contains("需要写入或高风险动作时必须进入确认路径"));
    assert!(workbench_prompt.contains("工具只能由 Runtime Gateway 执行"));
    assert!(
        !workbench_prompt.contains("workflow.write_requires_confirmation"),
        "runtime must not inject write workflow skill from user text: {workbench_prompt}"
    );
}

#[tokio::test]
async fn confirmation_task_summary_is_projected_into_workbench_prompt() {
    let provider = CapturingProvider::new();
    let mut registry = ToolRegistry::new();
    registry.register(WriteObservationTool);
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        test_tool_context(Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("pet id")),
        None,
    );
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::ConfirmationTask,
        engine,
    );

    let mut workbench = private_pet_context_workbench();
    workbench.context_pack.pending_confirmation_task =
        Some(maohuoban_ai_domain::ai::ContextConfirmationTaskSummary {
            confirmation_task_id: Uuid::parse_str("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
                .expect("task id"),
            tool_name: "commit_pet_observation_write".to_owned(),
            question_text: "是否确认写入这条观察记录？".to_owned(),
        });

    session
        .prompt_with_workbench("确认写入这条观察记录", workbench)
        .await
        .expect("prompt confirmation workbench");

    let requests = provider.take_requests();
    let workbench_prompt = requests[0]
        .messages
        .iter()
        .find(|message| message.content.contains("AgentSession Workbench"))
        .expect("workbench prompt should be present")
        .content
        .as_str();

    assert!(workbench_prompt.contains("当前待确认任务"));
    assert!(workbench_prompt.contains("commit_pet_observation_write"));
    assert!(workbench_prompt.contains("是否确认写入这条观察记录？"));
}

#[tokio::test]
async fn confirmation_task_workbench_selects_commit_task_type_in_planning_diagnostics() {
    let provider = CapturingProvider::new();
    let mut registry = ToolRegistry::new();
    registry.register(CommitObservationWriteTool);
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        AiToolContext {
            actor_user_id: Uuid::new_v4(),
            authorized_pet_id: Uuid::new_v4(),
            gateway_context: ToolGatewayExecutionContext {
                session_id: None,
                turn_id: None,
                message_id: None,
                confirmation_task_id: Some(
                    Uuid::parse_str("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
                        .expect("task id")
                        .to_string(),
                ),
            },
            gateway_observer: None,
        },
        None,
    );
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::ConfirmationTask,
        engine,
    );

    let mut workbench = private_pet_context_workbench();
    workbench.context_pack.pending_confirmation_task =
        Some(maohuoban_ai_domain::ai::ContextConfirmationTaskSummary {
            confirmation_task_id: Uuid::parse_str("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
                .expect("task id"),
            tool_name: "commit_pet_observation_write".to_owned(),
            question_text: "是否确认写入这条观察记录？".to_owned(),
        });

    session
        .prompt_with_workbench("确认写入这条观察记录", workbench)
        .await
        .expect("prompt confirmation workbench");

    let requests = provider.take_requests();
    let workbench_prompt = requests[0]
        .messages
        .iter()
        .find(|message| message.content.contains("AgentSession Workbench"))
        .expect("workbench prompt should be present")
        .content
        .as_str();

    assert!(workbench_prompt.contains("当前待确认任务"));
    assert!(
        requests[0]
            .tools
            .iter()
            .any(|tool| tool.name == "commit_pet_observation_write")
    );
}

#[tokio::test]
async fn evidence_tool_is_visible_without_prefetch_workflow_skill() {
    let provider = CapturingProvider::new();
    let mut registry = ToolRegistry::new();
    registry.register(PetIdentityFactTool);
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
        .prompt_with_workbench("梅录多大了？", private_pet_context_workbench())
        .await
        .expect("prompt evidence workbench");

    let requests = provider.take_requests();
    let workbench_prompt = requests[0]
        .messages
        .iter()
        .find(|message| message.content.contains("AgentSession Workbench"))
        .expect("workbench prompt should be present")
        .content
        .as_str();

    assert!(workbench_prompt.contains("load_pet_identity_context"));
    assert!(workbench_prompt.contains("模型只申请工具或基于已投影信息回答"));
    assert!(
        !workbench_prompt.contains("workflow.evidence_read_before_answer"),
        "runtime must not inject evidence workflow skill from user text: {workbench_prompt}"
    );
    assert_eq!(
        requests[0].tools.len(),
        1,
        "initial model planning request should expose the evidence tool"
    );
}

#[tokio::test]
async fn workbench_prompt_discloses_empty_visible_tool_list() {
    let provider = CapturingProvider::new();
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(ToolRegistry::new()),
        test_tool_context(Uuid::nil()),
        None,
    );
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session
        .prompt_with_workbench("帮我把宠物名字改成梅鹿", public_pet_domain_workbench())
        .await
        .expect("prompt public workbench");

    let requests = provider.take_requests();
    let workbench_prompt = requests[0]
        .messages
        .iter()
        .find(|message| message.content.contains("AgentSession Workbench"))
        .expect("workbench prompt should be present")
        .content
        .as_str();

    assert!(
        workbench_prompt.contains("本轮可执行工具:\n- 无。"),
        "workbench prompt should disclose empty runtime tool list: {workbench_prompt}"
    );
    assert!(
        workbench_prompt.contains("用户询问工具或可执行能力时，只能基于“本轮可执行工具”回答"),
        "workbench prompt should bind tool disclosure to visible runtime tools: {workbench_prompt}"
    );
}

#[tokio::test]
async fn workbench_prompt_projects_skill_instructions_in_runtime_order() {
    let provider = CapturingProvider::new();
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(ToolRegistry::new()),
        test_tool_context(Uuid::nil()),
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
        .expect("prompt public workbench");

    let requests = provider.take_requests();
    let workbench_prompt = requests[0]
        .messages
        .iter()
        .find(|message| message.content.contains("AgentSession Workbench"))
        .expect("workbench prompt should be present")
        .content
        .as_str();
    let system_index = workbench_prompt
        .find("system.tool_gateway_boundary")
        .expect("system skill should be projected");
    let domain_index = workbench_prompt
        .find("domain.public_pet_care")
        .expect("domain skill should be projected");

    assert!(workbench_prompt.contains("Skill 指令:"));
    assert!(
        system_index < domain_index,
        "system skill must be projected before domain skill: {workbench_prompt}"
    );
    assert!(
        !workbench_prompt.contains("personalization."),
        "prompt projection must not invent personalization skill without user match: {workbench_prompt}"
    );
}

#[tokio::test]
async fn workbench_prompt_discloses_visible_runtime_tools() {
    let provider = CapturingProvider::new();
    let mut registry = ToolRegistry::new();
    registry.register(AppHelpTool);
    let engine = AgentRuntimeLoopEngine::new(
        Arc::new(provider.clone()),
        Arc::new(registry),
        test_tool_context(Uuid::nil()),
        None,
    );
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );

    session
        .prompt_with_workbench("你有哪些工具", public_pet_domain_workbench())
        .await
        .expect("prompt public workbench");

    let requests = provider.take_requests();
    let workbench_prompt = requests[0]
        .messages
        .iter()
        .find(|message| message.content.contains("AgentSession Workbench"))
        .expect("workbench prompt should be present")
        .content
        .as_str();

    assert!(
        workbench_prompt.contains("- explain_app_feature：解释毛伙伴 App 页面和流程"),
        "workbench prompt should list visible runtime tool schemas: {workbench_prompt}"
    );
    assert_eq!(requests[0].tools[0].name, "explain_app_feature");
}

#[tokio::test]
async fn workbench_prompt_discloses_tool_fact_schema_in_natural_language() {
    let provider = CapturingProvider::new();
    let mut registry = ToolRegistry::new();
    registry.register(PetIdentityFactTool);
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
        .prompt_with_workbench("工具说明", private_pet_context_workbench())
        .await
        .expect("prompt private workbench");

    let requests = provider.take_requests();
    let workbench_prompt = requests[0]
        .messages
        .iter()
        .find(|message| message.content.contains("AgentSession Workbench"))
        .expect("workbench prompt should be present")
        .content
        .as_str();

    assert!(
        workbench_prompt.contains("可返回事实: 宠物基础档案事实"),
        "workbench prompt should disclose fact schema description: {workbench_prompt}"
    );
    assert!(
        workbench_prompt.contains("年龄/出生至今天数"),
        "workbench prompt should disclose natural fact labels: {workbench_prompt}"
    );
    assert!(
        workbench_prompt.contains("多大了") && workbench_prompt.contains("陪伴我多久了"),
        "workbench prompt should disclose example queries from the tool protocol: {workbench_prompt}"
    );
    assert!(
        requests[0].tools[0].description.contains("多大了")
            && requests[0].tools[0].description.contains("陪伴多久"),
        "model-visible tool description should include natural fact schema: {:?}",
        requests[0].tools[0]
    );
}
