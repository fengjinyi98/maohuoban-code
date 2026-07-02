import Foundation
import XCTest
@testable import maohuoban

// SettingsPasswordRepositoryTests 登录密码仓储契约测试
// 核心职责：
// - 固化账号安全和登录密码接口的 HTTP 契约
// - 验证后端 message 可被设置页 Toast 消费
@MainActor
final class SettingsPasswordRepositoryTests: XCTestCase {
    override func tearDown() {
        SettingsPasswordRepositoryURLProtocol.handler = nil
        super.tearDown()
    }

    func testSetInitialPasswordSendsAuthorizedRequestAndDecodesSecurityState() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/account/password")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
            let body = try XCTUnwrap(request.bodyDataForSettingsPasswordRepositoryTest())
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["new_password"] as? String, "Newpass123")
            XCTAssertEqual(json?["confirm_password"] as? String, "Newpass123")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "account.password_set",
                  "message": "登录密码已设置",
                  "data": {
                    "phone_masked": "138****8016",
                    "has_password": true,
                    "password_status_text": "已设置",
                    "password_updated_at": null,
                    "wechat_bound": false,
                    "apple_bound": false,
                    "real_name_status": "unverified",
                    "official_verification_status": "unverified"
                  }
                }
                """
            )
        }

        let response = try await repository.setInitialPassword(
            newPassword: "Newpass123",
            confirmPassword: "Newpass123"
        )

        XCTAssertEqual(response.message, "登录密码已设置")
        XCTAssertTrue(response.data?.hasPassword == true)
        XCTAssertEqual(response.data?.passwordStatusText, "已设置")
    }

    func testChangePasswordRequiresCurrentPasswordAndChallengePayload() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.url?.path, "/api/v1/account/password")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
            let body = try XCTUnwrap(request.bodyDataForSettingsPasswordRepositoryTest())
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["current_password"] as? String, "Oldpass123")
            XCTAssertEqual(json?["challenge_id"] as? String, "challenge-1")
            XCTAssertEqual(json?["code"] as? String, "123456")
            XCTAssertEqual(json?["new_password"] as? String, "Newpass123")
            XCTAssertEqual(json?["confirm_password"] as? String, "Newpass123")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "account.password_changed",
                  "message": "登录密码已修改",
                  "data": {
                    "phone_masked": "138****8017",
                    "has_password": true,
                    "password_status_text": "已设置",
                    "password_updated_at": null,
                    "wechat_bound": false,
                    "apple_bound": false,
                    "real_name_status": "unverified",
                    "official_verification_status": "unverified"
                  }
                }
                """
            )
        }

        let response = try await repository.changePassword(
            currentPassword: "Oldpass123",
            challengeID: "challenge-1",
            code: "123456",
            newPassword: "Newpass123",
            confirmPassword: "Newpass123"
        )

        XCTAssertEqual(response.message, "登录密码已修改")
        XCTAssertTrue(response.data?.hasPassword == true)
    }

    func testSendPasswordChangeCodeDecodesChallengeMessage() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/account/password/change-code")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "account.password_change_code_sent",
                  "message": "验证码已发送",
                  "data": {
                    "challenge_id": "challenge-1",
                    "expires_in_seconds": 300,
                    "resend_after_seconds": 60
                  }
                }
                """
            )
        }

        let response = try await repository.sendPasswordChangeCode()

        XCTAssertEqual(response.message, "验证码已发送")
        XCTAssertEqual(response.data?.challengeID, "challenge-1")
        XCTAssertEqual(response.data?.resendAfterSeconds, 60)
    }

    private func makeRepository(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> DefaultSettingsPasswordRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SettingsPasswordRepositoryURLProtocol.self]
        SettingsPasswordRepositoryURLProtocol.handler = handler
        let session = URLSession(configuration: configuration)
        return DefaultSettingsPasswordRepository(
            client: MHBHTTPClient.authenticated(
                baseURL: URL(string: "http://127.0.0.1:18080")!,
                session: session,
                tokenStore: SettingsPasswordRepositoryTestTokenStore(),
                retryPolicy: .disabled
            )
        )
    }

    private static func jsonResponse(statusCode: Int, body: String) -> (HTTPURLResponse, Data) {
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
}

// SettingsPasswordRepositoryURLProtocol 登录密码仓储测试协议桩
// 核心职责：
// - 拦截 URLSession 请求
// - 将请求交给测试断言并返回固定响应
private final class SettingsPasswordRepositoryURLProtocol: URLProtocol {
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

// SettingsPasswordRepositoryTestTokenStore 登录密码仓储测试 token 存储
// 核心职责：
// - 为仓储契约测试提供固定 Authorization 请求头
// - 避免测试读取真实 Keychain 登录状态
private struct SettingsPasswordRepositoryTestTokenStore: MHBTokenStore {
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

private extension URLRequest {
    func bodyDataForSettingsPasswordRepositoryTest() -> Data? {
        if let httpBody {
            return httpBody
        }
        guard let httpBodyStream else {
            return nil
        }

        httpBodyStream.open()
        defer { httpBodyStream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while httpBodyStream.hasBytesAvailable {
            let readCount = httpBodyStream.read(&buffer, maxLength: buffer.count)
            if readCount < 0 {
                return nil
            }
            if readCount == 0 {
                break
            }
            data.append(buffer, count: readCount)
        }
        return data
    }
}
