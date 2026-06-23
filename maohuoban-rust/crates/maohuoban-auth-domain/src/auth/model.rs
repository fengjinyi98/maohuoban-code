use std::fmt;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// DeviceDescriptor 客户端设备描述
/// 核心职责：
/// - 表达一次登录绑定的设备维度
/// - 为后续多设备管理、踢下线、可信设备扩展提供统一输入
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceDescriptor {
    pub device_id: String,
    pub device_name: String,
    pub platform: String,
    pub app_version: String,
}

/// AuthUser 已认证用户视图
/// 核心职责：
/// - 承载登录接口需要返回的最小用户身份
/// - 隐藏凭证、设备会话等敏感持久化细节
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthUser {
    pub id: Uuid,
    pub phone: String,
}

/// PhoneCodeChallenge 手机验证码挑战
/// 核心职责：
/// - 表达验证码发送后的短期挑战标识
/// - 约束客户端只通过 challenge id 完成后续校验
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PhoneCodeChallenge {
    pub challenge_id: String,
    pub expires_in_seconds: i64,
    pub resend_after_seconds: i64,
}

/// TokenPair 双 token 响应
/// 核心职责：
/// - 表达短期 access token 与长期 refresh token
/// - 暴露客户端刷新所需的时效信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TokenPair {
    pub access_token: String,
    pub refresh_token: String,
    pub token_type: String,
    pub expires_in_seconds: i64,
    pub refresh_expires_in_seconds: i64,
}

/// AuthSession 登录成功会话
/// 核心职责：
/// - 组合用户视图与 token 响应
/// - 作为登录、刷新接口的统一成功输出
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthSession {
    pub user: AuthUser,
    pub tokens: TokenPair,
}

/// AccessTokenSubject access token 认证主体
/// 核心职责：
/// - 承载 access token 中可验证的账号与设备会话标识
/// - 为业务接口建立服务端可信用户上下文
#[derive(Debug, Clone)]
pub struct AccessTokenSubject {
    pub user_id: Uuid,
    pub session_id: Uuid,
}

/// AuthenticatedSession 已认证访问上下文
/// 核心职责：
/// - 组合当前用户和 access token 对应设备会话
/// - 支持账号安全接口判断当前设备边界
#[derive(Debug, Clone)]
pub struct AuthenticatedSession {
    pub user: AuthUser,
    pub session_id: Uuid,
}

/// RefreshSession 服务端 refresh 会话
/// 核心职责：
/// - 承载 refresh token 命中后的设备会话状态
/// - 为 token 轮换和重放检测提供最小上下文
#[derive(Debug, Clone)]
pub struct RefreshSession {
    pub session_id: Uuid,
    pub user: AuthUser,
    pub device_id: String,
}

/// RefreshTokenResolution refresh token 解析结果
/// 核心职责：
/// - 区分有效 token、旧 token 重放和未命中三类状态
/// - 让应用层用统一分支处理安全事件
#[derive(Debug, Clone)]
pub enum RefreshTokenResolution {
    Active(RefreshSession),
    Reused(RefreshSession),
    Missing,
}

/// AccountDeviceSession 账号设备会话读模型
/// 核心职责：
/// - 承载登录设备管理列表和详情所需字段
/// - 隐藏 refresh token hash 等敏感持久化信息
#[derive(Debug, Clone)]
pub struct AccountDeviceSession {
    pub session_id: Uuid,
    pub user_id: Uuid,
    pub device_id: String,
    pub device_name: String,
    pub platform: String,
    pub app_version: String,
    pub created_at: DateTime<Utc>,
    pub last_seen_at: DateTime<Utc>,
    pub expires_at: DateTime<Utc>,
}

/// OAuthProvider 第三方登录提供方
/// 核心职责：
/// - 固定当前支持和预留的第三方登录枚举
/// - 为接口层输出稳定 TODO 文案提供来源
#[derive(Debug, Clone, Copy)]
pub enum OAuthProvider {
    Apple,
    Wechat,
}

impl OAuthProvider {
    #[must_use]
    pub const fn label(self) -> &'static str {
        match self {
            Self::Apple => "Apple",
            Self::Wechat => "微信",
        }
    }
}

impl fmt::Display for OAuthProvider {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(self.label())
    }
}
