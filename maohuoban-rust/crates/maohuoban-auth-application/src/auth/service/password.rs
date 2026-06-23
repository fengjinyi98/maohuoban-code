use maohuoban_auth_domain::auth::{
    AuthError, AuthResult, AuthSession, AuthUser, DeviceDescriptor, PhoneCodeChallenge,
};

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

        self.profiles
            .ensure_default_profile(&credential.user)
            .await?;
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

    pub async fn has_password(&self, user_id: uuid::Uuid) -> AuthResult<bool> {
        self.users.has_password_credential(user_id).await
    }

    pub async fn set_initial_password(
        &self,
        user: &AuthUser,
        new_password: &str,
        confirm_password: &str,
    ) -> AuthResult<()> {
        if self.users.has_password_credential(user.id).await? {
            return Err(AuthError::PasswordAlreadySet);
        }
        validate_new_password(new_password, confirm_password)?;

        let password_hash = self.passwords.hash_password(new_password)?;
        self.users
            .save_password_credential(user.id, &password_hash)
            .await?;
        self.record_event(
            Some(user.id),
            "account.password_set",
            [("phone", mask_phone(&user.phone))],
        )
        .await;
        Ok(())
    }

    pub async fn send_password_change_code(
        &self,
        user: &AuthUser,
    ) -> AuthResult<PhoneCodeChallenge> {
        if !self.users.has_password_credential(user.id).await? {
            return Err(AuthError::PasswordNotSet);
        }

        let challenge = self
            .otp_store
            .create_login_challenge(
                "password_change",
                &user.phone,
                &self.config.development_fixed_code,
                self.config.otp_ttl_seconds,
                self.config.otp_resend_cooldown_seconds,
            )
            .await?;
        self.record_event(
            Some(user.id),
            "account.password_change_code.sent",
            [("phone", mask_phone(&user.phone))],
        )
        .await;
        Ok(challenge)
    }

    pub async fn change_password(
        &self,
        user: &AuthUser,
        current_password: &str,
        challenge_id: &str,
        code: &str,
        new_password: &str,
        confirm_password: &str,
    ) -> AuthResult<()> {
        validate_new_password(new_password, confirm_password)?;
        let credential = self
            .users
            .find_password_credential_by_phone(&user.phone)
            .await?
            .ok_or(AuthError::PasswordNotSet)?;
        let is_current_valid = self
            .passwords
            .verify_password(current_password, &credential.password_hash)?;
        if !is_current_valid {
            return Err(AuthError::CurrentPasswordInvalid);
        }

        let verified_phone = self
            .otp_store
            .verify_login_challenge(challenge_id, code)
            .await?;
        if verified_phone != user.phone {
            return Err(AuthError::InvalidCode);
        }

        let password_hash = self.passwords.hash_password(new_password)?;
        self.users
            .save_password_credential(user.id, &password_hash)
            .await?;
        self.record_event(
            Some(user.id),
            "account.password_changed",
            [("phone", mask_phone(&user.phone))],
        )
        .await;
        Ok(())
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

fn validate_new_password(new_password: &str, confirm_password: &str) -> AuthResult<()> {
    if new_password != confirm_password {
        return Err(AuthError::PasswordMismatch);
    }
    if !(8..=20).contains(&new_password.chars().count()) {
        return Err(AuthError::PasswordWeak);
    }

    let has_letter = new_password
        .chars()
        .any(|character| character.is_ascii_alphabetic());
    let has_number = new_password
        .chars()
        .any(|character| character.is_ascii_digit());
    let has_symbol = new_password
        .chars()
        .any(|character| !character.is_ascii_alphanumeric());
    let category_count = [has_letter, has_number, has_symbol]
        .into_iter()
        .filter(|matched| *matched)
        .count();
    if category_count < 2 {
        return Err(AuthError::PasswordWeak);
    }

    Ok(())
}
