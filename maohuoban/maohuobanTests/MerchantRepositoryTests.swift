import XCTest
@testable import maohuoban

// MerchantRepositoryTests 商家读取仓库测试
// 核心职责：
// - 固化 iOS 到 Rust 商家宠物列表接口的请求契约
// - 验证当前用户上下文和状态筛选通过请求传递
@MainActor
final class MerchantRepositoryTests: XCTestCase {
    override func tearDown() {
        MerchantRepositoryURLProtocol.handler = nil
        super.tearDown()
    }

    func testListPetsSendsStatusAndUserContext() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/merchants/merchant-1/pets")
            XCTAssertEqual(request.url?.query, "status=available")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-maohuoban-user-id"), "user-1")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "merchant.pets_loaded",
                  "message": "商家宠物列表已加载",
                  "data": {
                    "merchant_id": "merchant-1",
                    "status": "available",
                    "pets": [
                      {
                        "id": "pet-1",
                        "owner_user_id": null,
                        "merchant_id": "merchant-1",
                        "name": "小橘",
                        "species": "cat",
                        "breed": "布偶猫",
                        "sex": "female",
                        "birthday": "2026-03-18",
                        "managed_status": "available",
                        "source_kind": "litter_birth",
                        "created_at": "2026-06-13T09:20:00Z",
                        "updated_at": "2026-06-13T09:20:00Z"
                      }
                    ]
                  }
                }
                """
            )
        }

        let response = try await repository.listPets(
            merchantID: "merchant-1",
            status: .available,
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "商家宠物列表已加载")
        XCTAssertEqual(response.data?.merchantID, "merchant-1")
        XCTAssertEqual(response.data?.status, .available)
        XCTAssertEqual(response.data?.pets.first?.name, "小橘")
        XCTAssertEqual(response.data?.pets.first?.sourceKind, .litterBirth)
    }

    private func makeRepository(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> DefaultMerchantRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MerchantRepositoryURLProtocol.self]
        MerchantRepositoryURLProtocol.handler = handler
        let session = URLSession(configuration: configuration)
        let client = MHBHTTPClient(baseURL: URL(string: "http://127.0.0.1:18080")!, session: session)
        return DefaultMerchantRepository(client: client)
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

// MerchantRepositoryURLProtocol 商家仓库测试协议桩
// 核心职责：
// - 拦截 URLSession 请求
// - 将请求交给测试断言并返回固定响应
private final class MerchantRepositoryURLProtocol: URLProtocol {
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
