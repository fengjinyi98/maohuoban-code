import Foundation
import XCTest
@testable import maohuoban

// MerchantRepositoryTestCase 商家仓库测试基类
// 核心职责：
// - 提供商家仓库测试共享 HTTP 桩与响应构造
// - 统一清理 URLProtocol handler
@MainActor
class MerchantRepositoryTestCase: XCTestCase {
    override func tearDown() {
        MerchantRepositoryURLProtocol.handler = nil
        super.tearDown()
    }

    func makeRepository(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> DefaultMerchantRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MerchantRepositoryURLProtocol.self]
        MerchantRepositoryURLProtocol.handler = handler
        let session = URLSession(configuration: configuration)
        let client = MHBHTTPClient.authenticated(
            baseURL: URL(string: "http://127.0.0.1:18080")!,
            session: session,
            tokenStore: MerchantRepositoryTestTokenStore(),
            retryPolicy: .disabled
        )
        return DefaultMerchantRepository(client: client)
    }

    static func assertAuthorizationHeader(_ request: URLRequest) {
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
    }

    static func jsonResponse(statusCode: Int, body: String) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(
                url: URL(string: "http://127.0.0.1:18080")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!,
            Data(body.utf8)
        )
    }

    static func requestBodyData(_ request: URLRequest) throws -> Data {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            return Data()
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while true {
            let count = stream.read(buffer, maxLength: bufferSize)
            if count > 0 {
                data.append(buffer, count: count)
            } else {
                break
            }
        }

        return data
    }
}

// MerchantRepositoryTestTokenStore 商家仓库测试 token 存储
// 核心职责：
// - 为商家仓库契约测试提供固定登录凭证
// - 避免测试读取真实 Keychain 状态
private struct MerchantRepositoryTestTokenStore: MHBTokenStore {
    func loadTokens() throws -> MHBStoredTokens? {
        MHBStoredTokens(
            accessToken: "test-access-token",
            refreshToken: "test-refresh-token",
            tokenType: "Bearer",
            expiresInSeconds: 3600,
            refreshExpiresInSeconds: 86_400
        )
    }

    func saveTokens(_ tokens: MHBStoredTokens) throws {}

    func clearTokens() throws {}
}
