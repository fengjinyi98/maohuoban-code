import Foundation
import XCTest
import MaohuobanDiagnostics
@testable import maohuoban

// PetRepositoryDiagnosticsTests 宠物仓库网络诊断测试
// 核心职责：
// - 验证 HTTP 客户端记录成功请求摘要
// - 验证业务失败响应写入错误级别诊断事件
@MainActor
final class PetRepositoryDiagnosticsTests: PetRepositoryTestCase {
    func testHTTPClientRecordsNetworkSummaryForJSONRequest() async throws {
        let diagnostics = try await Self.installDiagnostics()
        let client = makeHTTPClient { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pets")
            return Self.jsonResponse(
                statusCode: 201,
                body:
                """
                {
                  "success": true,
                  "code": "pet.created",
                  "message": "宠物档案已创建",
                  "data": {}
                }
                """
            )
        }

        let response: MHBAPIResponse<MHBEmptyResponse> = try await client.post(
            path: "/api/v1/pets",
            body: ["name": "糯米"],
            headers: ["x-maohuoban-user-id": "user-1"]
        )

        XCTAssertEqual(response.code, "pet.created")
        let events = try await diagnostics.readEvents()
        XCTAssertTrue(events.contains { event in
            event.kind == .network
                && event.metadata["method"] == "POST"
                && event.metadata["status_code"] == "201"
                && event.metadata["api_code"] == "pet.created"
                && event.metadata["api_success"] == true
                && event.metadata["request_body_bytes"] != nil
                && event.metadata["response_body_bytes"] != nil
        })
    }

    func testHTTPClientRecordsNetworkSummaryForBusinessFailure() async throws {
        let diagnostics = try await Self.installDiagnostics()
        let client = makeHTTPClient { _ in
            Self.jsonResponse(
                statusCode: 422,
                body:
                """
                {
                  "success": false,
                  "code": "pet.breed_invalid",
                  "message": "品种格式无效",
                  "data": null
                }
                """
            )
        }

        do {
            let _: MHBAPIResponse<MHBEmptyResponse> = try await client.patch(
                path: "/api/v1/pets/pet-1",
                body: ["breed": "布偶"],
                headers: ["x-maohuoban-user-id": "user-1"]
            )
            XCTFail("Expected business error")
        } catch {
            XCTAssertEqual(error.toastMessage, "品种格式无效")
        }

        let events = try await diagnostics.readEvents()
        XCTAssertTrue(events.contains { event in
            event.kind == .network
                && event.severity == .error
                && event.metadata["method"] == "PATCH"
                && event.metadata["status_code"] == "422"
                && event.metadata["api_code"] == "pet.breed_invalid"
                && event.metadata["api_success"] == false
        })
    }
}
