use uuid::Uuid;

use maohuoban_ai_domain::ai::AiToolConfirmationRequirement;

use crate::ai::policy::PolicyDecision;
use crate::ai::tools::{AiToolContext, AiToolMetadata, AiToolRiskLevel, ToolRegistry};

/// PolicyGuard 工具策略守卫
/// 核心职责：
/// - 基于工具 metadata、后端注入上下文和参数执行裁决
/// - 阻止未知工具、越权 pet 目标和确认前写入执行
#[derive(Debug, Default, Clone, Copy)]
pub struct PolicyGuard;

impl PolicyGuard {
    /// evaluate_registry 基于 ToolRegistry 查找工具并执行策略裁决
    #[must_use]
    pub fn evaluate_registry(
        &self,
        registry: &ToolRegistry,
        tool_name: &str,
        ctx: &AiToolContext,
        args: &serde_json::Value,
    ) -> PolicyDecision {
        let Some(tool) = registry.get(tool_name) else {
            return PolicyDecision::Deny {
                reason: "unknown tool".to_owned(),
            };
        };

        self.evaluate_tool(tool_name, &tool.metadata(), ctx, args)
    }

    /// evaluate_tool 基于工具 metadata 和调用参数执行策略裁决
    #[must_use]
    pub fn evaluate_tool(
        &self,
        tool_name: &str,
        metadata: &AiToolMetadata,
        ctx: &AiToolContext,
        args: &serde_json::Value,
    ) -> PolicyDecision {
        if !is_authorized_pet_target(ctx, args) {
            return PolicyDecision::Deny {
                reason: "pet not authorized".to_owned(),
            };
        }

        if is_write_commit_tool(tool_name) && !matches_confirmation_task(ctx, args) {
            return PolicyDecision::Deny {
                reason: "confirmation task not authorized".to_owned(),
            };
        }

        if is_write_commit_tool(tool_name) && matches_confirmation_task(ctx, args) {
            return PolicyDecision::Allow;
        }

        if is_write_prepare_tool(tool_name) {
            return PolicyDecision::Allow;
        }

        if is_controlled_background_write_tool(tool_name) {
            return PolicyDecision::Allow;
        }

        if metadata.requires_confirmation
            || !metadata.read_only
            || matches!(
                metadata.risk_level,
                AiToolRiskLevel::High | AiToolRiskLevel::Critical
            )
        {
            return PolicyDecision::RequireConfirmation {
                confirmation: AiToolConfirmationRequirement {
                    confirmation_task_id: Uuid::new_v4().to_string(),
                    tool_name: tool_name.to_owned(),
                    question_text: format!("是否确认执行 {}？", metadata.scope),
                    args: args.clone(),
                },
            };
        }

        PolicyDecision::Allow
    }
}

/// is_authorized_pet_target 校验参数 pet_id 是否匹配后端授权目标
/// 核心职责：
/// - 只信任 AiToolContext 中的 authorized_pet_id
/// - 参数缺失 pet_id 时交由具体工具做必填校验
fn is_authorized_pet_target(ctx: &AiToolContext, args: &serde_json::Value) -> bool {
    let Some(raw_pet_id) = args.get("pet_id").and_then(serde_json::Value::as_str) else {
        return true;
    };

    Uuid::parse_str(raw_pet_id).is_ok_and(|pet_id| pet_id == ctx.authorized_pet_id)
}

fn is_write_commit_tool(tool_name: &str) -> bool {
    tool_name.starts_with("commit_")
}

fn is_write_prepare_tool(tool_name: &str) -> bool {
    tool_name.starts_with("prepare_")
}

fn is_controlled_background_write_tool(tool_name: &str) -> bool {
    tool_name == "save_abnormal_episode_followup_plan"
}

fn matches_confirmation_task(ctx: &AiToolContext, args: &serde_json::Value) -> bool {
    let Some(expected) = ctx.gateway_context.confirmation_task_id.as_deref() else {
        return false;
    };
    args.get("confirmation_task_id")
        .and_then(serde_json::Value::as_str)
        .is_some_and(|actual| actual == expected)
}
