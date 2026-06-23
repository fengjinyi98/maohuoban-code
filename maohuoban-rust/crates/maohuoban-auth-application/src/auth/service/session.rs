use chrono::{Duration, Utc};
use maohuoban_auth_domain::auth::{
    AuthError, AuthResult, AuthSession, AuthUser, AuthenticatedSession, DeviceDescriptor,
    OAuthProvider, RefreshTokenResolution, TokenPair,
};
use uuid::Uuid;

use super::AuthService;
use crate::auth::NewDeviceSession;

impl AuthService {
    pub async fn refresh(&self, refresh_token: &str, device_id: &str) -> AuthResult<AuthSession> {
        let refresh_token_hash = self.tokens.hash_refresh_token(refresh_token);
        match self
            .sessions
            .resolve_refresh_token(&refresh_token_hash, device_id)
            .await?
        {
            RefreshTokenResolution::Active(session) => {
                let new_refresh_token = self.tokens.generate_refresh_token()?;
                let new_refresh_token_hash = self.tokens.hash_refresh_token(&new_refresh_token);
                let refresh_expires_at =
                    Utc::now() + Duration::seconds(self.tokens.refresh_token_ttl_seconds());
                self.sessions
                    .rotate_refresh_token(
                        session.session_id,
                        &refresh_token_hash,
                        &new_refresh_token_hash,
                        refresh_expires_at,
                    )
                    .await?;
                let access_token = self
                    .tokens
                    .issue_access_token(&session.user, session.session_id)?;
                let auth_session = AuthSession {
                    user: session.user,
                    tokens: TokenPair {
                        access_token,
                        refresh_token: new_refresh_token,
                        token_type: "Bearer".to_owned(),
                        expires_in_seconds: self.tokens.access_token_ttl_seconds(),
                        refresh_expires_in_seconds: self.tokens.refresh_token_ttl_seconds(),
                    },
                };
                self.record_event(
                    Some(auth_session.user.id),
                    "auth.refresh.rotated",
                    [("device_id", session.device_id)],
                )
                .await;
                Ok(auth_session)
            }
            RefreshTokenResolution::Reused(session) => {
                self.sessions.revoke_session(session.session_id).await?;
                self.record_event(
                    Some(session.user.id),
                    "auth.refresh.reused",
                    [("device_id", session.device_id)],
                )
                .await;
                Err(AuthError::RefreshReused)
            }
            RefreshTokenResolution::Missing => Err(AuthError::RefreshInvalid),
        }
    }

    pub async fn authenticate_access_token(&self, access_token: &str) -> AuthResult<AuthUser> {
        Ok(self
            .authenticate_access_token_context(access_token)
            .await?
            .user)
    }

    pub async fn authenticate_access_token_context(
        &self,
        access_token: &str,
    ) -> AuthResult<AuthenticatedSession> {
        let subject = self.tokens.verify_access_token(access_token)?;
        let session = self
            .sessions
            .find_active_session(subject.user_id, subject.session_id)
            .await?
            .ok_or(AuthError::SessionInvalid)?;
        let user = self
            .users
            .find_active_user_by_id(subject.user_id)
            .await?
            .ok_or(AuthError::AccessInvalid)?;
        if user.id != session.user.id {
            return Err(AuthError::AccessInvalid);
        }
        Ok(AuthenticatedSession {
            user,
            session_id: session.session_id,
        })
    }

    pub async fn logout(&self, refresh_token: &str, device_id: &str) -> AuthResult<()> {
        let refresh_token_hash = self.tokens.hash_refresh_token(refresh_token);
        match self
            .sessions
            .resolve_refresh_token(&refresh_token_hash, device_id)
            .await?
        {
            RefreshTokenResolution::Active(session) | RefreshTokenResolution::Reused(session) => {
                self.sessions.revoke_session(session.session_id).await?;
                self.record_event(
                    Some(session.user.id),
                    "auth.logout.success",
                    [("device_id", session.device_id)],
                )
                .await;
                Ok(())
            }
            RefreshTokenResolution::Missing => Err(AuthError::RefreshInvalid),
        }
    }

    pub fn oauth_login(&self, provider: OAuthProvider) -> AuthResult<AuthSession> {
        Err(AuthError::OAuthTodo(provider))
    }

    pub(super) async fn create_login_session(
        &self,
        user: AuthUser,
        device: DeviceDescriptor,
    ) -> AuthResult<AuthSession> {
        let session_id = Uuid::new_v4();
        let refresh_token = self.tokens.generate_refresh_token()?;
        let refresh_token_hash = self.tokens.hash_refresh_token(&refresh_token);
        let refresh_expires_at =
            Utc::now() + Duration::seconds(self.tokens.refresh_token_ttl_seconds());
        self.sessions
            .create_device_session(NewDeviceSession {
                session_id,
                user_id: user.id,
                device,
                refresh_token_hash,
                expires_at: refresh_expires_at,
            })
            .await?;
        let access_token = self.tokens.issue_access_token(&user, session_id)?;
        Ok(AuthSession {
            user,
            tokens: TokenPair {
                access_token,
                refresh_token,
                token_type: "Bearer".to_owned(),
                expires_in_seconds: self.tokens.access_token_ttl_seconds(),
                refresh_expires_in_seconds: self.tokens.refresh_token_ttl_seconds(),
            },
        })
    }
}
