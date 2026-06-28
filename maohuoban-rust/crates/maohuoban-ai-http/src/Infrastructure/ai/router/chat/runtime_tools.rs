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
            "properties": {
                "pet_id": { "type": "string", "format": "uuid" }
            },
            "required": ["pet_id"]
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

    async fn execute(&self, ctx: &AiToolContext, args: &serde_json::Value) -> AiToolResult {
        let Some(pet_id) = requested_pet_id(args) else {
            return AiToolResult::failed("missing pet_id");
        };

        if pet_id != self.target_pet.pet_id {
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

/// requested_pet_id 读取工具参数中的目标宠物 ID
/// 核心职责：
/// - 保持工具层对必填参数做明确校验
fn requested_pet_id(args: &serde_json::Value) -> Option<Uuid> {
    args.get("pet_id")
        .and_then(serde_json::Value::as_str)
        .and_then(|value| Uuid::parse_str(value).ok())
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
