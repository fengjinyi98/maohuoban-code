import XCTest
@testable import maohuoban

// PetRepositoryFoodInventoryRestoreContractTests 食品资产恢复仓库契约测试
// 核心职责：
// - 固定食品资产恢复接口路径
// - 验证恢复请求提交目标库存状态
@MainActor
final class PetRepositoryFoodInventoryRestoreContractTests: PetRepositoryTestCase {
    func testListFoodInventoryItemsAlsoLoadsArchivedItemsForRestoreEntry() async throws {
        var requestedQueries: [String?] = []
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/food-inventory/items")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
            requestedQueries.append(request.url?.query)

            if request.url?.query == "status=archived" {
                return Self.jsonResponse(
                    statusCode: 200,
                    body:
                    """
                    {
                      "success": true,
                      "code": "food_inventory.list_loaded",
                      "message": "食品资产列表已加载",
                      "data": {
                        "items": [
                          {
                            "id": "food-archived",
                            "scope_type": "user",
                            "scope_id": "user-1",
                            "created_by_user_id": "user-1",
                            "name": "归档主粮",
                            "brand": "Orijen",
                            "category": "main_food",
                            "inventory_status": "archived",
                            "quantity": 1,
                            "unit": "袋",
                            "spec": "5.4kg",
                            "expiry_date": "2027-01-15",
                            "cover_asset_id": null,
                            "barcode": null,
                            "source_kind": "manual",
                            "note": null,
                            "created_at": "2026-06-25T08:00:00Z",
                            "updated_at": "2026-06-25T08:00:00Z",
                            "archived_at": "2026-06-26T08:00:00Z"
                          }
                        ]
                      }
                    }
                    """
                )
            }

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "food_inventory.list_loaded",
                  "message": "食品资产列表已加载",
                  "data": {
                    "items": [
                      {
                        "id": "food-active",
                        "scope_type": "user",
                        "scope_id": "user-1",
                        "created_by_user_id": "user-1",
                        "name": "当前主粮",
                        "brand": "Orijen",
                        "category": "main_food",
                        "inventory_status": "in_use",
                        "quantity": 1,
                        "unit": "袋",
                        "spec": "5.4kg",
                        "expiry_date": "2027-01-15",
                        "cover_asset_id": null,
                        "barcode": null,
                        "source_kind": "manual",
                        "note": null,
                        "created_at": "2026-06-25T08:00:00Z",
                        "updated_at": "2026-06-25T08:00:00Z",
                        "archived_at": null
                      }
                    ]
                  }
                }
                """
            )
        }

        let items = try await repository.listFoodInventoryItems(currentUserID: "user-1")

        XCTAssertEqual(requestedQueries, [nil, "status=archived"])
        XCTAssertEqual(items.map(\.id), ["food-active", "food-archived"])
        XCTAssertEqual(items.last?.archivedAt, "2026-06-26T08:00:00Z")
    }

    func testRestoreFoodInventoryItemPostsRestoreEndpoint() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/food-inventory/items/food-1/restore")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["inventory_status"] as? String, "sealed")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "food_inventory.item_restored",
                  "message": "食品资产已恢复",
                  "data": {
                    "id": "food-1",
                    "scope_type": "user",
                    "scope_id": "user-1",
                    "created_by_user_id": "user-1",
                    "name": "渴望六种鱼",
                    "brand": "Orijen",
                    "category": "main_food",
                    "inventory_status": "sealed",
                    "quantity": 1,
                    "unit": "袋",
                    "spec": "5.4kg",
                    "expiry_date": "2027-01-15",
                    "cover_asset_id": null,
                    "barcode": null,
                    "source_kind": "manual",
                    "note": null,
                    "created_at": "2026-06-25T08:00:00Z",
                    "updated_at": "2026-06-25T08:00:00Z",
                    "archived_at": null
                  }
                }
                """
            )
        }

        let item = try await repository.restoreFoodInventoryItem(
            itemID: "food-1",
            status: .sealed,
            currentUserID: "user-1"
        )

        XCTAssertEqual(item.id, "food-1")
        XCTAssertEqual(item.inventoryStatus, .sealed)
        XCTAssertNil(item.archivedAt)
    }
}
