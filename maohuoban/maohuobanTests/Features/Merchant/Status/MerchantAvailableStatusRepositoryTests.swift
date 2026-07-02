import XCTest
@testable import maohuoban

// MerchantAvailableStatusRepositoryTests 商家可售状态仓库测试
// 核心职责：
// - 固化发布可售状态请求契约
// - 验证发布响应中的宠物与事件解码行为
@MainActor
final class MerchantAvailableStatusRepositoryTests: MerchantRepositoryTestCase {
    func testPublishAvailableStatusSendsDraftAndUserContext() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(
                request.url?.path,
                "/api/v1/merchants/merchant-1/pets/pet-1/available-status"
            )
            Self.assertAuthorizationHeader(request)

            let body = try Self.requestBodyData(request)
            XCTAssertFalse(body.isEmpty)
            let json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(json["summary"] as? String, "已完成基础健康记录，可预约到店看猫。")
            XCTAssertEqual(json["occurred_at"] as? String, "2026-06-14T10:00:00Z")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "merchant.available_status_published",
                  "message": "可售状态已发布",
                  "data": {
                    "pet": {
                      "id": "pet-1",
                      "owner_user_id": null,
                      "merchant_id": "merchant-1",
                      "name": "小白",
                      "species": "cat",
                      "breed": "布偶猫",
                      "sex": "unknown",
                      "birthday": "2026-03-18",
                      "managed_status": "available",
                      "source_kind": "litter_birth",
                      "created_at": "2026-06-13T09:20:00Z",
                      "updated_at": "2026-06-14T10:00:00Z"
                    },
                    "event": {
                      "id": "event-1",
                      "pet_id": "pet-1",
                      "litter_id": null,
                      "event_kind": "merchant",
                      "event_subkind": "available_status",
                      "title": "已发布可售状态",
                      "summary": "已完成基础健康记录，可预约到店看猫。",
                      "visibility": "buyer_visible",
                      "occurred_at": "2026-06-14T10:00:00Z",
                      "record_revision": 1
                    }
                  }
                }
                """
            )
        }

        let response = try await repository.publishAvailableStatus(
            merchantID: "merchant-1",
            petID: "pet-1",
            draft: MerchantAvailableStatusDraft(
                summary: "已完成基础健康记录，可预约到店看猫。",
                occurredAt: "2026-06-14T10:00:00Z"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "可售状态已发布")
        XCTAssertEqual(response.data?.pet.managedStatus, .available)
        XCTAssertEqual(response.data?.event.kind, .merchant)
        XCTAssertEqual(response.data?.event.visibility, .buyerVisible)
    }
}
