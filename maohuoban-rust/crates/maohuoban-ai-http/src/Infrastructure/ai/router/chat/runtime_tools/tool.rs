//! RuntimePetContextTool 运行时宠物上下文工具实现
//! 核心职责：
//! - 实现 AiToolDefinition 协议，将后端事实包投影为工具结果
//! - 统一 tool access 审计写入

use std::sync::Arc;

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use maohuoban_ai_application::ai::ports::{
    AbnormalFollowupPlanDraft, AiSessionRepository, AiToolAccessLog,
};
use maohuoban_ai_application::ai::tools::{
    AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel,
};
use maohuoban_ai_domain::ai::{
    AiFactEntry, AiFactPackage, AiFactStrength, AiPetDisplaySnapshot, AiResult, ToolFailure,
    Toolset,
};
use uuid::Uuid;

use super::super::super::AiPetContextProviders;
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
        match self.kind {
            RuntimePetContextToolKind::AbnormalEpisodeFacts => serde_json::json!({
                "type": "object",
                "properties": {
                    "episode_id": { "type": "string", "format": "uuid" }
                },
                "required": []
            }),
            RuntimePetContextToolKind::PrepareObservationWrite => serde_json::json!({
                "type": "object",
                "properties": {
                    "note": { "type": "string" }
                },
                "required": ["note"]
            }),
            RuntimePetContextToolKind::CommitObservationWrite => serde_json::json!({
                "type": "object",
                "properties": {
                    "confirmation_task_id": { "type": "string", "format": "uuid" }
                },
                "required": ["confirmation_task_id"]
            }),
            RuntimePetContextToolKind::SaveAbnormalFollowupPlan => serde_json::json!({
                "type": "object",
                "properties": {
                    "due_at": { "type": "string", "format": "date-time" },
                    "message_title": { "type": "string" },
                    "message_body": { "type": "string" },
                    "rationale": { "type": "string" },
                    "recommended_actions": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "enum": [
                                "update_observation",
                                "chat_with_agent",
                                "mark_recovered",
                                "book_clinic"
                            ]
                        }
                    }
                },
                "required": [
                    "due_at",
                    "message_title",
                    "message_body",
                    "rationale",
                    "recommended_actions"
                ]
            }),
            _ => serde_json::json!({
                "type": "object",
                "properties": {},
                "required": []
            }),
        }
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: self.kind.scope().to_owned(),
            read_only: !matches!(
                self.kind,
                RuntimePetContextToolKind::PrepareObservationWrite
                    | RuntimePetContextToolKind::CommitObservationWrite
                    | RuntimePetContextToolKind::SaveAbnormalFollowupPlan
            ),
            concurrency_safe: !matches!(
                self.kind,
                RuntimePetContextToolKind::PrepareObservationWrite
                    | RuntimePetContextToolKind::CommitObservationWrite
                    | RuntimePetContextToolKind::SaveAbnormalFollowupPlan
            ),
            risk_level: if matches!(
                self.kind,
                RuntimePetContextToolKind::PrepareObservationWrite
                    | RuntimePetContextToolKind::CommitObservationWrite
                    | RuntimePetContextToolKind::SaveAbnormalFollowupPlan
            ) {
                AiToolRiskLevel::High
            } else {
                AiToolRiskLevel::Low
            },
            requires_confirmation: matches!(
                self.kind,
                RuntimePetContextToolKind::PrepareObservationWrite
            ),
            domain_tags: vec![self.kind.domain_tag().to_owned()],
            toolset: if matches!(self.kind, RuntimePetContextToolKind::CommitObservationWrite) {
                Toolset::Confirmation
            } else {
                Toolset::PrivatePetContext
            },
            progress_text: self.kind.progress_text(),
            result_fact_schema: Some(self.kind.fact_schema()),
        }
    }

    async fn execute(&self, ctx: &AiToolContext, args: &serde_json::Value) -> AiToolResult {
        if self.kind == RuntimePetContextToolKind::PrepareObservationWrite {
            return self.execute_prepare_observation_write(ctx, args).await;
        }
        let result = self.execute_kind(ctx, args).await;
        match result {
            Ok(package) => {
                self.record_tool_access(ctx.actor_user_id, true, None, &package)
                    .await;
                AiToolResult::allowed_with_fact_package(package)
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
    async fn execute_kind(
        &self,
        ctx: &AiToolContext,
        args: &serde_json::Value,
    ) -> AiResult<AiFactPackage> {
        match self.kind {
            RuntimePetContextToolKind::Identity => {
                self.providers
                    .identity_fact_provider
                    .load_identity_fact_package(ctx.actor_user_id, &self.target_pet)
                    .await
            }
            RuntimePetContextToolKind::AbnormalEpisodeFacts => {
                let episode_id = optional_uuid_arg(args, "episode_id")?;
                self.providers
                    .abnormal_episode_fact_provider
                    .load_abnormal_episode_fact_package(
                        ctx.actor_user_id,
                        &self.target_pet,
                        episode_id,
                    )
                    .await
            }
            RuntimePetContextToolKind::CurrentDiet => {
                self.providers
                    .diet_fact_provider
                    .load_current_diet_fact_package(ctx.actor_user_id, &self.target_pet)
                    .await
            }
            RuntimePetContextToolKind::RecentHealthFacts => {
                self.providers
                    .health_quick_fact_provider
                    .load_recent_health_quick_fact_package(ctx.actor_user_id, &self.target_pet)
                    .await
            }
            RuntimePetContextToolKind::FoodInventoryHints => {
                self.providers
                    .food_inventory_hint_provider
                    .load_food_inventory_hint_package(ctx.actor_user_id, &self.target_pet)
                    .await
            }
            RuntimePetContextToolKind::DietConfirmationCandidates => {
                self.providers
                    .diet_confirmation_candidate_provider
                    .load_diet_confirmation_candidate_package(ctx.actor_user_id, &self.target_pet)
                    .await
            }
            RuntimePetContextToolKind::PrepareObservationWrite => {
                unreachable!(
                    "prepare observation write handled in execute_prepare_observation_write"
                )
            }
            RuntimePetContextToolKind::CommitObservationWrite => {
                let confirmation_task_id = args
                    .get("confirmation_task_id")
                    .and_then(serde_json::Value::as_str)
                    .and_then(|value| Uuid::parse_str(value).ok())
                    .ok_or_else(|| {
                        maohuoban_ai_domain::ai::AiError::InvalidInput("缺少确认任务 ID".to_owned())
                    })?;
                let committed = self
                    .providers
                    .observation_write_provider
                    .commit_observation_write(
                        ctx.actor_user_id,
                        self.target_pet.pet_id,
                        confirmation_task_id,
                    )
                    .await
                    .map_err(|error| {
                        maohuoban_ai_domain::ai::AiError::Infrastructure(error.to_string())
                    })?;
                Ok(observation_commit_fact_package(committed.event_id))
            }
            RuntimePetContextToolKind::SaveAbnormalFollowupPlan => {
                let draft = parse_followup_plan_draft(args)?;
                let saved = self
                    .providers
                    .abnormal_followup_plan_provider
                    .save_followup_plan(
                        ctx.actor_user_id,
                        self.target_pet.pet_id,
                        ctx.observation_write_context.clone(),
                        draft,
                    )
                    .await
                    .map_err(|error| {
                        maohuoban_ai_domain::ai::AiError::Infrastructure(error.to_string())
                    })?;
                Ok(abnormal_followup_plan_fact_package(
                    saved.followup_id,
                    saved.due_at,
                ))
            }
        }
    }

    async fn execute_prepare_observation_write(
        &self,
        ctx: &AiToolContext,
        args: &serde_json::Value,
    ) -> AiToolResult {
        let Some(note) = args.get("note").and_then(serde_json::Value::as_str) else {
            return AiToolResult::invalid_arguments_failure();
        };
        match self
            .providers
            .observation_write_provider
            .prepare_observation_write(
                ctx.actor_user_id,
                self.target_pet.pet_id,
                note.to_owned(),
                ctx.observation_write_context.clone(),
            )
            .await
        {
            Ok(prepared) => {
                self.record_tool_access(
                    ctx.actor_user_id,
                    true,
                    None,
                    &observation_prepare_fact_package(&prepared.confirmation.confirmation_task_id),
                )
                .await;
                AiToolResult::requires_confirmation(prepared.confirmation)
            }
            Err(error) => {
                let safe_message = error.to_string();
                self.record_tool_access(
                    ctx.actor_user_id,
                    false,
                    Some("pet.observation.write_prepare.failed".to_owned()),
                    &AiFactPackage::empty(),
                )
                .await;
                AiToolResult::failed(&safe_message)
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

fn observation_prepare_fact_package(confirmation_task_id: &str) -> AiFactPackage {
    let mut package = AiFactPackage::empty();
    package.pending_confirmations.push(AiFactEntry {
        key: "observation.write_prepare".to_owned(),
        value: format!("confirmation_task_id={confirmation_task_id}"),
        strength: AiFactStrength::PendingConfirmation,
        citation_id: None,
    });
    package.fact_strength = AiFactStrength::PendingConfirmation;
    package
}

fn observation_commit_fact_package(event_id: Uuid) -> AiFactPackage {
    let mut package = AiFactPackage::empty();
    package.facts.push(AiFactEntry {
        key: "observation.write_commit".to_owned(),
        value: format!("event_id={event_id}"),
        strength: AiFactStrength::Strong,
        citation_id: Some(event_id),
    });
    package.fact_strength = AiFactStrength::Strong;
    package
}

fn abnormal_followup_plan_fact_package(followup_id: Uuid, due_at: DateTime<Utc>) -> AiFactPackage {
    let mut package = AiFactPackage::empty();
    package.facts.push(AiFactEntry {
        key: "abnormal_followup_plan.saved".to_owned(),
        value: format!("followup_id={followup_id}; due_at={}", due_at.to_rfc3339()),
        strength: AiFactStrength::Strong,
        citation_id: Some(followup_id),
    });
    package.fact_strength = AiFactStrength::Strong;
    package
}

/// parse_followup_plan_draft 解析异常追踪计划工具参数
/// 核心职责：
/// - 将模型输出的 JSON 参数转换为受控计划草稿
/// - 保持 episode/followup 归属不进入模型可写参数
fn parse_followup_plan_draft(args: &serde_json::Value) -> AiResult<AbnormalFollowupPlanDraft> {
    let due_at_raw = required_string_arg(args, "due_at")?;
    let due_at = DateTime::parse_from_rfc3339(&due_at_raw)
        .map_err(|_| maohuoban_ai_domain::ai::AiError::InvalidInput("due_at 格式无效".to_owned()))?
        .with_timezone(&Utc);
    let recommended_actions = args
        .get("recommended_actions")
        .and_then(serde_json::Value::as_array)
        .ok_or_else(|| {
            maohuoban_ai_domain::ai::AiError::InvalidInput(
                "recommended_actions 必须是字符串数组".to_owned(),
            )
        })?
        .iter()
        .map(|value| {
            value.as_str().map(str::to_owned).ok_or_else(|| {
                maohuoban_ai_domain::ai::AiError::InvalidInput(
                    "recommended_actions 必须是字符串数组".to_owned(),
                )
            })
        })
        .collect::<AiResult<Vec<_>>>()?;

    Ok(AbnormalFollowupPlanDraft {
        due_at,
        message_title: required_string_arg(args, "message_title")?,
        message_body: required_string_arg(args, "message_body")?,
        rationale: required_string_arg(args, "rationale")?,
        recommended_actions,
    })
}

/// required_string_arg 解析必填字符串工具参数
/// 核心职责：
/// - 统一必填字符串参数错误
/// - 避免空字段绕过工具入参层校验
fn required_string_arg(args: &serde_json::Value, key: &str) -> AiResult<String> {
    let Some(value) = args.get(key).and_then(serde_json::Value::as_str) else {
        return Err(maohuoban_ai_domain::ai::AiError::InvalidInput(format!(
            "缺少 {key}"
        )));
    };
    if value.trim().is_empty() {
        return Err(maohuoban_ai_domain::ai::AiError::InvalidInput(format!(
            "{key} 不能为空"
        )));
    }
    Ok(value.to_owned())
}

/// optional_uuid_arg 解析可选 UUID 工具参数
/// 核心职责：
/// - 允许模型省略可选 ID 参数
/// - 对非法 UUID 返回稳定无效入参错误
fn optional_uuid_arg(args: &serde_json::Value, key: &str) -> AiResult<Option<Uuid>> {
    let Some(value) = args.get(key) else {
        return Ok(None);
    };
    let Some(raw) = value.as_str() else {
        return Err(maohuoban_ai_domain::ai::AiError::InvalidInput(format!(
            "{key} 必须是 UUID 字符串"
        )));
    };
    Uuid::parse_str(raw)
        .map(Some)
        .map_err(|_| maohuoban_ai_domain::ai::AiError::InvalidInput(format!("{key} 格式无效")))
}
