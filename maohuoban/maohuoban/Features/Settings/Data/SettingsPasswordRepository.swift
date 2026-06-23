import Foundation

// SettingsPasswordRepository 登录密码仓储协议
// 核心职责：
// - 定义设置页账号安全和登录密码接口
// - 隔离 HTTP 客户端、TokenStore 与展示层状态
protocol SettingsPasswordRepository {
    func loadSecurity() async throws(MHBAPIError) -> MHBAPIResponse<SettingsAccountSecurityState>

    func setInitialPassword(
        newPassword: String,
        confirmPassword: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<SettingsAccountSecurityState>

    func sendPasswordChangeCode() async throws(MHBAPIError) -> MHBAPIResponse<PhoneCodeChallenge>

    func changePassword(
        currentPassword: String,
        challengeID: String,
        code: String,
        newPassword: String,
        confirmPassword: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<SettingsAccountSecurityState>
}

// DefaultSettingsPasswordRepository 默认登录密码仓储
// 核心职责：
// - 使用 MHBHTTPClient 调用 Rust 账号安全接口
// - 统一附加 Authorization Bearer 请求头
struct DefaultSettingsPasswordRepository: SettingsPasswordRepository {
    let client: MHBHTTPClient
    let authorizationHeaderProvider: MHBAuthorizationHeaderProvider

    init(
        client: MHBHTTPClient = MHBHTTPClient(),
        authorizationHeaderProvider: MHBAuthorizationHeaderProvider = MHBAuthorizationHeaderProvider()
    ) {
        self.client = client
        self.authorizationHeaderProvider = authorizationHeaderProvider
    }

    func loadSecurity() async throws(MHBAPIError) -> MHBAPIResponse<SettingsAccountSecurityState> {
        try await client.get(
            path: "/api/v1/account/security",
            headers: try authorizationHeaderProvider.headers()
        )
    }

    func setInitialPassword(
        newPassword: String,
        confirmPassword: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<SettingsAccountSecurityState> {
        try await client.post(
            path: "/api/v1/account/password",
            body: SettingsSetPasswordRequest(
                newPassword: newPassword,
                confirmPassword: confirmPassword
            ),
            headers: try authorizationHeaderProvider.headers()
        )
    }

    func sendPasswordChangeCode() async throws(MHBAPIError) -> MHBAPIResponse<PhoneCodeChallenge> {
        try await client.post(
            path: "/api/v1/account/password/change-code",
            body: SettingsPasswordEmptyRequest(),
            headers: try authorizationHeaderProvider.headers()
        )
    }

    func changePassword(
        currentPassword: String,
        challengeID: String,
        code: String,
        newPassword: String,
        confirmPassword: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<SettingsAccountSecurityState> {
        try await client.patch(
            path: "/api/v1/account/password",
            body: SettingsChangePasswordRequest(
                currentPassword: currentPassword,
                challengeID: challengeID,
                code: code,
                newPassword: newPassword,
                confirmPassword: confirmPassword
            ),
            headers: try authorizationHeaderProvider.headers()
        )
    }
}

// SettingsPasswordEmptyRequest 空请求体
// 核心职责：
// - 复用 JSON POST 发送路径
// - 承接只依赖授权头的账号安全命令
private struct SettingsPasswordEmptyRequest: Encodable {}
