import Foundation
import XCTest
@testable import maohuoban

// MHBHTTPClientRequestInfrastructureTests 请求基础设施测试
// 核心职责：
// - 固化请求追踪、鉴权、幂等和重试契约
// - 防止网络诊断泄露敏感 query 或丢失后端 request id
@MainActor
class MHBHTTPClientRequestInfrastructureTests: XCTestCase {
    override func tearDown() {
        MHBHTTPClientTestURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - 测试夹具

    func makeClient(
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

    func makeAuthenticatedClient(
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

    static func successResponse(
        headers: [String: String] = [:]
    ) -> (HTTPURLResponse, Data) {
        jsonResponse(
            statusCode: 200,
            headers: headers,
            body: """
            {
              "success": true,
              "code": "ok",
              "message": "ok",
              "data": {}
            }
            """
        )
    }

    static func retryableResponse() -> (HTTPURLResponse, Data) {
        jsonResponse(
            statusCode: 503,
            body: """
            {
              "success": false,
              "code": "system.temporarily_unavailable",
              "message": "服务繁忙",
              "data": null
            }
            """
        )
    }

    static func unauthorizedExpiredTokenResponse() -> (HTTPURLResponse, Data) {
        jsonResponse(
            statusCode: 401,
            body: """
            {
              "success": false,
              "code": "auth.session_expired",
              "message": "登录状态已过期，请重新登录",
              "data": null
            }
            """
        )
    }

    static func jsonResponse(
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

// MARK: - 测试支持类型

struct MHBHTTPClientEmptyTestRequest: Encodable {}

final class MHBRecordedRequestStore {
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

struct MHBTestAuthorizationProvider: MHBHTTPAuthorizationProvider {
    let token: String

    func authorizationHeaders() throws(MHBAPIError) -> [String: String] {
        [MHBHTTPHeader.authorization: "Bearer \(token)"]
    }
}

final class MHBInMemoryTokenStore: MHBTokenStore {
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

final class MHBCountingTokenRefreshService: MHBTokenRefreshService {
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

enum MHBHTTPClientTestError: Error {
    case unexpectedRequest
}

final class MHBHTTPClientTestURLProtocol: URLProtocol {
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
