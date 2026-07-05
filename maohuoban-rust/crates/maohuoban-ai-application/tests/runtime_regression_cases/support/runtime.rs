use std::sync::Arc;

use maohuoban_ai_application::ai::ports::ObservationWriteContext;
use maohuoban_ai_application::ai::runtime::{AgentRuntimeLoopEngine, AgentSession, LoopEngine};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, ToolGatewayExecutionContext, ToolRegistry,
};
use maohuoban_ai_domain::ai::{
    AgentCapability, AgentDefinition, AgentEvent, AgentId, AgentSessionWorkbench, AgentToolStatus,
    AiConversationSurface, AiFactPackage, CapabilityCatalog, CapabilityDomain, ContextPack,
    ContextPetSummary, MemoryPack, ModelLabel, RecentConversationEntry, RecentConversationPack,
};
use uuid::Uuid;

use crate::support::ScriptedProvider;

pub const AUTHORIZED_PET_ID: &str = "11111111-1111-1111-1111-111111111111";

/// `public_pet_domain_workbench` 构造公共养宠领域 workbench
/// 核心职责：
/// - 固定公共领域能力目录
/// - 不提供私域宠物上下文
pub fn public_pet_domain_workbench() -> AgentSessionWorkbench {
    AgentSessionWorkbench {
        agent_definition: AgentDefinition {
            agent_id: AgentId::main_pet_care_agent(),
            name: "毛球".to_owned(),
            purpose: "宠物垂直照护与用户宠物私域助手".to_owned(),
            default_model_label: ModelLabel::Primary,
            capability_domains: vec![CapabilityDomain::PublicPetDomain],
        },
        capability_catalog: CapabilityCatalog {
            capabilities: vec![AgentCapability {
                code: "public_pet_care".to_owned(),
                domain: CapabilityDomain::PublicPetDomain,
                title: "公共养宠咨询".to_owned(),
                when_to_use: "用户咨询通用照护、饮食、行为或常见症状观察时使用".to_owned(),
                requires_private_context: false,
            }],
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

/// `private_pet_workbench` 构造带授权宠物的 workbench
/// 核心职责：
/// - 复用公共领域基础配置
/// - 注入选中宠物摘要
pub fn private_pet_workbench() -> AgentSessionWorkbench {
    let mut wb = public_pet_domain_workbench();
    wb.context_pack.selected_pet = Some(ContextPetSummary {
        pet_id: Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id"),
        name: "饭团".to_owned(),
        species: "cat".to_owned(),
    });
    wb
}

/// `workbench_with_history` 构造带最近对话历史的 workbench
/// 核心职责：
/// - 复用公共领域基础配置
/// - 注入最近对话历史包
pub fn workbench_with_history(history: Vec<RecentConversationEntry>) -> AgentSessionWorkbench {
    let mut wb = public_pet_domain_workbench();
    wb.recent_conversation_pack = Some(RecentConversationPack { entries: history });
    wb
}

/// `authorized_context` 构造授权宠物工具上下文
/// 核心职责：
/// - 固定授权宠物 ID
/// - 为私域工具调用 case 提供上下文
pub fn authorized_context() -> AiToolContext {
    AiToolContext {
        actor_user_id: Uuid::new_v4(),
        observation_write_context: ObservationWriteContext::default(),
        authorized_pet_id: Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id"),
        gateway_context: ToolGatewayExecutionContext::default(),
        gateway_observer: None,
    }
}

/// `unauthorized_context` 构造未授权宠物工具上下文
/// 核心职责：
/// - 固定 nil 宠物 ID
/// - 验证私域工具越权拒绝
pub fn unauthorized_context() -> AiToolContext {
    AiToolContext {
        actor_user_id: Uuid::new_v4(),
        observation_write_context: ObservationWriteContext::default(),
        authorized_pet_id: Uuid::nil(),
        gateway_context: ToolGatewayExecutionContext::default(),
        gateway_observer: None,
    }
}

/// `build_engine` 构造 Runtime loop engine
/// 核心职责：
/// - 注入脚本化 provider
/// - 注入工具注册表和工具上下文
pub fn build_engine(
    provider: Arc<ScriptedProvider>,
    registry: ToolRegistry,
    ctx: AiToolContext,
) -> AgentRuntimeLoopEngine {
    AgentRuntimeLoopEngine::new(provider, Arc::new(registry), ctx, None)
}

/// `build_engine_with_fact_package` 构造带事实包的 Runtime loop engine
/// 核心职责：
/// - 注入脚本化 provider
/// - 注入已验证事实包
pub fn build_engine_with_fact_package(
    provider: Arc<ScriptedProvider>,
    registry: ToolRegistry,
    ctx: AiToolContext,
    fact_package: AiFactPackage,
) -> AgentRuntimeLoopEngine {
    AgentRuntimeLoopEngine::new(provider, Arc::new(registry), ctx, Some(fact_package))
}

/// `run_prompt` 使用任意 `LoopEngine` 运行 prompt 并收集事件
pub async fn run_prompt<E: LoopEngine>(
    engine: E,
    input: &str,
    workbench: Option<AgentSessionWorkbench>,
) -> Vec<AgentEvent> {
    let mut session = AgentSession::new(
        Uuid::new_v4(),
        AgentId::main_pet_care_agent(),
        AiConversationSurface::HomePrivate,
        engine,
    );
    match workbench {
        Some(wb) => session
            .prompt_with_workbench(input, wb)
            .await
            .expect("prompt"),
        None => session.prompt(input).await.expect("prompt"),
    }
}

/// `final_text` 从 Runtime 事件中提取最终文本
/// 核心职责：
/// - 查找 `TurnFinished` 事件
/// - 返回可见最终回答文本
pub fn final_text(events: &[AgentEvent]) -> String {
    events
        .iter()
        .find_map(|e| match e {
            AgentEvent::TurnFinished { final_text, .. } => Some(final_text.clone()),
            _ => None,
        })
        .unwrap_or_default()
}

/// `has_tool_started` 判断指定工具是否开始执行
/// 核心职责：
/// - 查找 `ToolStarted` 事件
/// - 按工具名过滤
pub fn has_tool_started(events: &[AgentEvent], tool_name: &str) -> bool {
    events
        .iter()
        .any(|e| matches!(e, AgentEvent::ToolStarted { tool_name: name, .. } if name == tool_name))
}

/// `has_tool_finished` 判断是否出现指定工具完成状态
/// 核心职责：
/// - 查找 `ToolFinished` 事件
/// - 按工具状态过滤
pub fn has_tool_finished(events: &[AgentEvent], status: AgentToolStatus) -> bool {
    events
        .iter()
        .any(|e| matches!(e, AgentEvent::ToolFinished { status: s, .. } if *s == status))
}
