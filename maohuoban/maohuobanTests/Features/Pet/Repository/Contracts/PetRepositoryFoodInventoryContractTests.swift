import XCTest
@testable import maohuoban

// PetRepositoryFoodInventoryContractTests 食品资产仓库契约测试
// 核心职责：
// - 固定储物柜食品资产接口路径
// - 验证列表响应 data.items 解码
@MainActor
final class PetRepositoryFoodInventoryContractTests: PetRepositoryTestCase {
    func testListFoodInventoryItemsUsesItemsEndpointAndDecodesItemsWrapper() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/food-inventory/items")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

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
                    ]
                  }
                }
                """
            )
        }

        let items = try await repository.listFoodInventoryItems(currentUserID: "user-1")

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].id, "food-1")
        XCTAssertEqual(items[0].name, "渴望六种鱼")
        XCTAssertEqual(items[0].category, .mainFood)
    }

    func testListFoodInventoryItemsAlsoLoadsArchivedItemsForRestoreEntry() async throws {
        var requestedQueries: [String?] = []
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/food-inventory/items")
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

    func testSetPetCurrentStaplePostsDietStapleEndpoint() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pets/pet-1/diet/staple")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["food_item_id"] as? String, "food-1")
            XCTAssertEqual(json["reason"] as? String, "用户设置当前主粮")

            return Self.jsonResponse(
                statusCode: 201,
                body:
                """
                {
                  "success": true,
                  "code": "pet.current_staple_set",
                  "message": "当前主粮已设置",
                  "data": {
                    "id": "assignment-1",
                    "pet_id": "pet-1",
                    "food_item_id": "food-1",
                    "role": "current_staple",
                    "status": "active",
                    "started_at": "2026-06-25T08:00:00Z",
                    "ended_at": null,
                    "reason": "用户设置当前主粮",
                    "created_by_user_id": "user-1",
                    "created_at": "2026-06-25T08:00:00Z",
                    "updated_at": "2026-06-25T08:00:00Z"
                  }
                }
                """
            )
        }

        let assignment = try await repository.setPetCurrentStaple(
            petID: "pet-1",
            foodItemID: "food-1",
            currentUserID: "user-1"
        )

        XCTAssertEqual(assignment.id, "assignment-1")
        XCTAssertEqual(assignment.petID, "pet-1")
        XCTAssertEqual(assignment.foodItemID, "food-1")
        XCTAssertEqual(assignment.role, "current_staple")
    }

    func testSetPetFoodAssignmentPostsDietAssignmentsEndpoint() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pets/pet-1/diet/assignments")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["food_item_id"] as? String, "food-2")
            XCTAssertEqual(json["role"] as? String, "trying")
            XCTAssertEqual(json["reason"] as? String, "用户设置饮食配置")

            return Self.jsonResponse(
                statusCode: 201,
                body:
                """
                {
                  "success": true,
                  "code": "pet.diet_assignment_set",
                  "message": "饮食配置已设置",
                  "data": {
                    "id": "assignment-2",
                    "pet_id": "pet-1",
                    "food_item_id": "food-2",
                    "role": "trying",
                    "status": "active",
                    "started_at": "2026-06-25T08:00:00Z",
                    "ended_at": null,
                    "reason": "用户设置饮食配置",
                    "created_by_user_id": "user-1",
                    "created_at": "2026-06-25T08:00:00Z",
                    "updated_at": "2026-06-25T08:00:00Z"
                  }
                }
                """
            )
        }

        let assignment = try await repository.setPetFoodAssignment(
            petID: "pet-1",
            foodItemID: "food-2",
            role: .trying,
            currentUserID: "user-1"
        )

        XCTAssertEqual(assignment.id, "assignment-2")
        XCTAssertEqual(assignment.foodItemID, "food-2")
        XCTAssertEqual(assignment.role, "trying")
    }
}
