import Foundation
import XCTest
@testable import maohuoban

// PetRepositoryTradeImportContractTests 交易宠物导入仓库契约测试
// 核心职责：
// - 验证交易宠物导入请求契约
// - 验证导入结果中的宠物与事件响应解码
@MainActor
final class PetRepositoryTradeImportContractTests: PetRepositoryTestCase {
    func testImportTradePetSendsUserContextAndDecodesImport() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pets/imports/trade")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["name"] as? String, "奶盖")
            XCTAssertEqual(json?["species"] as? String, "cat")
            XCTAssertEqual(json?["breed"] as? String, "布偶")
            XCTAssertEqual(json?["sex"] as? String, "female")
            XCTAssertEqual(json?["birthday"] as? String, "2024-03-20")
            XCTAssertEqual(json?["seller_name"] as? String, "安心猫舍")
            XCTAssertEqual(json?["trade_reference"] as? String, "offline-contract-001")
            XCTAssertEqual(json?["summary"] as? String, "线下交易完成，已完成基础体检")
            XCTAssertEqual(json?["occurred_at"] as? String, "2026-06-13T10:00:00Z")

            return Self.jsonResponse(
                statusCode: 201,
                body:
                """
                {
                  "success": true,
                  "code": "pet.trade_imported",
                  "message": "交易宠物已导入",
                  "data": {
                    "pet": {
                      "id": "pet-1",
                      "owner_user_id": "user-1",
                      "name": "奶盖",
                      "species": "cat",
                      "breed": "布偶",
                      "sex": "female",
                      "birthday": "2024-03-20"
                    },
                    "event": {
                      "id": "event-1",
                      "pet_id": "pet-1",
                      "event_kind": "trade",
                      "event_subkind": "trade_imported",
                      "title": "交易宠物导入",
                      "summary": "线下交易完成，已完成基础体检",
                      "visibility": "private",
                      "occurred_at": "2026-06-13T10:00:00Z",
                      "record_revision": 1
                    }
                  }
                }
                """
            )
        }

        let response = try await repository.importTradePet(
            draft: TradePetImportDraft(
                name: "奶盖",
                species: .cat,
                breed: "布偶",
                sex: .female,
                birthday: "2024-03-20",
                sellerName: "安心猫舍",
                tradeReference: "offline-contract-001",
                summary: "线下交易完成，已完成基础体检",
                occurredAt: "2026-06-13T10:00:00Z"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "交易宠物已导入")
        XCTAssertEqual(response.data?.pet.id, "pet-1")
        XCTAssertEqual(response.data?.event.petID, "pet-1")
        XCTAssertEqual(response.data?.event.kind, .trade)
    }
}
