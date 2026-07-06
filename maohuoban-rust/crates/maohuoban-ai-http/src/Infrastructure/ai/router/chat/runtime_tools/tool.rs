//! RuntimePetContextTool 运行时宠物上下文工具实现
//! 核心职责：
//! - 实现 AiToolDefinition 协议，将后端事实包投影为工具结果
//! - 统一 tool access 审计写入

use std::sync::Arc;

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use maohuoban_ai_application::ai::ports::{
    AbnormalFollowupPlanDraft, AbnormalSymptomCreationDraft, AiSessionRepository, AiToolAccessLog,
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
            RuntimePetContextToolKind::PrepareAbnormalSymptomCreation => serde_json::json!({
                "type": "object",
                "properties": {
                    "occurred_at": { "type": "string", "format": "date-time" },
                    "symptom_kinds": {
                        "type": "array",
                        "items": {
                            "type": "string",
                            "enum": [
                                "appetite",
                                "energy",
                                "stool",
                                "vomit",
                                "skin",
                                "eye",
                                "ear",
                                "mouth",
                                "respiratory",
                                "urinary",
                                "mobility",
                                "weight",
                                "behavior",
                                "other"
                            ]
                        }
                    },
                    "severity": {
                        "type": "string",
                        "enum": ["mild", "obvious", "severe"]
                    },
                    "note": { "type": "string" }
                },
                "required": ["occurred_at", "symptom_kinds", "severity", "note"]
            }),
            RuntimePetContextToolKind::CommitObservationWrite => serde_json::json!({
                "type": "object",
                "properties": {
                    "confirmation_task_id": { "type": "string", "format": "uuid" }
                },
                "required": ["confirmation_task_id"]
            }),
            RuntimePetContextToolKind::SaveAbnormalFollowupPlan => {
                abnormal_followup_plan_parameters_schema()
            }
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
                    | RuntimePetContextToolKind::PrepareAbnormalSymptomCreation
                    | RuntimePetContextToolKind::CommitObservationWrite
                    | RuntimePetContextToolKind::SaveAbnormalFollowupPlan
            ),
            concurrency_safe: !matches!(
                self.kind,
                RuntimePetContextToolKind::PrepareObservationWrite
                    | RuntimePetContextToolKind::PrepareAbnormalSymptomCreation
                    | RuntimePetContextToolKind::CommitObservationWrite
                    | RuntimePetContextToolKind::SaveAbnormalFollowupPlan
            ),
            risk_level: if matches!(
                self.kind,
                RuntimePetContextToolKind::PrepareObservationWrite
                    | RuntimePetContextToolKind::PrepareAbnormalSymptomCreation
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
                    | RuntimePetContextToolKind::PrepareAbnormalSymptomCreation
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
        if self.kind == RuntimePetContextToolKind::PrepareAbnormalSymptomCreation {
            return self
                .execute_prepare_abnormal_symptom_creation(ctx, args)
                .await;
        }
        let result = self.execute_kind(ctx, args).await;
        match result {
            Ok(package) => {
                self.record_tool_access(ctx.actor_user_id, true, None, args, &package)
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
                    args,
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

/// abnormal_followup_plan_parameters_schema 构建异常主动追踪计划工具 schema
/// 核心职责：
/// - 约束模型只提交计划草稿字段
/// - 固定 time_decision 审计字段结构
fn abnormal_followup_plan_parameters_schema() -> serde_json::Value {
    serde_json::json!({
        "type": "object",
        "properties": {
            "due_at": { "type": "string", "format": "date-time" },
            "message_title": { "type": "string" },
            "message_body": { "type": "string" },
            "rationale": { "type": "string" },
            "time_decision": abnormal_followup_plan_time_decision_schema(),
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
            "time_decision",
            "recommended_actions"
        ]
    })
}

/// abnormal_followup_plan_time_decision_schema 构建追踪时间决策审计 schema
/// 核心职责：
/// - 固定模型解释 due_at 的必填证据字段
/// - 避免计划保存绕过信息断层和身份上下文审计
fn abnormal_followup_plan_time_decision_schema() -> serde_json::Value {
    serde_json::json!({
        "type": "object",
        "description": "模型选择 due_at 的可审计时间决策说明。该字段只用于审计，不会让代码替模型决定提醒时间。",
        "properties": {
            "now_at": { "type": "string", "format": "date-time" },
            "occurred_at": { "type": "string", "format": "date-time" },
            "episode_started_at": { "type": "string", "format": "date-time" },
            "last_observed_at": {
                "anyOf": [
                    { "type": "string", "format": "date-time" },
                    { "type": "null" }
                ]
            },
            "elapsed_minutes": { "type": "integer" },
            "attention_timing": {
                "type": "string",
                "enum": ["now_or_soon", "scheduled_later", "monitor_without_prompt"]
            },
            "staleness_assessment": {
                "type": "object",
                "description": "模型对当前异常信息断层的判断。只用于审计模型如何理解 now_at - max(occurred_at,last_observed_at)。",
                "properties": {
                    "basis": { "type": "string" },
                    "staleness_minutes": { "type": "integer" },
                    "reason": { "type": "string" }
                },
                "required": ["basis", "staleness_minutes", "reason"]
            },
            "identity_context": {
                "type": "object",
                "description": "模型规划时使用的宠物基础身份事实摘要，例如物种、生日、出生至今天数或年龄阶段。",
                "properties": {
                    "species": { "type": "string" },
                    "birthday": {
                        "anyOf": [
                            { "type": "string" },
                            { "type": "null" }
                        ]
                    },
                    "world_days": {
                        "anyOf": [
                            { "type": "integer" },
                            { "type": "null" }
                        ]
                    },
                    "age_note": { "type": "string" }
                },
                "required": ["species"]
            },
            "selected_due_at": { "type": "string", "format": "date-time" },
            "delay_minutes": { "type": "integer" },
            "urgency_window": { "type": "string" },
            "reason": { "type": "string" },
            "time_tool_used": { "type": "boolean" }
        },
        "required": [
            "now_at",
            "occurred_at",
            "episode_started_at",
            "last_observed_at",
            "elapsed_minutes",
            "attention_timing",
            "staleness_assessment",
            "identity_context",
            "selected_due_at",
            "delay_minutes",
            "urgency_window",
            "reason",
            "time_tool_used"
        ]
    })
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
            RuntimePetContextToolKind::PrepareAbnormalSymptomCreation => {
                unreachable!(
                    "prepare abnormal symptom creation handled in execute_prepare_abnormal_symptom_creation"
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
                let mut confirmation = prepared.confirmation;
                confirmation.args = args.clone();
                self.record_tool_access(
                    ctx.actor_user_id,
                    true,
                    None,
                    args,
                    &observation_prepare_fact_package(&confirmation.confirmation_task_id),
                )
                .await;
                AiToolResult::requires_confirmation(confirmation)
            }
            Err(error) => {
                let safe_message = error.to_string();
                self.record_tool_access(
                    ctx.actor_user_id,
                    false,
                    Some("pet.observation.write_prepare.failed".to_owned()),
                    args,
                    &AiFactPackage::empty(),
                )
                .await;
                AiToolResult::failed(&safe_message)
            }
        }
    }

    async fn execute_prepare_abnormal_symptom_creation(
        &self,
        ctx: &AiToolContext,
        args: &serde_json::Value,
    ) -> AiToolResult {
        let Ok(draft) = parse_abnormal_symptom_creation_draft(args) else {
            return AiToolResult::invalid_arguments_failure();
        };
        match self
            .providers
            .abnormal_symptom_creation_provider
            .prepare_abnormal_symptom_creation(
                ctx.actor_user_id,
                self.target_pet.pet_id,
                self.session_id,
                draft,
            )
            .await
        {
            Ok(prepared) => {
                let mut confirmation = prepared.confirmation;
                confirmation.args = args.clone();
                self.record_tool_access(
                    ctx.actor_user_id,
                    true,
                    None,
                    args,
                    &abnormal_symptom_creation_prepare_fact_package(
                        &confirmation.confirmation_task_id,
                    ),
                )
                .await;
                AiToolResult::requires_confirmation(confirmation)
            }
            Err(error) => {
                let safe_message = error.to_string();
                self.record_tool_access(
                    ctx.actor_user_id,
                    false,
                    Some("pet.abnormal_symptom.create_prepare.failed".to_owned()),
                    args,
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
        args: &serde_json::Value,
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
                request_payload: Some(args.clone()),
                response_payload: Some(tool_response_payload(package)),
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

fn abnormal_symptom_creation_prepare_fact_package(confirmation_task_id: &str) -> AiFactPackage {
    let mut package = AiFactPackage::empty();
    package.pending_confirmations.push(AiFactEntry {
        key: "abnormal_symptom.create_prepare".to_owned(),
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
        time_decision: args.get("time_decision").cloned().ok_or_else(|| {
            maohuoban_ai_domain::ai::AiError::InvalidInput("缺少 time_decision".to_owned())
        })?,
    })
}

/// parse_abnormal_symptom_creation_draft 解析异常创建工具参数
/// 核心职责：
/// - 将模型提交的异常候选字段转换为确认任务草稿
/// - 只做字段结构校验，不替模型判断是否应该创建异常
fn parse_abnormal_symptom_creation_draft(
    args: &serde_json::Value,
) -> AiResult<AbnormalSymptomCreationDraft> {
    let occurred_at_raw = required_string_arg(args, "occurred_at")?;
    let occurred_at = DateTime::parse_from_rfc3339(&occurred_at_raw)
        .map_err(|_| {
            maohuoban_ai_domain::ai::AiError::InvalidInput("occurred_at 格式无效".to_owned())
        })?
        .with_timezone(&Utc);
    let symptom_kinds =
        args.get("symptom_kinds")
            .and_then(serde_json::Value::as_array)
            .ok_or_else(|| {
                maohuoban_ai_domain::ai::AiError::InvalidInput(
                    "symptom_kinds 必须是字符串数组".to_owned(),
                )
            })?
            .iter()
            .map(|value| {
                let Some(kind) = value.as_str() else {
                    return Err(maohuoban_ai_domain::ai::AiError::InvalidInput(
                        "symptom_kinds 必须是字符串数组".to_owned(),
                    ));
                };
                match kind {
                    "appetite" | "energy" | "stool" | "vomit" | "skin" | "eye" | "ear"
                    | "mouth" | "respiratory" | "urinary" | "mobility" | "weight" | "behavior"
                    | "other" => Ok(kind.to_owned()),
                    _ => Err(maohuoban_ai_domain::ai::AiError::InvalidInput(
                        "symptom_kinds 包含未知类型".to_owned(),
                    )),
                }
            })
            .collect::<AiResult<Vec<_>>>()?;
    if symptom_kinds.is_empty() {
        return Err(maohuoban_ai_domain::ai::AiError::InvalidInput(
            "symptom_kinds 不能为空".to_owned(),
        ));
    }
    let severity = required_string_arg(args, "severity")?;
    match severity.as_str() {
        "mild" | "obvious" | "severe" => {}
        _ => {
            return Err(maohuoban_ai_domain::ai::AiError::InvalidInput(
                "severity 格式无效".to_owned(),
            ));
        }
    }
    Ok(AbnormalSymptomCreationDraft {
        occurred_at,
        symptom_kinds,
        severity,
        note: required_string_arg(args, "note")?,
    })
}

/// tool_response_payload 生成工具响应审计摘要
/// 核心职责：
/// - 记录工具返回事实的引用和事实桶数量
/// - 避免在工具审计表重复写完整事实正文
fn tool_response_payload(package: &AiFactPackage) -> serde_json::Value {
    serde_json::json!({
        "returned_ref_ids": package
            .citations
            .iter()
            .map(|citation| citation.source_id.to_string())
            .collect::<Vec<_>>(),
        "fact_count": package.facts.len(),
        "weak_hint_count": package.weak_hints.len(),
        "pending_confirmation_count": package.pending_confirmations.len()
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
