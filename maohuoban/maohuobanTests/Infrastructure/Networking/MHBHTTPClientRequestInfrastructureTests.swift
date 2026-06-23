import Foundation
import XCTest
@testable import maohuoban

// MHBHTTPClientRequestInfrastructureTests 请求基础设施测试
// 核心职责：
// - 固化请求追踪、鉴权、幂等和重试契约
// - 防止网络诊断泄露敏感 query 或丢失后端 request id
@MainActor
final class MHBHTTPClientRequestInfrastructureTests: XCTestCase {
    override func tearDown() {
        MHBHTTPClientTestURLProtocol.handler = nil
        super.tearDown()
    }

    func testSendInjectsTraceparentRequestIDAndIdempotencyKeyForWriteRequest() async throws {
        let requestStore = MHBRecordedRequestStore()
        let client = makeClient { request in
            requestStore.record(request)
            return Self.successResponse()
        }

        let response: MHBAPIResponse<MHBEmptyResponse> = try await client.post(
            path: "/api/v1/pets",
            body: MHBHTTPClientEmptyTestRequest()
        )

        XCTAssertTrue(response.success)
        let request = try XCTUnwrap(requestStore.requests.first)
        XCTAssertNotNil(
            request.value(forHTTPHeaderField: MHBHTTPHeader.requestID)
                .flatMap(UUID.init(uuidString:))
        )
        XCTAssertNotNil(
            request.value(forHTTPHeaderField: MHBHTTPHeader.idempotencyKey)
                .flatMap(UUID.init(uuidString:))
        )
        XCTAssertTrue(
            request.value(forHTTPHeaderField: MHBHTTPHeader.traceparent)?
                .range(
                    of: #"^00-[0-9a-f]{32}-[0-9a-f]{16}-01$"#,
                    options: .regularExpression
                ) != nil
        )
    }

    func testBackendCorrelationHeadersKeepExistingValuesAndExposeResponseRequestID() async throws {
        let requestStore = MHBRecordedRequestStore()
        let client = makeClient { request in
            requestStore.record(request)
            return Self.successResponse(headers: [
                MHBHTTPHeader.requestID: "backend-request-9"
            ])
        }

        var request = URLRequest(url: URL(string: "http://127.0.0.1:18080/api/v1/profile/me")!)
        request.httpMethod = "GET"
        request.setValue("client-request-1", forHTTPHeaderField: MHBHTTPHeader.requestID)
        request.setValue("00-1234567890abcdef1234567890abcdef-1234567890abcdef-01", forHTTPHeaderField: MHBHTTPHeader.traceparent)

        let response: MHBAPIResponse<MHBEmptyResponse> = try await client.send(request)

        XCTAssertTrue(response.success)
        let sentRequest = try XCTUnwrap(requestStore.requests.first)
        XCTAssertEqual(sentRequest.value(forHTTPHeaderField: MHBHTTPHeader.requestID), "client-request-1")
        XCTAssertEqual(
            sentRequest.value(forHTTPHeaderField: MHBHTTPHeader.traceparent),
            "00-1234567890abcdef1234567890abcdef-1234567890abcdef-01"
        )

        let metadata = MHBHTTPNetworkSummaryBuilder.metadata(
            request: sentRequest,
            response: HTTPURLResponse(
                url: sentRequest.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [MHBHTTPHeader.requestID: "backend-request-9"]
            ),
            responseData: Data(),
            requestBodyBytes: nil
        )
        XCTAssertEqual(metadata["request_id"], "client-request-1")
        XCTAssertEqual(metadata["response_request_id"], "backend-request-9")
    }

    func testAPISessionFactoryUsesDedicatedConfiguration() {
        let configuration = MHBHTTPClientSessionFactory.configuration()

        XCTAssertEqual(configuration.timeoutIntervalForRequest, 30)
        XCTAssertEqual(configuration.timeoutIntervalForResource, 60)
        XCTAssertEqual(configuration.requestCachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertNil(configuration.urlCache)
        XCTAssertTrue(configuration.waitsForConnectivity)
        XCTAssertTrue(configuration.allowsCellularAccess)
        XCTAssertTrue(configuration.allowsConstrainedNetworkAccess)
        XCTAssertTrue(configuration.allowsExpensiveNetworkAccess)
    }

    func testAuthorizationMiddlewareAddsBearerHeaderWhenRepositoryDoesNotPassHeaders() async throws {
        let requestStore = MHBRecordedRequestStore()
        let client = makeClient(
            authorizationProvider: MHBTestAuthorizationProvider(token: "middleware-token")
        ) { request in
            requestStore.record(request)
            return Self.successResponse()
        }

        let response: MHBAPIResponse<MHBEmptyResponse> = try await client.get(path: "/api/v1/profile/me")

        XCTAssertTrue(response.success)
        XCTAssertEqual(
            requestStore.requests.first?.value(forHTTPHeaderField: MHBHTTPHeader.authorization),
            "Bearer middleware-token"
        )
    }

    func testDiagnosticsSummaryRedactsSensitiveQueryValues() {
        let url = URL(
            string: "https://api.maohuoban.test/api/v1/search?phone=13800138000&city=hangzhou&token=secret&password=pw&code=123456&page=2"
        )!

        let redacted = MHBHTTPNetworkSummaryBuilder.redactedURLString(from: url)

        XCTAssertEqual(
            redacted,
            "https://api.maohuoban.test/api/v1/search?phone=%5BREDACTED%5D&city=hangzhou&token=%5BREDACTED%5D&password=%5BREDACTED%5D&code=%5BREDACTED%5D&page=2"
        )
    }

    func testRetryPolicyRetriesRetryableStatusAndKeepsSameIdempotencyKey() async throws {
        let requestStore = MHBRecordedRequestStore()
        let client = makeClient(retryPolicy: .immediate(maxAttempts: 2)) { request in
            requestStore.record(request)
            if requestStore.requests.count == 1 {
                return Self.retryableResponse()
            }
            return Self.successResponse()
        }

        let response: MHBAPIResponse<MHBEmptyResponse> = try await client.post(
            path: "/api/v1/pets",
            body: MHBHTTPClientEmptyTestRequest()
        )

        XCTAssertTrue(response.success)
        XCTAssertEqual(requestStore.requests.count, 2)
        XCTAssertEqual(
            requestStore.requests.first?.value(forHTTPHeaderField: MHBHTTPHeader.idempotencyKey),
            requestStore.requests.last?.value(forHTTPHeaderField: MHBHTTPHeader.idempotencyKey)
        )
    }

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

    private func makeClient(
        authorizationProvider: MHBHTTPAuthorizationProvider? = nil,
        retryPolicy: MHBHTTPRetryPolicy = .disabled,
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> MHBHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MHBHTTPClientTestURLProtocol.self]
        MHBHTTPClientTestURLProtocol.handler = handler
        return MHBHTTPClient(
            baseURL: URL(string: "http://127.0.0.1:18080")!,
            session: URLSession(configuration: configuration),
            authorizationProvider: authorizationProvider,
            retryPolicy: retryPolicy
        )
    }

    private func makeAuthenticatedClient(
        tokenStore: MHBTokenStore,
        refreshService: MHBTokenRefreshService,
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> MHBHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MHBHTTPClientTestURLProtocol.self]
        MHBHTTPClientTestURLProtocol.handler = handler
        return MHBHTTPClient.authenticated(
            baseURL: URL(string: "http://127.0.0.1:18080")!,
            session: URLSession(configuration: configuration),
            tokenStore: tokenStore,
            refreshService: refreshService,
            retryPolicy: .disabled
        )
    }

    private static func successResponse(
        headers: [String: String] = [:]
    ) -> (HTTPURLResponse, Data) {
        jsonResponse(
            statusCode: 200,
            headers: headers,
            body:
            """
            {
              "success": true,
              "code": "ok",
              "message": "ok",
              "data": {}
            }
            """
        )
    }

    private static func retryableResponse() -> (HTTPURLResponse, Data) {
        jsonResponse(
            statusCode: 503,
            body:
            """
            {
              "success": false,
              "code": "system.temporarily_unavailable",
              "message": "服务繁忙",
              "data": null
            }
            """
        )
    }

    private static func unauthorizedExpiredTokenResponse() -> (HTTPURLResponse, Data) {
        jsonResponse(
            statusCode: 401,
            body:
            """
            {
              "success": false,
              "code": "auth.session_expired",
              "message": "登录状态已过期，请重新登录",
              "data": null
            }
            """
        )
    }

    private static func jsonResponse(
        statusCode: Int,
        headers: [String: String] = [:],
        body: String
    ) -> (HTTPURLResponse, Data) {
        var responseHeaders = headers
        responseHeaders["Content-Type"] = "application/json"
        return (
            HTTPURLResponse(
                url: URL(string: "http://127.0.0.1:18080")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: responseHeaders
            )!,
            Data(body.utf8)
        )
    }
}

private struct MHBHTTPClientEmptyTestRequest: Encodable {}

private final class MHBRecordedRequestStore {
    private let lock = NSLock()
    private var storage: [URLRequest] = []

    var requests: [URLRequest] {
        lock.withLock { storage }
    }

    func record(_ request: URLRequest) {
        lock.withLock {
            storage.append(request)
        }
    }
}

private struct MHBTestAuthorizationProvider: MHBHTTPAuthorizationProvider {
    let token: String

    func authorizationHeaders() throws(MHBAPIError) -> [String: String] {
        [MHBHTTPHeader.authorization: "Bearer \(token)"]
    }
}

private final class MHBInMemoryTokenStore: MHBTokenStore {
    private let lock = NSLock()
    private var tokens: MHBStoredTokens?

    func loadTokens() throws -> MHBStoredTokens? {
        lock.withLock { tokens }
    }

    func saveTokens(_ tokens: MHBStoredTokens) throws {
        lock.withLock {
            self.tokens = tokens
        }
    }

    func clearTokens() throws {
        lock.withLock {
            tokens = nil
        }
    }
}

private final class MHBCountingTokenRefreshService: MHBTokenRefreshService {
    private let lock = NSLock()
    private var storageCallCount = 0

    var callCount: Int {
        lock.withLock { storageCallCount }
    }

    func refresh(currentTokens: MHBStoredTokens) async throws(MHBAPIError) -> MHBStoredTokens {
        lock.withLock {
            storageCallCount += 1
        }
        try? await Task.sleep(for: .milliseconds(50))
        return MHBStoredTokens(
            accessToken: "fresh-token",
            refreshToken: currentTokens.refreshToken,
            tokenType: currentTokens.tokenType,
            expiresInSeconds: 3600,
            refreshExpiresInSeconds: currentTokens.refreshExpiresInSeconds
        )
    }
}

private enum MHBHTTPClientTestError: Error {
    case unexpectedRequest
}

private final class MHBHTTPClientTestURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
