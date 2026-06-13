import XCTest
@testable import maohuoban

// PetRepositoryTests 宠物写入仓库测试
// 核心职责：
// - 固化 iOS 到 Rust 宠物接口的请求契约
// - 验证当前用户上下文通过请求头传递
@MainActor
final class PetRepositoryTests: XCTestCase {
    override func tearDown() {
        PetRepositoryURLProtocol.handler = nil
        super.tearDown()
    }

    func testCreatePetSendsUserContextAndDecodesProfile() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pets")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-maohuoban-user-id"), "user-1")

            let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["name"] as? String, "糯米")
            XCTAssertEqual(json?["species"] as? String, "dog")
            XCTAssertEqual(json?["breed"] as? String, "比熊犬")
            XCTAssertEqual(json?["sex"] as? String, "female")
            XCTAssertEqual(json?["birthday"] as? String, "2024-04-01")

            return Self.jsonResponse(
                statusCode: 201,
                body:
                """
                {
                  "success": true,
                  "code": "pet.created",
                  "message": "宠物档案已创建",
                  "data": {
                    "id": "pet-1",
                    "owner_user_id": "user-1",
                    "name": "糯米",
                    "species": "dog",
                    "breed": "比熊犬",
                    "sex": "female",
                    "birthday": "2024-04-01"
                  }
                }
                """
            )
        }

        let response = try await repository.createPet(
            draft: PetProfileDraft(
                name: "糯米",
                species: .dog,
                breed: "比熊犬",
                sex: .female,
                birthday: "2024-04-01"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "宠物档案已创建")
        XCTAssertEqual(response.data?.id, "pet-1")
        XCTAssertEqual(response.data?.ownerUserID, "user-1")
    }

    func testCreateEventSendsUserContextAndDecodesEvent() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pets/pet-1/events")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-maohuoban-user-id"), "user-1")

            let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["event_kind"] as? String, "health")
            XCTAssertEqual(json?["event_subkind"] as? String, "weight")
            XCTAssertEqual(json?["title"] as? String, "体重记录")
            XCTAssertEqual(json?["summary"] as? String, "5.2kg，较上次稳定")
            XCTAssertEqual(json?["visibility"] as? String, "private")
            XCTAssertEqual(json?["occurred_at"] as? String, "2026-06-13T09:20:00Z")

            return Self.jsonResponse(
                statusCode: 201,
                body:
                """
                {
                  "success": true,
                  "code": "pet.event_created",
                  "message": "宠物事件已记录",
                    "data": {
                      "id": "event-1",
                      "pet_id": "pet-1",
                      "litter_id": null,
                      "event_kind": "health",
                      "event_subkind": "weight",
                      "title": "体重记录",
                      "summary": "5.2kg，较上次稳定",
                      "visibility": "private",
                      "event_payload": {
                        "weight_kg": 5.2
                      },
                      "occurred_at": "2026-06-13T09:20:00Z",
                      "record_revision": 1
                    }
                }
                """
            )
        }

        let response = try await repository.createEvent(
            petID: "pet-1",
            draft: PetEventDraft(
                kind: .health,
                subkind: "weight",
                title: "体重记录",
                summary: "5.2kg，较上次稳定",
                visibility: .private,
                occurredAt: "2026-06-13T09:20:00Z"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "宠物事件已记录")
        XCTAssertEqual(response.data?.petID, "pet-1")
        XCTAssertEqual(response.data?.recordRevision, 1)
    }

    func testLoadEventDetailSendsUserContextAndDecodesEvent() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/pet-events/event-1")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-maohuoban-user-id"), "user-1")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "pet.event_loaded",
                  "message": "宠物事件已加载",
                  "data": {
                    "id": "event-1",
                    "pet_id": "pet-1",
                    "event_kind": "health",
                    "event_subkind": "weight",
                    "title": "体重记录",
                    "summary": "5.2kg，较上次稳定",
                    "visibility": "private",
                    "occurred_at": "2026-06-13T09:20:00Z",
                    "record_revision": 1
                  }
                }
                """
            )
        }

        let response = try await repository.loadEventDetail(
            eventID: "event-1",
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "宠物事件已加载")
        XCTAssertEqual(response.data?.id, "event-1")
        XCTAssertEqual(response.data?.petID, "pet-1")
        XCTAssertNil(response.data?.litterID)
        XCTAssertEqual(response.data?.title, "体重记录")
    }

    private func makeRepository(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> DefaultPetRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PetRepositoryURLProtocol.self]
        PetRepositoryURLProtocol.handler = handler
        let session = URLSession(configuration: configuration)
        let client = MHBHTTPClient(baseURL: URL(string: "http://127.0.0.1:18080")!, session: session)
        return DefaultPetRepository(client: client)
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

// PetRepositoryURLProtocol 宠物仓库测试协议桩
// 核心职责：
// - 拦截 URLSession 请求
// - 将请求交给测试断言并返回固定响应
private final class PetRepositoryURLProtocol: URLProtocol {
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

private extension URLRequest {
    func bodyDataForPetRepositoryTest() -> Data? {
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
