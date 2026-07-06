import XCTest
@testable import maohuoban

// SameCityRepositoryTests 同城仓库测试
// 核心职责：
// - 固化 iOS 到 Rust 同城医院接口的请求契约
// - 验证当前用户上下文、城市筛选和预约字段传递
@MainActor
final class SameCityRepositoryTests: XCTestCase {
    override func tearDown() {
        SameCityRepositoryURLProtocol.handler = nil
        super.tearDown()
    }

    func testListHospitalsSendsCityAndUserContext() async throws {
        let capturedRequest = CapturedSameCityRequest()
        let repository = makeRepository { request in
            capturedRequest.record(request)
            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "samecity.hospitals_loaded",
                  "message": "合作医院已加载",
                  "data": {
                    "city": "毛伙伴市",
                    "hospitals": [
                      {
                        "id": "7a5af99c-1e4f-4715-9498-4bcae4f0f101",
                        "name": "毛伙伴闭环验证医院",
                        "city": "毛伙伴市",
                        "district": "验证区",
                        "address": "毛伙伴市验证区闭环路 188 号",
                        "phone": "028-88880001",
                        "service_tags": ["体检", "疫苗", "复诊"],
                        "verification_status": "verified",
                        "partnership_status": "active",
                        "his_enabled": true,
                        "his_tenant_id": "tenant-1",
                        "appointment_enabled": true,
                        "medical_record_return_enabled": true
                      }
                    ]
                  }
                }
                """
            )
        }

        let response = try await repository.listHospitals(
            city: "毛伙伴市",
            currentUserID: "user-1"
        )

        let request = try XCTUnwrap(capturedRequest.load())
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/api/v1/same-city/hospitals")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-maohuoban-user-id"), "user-1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
        let requestURL = try XCTUnwrap(request.url)
        let components = try XCTUnwrap(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.queryItems?.first(where: { $0.name == "city" })?.value, "毛伙伴市")
        XCTAssertEqual(response.message, "合作医院已加载")
        XCTAssertEqual(response.data?.city, "毛伙伴市")
        XCTAssertEqual(response.data?.hospitals.first?.name, "毛伙伴闭环验证医院")
        XCTAssertEqual(response.data?.hospitals.first?.verificationStatus, .verified)
        XCTAssertEqual(response.data?.hospitals.first?.partnershipStatus, .active)
        XCTAssertEqual(response.data?.hospitals.first?.hisEnabled, true)
        XCTAssertEqual(response.data?.hospitals.first?.hisTenantID, "tenant-1")
        XCTAssertEqual(response.data?.hospitals.first?.appointmentEnabled, true)
        XCTAssertEqual(response.data?.hospitals.first?.medicalRecordReturnEnabled, true)
    }

    func testBookHospitalAppointmentSendsDraftAndUserContext() async throws {
        let capturedRequest = CapturedSameCityRequest()
        let repository = makeRepository { request in
            capturedRequest.record(request)
            return Self.jsonResponse(
                statusCode: 201,
                body:
                """
                {
                  "success": true,
                  "code": "samecity.hospital_appointment_created",
                  "message": "医院预约已提交",
                  "data": {
                    "id": "appointment-1",
                    "owner_user_id": "user-1",
                    "pet_id": "pet-1",
                    "hospital_id": "hospital-1",
                    "scheduled_at": "2026-06-15T09:30:00Z",
                    "reason": "基础体检",
                    "note": "希望安排上午到店",
                    "status": "pending"
                  }
                }
                """
            )
        }

        let response = try await repository.bookHospitalAppointment(
            draft: HospitalAppointmentDraft(
                hospitalID: "hospital-1",
                petID: "pet-1",
                scheduledAt: "2026-06-15T09:30:00Z",
                reason: "基础体检",
                note: "希望安排上午到店"
            ),
            currentUserID: "user-1"
        )

        let request = try XCTUnwrap(capturedRequest.load())
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/v1/same-city/hospital-appointments")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-maohuoban-user-id"), "user-1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
        let body = try Self.requestBodyData(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["hospital_id"] as? String, "hospital-1")
        XCTAssertEqual(json["pet_id"] as? String, "pet-1")
        XCTAssertEqual(json["scheduled_at"] as? String, "2026-06-15T09:30:00Z")
        XCTAssertEqual(json["reason"] as? String, "基础体检")
        XCTAssertEqual(json["note"] as? String, "希望安排上午到店")
        XCTAssertEqual(response.message, "医院预约已提交")
        XCTAssertEqual(response.data?.id, "appointment-1")
        XCTAssertEqual(response.data?.petID, "pet-1")
        XCTAssertEqual(response.data?.status, .pending)
    }

    func testCancelHospitalAppointmentSendsAppointmentIDAndKeepsToastMessage() async throws {
        let capturedRequest = CapturedSameCityRequest()
        let repository = makeRepository { request in
            capturedRequest.record(request)
            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "samecity.hospital_appointment_cancelled",
                  "message": "医院预约已取消",
                  "data": {
                    "id": "appointment-1",
                    "owner_user_id": "user-1",
                    "pet_id": "pet-1",
                    "hospital_id": "hospital-1",
                    "scheduled_at": "2026-06-15T09:30:00Z",
                    "reason": "基础体检",
                    "note": "希望安排上午到店",
                    "status": "cancelled"
                  }
                }
                """
            )
        }

        let response = try await repository.cancelHospitalAppointment(
            appointmentID: "appointment-1",
            currentUserID: "user-1"
        )

        let request = try XCTUnwrap(capturedRequest.load())
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/api/v1/same-city/hospital-appointments/appointment-1/cancel")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-maohuoban-user-id"), "user-1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
        XCTAssertEqual(response.message, "医院预约已取消")
        XCTAssertEqual(response.data?.id, "appointment-1")
        XCTAssertEqual(response.data?.status, .cancelled)
    }

    private func makeRepository(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> DefaultSameCityRepository {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SameCityRepositoryURLProtocol.self]
        SameCityRepositoryURLProtocol.handler = handler
        let session = URLSession(configuration: configuration)
        let client = MHBHTTPClient.authenticated(
            baseURL: URL(string: "http://127.0.0.1:18080")!,
            session: session,
            tokenStore: PetRepositoryTestTokenStore(),
            retryPolicy: .disabled
        )
        return DefaultSameCityRepository(client: client)
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

// SameCityRepositoryURLProtocol 同城仓库测试协议桩
// 核心职责：
// - 拦截 URLSession 请求
// - 将请求交给测试断言并返回固定响应
private final class SameCityRepositoryURLProtocol: URLProtocol {
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

// CapturedSameCityRequest 同城请求捕获器
// 核心职责：
// - 在线程安全容器中保存 URLProtocol 捕获的请求
// - 支持测试主流程在请求完成后执行 XCTest 断言
private final class CapturedSameCityRequest {
    private let lock = NSLock()
    private var request: URLRequest?

    func record(_ request: URLRequest) {
        lock.lock()
        self.request = request
        lock.unlock()
    }

    func load() -> URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return request
    }
}
