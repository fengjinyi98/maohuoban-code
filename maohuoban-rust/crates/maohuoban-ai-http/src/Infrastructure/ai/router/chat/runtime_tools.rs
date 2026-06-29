use std::sync::Arc;

use async_trait::async_trait;
use maohuoban_ai_application::ai::ports::{AiSessionRepository, AiToolAccessLog};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel, ToolRegistry,
};
use maohuoban_ai_domain::ai::{AiFactEntry, AiFactPackage, AiPetDisplaySnapshot, AiResult};
use uuid::Uuid;

use super::super::{AiHttpState, AiPetContextProviders};

/// build_runtime_tool_registry 构建当前请求的 Runtime Tool Gateway
/// 核心职责：
/// - 将已授权目标宠物上下文注册为模型可调用工具
/// - 保持工具执行统一经过 ToolRegistry 和 PolicyGuard
pub(super) fn build_runtime_tool_registry(
    state: &AiHttpState,
    session_id: Uuid,
    target_pet: &AiPetDisplaySnapshot,
) -> ToolRegistry {
    let mut registry = ToolRegistry::new();
    for kind in RuntimePetContextToolKind::all() {
        registry.register(RuntimePetContextTool {
            kind,
            providers: state.pet_context_providers.clone(),
            session_repository: state.session_repository.clone(),
            session_id,
            target_pet: target_pet.clone(),
        });
    }
    registry
}

#[derive(Debug, Clone, Copy)]
enum RuntimePetContextToolKind {
    Identity,
    CurrentDiet,
    FoodInventoryHints,
    DietConfirmationCandidates,
}

impl RuntimePetContextToolKind {
    fn all() -> [Self; 4] {
        [
            Self::Identity,
            Self::CurrentDiet,
            Self::FoodInventoryHints,
            Self::DietConfirmationCandidates,
        ]
    }

    fn name(self) -> &'static str {
        match self {
            Self::Identity => "load_pet_identity_context",
            Self::CurrentDiet => "load_pet_current_diet_context",
            Self::FoodInventoryHints => "load_food_inventory_change_hints",
            Self::DietConfirmationCandidates => "load_pet_diet_confirmation_candidates",
        }
    }

    fn description(self) -> &'static str {
        match self {
            Self::Identity => "加载目标宠物身份档案上下文",
            Self::CurrentDiet => "加载目标宠物当前饮食上下文",
            Self::FoodInventoryHints => "加载目标宠物储物柜变化弱线索",
            Self::DietConfirmationCandidates => "加载目标宠物饮食待确认候选",
        }
    }

    fn scope(self) -> &'static str {
        match self {
            Self::Identity => "pet.identity.read",
            Self::CurrentDiet => "pet.current_diet.read",
            Self::FoodInventoryHints => "food_inventory_change_hints.read",
            Self::DietConfirmationCandidates => "pet.diet_confirmation_candidates.read",
        }
    }

    fn requested_scope(self) -> &'static str {
        match self {
            Self::Identity => "pet_identity",
            Self::CurrentDiet => "pet_current_diet",
            Self::FoodInventoryHints => "food_inventory_change_hints",
            Self::DietConfirmationCandidates => "pet_diet_confirmation_candidates",
        }
    }

    fn domain_tag(self) -> &'static str {
        match self {
            Self::Identity => "identity",
            Self::CurrentDiet => "diet",
            Self::FoodInventoryHints => "inventory",
            Self::DietConfirmationCandidates => "diet_confirmation",
        }
    }
}

struct RuntimePetContextTool {
    kind: RuntimePetContextToolKind,
    providers: AiPetContextProviders,
    session_repository: Arc<dyn AiSessionRepository>,
    session_id: Uuid,
    target_pet: AiPetDisplaySnapshot,
}

#[async_trait]
impl AiToolDefinition for RuntimePetContextTool {
    fn name(&self) -> &'static str {
        self.kind.name()
    }

    fn description(&self) -> &'static str {
        self.kind.description()
    }

    fn parameters_schema(&self) -> serde_json::Value {
        serde_json::json!({
            "type": "object",
            "properties": {},
            "required": []
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: self.kind.scope().to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec![self.kind.domain_tag().to_owned()],
        }
    }

    async fn execute(&self, ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        if ctx.authorized_pet_id != self.target_pet.pet_id {
            return AiToolResult::denied("pet not authorized");
        }

        let result = self.load_package(ctx.actor_user_id).await;
        match result {
            Ok(package) => {
                self.record_tool_access(ctx.actor_user_id, true, None, &package)
                    .await;
                AiToolResult::allowed_with_facts(package_entries(&package), package.citations)
            }
            Err(error) => {
                let stable_code = error.stable_code().to_owned();
                self.record_tool_access(
                    ctx.actor_user_id,
                    false,
                    Some(stable_code.clone()),
                    &AiFactPackage::empty(),
                )
                .await;
                AiToolResult::failed(&stable_code)
            }
        }
    }
}

impl RuntimePetContextTool {
    async fn load_package(&self, actor_user_id: Uuid) -> AiResult<AiFactPackage> {
        match self.kind {
            RuntimePetContextToolKind::Identity => {
                self.providers
                    .identity_fact_provider
                    .load_identity_fact_package(actor_user_id, &self.target_pet)
                    .await
            }
            RuntimePetContextToolKind::CurrentDiet => {
                self.providers
                    .diet_fact_provider
                    .load_current_diet_fact_package(actor_user_id, &self.target_pet)
                    .await
            }
            RuntimePetContextToolKind::FoodInventoryHints => {
                self.providers
                    .food_inventory_hint_provider
                    .load_food_inventory_hint_package(actor_user_id, &self.target_pet)
                    .await
            }
            RuntimePetContextToolKind::DietConfirmationCandidates => {
                self.providers
                    .diet_confirmation_candidate_provider
                    .load_diet_confirmation_candidate_package(actor_user_id, &self.target_pet)
                    .await
            }
        }
    }

    async fn record_tool_access(
        &self,
        actor_user_id: Uuid,
        allowed: bool,
        denied_reason: Option<String>,
        package: &AiFactPackage,
    ) {
        let returned_ref_ids = package
            .citations
            .iter()
            .map(|citation| citation.source_id.to_string())
            .collect();
        let _ = self
            .session_repository
            .insert_tool_access_log(&AiToolAccessLog {
                session_id: Some(self.session_id),
                actor_user_id,
                tool_name: self.kind.name().to_owned(),
                requested_scope: self.kind.requested_scope().to_owned(),
                target_pet_id: Some(self.target_pet.pet_id),
                allowed,
                denied_reason,
                returned_ref_ids,
                duration_ms: 0,
                risk_signal: None,
            })
            .await;
    }
}

/// package_entries 合并事实包内可回灌给模型的事实条目
/// 核心职责：
/// - 同时返回强事实、计算事实和弱线索
fn package_entries(package: &AiFactPackage) -> Vec<AiFactEntry> {
    package
        .facts
        .iter()
        .chain(package.computed.iter())
        .chain(package.weak_hints.iter())
        .cloned()
        .collect()
}

#[cfg(test)]
mod tests {
    use async_trait::async_trait;
    use maohuoban_ai_application::ai::ports::{
        AiRequestGateLog, FoodInventoryHintProvider, PetDietConfirmationCandidateProvider,
        PetDietFactProvider, PetIdentityFactProvider,
    };
    use maohuoban_ai_application::ai::tools::{AiToolContext, AiToolDefinition};
    use maohuoban_ai_domain::ai::{
        AiChatSession, AiCitation, AiFactEntry, AiFactPackage, AiFactStrength, AiMessage,
        AiPetDisplaySnapshot, AiProposedAction, AiResult,
    };
    use serde_json::json;

    use super::*;

    struct EmptySessionRepository;

    #[async_trait]
    impl AiSessionRepository for EmptySessionRepository {
        async fn upsert_session(&self, _session: &AiChatSession) -> AiResult<()> {
            Ok(())
        }

        async fn insert_message(&self, _message: &AiMessage) -> AiResult<()> {
            Ok(())
        }

        async fn list_sessions_by_actor(
            &self,
            _actor_user_id: Uuid,
            _limit: i64,
        ) -> AiResult<Vec<AiChatSession>> {
            Ok(Vec::new())
        }

        async fn list_messages_by_session(&self, _session_id: Uuid) -> AiResult<Vec<AiMessage>> {
            Ok(Vec::new())
        }

        async fn get_session(&self, _session_id: Uuid) -> AiResult<Option<AiChatSession>> {
            Ok(None)
        }

        async fn rename_session(
            &self,
            _session_id: Uuid,
            _actor_user_id: Uuid,
            _title: &str,
        ) -> AiResult<Option<AiChatSession>> {
            Ok(None)
        }

        async fn set_session_pinned(
            &self,
            _session_id: Uuid,
            _actor_user_id: Uuid,
            _is_pinned: bool,
        ) -> AiResult<Option<AiChatSession>> {
            Ok(None)
        }

        async fn archive_session(
            &self,
            _session_id: Uuid,
            _actor_user_id: Uuid,
        ) -> AiResult<Option<AiChatSession>> {
            Ok(None)
        }

        async fn insert_request_gate_log(&self, _log: &AiRequestGateLog) -> AiResult<()> {
            Ok(())
        }

        async fn insert_tool_access_log(&self, _log: &AiToolAccessLog) -> AiResult<()> {
            Ok(())
        }

        async fn insert_message_citations(
            &self,
            _message_id: Uuid,
            _session_id: Uuid,
            _citations: &[AiCitation],
        ) -> AiResult<()> {
            Ok(())
        }

        async fn insert_proposed_action(
            &self,
            _session_id: Uuid,
            _action: &AiProposedAction,
        ) -> AiResult<()> {
            Ok(())
        }
    }

    struct EmptyPetContextProvider;

    #[async_trait]
    impl PetIdentityFactProvider for EmptyPetContextProvider {
        async fn load_identity_fact_package(
            &self,
            _actor_user_id: Uuid,
            target_pet: &AiPetDisplaySnapshot,
        ) -> AiResult<AiFactPackage> {
            Ok(fact_package_for(target_pet))
        }
    }

    #[async_trait]
    impl PetDietFactProvider for EmptyPetContextProvider {
        async fn load_current_diet_fact_package(
            &self,
            _actor_user_id: Uuid,
            target_pet: &AiPetDisplaySnapshot,
        ) -> AiResult<AiFactPackage> {
            Ok(fact_package_for(target_pet))
        }
    }

    #[async_trait]
    impl FoodInventoryHintProvider for EmptyPetContextProvider {
        async fn load_food_inventory_hint_package(
            &self,
            _actor_user_id: Uuid,
            target_pet: &AiPetDisplaySnapshot,
        ) -> AiResult<AiFactPackage> {
            Ok(fact_package_for(target_pet))
        }
    }

    #[async_trait]
    impl PetDietConfirmationCandidateProvider for EmptyPetContextProvider {
        async fn load_diet_confirmation_candidate_package(
            &self,
            _actor_user_id: Uuid,
            target_pet: &AiPetDisplaySnapshot,
        ) -> AiResult<AiFactPackage> {
            Ok(fact_package_for(target_pet))
        }
    }

    #[test]
    fn runtime_current_pet_tool_schema_does_not_require_model_pet_id() {
        let tool = runtime_identity_tool();

        assert_eq!(
            tool.parameters_schema(),
            json!({
                "type": "object",
                "properties": {},
                "required": []
            })
        );
    }

    #[tokio::test]
    async fn runtime_current_pet_tool_uses_authorized_target_without_model_pet_id() {
        let tool = runtime_identity_tool();
        let result = tool
            .execute(
                &AiToolContext {
                    actor_user_id: Uuid::new_v4(),
                    authorized_pet_id: tool.target_pet.pet_id,
                },
                &json!({}),
            )
            .await;

        assert!(result.allowed);
        assert!(result.denied_reason.is_none());
        assert!(result.failed_reason.is_none());
        assert_eq!(result.facts[0].value, "当前目标宠物事实");
    }

    fn runtime_identity_tool() -> RuntimePetContextTool {
        let provider = Arc::new(EmptyPetContextProvider);
        RuntimePetContextTool {
            kind: RuntimePetContextToolKind::Identity,
            providers: AiPetContextProviders::new(
                provider.clone(),
                provider.clone(),
                provider.clone(),
                provider,
            ),
            session_repository: Arc::new(EmptySessionRepository),
            session_id: Uuid::new_v4(),
            target_pet: AiPetDisplaySnapshot {
                pet_id: Uuid::parse_str("11111111-1111-1111-1111-111111111111").expect("pet id"),
                pet_name: "饭团".to_owned(),
                pet_avatar_url: None,
                pet_species: "cat".to_owned(),
                profile_number: "MHB001".to_owned(),
            },
        }
    }

    fn fact_package_for(target_pet: &AiPetDisplaySnapshot) -> AiFactPackage {
        let mut package = AiFactPackage::empty();
        package.target_pet = Some(target_pet.clone());
        package.facts.push(AiFactEntry {
            key: "test.fact".to_owned(),
            value: "当前目标宠物事实".to_owned(),
            strength: AiFactStrength::Strong,
            citation_id: None,
        });
        package
    }
}
