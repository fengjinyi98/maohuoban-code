import XCTest
@testable import maohuoban

// AuthViewModelTests 登录状态测试
// 核心职责：
// - 固化冷启动 refresh 的本地凭证处理策略
// - 区分服务不可用和服务端明确失效两类错误
@MainActor
final class AuthViewModelTests: XCTestCase {
    func testBootstrapSessionKeepsStoredTokensWhenBackendIsUnavailable() async {
        let tokens = Self.storedTokens()
        let tokenStore = InMemoryAuthTokenStore(tokens: tokens)
        let repository = CapturingAuthRepository()
        repository.refreshResult = .failure(.transport("connection refused"))
        let viewModel = AuthViewModel(repository: repository, tokenStore: tokenStore)

        await viewModel.bootstrapSession()

        XCTAssertEqual(tokenStore.tokens, tokens)
        XCTAssertFalse(viewModel.isAuthenticated)
        XCTAssertEqual(repository.receivedRefreshToken, "refresh-token")
    }

    func testBootstrapSessionClearsStoredTokensWhenRefreshIsInvalid() async {
        let tokenStore = InMemoryAuthTokenStore(tokens: Self.storedTokens())
        let repository = CapturingAuthRepository()
        repository.refreshResult = .failure(
            .business(code: "auth.refresh_invalid", message: "登录状态已失效，请重新登录", statusCode: 401)
        )
        let viewModel = AuthViewModel(repository: repository, tokenStore: tokenStore)

        await viewModel.bootstrapSession()

        XCTAssertNil(tokenStore.tokens)
        XCTAssertFalse(viewModel.isAuthenticated)
    }

    private static func storedTokens() -> MHBStoredTokens {
        MHBStoredTokens(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            tokenType: "Bearer",
            expiresInSeconds: 900,
            refreshExpiresInSeconds: 15_552_000
        )
    }
}

// InMemoryAuthTokenStore 内存 token 存储
// 核心职责：
// - 支持 AuthViewModel 单元测试读写本地凭证
// - 暴露最终 token 状态用于断言
private final class InMemoryAuthTokenStore: MHBTokenStore {
    var tokens: MHBStoredTokens?

    init(tokens: MHBStoredTokens?) {
        self.tokens = tokens
    }

    func loadTokens() throws -> MHBStoredTokens? {
        tokens
    }

    func saveTokens(_ tokens: MHBStoredTokens) throws {
        self.tokens = tokens
    }

    func clearTokens() throws {
        tokens = nil
    }
}

// CapturingAuthRepository 认证仓库测试替身
// 核心职责：
// - 捕获 refresh token 输入
// - 以预设结果驱动 AuthViewModel 分支
private final class CapturingAuthRepository: AuthRepository {
    var receivedRefreshToken: String?
    var refreshResult: Result<MHBAPIResponse<AuthSession>, MHBAPIError> = .failure(.invalidResponse)

    func sendPhoneCode(phone: String, agreementAccepted: Bool) async throws(MHBAPIError) -> MHBAPIResponse<PhoneCodeChallenge> {
        throw .invalidResponse
    }

    func verifyPhoneCode(challengeID: String, code: String) async throws(MHBAPIError) -> MHBAPIResponse<AuthSession> {
        throw .invalidResponse
    }

    func passwordLogin(phone: String, password: String) async throws(MHBAPIError) -> MHBAPIResponse<AuthSession> {
        throw .invalidResponse
    }

    func refresh(refreshToken: String) async throws(MHBAPIError) -> MHBAPIResponse<AuthSession> {
        receivedRefreshToken = refreshToken
        switch refreshResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func logout(refreshToken: String) async throws(MHBAPIError) -> MHBAPIResponse<MHBEmptyResponse> {
        throw .invalidResponse
    }

    func sendRecoveryCode(phone: String) async throws(MHBAPIError) -> MHBAPIResponse<PhoneCodeChallenge> {
        throw .invalidResponse
    }

    func resetPassword(challengeID: String, code: String, newPassword: String) async throws(MHBAPIError) -> MHBAPIResponse<MHBEmptyResponse> {
        throw .invalidResponse
    }

    func oauth(provider: String) async throws(MHBAPIError) -> MHBAPIResponse<AuthSession> {
        throw .invalidResponse
    }
}
