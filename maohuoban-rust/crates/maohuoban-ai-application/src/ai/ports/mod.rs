//! ports AI 应用层端口定义
//! 核心职责：
//! - 声明 LlmProvider、AuthorizedPetCatalog、AiSessionRepository 等端口 trait
//! - application 只依赖 trait，不感知基础设施实现
// MHB_STRUCTURE_EXEMPTION: 既有 AI application ports 聚合入口。

pub mod abnormal_episode_facts;
pub mod abnormal_followup_plan;
pub mod chat_turn_transaction;
pub mod diet_confirmation_candidates;
pub mod diet_context;
pub mod food_inventory_hints;
pub mod health_quick_facts;
pub mod identity_context;
pub mod llm;
pub mod memory_candidate_repository;
pub mod memory_repository;
pub mod observation_write_commit;
pub mod observation_write_prepare;
pub mod observation_write_provider;
pub mod pet_catalog;
pub mod session_event_repository;
pub mod session_repository;
pub mod session_summary_repository;
pub mod session_turn_repository;

pub use abnormal_episode_facts::{
    EmptyPetAbnormalEpisodeFactProvider, PetAbnormalEpisodeFactProvider,
};
pub use abnormal_followup_plan::{
    AbnormalFollowupPlanDraft, AbnormalFollowupPlanProvider, SavedAbnormalFollowupPlan,
};
pub use chat_turn_transaction::{ChatTurnTransactionPort, FinalizerTxInput, IngressTxInput};
pub use diet_confirmation_candidates::PetDietConfirmationCandidateProvider;
pub use diet_context::{EmptyPetDietFactProvider, PetDietFactProvider};
pub use food_inventory_hints::FoodInventoryHintProvider;
pub use health_quick_facts::{EmptyPetHealthQuickFactProvider, PetHealthQuickFactProvider};
pub use identity_context::{EmptyPetIdentityFactProvider, PetIdentityFactProvider};
pub use llm::{DisabledLlmProvider, FakeLlmProvider, LlmProvider};
pub use memory_candidate_repository::{MemoryCandidateRepository, NoopMemoryCandidateRepository};
pub use memory_repository::{MemoryQuery, MemoryRepository, NoopMemoryRepository};
pub use observation_write_commit::CommittedObservationWrite;
pub use observation_write_prepare::PreparedObservationWrite;
pub use observation_write_provider::{ObservationWriteContext, PetObservationWriteProvider};
pub use pet_catalog::{AuthorizedPetCatalog, EmptyPetCatalog, InMemoryPetCatalog};
pub use session_event_repository::SessionEventRepository;
pub use session_repository::{AiRequestGateLog, AiSessionRepository, AiToolAccessLog};
pub use session_summary_repository::{NoopSessionSummaryRepository, SessionSummaryRepository};
pub use session_turn_repository::SessionTurnRepository;
