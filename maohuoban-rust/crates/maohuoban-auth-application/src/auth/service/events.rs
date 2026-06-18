use std::collections::BTreeMap;

use maohuoban_auth_domain::auth::{AuthError, AuthResult};
use uuid::Uuid;

use super::AuthService;
use crate::auth::AuthAuditEvent;

impl AuthService {
    pub(super) async fn record_event(
        &self,
        user_id: Option<Uuid>,
        event_type: &str,
        metadata: impl IntoIterator<Item = (&'static str, String)>,
    ) {
        let metadata = metadata
            .into_iter()
            .map(|(key, value)| (key.to_owned(), value))
            .collect::<BTreeMap<_, _>>();
        let _ = self
            .events
            .record_auth_event(AuthAuditEvent {
                user_id,
                event_type: event_type.to_owned(),
                metadata,
            })
            .await;
    }
}

pub(super) fn normalize_phone(phone: &str) -> AuthResult<String> {
    let phone = phone.trim();
    let is_valid = phone.len() == 11 && phone.chars().all(|item| item.is_ascii_digit());
    if is_valid {
        Ok(phone.to_owned())
    } else {
        Err(AuthError::InvalidPhone)
    }
}

pub(super) fn mask_phone(phone: &str) -> String {
    if phone.len() == 11 {
        format!("{}****{}", &phone[0..3], &phone[7..11])
    } else {
        "<invalid-phone>".to_owned()
    }
}
