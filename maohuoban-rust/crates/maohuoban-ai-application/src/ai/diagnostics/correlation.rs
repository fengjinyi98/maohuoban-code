use serde_json::{Value, json};
use uuid::Uuid;

use maohuoban_ai_domain::ai::LlmDiagnosticsCorrelation;

pub const CHAT_SESSION_ID_PREFIX_FIELD: &str = "chat_session_id_prefix";
pub const TURN_ID_PREFIX_FIELD: &str = "turn_id_prefix";
pub const MESSAGE_ID_PREFIX_FIELD: &str = "message_id_prefix";
pub const TOOL_CALL_ID_FIELD: &str = "tool_call_id";
pub const PROVIDER_FIELD: &str = "provider";
pub const MODEL_FIELD: &str = "model";

/// AiDiagnosticsCorrelation Agent 诊断关联键
/// 核心职责：
/// - 固定跨 Ingress、Workbench、Tool、Provider、Finalizer 的关联字段
/// - 只暴露 UUID 前缀和稳定字符串，避免把完整内部主键散落到日志
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct AiDiagnosticsCorrelation {
    pub session_id: Option<Uuid>,
    pub turn_id: Option<Uuid>,
    pub message_id: Option<Uuid>,
    pub tool_call_id: Option<String>,
    pub provider: Option<String>,
    pub model: Option<String>,
}

impl AiDiagnosticsCorrelation {
    #[must_use]
    pub fn for_session(session_id: Uuid) -> Self {
        Self {
            session_id: Some(session_id),
            ..Self::default()
        }
    }

    #[must_use]
    pub fn from_llm_diagnostics(correlation: &LlmDiagnosticsCorrelation) -> Self {
        Self {
            session_id: correlation.session_id,
            turn_id: correlation.turn_id,
            message_id: correlation.message_id,
            tool_call_id: correlation.tool_call_id.clone(),
            provider: None,
            model: None,
        }
    }

    #[must_use]
    pub fn with_turn_id(mut self, turn_id: Uuid) -> Self {
        self.turn_id = Some(turn_id);
        self
    }

    #[must_use]
    pub fn with_message_id(mut self, message_id: Uuid) -> Self {
        self.message_id = Some(message_id);
        self
    }

    #[must_use]
    pub fn with_tool_call_id(mut self, tool_call_id: impl Into<String>) -> Self {
        self.tool_call_id = Some(tool_call_id.into());
        self
    }

    #[must_use]
    pub fn with_provider(mut self, provider: impl Into<String>) -> Self {
        self.provider = Some(provider.into());
        self
    }

    #[must_use]
    pub fn with_model(mut self, model: impl Into<String>) -> Self {
        self.model = Some(model.into());
        self
    }

    #[must_use]
    pub fn to_metadata(&self) -> Vec<(&'static str, Value)> {
        vec![
            (
                CHAT_SESSION_ID_PREFIX_FIELD,
                json!(ai_diagnostics_uuid_prefix(self.session_id)),
            ),
            (
                TURN_ID_PREFIX_FIELD,
                json!(ai_diagnostics_uuid_prefix(self.turn_id)),
            ),
            (
                MESSAGE_ID_PREFIX_FIELD,
                json!(ai_diagnostics_uuid_prefix(self.message_id)),
            ),
            (
                TOOL_CALL_ID_FIELD,
                json!(self.tool_call_id.as_deref().unwrap_or_default()),
            ),
            (
                PROVIDER_FIELD,
                json!(self.provider.as_deref().unwrap_or_default()),
            ),
            (
                MODEL_FIELD,
                json!(self.model.as_deref().unwrap_or_default()),
            ),
        ]
    }
}

#[must_use]
pub fn ai_diagnostics_uuid_prefix(value: Option<Uuid>) -> String {
    value.map_or_else(String::new, |value| {
        value.to_string().chars().take(8).collect()
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn correlation_metadata_uses_stable_prefix_fields() {
        let session_id =
            Uuid::parse_str("11111111-2222-3333-4444-555555555555").expect("session id");
        let message_id =
            Uuid::parse_str("aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee").expect("message id");

        let metadata = AiDiagnosticsCorrelation::for_session(session_id)
            .with_turn_id(Uuid::parse_str("99999999-2222-3333-4444-555555555555").expect("turn id"))
            .with_message_id(message_id)
            .with_tool_call_id("call_1")
            .with_provider("openai_compatible")
            .with_model("primary")
            .to_metadata();

        assert!(metadata.contains(&(CHAT_SESSION_ID_PREFIX_FIELD, json!("11111111"))));
        assert!(metadata.contains(&(TURN_ID_PREFIX_FIELD, json!("99999999"))));
        assert!(metadata.contains(&(MESSAGE_ID_PREFIX_FIELD, json!("aaaaaaaa"))));
        assert!(metadata.contains(&(TOOL_CALL_ID_FIELD, json!("call_1"))));
        assert!(metadata.contains(&(PROVIDER_FIELD, json!("openai_compatible"))));
        assert!(metadata.contains(&(MODEL_FIELD, json!("primary"))));
    }
}
