import Foundation

// MHBAuthorizationHeaderProvider 认证请求头提供器
// 核心职责：
// - 从本地 TokenStore 读取服务端签发的 access token
// - 为业务请求生成 Authorization Bearer 请求头
struct MHBAuthorizationHeaderProvider {
    private let tokenStore: MHBTokenStore

    init(tokenStore: MHBTokenStore = MHBKeychainTokenStore()) {
        self.tokenStore = tokenStore
    }

    func headers() throws(MHBAPIError) -> [String: String] {
        guard let tokens = try? tokenStore.loadTokens() else {
            let error = MHBAPIError.business(
                code: "auth.session_expired",
                message: "登录状态已过期，请重新登录",
                statusCode: 401
            )
            NotificationCenter.default.post(
                name: .mhbAuthenticationInvalidated,
                object: error.toastMessage
            )
            throw error
        }

        return ["Authorization": "\(tokens.tokenType) \(tokens.accessToken)"]
    }
}
