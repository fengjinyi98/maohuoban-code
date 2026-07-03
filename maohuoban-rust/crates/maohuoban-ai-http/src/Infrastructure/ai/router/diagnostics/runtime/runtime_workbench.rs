use maohuoban_ai_application::ai::diagnostics::AiDiagnosticsCorrelation;
use maohuoban_ai_domain::ai::{AgentSessionWorkbench, AiConversationSurface};
use maohuoban_diagnostics::Severity;
use serde_json::json;
use uuid::Uuid;

use super::super::diagnostics_common::{length_bucket, record_ai_event, surface_code};

/// record_chat_render_plan_selected 记录本轮允许的结构化渲染块类型
pub(crate) fn record_chat_render_plan_selected(
    session_id: Uuid,
    message_id: Uuid,
    surface: AiConversationSurface,
    target_pet_present: bool,
    allowed_block_kinds: &[&str],
) {
    let mut metadata = AiDiagnosticsCorrelation::for_session(session_id)
        .with_message_id(message_id)
        .to_metadata();
    metadata.extend(vec![
        ("surface", json!(surface_code(surface))),
        ("target_pet_present", json!(target_pet_present)),
        ("allowed_block_kinds", json!(allowed_block_kinds)),
    ]);
    record_ai_event("ai.chat.render_plan.selected", Severity::Info, metadata);
}

/// record_chat_workbench_built 记录本轮 Workbench 观测基线
/// 核心职责：
/// - 固定能力目录、可见工具、上下文摘要和记忆/历史计数字段
/// - 支撑后续 planner、skill 和 memory worktree 复用同一观测边界
pub(crate) fn record_chat_workbench_built(
    session_id: Uuid,
    turn_id: Uuid,
    message_id: Uuid,
    workbench: &AgentSessionWorkbench,
    visible_tool_names: &[String],
) {
    let recent_conversation_count = workbench
        .recent_conversation_pack
        .as_ref()
        .map_or(0, |pack| pack.entries.len());
    let mut metadata = AiDiagnosticsCorrelation::for_session(session_id)
        .with_turn_id(turn_id)
        .with_message_id(message_id)
        .to_metadata();
    metadata.extend(vec![
        (
            "capability_catalog",
            json!(
                workbench
                    .capability_catalog
                    .capabilities
                    .iter()
                    .map(|capability| capability.code.clone())
                    .collect::<Vec<_>>()
            ),
        ),
        ("visible_tools", json!(visible_tool_names)),
        (
            "context_summary_present",
            json!(workbench.context_pack.session_summary.is_some()),
        ),
        (
            "context_summary_length_bucket",
            json!(length_bucket(
                workbench
                    .context_pack
                    .session_summary
                    .as_deref()
                    .map_or(0, |summary| summary.chars().count())
            )),
        ),
        ("memory_count", json!(workbench.memory_pack.entries.len())),
        (
            "recent_conversation_count",
            json!(recent_conversation_count),
        ),
        (
            "selected_pet_present",
            json!(workbench.context_pack.selected_pet.is_some()),
        ),
        (
            "authorized_pet_count",
            json!(workbench.context_pack.authorized_pets.len()),
        ),
    ]);
    record_ai_event("ai.chat.workbench.built", Severity::Info, metadata);
}
