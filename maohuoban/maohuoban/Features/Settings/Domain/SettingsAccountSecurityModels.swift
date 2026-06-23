import Foundation

// SettingsAccountSecurityState 账号安全状态
// 核心职责：
// - 承接后端账号安全摘要响应
// - 为设置页提供密码、绑定和认证状态展示数据
struct SettingsAccountSecurityState: Decodable, Equatable {
    let phoneMasked: String
    let hasPassword: Bool
    let passwordStatusText: String
    let passwordUpdatedAt: String?
    let wechatBound: Bool
    let appleBound: Bool
    let realNameStatus: String
    let officialVerificationStatus: String

    enum CodingKeys: String, CodingKey {
        case phoneMasked = "phone_masked"
        case hasPassword = "has_password"
        case passwordStatusText = "password_status_text"
        case passwordUpdatedAt = "password_updated_at"
        case wechatBound = "wechat_bound"
        case appleBound = "apple_bound"
        case realNameStatus = "real_name_status"
        case officialVerificationStatus = "official_verification_status"
    }
}

// SettingsSetPasswordRequest 首次设置登录密码请求
// 核心职责：
// - 提交新密码和确认密码
// - 保持首次设置流程不依赖验证码
struct SettingsSetPasswordRequest: Encodable, Equatable {
    let newPassword: String
    let confirmPassword: String

    enum CodingKeys: String, CodingKey {
        case newPassword = "new_password"
        case confirmPassword = "confirm_password"
    }
}

// SettingsChangePasswordRequest 修改登录密码请求
// 核心职责：
// - 提交当前密码和短信验证码挑战
// - 支持已设置密码后的双验证修改流程
struct SettingsChangePasswordRequest: Encodable, Equatable {
    let currentPassword: String
    let challengeID: String
    let code: String
    let newPassword: String
    let confirmPassword: String

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case challengeID = "challenge_id"
        case code
        case newPassword = "new_password"
        case confirmPassword = "confirm_password"
    }
}
