use maohuoban_auth_domain::auth::DeviceDescriptor;
use serde::Deserialize;

/// SendPhoneCodeRequest 发送验证码请求
/// 核心职责：
/// - 接收手机号和协议确认状态
/// - 保留 device 字段以兼容设计稿和后续风控
#[derive(Debug, Deserialize)]
pub(super) struct SendPhoneCodeRequest {
    pub(super) phone: String,
    pub(super) agreement_accepted: bool,
    #[allow(dead_code)]
    pub(super) device: DevicePayload,
}

/// VerifyPhoneCodeRequest 验证码登录请求
/// 核心职责：
/// - 接收 challenge、验证码和设备信息
/// - 将 HTTP DTO 转换为应用层输入
#[derive(Debug, Deserialize)]
pub(super) struct VerifyPhoneCodeRequest {
    pub(super) challenge_id: String,
    pub(super) code: String,
    pub(super) device: DevicePayload,
}

/// PasswordLoginRequest 密码登录请求
/// 核心职责：
/// - 接收手机号、密码和设备信息
/// - 支持后续密码登录 UI 直接接入
#[derive(Debug, Deserialize)]
pub(super) struct PasswordLoginRequest {
    pub(super) phone: String,
    pub(super) password: String,
    pub(super) device: DevicePayload,
}

/// SetAccountPasswordRequest 首次设置登录密码请求
/// 核心职责：
/// - 接收新密码和确认密码
/// - 保持首次设置不依赖验证码和旧密码
#[derive(Debug, Deserialize)]
pub(super) struct SetAccountPasswordRequest {
    pub(super) new_password: String,
    pub(super) confirm_password: String,
}

/// ChangeAccountPasswordRequest 修改登录密码请求
/// 核心职责：
/// - 接收旧密码、新密码和短信验证码
/// - 支持账号安全页的双验证修改流程
#[derive(Debug, Deserialize)]
pub(super) struct ChangeAccountPasswordRequest {
    pub(super) current_password: String,
    pub(super) challenge_id: String,
    pub(super) code: String,
    pub(super) new_password: String,
    pub(super) confirm_password: String,
}

/// RefreshTokenRequest 刷新 token 请求
/// 核心职责：
/// - 接收 refresh token 和设备 id
/// - 支持设备维度 session 轮换
#[derive(Debug, Deserialize)]
pub(super) struct RefreshTokenRequest {
    pub(super) refresh_token: String,
    pub(super) device_id: String,
}

/// LogoutRequest 退出登录请求
/// 核心职责：
/// - 接收当前设备 refresh token
/// - 支持服务端撤销当前设备 session
#[derive(Debug, Deserialize)]
pub(super) struct LogoutRequest {
    pub(super) refresh_token: String,
    pub(super) device_id: String,
}

/// SendRecoveryCodeRequest 账号恢复验证码请求
/// 核心职责：
/// - 接收账号恢复手机号
/// - 保留设备字段供后续风控扩展
#[derive(Debug, Deserialize)]
pub(super) struct SendRecoveryCodeRequest {
    pub(super) phone: String,
    #[allow(dead_code)]
    pub(super) device: DevicePayload,
}

/// ResetPasswordRequest 重置密码请求
/// 核心职责：
/// - 接收验证码 challenge 和新密码
/// - 将账号恢复流程保持在独立接口边界
#[derive(Debug, Deserialize)]
pub(super) struct ResetPasswordRequest {
    pub(super) challenge_id: String,
    pub(super) code: String,
    pub(super) new_password: String,
}

/// DevicePayload 设备请求载荷
/// 核心职责：
/// - 表达客户端设备字段
/// - 转换为领域层设备描述
#[derive(Debug, Deserialize)]
pub(super) struct DevicePayload {
    device_id: String,
    device_name: String,
    platform: String,
    app_version: String,
}

impl DevicePayload {
    pub(super) fn into_device_descriptor(self) -> DeviceDescriptor {
        DeviceDescriptor {
            device_id: self.device_id,
            device_name: self.device_name,
            platform: self.platform,
            app_version: self.app_version,
        }
    }
}

use maohuoban_auth_domain::auth::{
    AccountDeviceSession, AuthSession, AuthUser, PhoneCodeChallenge,
};
use maohuoban_profile_domain::profile::{AvatarPresentation, UserProfile};
use serde::Serialize;
use serde_json::Value;

/// PhoneCodeChallengeData 验证码响应数据
/// 核心职责：
/// - 向客户端返回 challenge id
/// - 暴露验证码有效期
#[derive(Debug, Serialize)]
pub(super) struct PhoneCodeChallengeData {
    challenge_id: String,
    expires_in_seconds: i64,
    resend_after_seconds: i64,
}

impl From<PhoneCodeChallenge> for PhoneCodeChallengeData {
    fn from(challenge: PhoneCodeChallenge) -> Self {
        Self {
            challenge_id: challenge.challenge_id,
            expires_in_seconds: challenge.expires_in_seconds,
            resend_after_seconds: challenge.resend_after_seconds,
        }
    }
}

/// AccountSecurityData 账号安全摘要响应
/// 核心职责：
/// - 返回设置页账号安全入口需要的密码状态
/// - 以后端 password credentials 事实源派生展示文案
#[derive(Debug, Serialize)]
pub(super) struct AccountSecurityData {
    phone_masked: String,
    has_password: bool,
    password_status_text: &'static str,
    password_updated_at: Option<String>,
    wechat_bound: bool,
    apple_bound: bool,
    real_name_status: &'static str,
    official_verification_status: &'static str,
}

impl AccountSecurityData {
    pub(super) fn from_user(user: &AuthUser, has_password: bool) -> Self {
        Self {
            phone_masked: mask_phone(&user.phone),
            has_password,
            password_status_text: if has_password {
                "已设置"
            } else {
                "未设置"
            },
            password_updated_at: None,
            wechat_bound: false,
            apple_bound: false,
            real_name_status: "unverified",
            official_verification_status: "unverified",
        }
    }
}

/// AccountDevicesData 登录设备列表响应
/// 核心职责：
/// - 包装当前账号有效登录设备
/// - 标记 access token 对应的当前设备
#[derive(Debug, Serialize)]
pub(super) struct AccountDevicesData {
    devices: Vec<AccountDeviceSummaryData>,
}

impl AccountDevicesData {
    pub(super) fn from_sessions(
        sessions: Vec<AccountDeviceSession>,
        current_session_id: uuid::Uuid,
    ) -> Self {
        Self {
            devices: sessions
                .into_iter()
                .map(|session| AccountDeviceSummaryData::from_session(session, current_session_id))
                .collect(),
        }
    }
}

/// AccountDeviceSummaryData 登录设备摘要响应
/// 核心职责：
/// - 返回设备列表所需展示字段
/// - 避免暴露 refresh token hash 等敏感字段
#[derive(Debug, Serialize)]
pub(super) struct AccountDeviceSummaryData {
    session_id: String,
    device_id: String,
    device_name: String,
    device_model: String,
    platform: String,
    location_text: String,
    last_active_text: String,
    is_current_device: bool,
}

impl AccountDeviceSummaryData {
    fn from_session(session: AccountDeviceSession, current_session_id: uuid::Uuid) -> Self {
        let is_current_device = session.session_id == current_session_id;
        Self {
            session_id: session.session_id.to_string(),
            device_id: session.device_id,
            device_name: session.device_name.clone(),
            device_model: device_model(&session.device_name, &session.platform).to_owned(),
            platform: session.platform,
            location_text: "未知地区".to_owned(),
            last_active_text: if is_current_device {
                "当前在线".to_owned()
            } else {
                session.last_seen_at.to_rfc3339()
            },
            is_current_device,
        }
    }
}

/// AccountDeviceDetailData 登录设备详情响应
/// 核心职责：
/// - 返回单个设备会话详情
/// - 标记当前设备并保留后续 IP/地区扩展位置
#[derive(Debug, Serialize)]
pub(super) struct AccountDeviceDetailData {
    session_id: String,
    device_id: String,
    device_name: String,
    device_model: String,
    platform: String,
    os_version: String,
    app_version: String,
    location_text: String,
    ip_address: String,
    first_login_text: String,
    last_active_text: String,
    is_current_device: bool,
}

impl AccountDeviceDetailData {
    pub(super) fn from_session(
        session: AccountDeviceSession,
        current_session_id: uuid::Uuid,
    ) -> Self {
        let is_current_device = session.session_id == current_session_id;
        Self {
            session_id: session.session_id.to_string(),
            device_id: session.device_id,
            device_name: session.device_name.clone(),
            device_model: device_model(&session.device_name, &session.platform).to_owned(),
            platform: session.platform.clone(),
            os_version: session.platform,
            app_version: session.app_version,
            location_text: "未知地区".to_owned(),
            ip_address: "未知".to_owned(),
            first_login_text: session.created_at.to_rfc3339(),
            last_active_text: if is_current_device {
                "当前在线".to_owned()
            } else {
                session.last_seen_at.to_rfc3339()
            },
            is_current_device,
        }
    }
}

fn device_model(device_name: &str, platform: &str) -> &'static str {
    let device_name = device_name.to_lowercase();
    let platform = platform.to_lowercase();
    if device_name.contains("ipad") || platform.contains("ipad") {
        "iPad"
    } else if device_name.contains("mac") || platform.contains("mac") {
        "Mac"
    } else {
        "iPhone"
    }
}

/// LoginData 登录响应数据
/// 核心职责：
/// - 扁平化 token 字段以匹配客户端契约
/// - 返回当前账号安全摘要和用户资料摘要
#[derive(Debug, Serialize)]
pub(super) struct LoginData {
    access_token: String,
    refresh_token: String,
    token_type: String,
    expires_in_seconds: i64,
    refresh_expires_in_seconds: i64,
    user: UserData,
}

impl LoginData {
    pub(super) fn from_session(
        session: AuthSession,
        profile: UserProfile,
        has_password: bool,
    ) -> Self {
        Self {
            access_token: session.tokens.access_token,
            refresh_token: session.tokens.refresh_token,
            token_type: session.tokens.token_type,
            expires_in_seconds: session.tokens.expires_in_seconds,
            refresh_expires_in_seconds: session.tokens.refresh_expires_in_seconds,
            user: UserData {
                id: session.user.id.to_string(),
                phone_masked: mask_phone(&session.user.phone),
                phone: session.user.phone,
                has_password,
                profile: UserProfileSummaryData::from(profile),
            },
        }
    }
}

/// UserData 登录用户响应
/// 核心职责：
/// - 返回客户端首屏需要的身份字段
/// - 隔离领域用户模型和 HTTP JSON 结构
#[derive(Debug, Serialize)]
struct UserData {
    id: String,
    phone: String,
    phone_masked: String,
    has_password: bool,
    profile: UserProfileSummaryData,
}

/// UserProfileSummaryData 登录用户资料摘要
/// 核心职责：
/// - 提供我的页首屏可缓存的用户资料字段
/// - 保持勋章、注册序号等非本阶段字段不进入登录响应
#[derive(Debug, Serialize)]
struct UserProfileSummaryData {
    maohuoban_id: String,
    display_name: String,
    avatar: Option<Value>,
    avatar_presentation: AvatarPresentation,
}

impl From<UserProfile> for UserProfileSummaryData {
    fn from(profile: UserProfile) -> Self {
        let avatar_presentation = profile.avatar_presentation();
        let avatar = profile
            .avatar
            .as_ref()
            .map(|media| Value::String(media.url.clone()));
        Self {
            maohuoban_id: profile.maohuoban_id,
            display_name: profile.display_name,
            avatar,
            avatar_presentation,
        }
    }
}

/// EmptyData 空响应数据
/// 核心职责：
/// - 统一无业务数据接口的 JSON data 形态
/// - 避免客户端对成功响应做特殊分支
#[derive(Debug, Serialize)]
pub(super) struct EmptyData {}

fn mask_phone(phone: &str) -> String {
    let chars: Vec<char> = phone.chars().collect();
    if chars.len() != 11 {
        return phone.to_owned();
    }

    let prefix: String = chars.iter().take(3).collect();
    let suffix: String = chars.iter().skip(7).collect();
    format!("{prefix}****{suffix}")
}
