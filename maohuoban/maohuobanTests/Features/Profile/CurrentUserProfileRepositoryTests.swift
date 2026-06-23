import Foundation
import XCTest
@testable import maohuoban

// CurrentUserProfileRepositoryTests 当前用户资料仓储契约测试
// 核心职责：
// - 固化个人资料读取和更新接口的 HTTP 契约
// - 验证后端 message 与头像展示字段可被前端消费
@MainActor
final class CurrentUserProfileRepositoryTests: XCTestCase {
    override func tearDown() {
        CurrentUserProfileRepositoryURLProtocol.handler = nil
        super.tearDown()
    }

    func testUpdateCurrentProfileSendsEditableFieldsAndDecodesToastMessage() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.url?.path, "/api/v1/profile/me")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            let body = try XCTUnwrap(request.bodyDataForCurrentUserProfileRepositoryTest())
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["display_name"] as? String, "橘子午后")
            XCTAssertEqual(json?["bio"] as? String, "记录两只毛孩子的日常。")
            XCTAssertEqual(json?["gender"] as? String, "female")
            XCTAssertEqual(json?["is_gender_visible"] as? Bool, false)
            XCTAssertEqual(json?["birthday"] as? String, "1999-12-31")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "profile.updated",
                  "message": "个人资料已更新",
                  "data": {
                    "user_id": "user-1",
                    "maohuoban_id": "8X29K4M7Q2",
                    "display_name": "橘子午后",
                    "default_display_name": "毛伙伴用户7K29Q",
                    "bio": "记录两只毛孩子的日常。",
                    "gender": "female",
                    "is_gender_visible": false,
                    "birthday": "1999-12-31",
                    "birthday_display_text": "1999-12-31",
                    "avatar": null,
                    "cover": null,
                    "avatar_presentation": {
                      "sex": "unknown",
                      "sex_visibility": "hidden"
                    },
                    "display_name_edit_policy": {
                      "max_count": 5,
                      "used_count": 1,
                      "remaining_count": 4,
                      "window_days": 30,
                      "window_ends_at": "2026-07-23T00:00:00Z",
                      "display_text": "7月23日前还可以修改 4 次昵称。"
                    },
                    "bio_edit_policy": {
                      "max_count": 3,
                      "used_count": 1,
                      "remaining_count": 2,
                      "window_days": 30,
                      "window_ends_at": "2026-07-23T00:00:00Z",
                      "display_text": "7月23日前还可以修改 2 次简介。"
                    }
                  }
                }
                """
            )
        }

        let response = try await repository.updateCurrentProfile(
            draft: CurrentUserProfileUpdateDraft(
                displayName: "橘子午后",
                bio: "记录两只毛孩子的日常。",
                gender: "female",
                isGenderVisible: false,
                birthday: "1999-12-31"
            )
        )

        XCTAssertEqual(response.code, "profile.updated")
        XCTAssertEqual(response.message, "个人资料已更新")
        XCTAssertEqual(response.data?.displayName, "橘子午后")
        XCTAssertEqual(response.data?.bio, "记录两只毛孩子的日常。")
        XCTAssertEqual(response.data?.avatarPresentation.sex, .unknown)
        XCTAssertEqual(response.data?.avatarPresentation.sexVisibility, .hidden)
        XCTAssertEqual(response.data?.displayNameEditPolicy?.remainingCount, 4)
        XCTAssertEqual(response.data?.displayNameEditPolicy?.displayText, "7月23日前还可以修改 4 次昵称。")
        XCTAssertEqual(response.data?.bioEditPolicy?.remainingCount, 2)
        XCTAssertEqual(response.data?.bioEditPolicy?.displayText, "7月23日前还可以修改 2 次简介。")
    }

    func testUploadCurrentProfileAvatarSendsMultipartImageToAvatarEndpoint() async throws {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/profile/me/avatar")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
            XCTAssertTrue(
                request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=") == true
            )
            XCTAssertNil(request.httpBody)
            XCTAssertNotNil(request.httpBodyStream)

            let body = try XCTUnwrap(request.bodyDataForCurrentUserProfileRepositoryTest())
            let bodyText = String(decoding: body, as: UTF8.self)
            XCTAssertTrue(bodyText.contains("Content-Disposition: form-data; name=\"file\"; filename=\"avatar.png\""))
            XCTAssertTrue(bodyText.contains("Content-Type: image/png"))
            XCTAssertTrue(bodyText.contains("Content-Disposition: form-data; name=\"source_client\""))
            XCTAssertTrue(bodyText.contains("ios"))

            return Self.profileMediaJSONResponse(
                code: "profile.avatar_uploaded",
                message: "头像已保存",
                avatarURL: "/api/v1/profile/media/avatar.png",
                coverURL: nil
            )
        }

        let response = try await repository.uploadCurrentProfileAvatar(
            draft: CurrentUserProfileMediaUploadDraft(
                fileName: "avatar.png",
                mimeType: "image/png",
                content: imageData,
                sourceClient: "ios"
            ),
            onUploadProgress: { _ in }
        )

        XCTAssertEqual(response.code, "profile.avatar_uploaded")
        XCTAssertEqual(response.message, "头像已保存")
        XCTAssertEqual(response.data?.avatar?.url, "/api/v1/profile/media/avatar.png")
    }

    func testUploadCurrentProfileCoverSendsMultipartImageToCoverEndpoint() async throws {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/profile/me/cover")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
            XCTAssertNil(request.httpBody)
            XCTAssertNotNil(request.httpBodyStream)

            let body = try XCTUnwrap(request.bodyDataForCurrentUserProfileRepositoryTest())
            let bodyText = String(decoding: body, as: UTF8.self)
            XCTAssertTrue(bodyText.contains("Content-Disposition: form-data; name=\"file\"; filename=\"cover.png\""))
            XCTAssertTrue(bodyText.contains("Content-Type: image/png"))

            return Self.profileMediaJSONResponse(
                code: "profile.cover_uploaded",
                message: "主页背景已保存",
                avatarURL: nil,
                coverURL: "/api/v1/profile/media/cover.png"
            )
        }

        let response = try await repository.uploadCurrentProfileCover(
            draft: CurrentUserProfileMediaUploadDraft(
                fileName: "cover.png",
                mimeType: "image/png",
                content: imageData,
                sourceClient: "ios"
            ),
            onUploadProgress: { _ in }
        )

        XCTAssertEqual(response.code, "profile.cover_uploaded")
        XCTAssertEqual(response.message, "主页背景已保存")
        XCTAssertEqual(response.data?.cover?.url, "/api/v1/profile/media/cover.png")
    }

    private func makeRepository(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> DefaultCurrentUserProfileRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CurrentUserProfileRepositoryURLProtocol.self]
        CurrentUserProfileRepositoryURLProtocol.handler = handler
        let session = URLSession(configuration: configuration)
        return DefaultCurrentUserProfileRepository(
            client: MHBHTTPClient.authenticated(
                baseURL: URL(string: "http://127.0.0.1:18080")!,
                session: session,
                tokenStore: CurrentUserProfileRepositoryTestTokenStore(),
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

    private static func profileMediaJSONResponse(
        code: String,
        message: String,
        avatarURL: String?,
        coverURL: String?
    ) -> (HTTPURLResponse, Data) {
        let avatarJSON = mediaJSON(url: avatarURL)
        let coverJSON = mediaJSON(url: coverURL)
        return jsonResponse(
            statusCode: 201,
            body:
            """
            {
              "success": true,
              "code": "\(code)",
              "message": "\(message)",
              "data": {
                "user_id": "user-1",
                "maohuoban_id": "8X29K4M7Q2",
                "display_name": "橘子午后",
                "default_display_name": "毛伙伴用户7K29Q",
                "bio": "记录两只毛孩子的日常。",
                "gender": "female",
                "is_gender_visible": false,
                "birthday": "1999-12-31",
                "birthday_display_text": "1999-12-31",
                "avatar": \(avatarJSON),
                "cover": \(coverJSON),
                "avatar_presentation": {
                  "sex": "unknown",
                  "sex_visibility": "hidden"
                },
                "display_name_edit_policy": null,
                "bio_edit_policy": null
              }
            }
            """
        )
    }

    private static func mediaJSON(url: String?) -> String {
        guard let url else {
            return "null"
        }
        return
            """
            {
              "asset_id": "asset-1",
              "url": "\(url)",
              "width": 1,
              "height": 1,
              "mime_type": "image/png",
              "updated_at": "2026-06-23T19:48:26Z"
            }
            """
    }
}

// CurrentUserProfileRepositoryURLProtocol 当前用户资料仓储测试协议桩
// 核心职责：
// - 拦截 URLSession 请求
// - 将请求交给测试断言并返回固定响应
private final class CurrentUserProfileRepositoryURLProtocol: URLProtocol {
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

// CurrentUserProfileRepositoryTestTokenStore 当前用户资料仓储测试 token 存储
// 核心职责：
// - 为仓储契约测试提供固定 Authorization 请求头
// - 避免测试读取真实 Keychain 登录状态
private struct CurrentUserProfileRepositoryTestTokenStore: MHBTokenStore {
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
    func bodyDataForCurrentUserProfileRepositoryTest() -> Data? {
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
