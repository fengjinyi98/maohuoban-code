import Foundation

// MHBAuthorizationHeaderProvider 认证请求头提供器
// 核心职责：
// - 从本地 TokenStore 读取服务端签发的 access token
// - 为业务请求生成 Authorization Bearer 请求头
struct MHBAuthorizationHeaderProvider {
    private let tokenStore: MHBTokenStore
    private let refreshCoordinator: MHBTokenRefreshCoordinator?
    private let refreshService: MHBTokenRefreshService?

    init(
        tokenStore: MHBTokenStore = MHBKeychainTokenStore(),
        refreshCoordinator: MHBTokenRefreshCoordinator? = nil,
        refreshService: MHBTokenRefreshService? = nil
    ) {
        self.tokenStore = tokenStore
        self.refreshCoordinator = refreshCoordinator
        self.refreshService = refreshService
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

    // refreshAuthorizationHeaders 刷新并生成认证请求头
    // 核心职责：
    // - 通过单飞协调器合并并发 refresh
    // - 使用刷新后的 access token 生成 Authorization header
    func refreshAuthorizationHeaders() async throws(MHBAPIError) -> [String: String] {
        guard let tokens = try? tokenStore.loadTokens(),
              let refreshCoordinator,
              let refreshService else {
            throw MHBAPIError.business(
                code: "auth.session_expired",
                message: "登录状态已过期，请重新登录",
                statusCode: 401
            )
        }
        let refreshedTokens = try await refreshCoordinator.refresh(
            currentTokens: tokens,
            tokenStore: tokenStore,
            service: refreshService
        )
        return ["Authorization": "\(refreshedTokens.tokenType) \(refreshedTokens.accessToken)"]
    }
}
