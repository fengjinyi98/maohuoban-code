use maohuoban_auth_application::auth::AuthAuditEvent;
use maohuoban_auth_domain::auth::AuthResult;
use maohuoban_diagnostics::{DiagnosticEvent, Diagnostics, EventKind, Severity};
use serde_json::{Map, Value, json};
use uuid::Uuid;

use super::PostgresAuthRepository;
use super::to_infrastructure_error;

impl PostgresAuthRepository {
    pub(super) async fn record_auth_event_command(&self, event: AuthAuditEvent) -> AuthResult<()> {
        let metadata = event
            .metadata
            .iter()
            .map(|(key, value)| (key.clone(), Value::String(value.clone())))
            .collect::<Map<_, _>>();
        let metadata_value = Value::Object(metadata.clone());

        sqlx::query(
            r#"
            INSERT INTO auth_audit_events (id, user_id, event_type, metadata)
            VALUES ($1, $2, $3, $4)
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(event.user_id)
        .bind(&event.event_type)
        .bind(&metadata_value)
        .execute(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        if let Some(diagnostics) = Diagnostics::current() {
            let mut diagnostic_event =
                DiagnosticEvent::new(EventKind::Identity, Severity::Info, event.event_type);
            if let Some(user_id) = event.user_id {
                diagnostic_event = diagnostic_event.metadata("user_id", json!(user_id));
            }
            for (key, value) in metadata {
                diagnostic_event = diagnostic_event.metadata(key, value);
            }
            diagnostics.record(diagnostic_event);
        }

        Ok(())
    }
}
