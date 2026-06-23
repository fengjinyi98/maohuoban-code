import Foundation
import XCTest
@testable import maohuoban

// SettingsDeviceSessionRepositoryTests 登录设备仓储契约测试
// 核心职责：
// - 固化登录设备管理接口的 HTTP 契约
// - 验证后端 message 可被设备管理页 Toast 消费
@MainActor
final class SettingsDeviceSessionRepositoryTests: XCTestCase {
    override func tearDown() {
        SettingsDeviceSessionRepositoryURLProtocol.handler = nil
        super.tearDown()
    }

    func testFetchDevicesSendsAuthorizedRequestAndDecodesMessage() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/account/devices")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "account.devices_loaded",
                  "message": "登录设备已加载",
                  "data": {
                    "devices": [
                      {
                        "session_id": "session-current",
                        "device_id": "ios-device-current",
                        "device_name": "iPhone 17 Pro",
                        "device_model": "iPhone",
                        "platform": "iOS",
                        "location_text": "未知地区",
                        "last_active_text": "当前在线",
                        "is_current_device": true
                      }
                    ]
                  }
                }
                """
            )
        }

        let response = try await repository.fetchDevices()

        XCTAssertEqual(response.message, "登录设备已加载")
        XCTAssertEqual(response.data?.devices.first?.sessionID, "session-current")
        XCTAssertEqual(response.data?.devices.first?.deviceID, "ios-device-current")
        XCTAssertTrue(response.data?.devices.first?.isCurrentDevice == true)
    }

    func testFetchDeviceDetailsUsesSessionIDPath() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/account/devices/session-ipad")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "account.device_loaded",
                  "message": "登录设备详情已加载",
                  "data": {
                    "session_id": "session-ipad",
                    "device_id": "ios-device-ipad",
                    "device_name": "iPad Pro",
                    "device_model": "iPad",
                    "platform": "iPadOS",
                    "os_version": "iPadOS",
                    "app_version": "1.0",
                    "location_text": "未知地区",
                    "ip_address": "未知",
                    "first_login_text": "2026-06-23T08:00:00Z",
                    "last_active_text": "2026-06-23T08:10:00Z",
                    "is_current_device": false
                  }
                }
                """
            )
        }

        let response = try await repository.fetchDeviceDetails(sessionID: "session-ipad")

        XCTAssertEqual(response.message, "登录设备详情已加载")
        XCTAssertEqual(response.data?.summary.sessionID, "session-ipad")
        XCTAssertEqual(response.data?.summary.deviceModel, "iPad")
        XCTAssertEqual(response.data?.appVersion, "1.0")
    }

    func testRemoveDeviceUsesDeleteAndKeepsToastMessage() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/api/v1/account/devices/session-ipad")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "account.device_revoked",
                  "message": "登录设备已移除",
                  "data": {}
                }
                """
            )
        }

        let response = try await repository.removeDevice(sessionID: "session-ipad")

        XCTAssertEqual(response.message, "登录设备已移除")
    }

    private func makeRepository(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> DefaultSettingsDeviceSessionRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SettingsDeviceSessionRepositoryURLProtocol.self]
        SettingsDeviceSessionRepositoryURLProtocol.handler = handler
        let session = URLSession(configuration: configuration)
        return DefaultSettingsDeviceSessionRepository(
            client: MHBHTTPClient.authenticated(
                baseURL: URL(string: "http://127.0.0.1:18080")!,
                session: session,
                tokenStore: SettingsDeviceSessionRepositoryTestTokenStore(),
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

// SettingsDeviceSessionRepositoryURLProtocol 登录设备仓储测试协议桩
// 核心职责：
// - 拦截 URLSession 请求
// - 将请求交给测试断言并返回固定响应
private final class SettingsDeviceSessionRepositoryURLProtocol: URLProtocol {
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

// SettingsDeviceSessionRepositoryTestTokenStore 登录设备仓储测试 token 存储
// 核心职责：
// - 为仓储契约测试提供固定 Authorization 请求头
// - 避免测试读取真实 Keychain 登录状态
private struct SettingsDeviceSessionRepositoryTestTokenStore: MHBTokenStore {
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
