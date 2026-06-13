import Foundation

// AuthMode 登录模式
// 核心职责：
// - 区分验证码登录与密码登录
// - 控制登录页表单字段和提交行为
enum AuthMode: Equatable {
    case phoneCode
    case password
}

// AuthStep 登录流程步骤
// 核心职责：
// - 表达登录、验证码、忘记密码三类界面状态
// - 支持 AuthRootView 根据状态切换页面
enum AuthStep: Equatable {
    case login
    case verification
    case recovery
}

// AuthUser 当前登录用户
// 核心职责：
// - 保存后端返回的最小身份信息
// - 作为 App 登录态判断的用户上下文
struct AuthUser: Decodable, Equatable {
    let id: String
    let phone: String
}

// AuthSession 登录会话
// 核心职责：
// - 承载后端返回的用户和 token
// - 转换为 Keychain 可存储凭证
struct AuthSession: Decodable, Equatable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresInSeconds: Int
    let refreshExpiresInSeconds: Int
    let user: AuthUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresInSeconds = "expires_in_seconds"
        case refreshExpiresInSeconds = "refresh_expires_in_seconds"
        case user
    }

    var storedTokens: MHBStoredTokens {
        MHBStoredTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: tokenType,
            expiresInSeconds: expiresInSeconds,
            refreshExpiresInSeconds: refreshExpiresInSeconds
        )
    }
}

// PhoneCodeChallenge 验证码挑战
// 核心职责：
// - 保存后端返回的 challenge id
// - 支持验证码页后续提交校验
struct PhoneCodeChallenge: Decodable, Equatable {
    let challengeID: String
    let expiresInSeconds: Int
    let resendAfterSeconds: Int

    enum CodingKeys: String, CodingKey {
        case challengeID = "challenge_id"
        case expiresInSeconds = "expires_in_seconds"
        case resendAfterSeconds = "resend_after_seconds"
    }
}
