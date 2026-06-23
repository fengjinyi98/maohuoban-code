use maohuoban_auth_domain::auth::{
    AuthError, AuthResult, AuthSession, DeviceDescriptor, PhoneCodeChallenge,
};

use super::AuthService;
use super::events::{mask_phone, normalize_phone};

impl AuthService {
    pub async fn send_phone_code(
        &self,
        phone: &str,
        agreement_accepted: bool,
    ) -> AuthResult<PhoneCodeChallenge> {
        let phone = normalize_phone(phone)?;
        if !agreement_accepted {
            return Err(AuthError::AgreementRequired);
        }

        let challenge = self
            .otp_store
            .create_login_challenge(
                "login",
                &phone,
                &self.config.development_fixed_code,
                self.config.otp_ttl_seconds,
                self.config.otp_resend_cooldown_seconds,
            )
            .await?;
        self.record_event(
            None,
            "auth.phone_code.sent",
            [("phone", mask_phone(&phone))],
        )
        .await;
        Ok(challenge)
    }

    pub async fn send_account_recovery_code(&self, phone: &str) -> AuthResult<PhoneCodeChallenge> {
        let phone = normalize_phone(phone)?;
        if self.users.find_user_by_phone(&phone).await?.is_none() {
            return Err(AuthError::UserNotFound);
        }

        let challenge = self
            .otp_store
            .create_login_challenge(
                "recovery",
                &phone,
                &self.config.development_fixed_code,
                self.config.otp_ttl_seconds,
                self.config.otp_resend_cooldown_seconds,
            )
            .await?;
        self.record_event(
            None,
            "account_recovery.code.sent",
            [("phone", mask_phone(&phone))],
        )
        .await;
        Ok(challenge)
    }

    pub async fn verify_phone_code(
        &self,
        challenge_id: &str,
        code: &str,
        device: DeviceDescriptor,
    ) -> AuthResult<AuthSession> {
        let phone = self
            .otp_store
            .verify_login_challenge(challenge_id, code)
            .await?;
        let user = self.users.upsert_user_by_phone(&phone).await?;
        self.profiles.ensure_default_profile(&user).await?;
        self.users.update_last_login_at(user.id).await?;
        let session = self.create_login_session(user, device).await?;
        self.record_event(
            Some(session.user.id),
            "auth.phone_code.login_success",
            [("phone", mask_phone(&session.user.phone))],
        )
        .await;
        Ok(session)
    }
}
