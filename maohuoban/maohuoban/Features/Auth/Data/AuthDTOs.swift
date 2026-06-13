import Foundation

// AuthDevicePayload 认证设备载荷
// 核心职责：
// - 向后端传递设备会话字段
// - 保持所有登录入口使用同一设备结构
struct AuthDevicePayload: Encodable {
    let deviceID: String
    let deviceName: String
    let platform: String
    let appVersion: String

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case deviceName = "device_name"
        case platform
        case appVersion = "app_version"
    }
}

// SendPhoneCodeRequest 手机验证码请求
// 核心职责：
// - 发起验证码登录 challenge
// - 携带协议同意状态和设备信息
struct SendPhoneCodeRequest: Encodable {
    let phone: String
    let agreementAccepted: Bool
    let device: AuthDevicePayload

    enum CodingKeys: String, CodingKey {
        case phone
        case agreementAccepted = "agreement_accepted"
        case device
    }
}

// VerifyPhoneCodeRequest 验证码登录请求
// 核心职责：
// - 提交 challenge id 与验证码
// - 携带设备信息创建后端 device session
struct VerifyPhoneCodeRequest: Encodable {
    let challengeID: String
    let code: String
    let device: AuthDevicePayload

    enum CodingKeys: String, CodingKey {
        case challengeID = "challenge_id"
        case code
        case device
    }
}

// PasswordLoginRequest 密码登录请求
// 核心职责：
// - 提交手机号和密码
// - 携带设备信息创建后端 device session
struct PasswordLoginRequest: Encodable {
    let phone: String
    let password: String
    let device: AuthDevicePayload
}

// RefreshTokenRequest 刷新登录态请求
// 核心职责：
// - 提交 refresh token
// - 通过 device id 绑定当前设备 session
struct RefreshTokenRequest: Encodable {
    let refreshToken: String
    let deviceID: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
        case deviceID = "device_id"
    }
}

// LogoutRequest 退出登录请求
// 核心职责：
// - 提交 refresh token
// - 撤销当前设备后端 session
struct LogoutRequest: Encodable {
    let refreshToken: String
    let deviceID: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
        case deviceID = "device_id"
    }
}

// SendRecoveryCodeRequest 账号恢复验证码请求
// 核心职责：
// - 请求忘记密码验证码
// - 保留设备信息供后续风控使用
struct SendRecoveryCodeRequest: Encodable {
    let phone: String
    let device: AuthDevicePayload
}

// ResetPasswordRequest 重置密码请求
// 核心职责：
// - 提交账号恢复 challenge、验证码和新密码
// - 完成密码更新和旧 session 撤销
struct ResetPasswordRequest: Encodable {
    let challengeID: String
    let code: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case challengeID = "challenge_id"
        case code
        case newPassword = "new_password"
    }
}

// OAuthLoginRequest 第三方登录占位请求
// 核心职责：
// - 固定第三方登录前端接入形态
// - 方便后续替换为真实微信或 Apple 凭证
struct OAuthLoginRequest: Encodable {
    let identityToken: String
    let nonce: String

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case nonce
    }
}
