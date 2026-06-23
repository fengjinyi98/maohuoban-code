use uuid::Uuid;

use super::AuthService;
use maohuoban_auth_domain::auth::{AccountDeviceSession, AuthError, AuthResult};

impl AuthService {
    pub async fn list_account_devices(
        &self,
        user_id: Uuid,
    ) -> AuthResult<Vec<AccountDeviceSession>> {
        self.sessions.list_active_device_sessions(user_id).await
    }

    pub async fn load_account_device(
        &self,
        user_id: Uuid,
        session_id: Uuid,
    ) -> AuthResult<AccountDeviceSession> {
        self.sessions
            .find_active_device_session(user_id, session_id)
            .await?
            .ok_or(AuthError::DeviceNotFound)
    }

    pub async fn revoke_account_device(
        &self,
        user_id: Uuid,
        current_session_id: Uuid,
        target_session_id: Uuid,
    ) -> AuthResult<()> {
        if current_session_id == target_session_id {
            return Err(AuthError::CurrentDeviceRemoveForbidden);
        }

        let revoked = self
            .sessions
            .revoke_device_session(user_id, target_session_id)
            .await?;
        if !revoked {
            return Err(AuthError::DeviceNotFound);
        }

        self.record_event(
            Some(user_id),
            "account.device_revoked",
            [("session_id", target_session_id.to_string())],
        )
        .await;
        Ok(())
    }
}
