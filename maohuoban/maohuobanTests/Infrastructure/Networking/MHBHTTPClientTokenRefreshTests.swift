import XCTest
@testable import maohuoban

@MainActor
extension MHBHTTPClientRequestInfrastructureTests {
    func testUnauthorizedResponseRefreshesTokenAndReplaysRequestWithFreshAuthorizationHeader() async throws {
        let requestStore = MHBRecordedRequestStore()
        let tokenStore = MHBInMemoryTokenStore()
        try tokenStore.saveTokens(
            MHBStoredTokens(
                accessToken: "expired",
                refreshToken: "refresh-1",
                tokenType: "Bearer",
                expiresInSeconds: 0,
                refreshExpiresInSeconds: 3600
            )
        )
        let refreshService = MHBCountingTokenRefreshService()
        let client = makeAuthenticatedClient(
            tokenStore: tokenStore,
            refreshService: refreshService
        ) { request in
            requestStore.record(request)
            switch request.value(forHTTPHeaderField: MHBHTTPHeader.authorization) {
            case "Bearer expired":
                return Self.unauthorizedExpiredTokenResponse()
            case "Bearer fresh-token":
                return Self.successResponse()
            default:
                throw MHBHTTPClientTestError.unexpectedRequest
            }
        }

        let response: MHBAPIResponse<MHBEmptyResponse> = try await client.get(path: "/api/v1/profile/me")

        XCTAssertTrue(response.success)
        XCTAssertEqual(refreshService.callCount, 1)
        XCTAssertEqual(try tokenStore.loadTokens()?.accessToken, "fresh-token")
        XCTAssertEqual(
            requestStore.requests.map { $0.value(forHTTPHeaderField: MHBHTTPHeader.authorization) },
            ["Bearer expired", "Bearer fresh-token"]
        )
    }

    func testConcurrentUnauthorizedResponsesShareSingleRefreshAndReplayWithFreshAuthorizationHeader() async throws {
        let requestStore = MHBRecordedRequestStore()
        let tokenStore = MHBInMemoryTokenStore()
        try tokenStore.saveTokens(
            MHBStoredTokens(
                accessToken: "expired",
                refreshToken: "refresh-1",
                tokenType: "Bearer",
                expiresInSeconds: 0,
                refreshExpiresInSeconds: 3600
            )
        )
        let refreshService = MHBCountingTokenRefreshService()
        let client = makeAuthenticatedClient(
            tokenStore: tokenStore,
            refreshService: refreshService
        ) { request in
            requestStore.record(request)
            switch request.value(forHTTPHeaderField: MHBHTTPHeader.authorization) {
            case "Bearer expired":
                return Self.unauthorizedExpiredTokenResponse()
            case "Bearer fresh-token":
                return Self.successResponse()
            default:
                throw MHBHTTPClientTestError.unexpectedRequest
            }
        }

        let first = Task { try await client.get(path: "/api/v1/profile/me") as MHBAPIResponse<MHBEmptyResponse> }
        let second = Task { try await client.get(path: "/api/v1/profile/me") as MHBAPIResponse<MHBEmptyResponse> }
        let responses = try await [first.value, second.value]

        XCTAssertEqual(responses.map(\.success), [true, true])
        XCTAssertEqual(refreshService.callCount, 1)
        XCTAssertEqual(
            requestStore.requests.map { $0.value(forHTTPHeaderField: MHBHTTPHeader.authorization) },
            ["Bearer expired", "Bearer expired", "Bearer fresh-token", "Bearer fresh-token"]
        )
    }

    func testTokenRefreshCoordinatorSharesConcurrentRefresh() async throws {
        let tokenStore = MHBInMemoryTokenStore()
        let initialTokens = MHBStoredTokens(
            accessToken: "expired",
            refreshToken: "refresh-1",
            tokenType: "Bearer",
            expiresInSeconds: 0,
            refreshExpiresInSeconds: 3600
        )
        try tokenStore.saveTokens(initialTokens)
        let refreshService = MHBCountingTokenRefreshService()
        let coordinator = MHBTokenRefreshCoordinator()

        async let first = coordinator.refresh(
            currentTokens: initialTokens,
            tokenStore: tokenStore,
            service: refreshService
        )
        async let second = coordinator.refresh(
            currentTokens: initialTokens,
            tokenStore: tokenStore,
            service: refreshService
        )

        let refreshed = try await [first, second]

        XCTAssertEqual(refreshed.map(\.accessToken), ["fresh-token", "fresh-token"])
        XCTAssertEqual(refreshService.callCount, 1)
        XCTAssertEqual(try tokenStore.loadTokens()?.accessToken, "fresh-token")
    }

    func testRefreshTokenInvalidationCodesInvalidateAuthentication() {
        XCTAssertTrue(
            MHBAPIError.business(
                code: "auth.refresh_invalid",
                message: "登录状态已失效，请重新登录",
                statusCode: 401
            ).isAuthenticationInvalidation
        )
        XCTAssertTrue(
            MHBAPIError.business(
                code: "auth.refresh_reused",
                message: "登录状态异常，请重新登录",
                statusCode: 401
            ).isAuthenticationInvalidation
        )
    }
}
