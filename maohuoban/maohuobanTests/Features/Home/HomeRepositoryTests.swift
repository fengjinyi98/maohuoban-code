import XCTest
@testable import maohuoban

// HomeRepositoryTests 首页仓库测试
// 核心职责：
// - 固化首页聚合接口请求路径和用户上下文
// - 验证多宠切换 selected_pet_id 查询参数
final class HomeRepositoryTests: XCTestCase {
    override func tearDown() {
        HomeRepositoryURLProtocol.handler = nil
        super.tearDown()
    }

    @MainActor
    func testDashboardRequestCarriesUserHeaderAndSelectedPetQuery() async throws {
        let requestBox = HomeRepositoryRequestBox()
        let repository = makeRepository { request in
            requestBox.request = request
            return Self.emptyDashboardResponse(request: request)
        }

        _ = try await repository.dashboard(
            currentUserID: "user-1",
            selectedPetID: "pet-2"
        )

        let request = try XCTUnwrap(requestBox.request)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-maohuoban-user-id"), "user-1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
        let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.path, "/api/v1/home/dashboard")
        XCTAssertEqual(
            components.queryItems?.first(where: { $0.name == "selected_pet_id" })?.value,
            "pet-2"
        )
    }

    @MainActor
    func testDashboardRequestOmitsEmptySelectedPetQuery() async throws {
        let requestBox = HomeRepositoryRequestBox()
        let repository = makeRepository { request in
            requestBox.request = request
            return Self.emptyDashboardResponse(request: request)
        }

        _ = try await repository.dashboard(
            currentUserID: "user-1",
            selectedPetID: ""
        )

        let request = try XCTUnwrap(requestBox.request)
        let components = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false))
        XCTAssertNil(components.queryItems?.first(where: { $0.name == "selected_pet_id" }))
    }

    @MainActor
    private func makeRepository(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> DefaultHomeRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HomeRepositoryURLProtocol.self]
        HomeRepositoryURLProtocol.handler = handler
        let session = URLSession(configuration: configuration)
        let client = MHBHTTPClient.authenticated(
            baseURL: URL(string: "http://127.0.0.1:18080")!,
            session: session,
            tokenStore: PetRepositoryTestTokenStore(),
            retryPolicy: .disabled
        )
        return DefaultHomeRepository(client: client)
    }

    // emptyDashboardResponse 构造空首页响应
    // 核心职责：
    // - 为仓库请求契约测试提供稳定响应体
    // - 避免每个测试重复声明首页 JSON
    private static func emptyDashboardResponse(request: URLRequest) -> (HTTPURLResponse, Data) {
        let data = Data(
            #"""
            {
              "success": true,
              "code": "home.dashboard_loaded",
              "message": "首页已加载",
              "data": {
                "identity": {
                  "kind": "pet_owner",
                  "display_name": "毛伙伴用户",
                  "city": null,
                  "verification_badge": null
                },
                "selected_pet": null,
                "pet_switcher": [],
                "care_summary": null,
                "reminders": [],
                "quick_actions": [],
                "partner_recommendation": null,
                "recent_timeline": [],
                "merchant_dashboard": null,
                "empty_state": null,
                "recommended_content": []
              }
            }
            """#.utf8
        )
        return (
            HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!,
            data
        )
    }
}

// HomeRepositoryURLProtocol 首页仓库测试协议桩
// 核心职责：
// - 拦截 URLSession 请求
// - 将请求交给测试闭包生成响应
private final class HomeRepositoryURLProtocol: URLProtocol {
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

    override func stopLoading() {
    }
}

// HomeRepositoryRequestBox 首页请求捕获容器
// 核心职责：
// - 保存 URLProtocol 捕获的请求
// - 避免测试闭包直接捕获可变局部变量
private final class HomeRepositoryRequestBox {
    var request: URLRequest?
}
