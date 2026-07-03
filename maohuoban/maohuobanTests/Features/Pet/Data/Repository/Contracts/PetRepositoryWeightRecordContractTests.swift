import Foundation
import XCTest
@testable import maohuoban

// PetRepositoryWeightRecordContractTests 体重记录仓库契约测试
// 核心职责：
// - 验证体重记录 CRUD 请求路径和请求体
// - 固化后端体重记录响应字段解码
@MainActor
final class PetRepositoryWeightRecordContractTests: PetRepositoryTestCase {
    func testListWeightRecordsSendsUserContextAndDecodesItems() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/pets/pet-1/weight-records")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "pet.weight_records_loaded",
                  "message": "体重记录已加载",
                  "data": {
                    "items": [
                      {
                        "id": "weight-1",
                        "pet_id": "pet-1",
                        "weight_grams": 4200,
                        "note": "晨间称重",
                        "source": "manual",
                        "occurred_at": "2026-07-04T01:00:00Z",
                        "record_revision": 1,
                        "created_at": "2026-07-04T01:00:00Z",
                        "updated_at": "2026-07-04T01:00:00Z"
                      }
                    ]
                  }
                }
                """
            )
        }

        let response = try await repository.listWeightRecords(petID: "pet-1", currentUserID: "user-1")

        XCTAssertEqual(response.message, "体重记录已加载")
        XCTAssertEqual(response.data?.items.first?.id, "weight-1")
        XCTAssertEqual(response.data?.items.first?.note, "晨间称重")
        XCTAssertEqual(response.data?.items.first?.weightText, "4.20")
    }

    func testCreateWeightRecordSendsNoteAndDecodesRecord() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pets/pet-1/weight-records")

            let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["weight_grams"] as? Int, 4250)
            XCTAssertEqual(json["note"] as? String, "饭前称重")
            XCTAssertEqual(json["occurred_at"] as? String, "2026-07-04T01:00:00Z")

            return Self.recordResponse(code: "pet.weight_record_created", message: "体重记录已创建")
        }

        let response = try await repository.createWeightRecord(
            petID: "pet-1",
            draft: PetWeightRecordDraft(
                weightGrams: 4250,
                note: "饭前称重",
                occurredAt: "2026-07-04T01:00:00Z"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.data?.weightGrams, 4250)
        XCTAssertEqual(response.data?.note, "饭前称重")
    }

    func testUpdateWeightRecordUsesPatchAndDeleteUsesDelete() async throws {
        var observedMethods: [String] = []
        let repository = makeRepository { request in
            observedMethods.append(request.httpMethod ?? "")
            if request.httpMethod == "PATCH" {
                XCTAssertEqual(request.url?.path, "/api/v1/pet-weight-records/weight-1")
                let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
                let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                XCTAssertEqual(json["weight_grams"] as? Int, 4300)
                XCTAssertEqual(json["note"] as? String, "更新备注")
                return Self.recordResponse(code: "pet.weight_record_updated", message: "体重记录已更新")
            }

            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/api/v1/pet-weight-records/weight-1")
            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "pet.weight_record_deleted",
                  "message": "体重记录已删除",
                  "data": {
                    "id": "weight-1",
                    "deleted": true
                  }
                }
                """
            )
        }

        _ = try await repository.updateWeightRecord(
            recordID: "weight-1",
            draft: PetWeightRecordDraft(
                weightGrams: 4300,
                note: "更新备注",
                occurredAt: "2026-07-04T02:00:00Z"
            ),
            currentUserID: "user-1"
        )
        let deleteResponse = try await repository.deleteWeightRecord(recordID: "weight-1", currentUserID: "user-1")

        XCTAssertEqual(observedMethods, ["PATCH", "DELETE"])
        XCTAssertEqual(deleteResponse.data?.id, "weight-1")
        XCTAssertEqual(deleteResponse.data?.deleted, true)
    }

    private static func recordResponse(code: String, message: String) -> (HTTPURLResponse, Data) {
        jsonResponse(
            statusCode: 200,
            body:
            """
            {
              "success": true,
              "code": "\(code)",
              "message": "\(message)",
              "data": {
                "id": "weight-1",
                "pet_id": "pet-1",
                "weight_grams": 4250,
                "note": "饭前称重",
                "source": "manual",
                "occurred_at": "2026-07-04T01:00:00Z",
                "record_revision": 1,
                "created_at": "2026-07-04T01:00:00Z",
                "updated_at": "2026-07-04T01:00:00Z"
              }
            }
            """
        )
    }
}
