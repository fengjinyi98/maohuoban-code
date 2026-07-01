use maohuoban_ai_domain::ai::AgentTurnId;
use serde_json::{Value, json};
use uuid::Uuid;

use super::SkillBundle;

/// SkillDiagnosticsSnapshot Skill 匹配诊断快照
/// 核心职责：
/// - 固定 active skill、layer、toolset policy 和 workflow policy 诊断字段
/// - 强制携带 session_id、turn_id 和 message_id 三个关联键
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SkillDiagnosticsSnapshot {
    session_id: Uuid,
    turn_id: AgentTurnId,
    message_id: Uuid,
    active_skill_ids: Vec<String>,
    active_skill_layers: Vec<&'static str>,
    toolset_allowed_toolsets: Vec<&'static str>,
    toolset_preferred_toolsets: Vec<&'static str>,
    toolset_preferred_tools: Vec<String>,
    workflow_skill_ids: Vec<String>,
    merged_instruction_length: usize,
}

impl SkillDiagnosticsSnapshot {
    /// new 基于 SkillBundle 创建诊断快照
    #[must_use]
    pub fn new(
        session_id: Uuid,
        turn_id: AgentTurnId,
        message_id: Uuid,
        bundle: &SkillBundle,
    ) -> Self {
        Self {
            session_id,
            turn_id,
            message_id,
            active_skill_ids: bundle
                .active_skills
                .iter()
                .map(|skill| skill.skill_id.clone())
                .collect(),
            active_skill_layers: bundle
                .active_skills
                .iter()
                .map(|skill| skill.layer.as_str())
                .collect(),
            toolset_allowed_toolsets: bundle
                .toolset_policy
                .allowed_toolsets
                .as_ref()
                .map_or_else(Vec::new, |toolsets| {
                    toolsets.iter().map(|toolset| toolset.as_str()).collect()
                }),
            toolset_preferred_toolsets: bundle
                .toolset_policy
                .preferred_toolsets
                .iter()
                .map(|toolset| toolset.as_str())
                .collect(),
            toolset_preferred_tools: bundle.toolset_policy.preferred_tools.clone(),
            workflow_skill_ids: bundle.workflow_policy.workflow_skill_ids.clone(),
            merged_instruction_length: bundle.merged_instruction.chars().count(),
        }
    }

    /// event_name 返回冻结事件名
    #[must_use]
    pub const fn event_name() -> &'static str {
        "ai.chat.skill.matched"
    }

    /// to_metadata_entries 返回 diagnostics 可直接记录的字段
    #[must_use]
    pub fn to_metadata_entries(&self) -> Vec<(&'static str, Value)> {
        vec![
            ("session_id", json!(self.session_id)),
            ("turn_id", json!(self.turn_id.as_uuid())),
            ("message_id", json!(self.message_id)),
            ("active_skill_ids", json!(self.active_skill_ids)),
            ("active_skill_layers", json!(self.active_skill_layers)),
            (
                "toolset_allowed_toolsets",
                json!(self.toolset_allowed_toolsets),
            ),
            (
                "toolset_preferred_toolsets",
                json!(self.toolset_preferred_toolsets),
            ),
            (
                "toolset_preferred_tools",
                json!(self.toolset_preferred_tools),
            ),
            ("workflow_skill_ids", json!(self.workflow_skill_ids)),
            (
                "merged_instruction_length",
                json!(self.merged_instruction_length),
            ),
        ]
    }

    /// to_metadata 返回 JSON object，供合同测试和诊断断言使用
    #[must_use]
    pub fn to_metadata(&self) -> Value {
        let mut object = serde_json::Map::new();
        for (key, value) in self.to_metadata_entries() {
            object.insert(key.to_owned(), value);
        }
        Value::Object(object)
    }
}
