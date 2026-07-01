//! RuntimePetContextTool 运行时宠物上下文工具实现
//! 核心职责：
//! - 实现 AiToolDefinition 协议，将后端事实包投影为工具结果
//! - 统一 tool access 审计写入

use std::sync::Arc;

use async_trait::async_trait;
use maohuoban_ai_application::ai::ports::{AiSessionRepository, AiToolAccessLog};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{
    AiFactPackage, AiPetDisplaySnapshot, AiResult, ToolFailure, Toolset,
};
use uuid::Uuid;

use super::super::super::AiPetContextProviders;
use super::entries::package_entries;
use super::kind::RuntimePetContextToolKind;

/// RuntimePetContextTool 运行时宠物上下文工具
/// 核心职责：
/// - 持有目标宠物、后端提供者和会话仓储引用
/// - 通过 Tool Gateway 统一执行宠物上下文查询
pub(super) struct RuntimePetContextTool {
    pub(super) kind: RuntimePetContextToolKind,
    pub(super) providers: AiPetContextProviders,
    pub(super) session_repository: Arc<dyn AiSessionRepository>,
    pub(super) session_id: Uuid,
    pub(super) target_pet: AiPetDisplaySnapshot,
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
            toolset: Toolset::PrivatePetContext,
            progress_text: self.kind.progress_text(),
            result_fact_schema: Some(self.kind.fact_schema()),
        }
    }

    async fn execute(&self, ctx: &AiToolContext, _args: &serde_json::Value) -> AiToolResult {
        let result = self.load_package(ctx.actor_user_id).await;
        match result {
            Ok(package) => {
                let facts = package_entries(&package);
                let citations = package.citations.clone();
                self.record_tool_access(ctx.actor_user_id, true, None, &package)
                    .await;
                AiToolResult::allowed_with_facts(facts, citations)
            }
            Err(error) => {
                let stable_code = error.stable_code().to_owned();
                let recoverable = error.is_retryable();
                let safe_message = error.user_visible_message().to_owned();
                self.record_tool_access(
                    ctx.actor_user_id,
                    false,
                    Some(stable_code.clone()),
                    &AiFactPackage::empty(),
                )
                .await;
                AiToolResult::failed_with_failure(ToolFailure::new(
                    &stable_code,
                    recoverable,
                    &safe_message,
                    &stable_code,
                ))
            }
        }
    }
}

impl RuntimePetContextTool {
    /// load_package 按工具类型加载对应事实包
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

    /// record_tool_access 写入工具访问审计日志
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
