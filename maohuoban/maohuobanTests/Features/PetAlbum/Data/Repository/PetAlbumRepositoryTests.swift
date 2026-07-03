import XCTest
@testable import maohuoban

// PetAlbumRepositoryTests 宠物相册仓库测试
// 核心职责：
// - 固化相册后端接口路径、用户上下文和分页参数
// - 验证后端相册 JSON 映射到前端展示模型
final class PetAlbumRepositoryTests: PetRepositoryTestCase {
    @MainActor
    func testListAlbumsRequestCarriesUserHeaderAndPaginationQuery() async throws {
        let requestBox = RequestBox()
        let repository = makeAlbumRepository { request in
            requestBox.request = request
            return Self.albumListResponse(request: request)
        }

        let response = try await repository.listAlbums(
            currentUserID: "user-1",
            limit: 20,
            cursor: "cursor-1"
        )

        let request = try XCTUnwrap(requestBox.request)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-maohuoban-user-id"), "user-1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
        let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.path, "/api/v1/pet-albums")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "limit" })?.value, "20")
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "cursor" })?.value, "cursor-1")
        XCTAssertEqual(response.data?.items.first?.coverURL, "/media/album-cover.jpg")
        XCTAssertEqual(response.data?.nextCursor, "next-1")
    }

    @MainActor
    func testCreateAlbumPostsDraftToPetAlbumEndpoint() async throws {
        let requestBox = RequestBox()
        let repository = makeAlbumRepository { request in
            requestBox.request = request
            return Self.albumResponse(request: request, code: "pet_album.created")
        }

        _ = try await repository.createAlbum(
            draft: PetAlbumCreateDraft(name: " 成长记录 ", isPrivate: true),
            currentUserID: "user-1"
        )

        let request = try XCTUnwrap(requestBox.request)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/v1/pet-albums")
        let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["title"] as? String, "成长记录")
        XCTAssertEqual(json["is_private"] as? Bool, true)
    }

    @MainActor
    private func makeAlbumRepository(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> DefaultPetAlbumRepository {
        DefaultPetAlbumRepository(client: makeHTTPClient(handler: handler))
    }

    private static func albumListResponse(request: URLRequest) -> (HTTPURLResponse, Data) {
        jsonResponse(
            statusCode: 200,
            body: #"""
            {
              "success": true,
              "code": "pet_album.list_loaded",
              "message": "相册列表已加载",
              "data": {
                "items": [
                  {
                    "id": "album-1",
                    "pet_id": null,
                    "owner_user_id": "user-1",
                    "title": "成长记录",
                    "description": null,
                    "is_private": true,
                    "is_pinned": false,
                    "cover_asset_id": "asset-1",
                    "cover_url": "/media/album-cover.jpg",
                    "photo_count": 3,
                    "archived_at": null,
                    "created_at": "2026-07-01T12:00:00Z",
                    "updated_at": "2026-07-03T12:00:00Z"
                  }
                ],
                "next_cursor": "next-1"
              }
            }
            """#
        )
    }

    private static func albumResponse(request: URLRequest, code: String) -> (HTTPURLResponse, Data) {
        jsonResponse(
            statusCode: 201,
            body: #"""
            {
              "success": true,
              "code": "\#(code)",
              "message": "相册已创建",
              "data": {
                "id": "album-1",
                    "pet_id": null,
                "owner_user_id": "user-1",
                "title": "成长记录",
                "description": null,
                "is_private": true,
                "is_pinned": false,
                "cover_asset_id": null,
                "cover_url": null,
                "photo_count": 0,
                "archived_at": null,
                "created_at": "2026-07-01T12:00:00Z",
                "updated_at": "2026-07-03T12:00:00Z"
              }
            }
            """#
        )
    }
}

private extension PetAlbumRepositoryTests {
    // RequestBox 相册请求捕获容器
    // 核心职责：
    // - 保存 URLProtocol 捕获的请求
    // - 避免测试闭包直接捕获可变局部变量
    final class RequestBox {
        var request: URLRequest?
    }
}
