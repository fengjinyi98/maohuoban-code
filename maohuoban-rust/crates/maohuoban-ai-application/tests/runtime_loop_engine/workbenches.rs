//! workbenches Workbench 与 Response 构建器
//! 核心职责：
//! - 构造 public / private pet 场景的 `AgentSessionWorkbench`
//! - 构造 `final_response、json_final_response` 等脚本响应

use maohuoban_ai_domain::ai::{
    AgentCapability, AgentDefinition, AgentId, AgentSessionWorkbench, AiConversationSurface,
    AiMessageRole, CapabilityCatalog, CapabilityDomain, ContextPack, ContextPetSummary,
    LlmChatResponse, LlmFinishReason, LlmMessage, LlmRole, LlmUsage, MemoryPack, ModelLabel,
    RecentConversationEntry, RecentConversationPack,
};
use uuid::Uuid;

use super::helpers::AUTHORIZED_PET_ID;

pub(super) fn final_response() -> LlmChatResponse {
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: "毛球当前状态正常".to_owned(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![],
        usage: LlmUsage {
            input_tokens: 12,
            output_tokens: 6,
            total_tokens: 18,
        },
        finish_reason: LlmFinishReason::Stop,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

pub(super) fn json_final_response() -> LlmChatResponse {
    LlmChatResponse {
        message: LlmMessage {
            role: LlmRole::Assistant,
            content: serde_json::json!({
                "answer_text": "毛球当前状态正常，可以继续观察精神和食欲。",
                "display_blocks": [
                    {
                        "type": "paragraph",
                        "text": "毛球当前状态正常，可以继续观察精神和食欲。"
                    }
                ],
                "follow_up_questions": [],
                "safety_notes": []
            })
            .to_string(),
            reasoning_content: None,
            tool_call_id: None,
            tool_calls: Vec::new(),
        },
        tool_calls: vec![],
        usage: LlmUsage {
            input_tokens: 12,
            output_tokens: 20,
            total_tokens: 32,
        },
        finish_reason: LlmFinishReason::Stop,
        provider: "scripted".to_owned(),
        model: "primary".to_owned(),
    }
}

pub(super) fn public_pet_domain_workbench() -> AgentSessionWorkbench {
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
            selected_pet: None,
            authorized_pets: Vec::new(),
            session_summary: None,
        },
        memory_pack: MemoryPack {
            entries: Vec::new(),
        },
        recent_conversation_pack: None,
    }
}

pub(super) fn private_pet_context_workbench() -> AgentSessionWorkbench {
    let mut workbench = public_pet_domain_workbench();
    workbench
        .agent_definition
        .capability_domains
        .push(CapabilityDomain::PrivatePetContext);
    workbench
        .capability_catalog
        .capabilities
        .push(AgentCapability {
            code: "private_pet_context".to_owned(),
            domain: CapabilityDomain::PrivatePetContext,
            title: "授权宠物私域上下文".to_owned(),
            when_to_use: "用户询问已选宠物的档案、年龄、生日、陪伴、饮食或记录事实时使用"
                .to_owned(),
            requires_private_context: true,
        });
    workbench.context_pack.selected_pet = Some(ContextPetSummary {
        pet_id: Uuid::parse_str(AUTHORIZED_PET_ID).expect("pet id"),
        name: "梅录".to_owned(),
        species: "cat".to_owned(),
    });
    workbench
}

pub(super) fn workbench_with_recent_history() -> AgentSessionWorkbench {
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
            selected_pet: None,
            authorized_pets: Vec::new(),
            session_summary: None,
        },
        memory_pack: MemoryPack {
            entries: Vec::new(),
        },
        recent_conversation_pack: Some(RecentConversationPack {
            entries: vec![
                RecentConversationEntry {
                    role: AiMessageRole::User,
                    content: "豆包今天拉肚子怎么办".to_owned(),
                    tool_call_id: None,
                    tool_calls: Vec::new(),
                },
                RecentConversationEntry {
                    role: AiMessageRole::Assistant,
                    content: "先观察精神和食欲，如果持续超过24小时需要就医".to_owned(),
                    tool_call_id: None,
                    tool_calls: Vec::new(),
                },
            ],
        }),
    }
}
