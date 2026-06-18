use maohuoban_auth_domain::auth::{AuthError, AuthResult, AuthSession, DeviceDescriptor};

use super::AuthService;
use super::events::{mask_phone, normalize_phone};

impl AuthService {
    pub async fn password_login(
        &self,
        phone: &str,
        password: &str,
        device: DeviceDescriptor,
    ) -> AuthResult<AuthSession> {
        let phone = normalize_phone(phone)?;
        let credential = self
            .users
            .find_password_credential_by_phone(&phone)
            .await?
            .ok_or(AuthError::InvalidCredentials)?;

        let is_valid = self
            .passwords
            .verify_password(password, &credential.password_hash)?;
        if !is_valid {
            self.record_event(
                Some(credential.user.id),
                "auth.password.login_failed",
                [("phone", mask_phone(&phone))],
            )
            .await;
            return Err(AuthError::InvalidCredentials);
        }

        self.users.update_last_login_at(credential.user.id).await?;
        let session = self.create_login_session(credential.user, device).await?;
        self.record_event(
            Some(session.user.id),
            "auth.password.login_success",
            [("phone", mask_phone(&session.user.phone))],
        )
        .await;
        Ok(session)
    }

    pub async fn reset_password(
        &self,
        challenge_id: &str,
        code: &str,
        new_password: &str,
    ) -> AuthResult<()> {
        let phone = self
            .otp_store
            .verify_login_challenge(challenge_id, code)
            .await?;
        let user = self
            .users
            .find_user_by_phone(&phone)
            .await?
            .ok_or(AuthError::UserNotFound)?;
        let password_hash = self.passwords.hash_password(new_password)?;
        self.users
            .save_password_credential(user.id, &password_hash)
            .await?;
        self.sessions.revoke_user_sessions(user.id).await?;
        self.record_event(
            Some(user.id),
            "account_recovery.password_reset",
            [("phone", mask_phone(&phone))],
        )
        .await;
        Ok(())
    }
}
