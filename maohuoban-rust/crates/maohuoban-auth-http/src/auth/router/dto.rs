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
