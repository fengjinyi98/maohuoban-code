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

    func testCreatePetSendsDraftAndUserContext() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/merchants/merchant-1/pets")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-maohuoban-user-id"), "user-1")

            let body = try Self.requestBodyData(request)
            XCTAssertFalse(body.isEmpty)
            let json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(json["name"] as? String, "奶糖")
            XCTAssertEqual(json["species"] as? String, "cat")
            XCTAssertEqual(json["breed"] as? String, "布偶猫")
            XCTAssertEqual(json["sex"] as? String, "female")
            XCTAssertEqual(json["birthday"] as? String, "2026-04-01")
            XCTAssertEqual(json["managed_status"] as? String, "needs_record")

            return Self.jsonResponse(
                statusCode: 201,
                body:
                """
                {
                  "success": true,
                  "code": "merchant.pet_created",
                  "message": "商家宠物已新增",
                  "data": {
                    "id": "pet-2",
                    "owner_user_id": null,
                    "merchant_id": "merchant-1",
                    "name": "奶糖",
                    "species": "cat",
                    "breed": "布偶猫",
                    "sex": "female",
                    "birthday": "2026-04-01",
                    "managed_status": "needs_record",
                    "source_kind": "merchant_managed",
                    "created_at": "2026-06-13T09:20:00Z",
                    "updated_at": "2026-06-13T09:20:00Z"
                  }
                }
                """
            )
        }

        let response = try await repository.createPet(
            merchantID: "merchant-1",
            draft: MerchantPetDraft(
                name: "奶糖",
                species: .cat,
                breed: "布偶猫",
                sex: .female,
                birthday: "2026-04-01",
                managedStatus: .needsRecord
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "商家宠物已新增")
        XCTAssertEqual(response.data?.id, "pet-2")
        XCTAssertEqual(response.data?.merchantID, "merchant-1")
        XCTAssertEqual(response.data?.sourceKind, .merchantManaged)
    }

    func testLoadLitterDetailSendsIDsAndUserContext() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/merchants/merchant-1/litters/litter-1")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-maohuoban-user-id"), "user-1")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "merchant.litter_loaded",
                  "message": "窝次详情已加载",
                  "data": {
                    "id": "litter-1",
                    "merchant_id": "merchant-1",
                    "name": "2026 春季 A 窝",
                    "species": "cat",
                    "born_at": "2026-03-18",
                    "born_count": 3,
                    "alive_count": 3,
                    "available_count": 2,
                    "status": "active",
                    "sire_pet": {
                      "id": "pet-sire",
                      "owner_user_id": null,
                      "merchant_id": "merchant-1",
                      "name": "Leo",
                      "species": "cat",
                      "breed": "布偶猫",
                      "sex": "male",
                      "birthday": "2026-03-18",
                      "managed_status": "retained",
                      "source_kind": "merchant_managed",
                      "created_at": "2026-06-13T09:20:00Z",
                      "updated_at": "2026-06-13T09:20:00Z"
                    },
                    "dam_pet": {
                      "id": "pet-dam",
                      "owner_user_id": null,
                      "merchant_id": "merchant-1",
                      "name": "Luna",
                      "species": "cat",
                      "breed": "布偶猫",
                      "sex": "female",
                      "birthday": "2026-03-18",
                      "managed_status": "retained",
                      "source_kind": "merchant_managed",
                      "created_at": "2026-06-13T09:20:00Z",
                      "updated_at": "2026-06-13T09:20:00Z"
                    },
                    "children": [],
                    "relationships": [],
                    "recent_events": []
                  }
                }
                """
            )
        }

        let response = try await repository.loadLitterDetail(
            merchantID: "merchant-1",
            litterID: "litter-1",
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "窝次详情已加载")
        XCTAssertEqual(response.data?.id, "litter-1")
        XCTAssertEqual(response.data?.merchantID, "merchant-1")
        XCTAssertEqual(response.data?.sirePet?.name, "Leo")
        XCTAssertEqual(response.data?.damPet?.name, "Luna")
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

    private static func requestBodyData(_ request: URLRequest) throws -> Data {
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
