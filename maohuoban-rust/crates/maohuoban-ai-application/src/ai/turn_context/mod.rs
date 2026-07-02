//! turn_context Turn 前置上下文构建器
//! 核心职责：
//! - 把安全裁决、会话摘要、宠物上下文、能力目录、记忆包从 LoopEngine 中拆出
//! - 让 LoopEngine 只负责模型循环和工具回灌

pub mod context_budget;
mod temporal_context_provider;

pub use context_budget::ContextBudgetPolicy;
pub use temporal_context_provider::TemporalContextProvider;

use maohuoban_ai_domain::ai::{
    AgentCapability, AgentDefinition, AgentId, AgentSessionWorkbench, AiConversationSurface,
    AiPetDisplaySnapshot, CapabilityCatalog, CapabilityDomain, ContextConfirmationTaskSummary,
    ContextPack, ContextPetSummary, MemoryEntry, MemoryPack, ModelLabel, RecentConversationPack,
};

/// TurnContextBuilder Turn 前置上下文构建器
/// 核心职责：
/// - 组装 AgentSessionWorkbench 所需的全部上下文组件
/// - 根据是否有已选宠物决定私域能力和记忆的可见性
/// - 保持 LoopEngine 不承担上下文组装职责
pub struct TurnContextBuilder {
    surface: AiConversationSurface,
    target_pet: Option<AiPetDisplaySnapshot>,
    session_summary: Option<String>,
    pending_confirmation_task: Option<ContextConfirmationTaskSummary>,
    memory_entries: Vec<MemoryEntry>,
    recent_conversation: Option<RecentConversationPack>,
}

impl TurnContextBuilder {
    /// new 创建上下文构建器
    #[must_use]
    pub fn new(surface: AiConversationSurface) -> Self {
        Self {
            surface,
            target_pet: None,
            session_summary: None,
            pending_confirmation_task: None,
            memory_entries: Vec::new(),
            recent_conversation: None,
        }
    }

    /// with_target_pet 设置目标宠物
    #[must_use]
    pub fn with_target_pet(mut self, pet: Option<AiPetDisplaySnapshot>) -> Self {
        self.target_pet = pet;
        self
    }

    /// with_session_summary 设置会话摘要
    #[must_use]
    pub fn with_session_summary(mut self, summary: Option<String>) -> Self {
        self.session_summary = summary;
        self
    }

    /// with_pending_confirmation_task 设置当前待确认任务摘要
    #[must_use]
    pub fn with_pending_confirmation_task(
        mut self,
        task: Option<ContextConfirmationTaskSummary>,
    ) -> Self {
        self.pending_confirmation_task = task;
        self
    }

    /// with_memory_entries 设置记忆条目
    #[must_use]
    pub fn with_memory_entries(mut self, entries: Vec<MemoryEntry>) -> Self {
        self.memory_entries = entries;
        self
    }

    /// with_recent_conversation 设置同会话最近历史
    #[must_use]
    pub fn with_recent_conversation(mut self, pack: RecentConversationPack) -> Self {
        self.recent_conversation = Some(pack);
        self
    }

    /// build 构建本轮 Agent 工作台
    /// 核心职责：
    /// - 无已选宠物时只暴露公共能力，过滤私域记忆
    /// - 有已选宠物时追加私域能力，按宠物作用域过滤私域记忆
    #[must_use]
    pub fn build(self) -> AgentSessionWorkbench {
        let has_pet = self.target_pet.is_some();

        let (capability_domains, capabilities) = if has_pet {
            (
                vec![
                    CapabilityDomain::PublicPetDomain,
                    CapabilityDomain::PrivatePetContext,
                    CapabilityDomain::TemporalReasoning,
                    CapabilityDomain::AppProductSupport,
                    CapabilityDomain::AssistantIdentity,
                ],
                vec![
                    public_pet_care_capability(),
                    private_pet_context_capability(),
                    temporal_date_calculation_capability(),
                    app_product_support_capability(),
                    assistant_identity_capability(),
                ],
            )
        } else {
            (
                vec![
                    CapabilityDomain::PublicPetDomain,
                    CapabilityDomain::TemporalReasoning,
                    CapabilityDomain::AppProductSupport,
                    CapabilityDomain::AssistantIdentity,
                ],
                vec![
                    public_pet_care_capability(),
                    temporal_date_calculation_capability(),
                    app_product_support_capability(),
                    assistant_identity_capability(),
                ],
            )
        };

        let selected_pet = self.target_pet.as_ref().map(context_pet_summary);
        let authorized_pets = selected_pet.iter().cloned().collect();

        let memory_pack = match self.target_pet.as_ref() {
            Some(pet) => MemoryPack {
                entries: self.memory_entries,
            }
            .filter_for_pet_context(pet.pet_id),
            None => MemoryPack {
                entries: self.memory_entries,
            }
            .filter_for_public_context(),
        };

        let timezone = "Asia/Shanghai".to_owned();
        let temporal_context = Some(TemporalContextProvider::now_for_timezone(&timezone));

        AgentSessionWorkbench {
            recent_conversation_pack: self.recent_conversation,
            agent_definition: AgentDefinition {
                agent_id: AgentId::main_pet_care_agent(),
                name: "毛球".to_owned(),
                purpose: "宠物垂直照护、毛伙伴 App 帮助与用户宠物私域助手".to_owned(),
                default_model_label: ModelLabel::Primary,
                capability_domains,
            },
            capability_catalog: CapabilityCatalog { capabilities },
            context_pack: ContextPack {
                surface: self.surface,
                locale: "zh-Hans".to_owned(),
                timezone,
                temporal_context,
                selected_pet,
                authorized_pets,
                session_summary: self.session_summary,
                pending_confirmation_task: self.pending_confirmation_task,
            },
            memory_pack,
        }
    }
}

fn context_pet_summary(pet: &AiPetDisplaySnapshot) -> ContextPetSummary {
    ContextPetSummary {
        pet_id: pet.pet_id,
        name: pet.pet_name.clone(),
        species: pet.pet_species.clone(),
    }
}

fn public_pet_care_capability() -> AgentCapability {
    AgentCapability {
        code: "public_pet_domain".to_owned(),
        domain: CapabilityDomain::PublicPetDomain,
        title: "公共养宠咨询".to_owned(),
        when_to_use: "用户咨询通用照护、饮食、行为或常见症状观察时使用".to_owned(),
        requires_private_context: false,
    }
}

fn private_pet_context_capability() -> AgentCapability {
    AgentCapability {
        code: "private_pet_context".to_owned(),
        domain: CapabilityDomain::PrivatePetContext,
        title: "授权宠物上下文".to_owned(),
        when_to_use: "用户询问自己宠物档案、饮食或已授权上下文时使用".to_owned(),
        requires_private_context: true,
    }
}

fn temporal_date_calculation_capability() -> AgentCapability {
    AgentCapability {
        code: "temporal_date_calculation".to_owned(),
        domain: CapabilityDomain::TemporalReasoning,
        title: "日期与时间计算".to_owned(),
        when_to_use: "用户询问今天、明天、昨天、生日、年龄、相差天数、提前或延后日期时使用"
            .to_owned(),
        requires_private_context: false,
    }
}

fn app_product_support_capability() -> AgentCapability {
    AgentCapability {
        code: "app_product_support".to_owned(),
        domain: CapabilityDomain::AppProductSupport,
        title: "毛伙伴 App 使用帮助".to_owned(),
        when_to_use: "用户询问 App 页面、流程、入口和操作指引时使用".to_owned(),
        requires_private_context: false,
    }
}

fn assistant_identity_capability() -> AgentCapability {
    AgentCapability {
        code: "assistant_identity".to_owned(),
        domain: CapabilityDomain::AssistantIdentity,
        title: "助手身份说明".to_owned(),
        when_to_use: "用户询问毛球是谁、能做什么、能力边界是什么时使用".to_owned(),
        requires_private_context: false,
    }
}
