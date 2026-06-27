//! ports AI 应用层端口定义
//! 核心职责：
//! - 声明 LlmProvider、AuthorizedPetCatalog、AiSessionRepository 等端口 trait
//! - application 只依赖 trait，不感知基础设施实现

pub mod diet_context;
pub mod food_inventory_hints;
pub mod identity_context;
pub mod llm;
pub mod pet_catalog;
pub mod session_repository;

pub use diet_context::{EmptyPetDietFactProvider, PetDietFactProvider};
pub use food_inventory_hints::FoodInventoryHintProvider;
pub use identity_context::{EmptyPetIdentityFactProvider, PetIdentityFactProvider};
pub use llm::{DisabledLlmProvider, FakeLlmProvider, LlmProvider};
pub use pet_catalog::{AuthorizedPetCatalog, EmptyPetCatalog, InMemoryPetCatalog};
pub use session_repository::{AiRequestGateLog, AiSessionRepository, AiToolAccessLog};
