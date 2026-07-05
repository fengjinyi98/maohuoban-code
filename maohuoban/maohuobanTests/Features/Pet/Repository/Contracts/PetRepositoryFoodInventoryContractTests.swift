import XCTest
@testable import maohuoban

// PetRepositoryFoodInventoryContractTests 食品资产仓库契约测试
// 核心职责：
// - 固定储物柜食品资产接口路径
// - 验证列表响应 data.items 解码
@MainActor
final class PetRepositoryFoodInventoryContractTests: PetRepositoryTestCase {
    func testListFoodInventoryItemsUsesItemsEndpointAndDecodesItemsWrapper() async throws {
        var requestCount = 0
        let repository = makeRepository { request in
            requestCount += 1
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/food-inventory/items")
            XCTAssertNil(request.url?.query)
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
                    "production_date": "2025-07-15",
                    "shelf_life_months": 18,
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
        XCTAssertEqual(requestCount, 1)
    }

    func testDeleteFoodInventoryItemUsesDeleteEndpoint() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/api/v1/food-inventory/items/food-1")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "food_inventory.item_deleted",
                  "message": "食品资产已移出储物柜",
                  "data": {
                    "id": "food-1",
                    "scope_type": "user",
                    "scope_id": "user-1",
                    "created_by_user_id": "user-1",
                    "name": "当前主粮",
                    "brand": "Orijen",
                    "category": "main_food",
                    "inventory_status": "archived",
                    "quantity": 1,
                    "unit": "袋",
                    "spec": "5.4kg",
                    "production_date": "2025-07-15",
                    "shelf_life_months": 18,
                    "expiry_date": "2027-01-15",
                    "cover_asset_id": null,
                    "barcode": null,
                    "source_kind": "manual",
                    "note": null,
                    "created_at": "2026-06-25T08:00:00Z",
                    "updated_at": "2026-06-25T08:00:00Z",
                    "archived_at": "2026-07-04T08:00:00Z"
                  }
                }
                """
            )
        }

        let item = try await repository.deleteFoodInventoryItem(
            itemID: "food-1",
            currentUserID: "user-1"
        )

        XCTAssertEqual(item.id, "food-1")
        XCTAssertEqual(item.inventoryStatus, .archived)
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

    func testCreateFoodInventoryItemPostsCoverAssetID() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/food-inventory/items")
            let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["cover_asset_id"] as? String, "asset-cover-1")

            return Self.foodInventoryItemResponse(
                statusCode: 201,
                code: "food_inventory.item_created",
                coverAssetID: "asset-cover-1"
            )
        }

        var draft = FoodInventoryDraft()
        draft.name = "封面主粮"
        draft.coverAssetID = "asset-cover-1"
        let item = try await repository.createFoodInventoryItem(
            draft: draft,
            currentUserID: "user-1"
        )

        XCTAssertEqual(item.coverAssetID, "asset-cover-1")
        XCTAssertEqual(item.coverURL, "/api/v1/media/assets/asset-cover-1/content")
    }

    func testUpdateFoodInventoryItemPostsCoverAssetID() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.url?.path, "/api/v1/food-inventory/items/food-1")
            let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["cover_asset_id"] as? String, "asset-cover-2")

            return Self.foodInventoryItemResponse(
                statusCode: 200,
                code: "food_inventory.item_updated",
                coverAssetID: "asset-cover-2"
            )
        }

        var draft = FoodInventoryDraft()
        draft.name = "封面主粮"
        draft.coverAssetID = "asset-cover-2"
        let item = try await repository.updateFoodInventoryItem(
            itemID: "food-1",
            draft: draft,
            currentUserID: "user-1"
        )

        XCTAssertEqual(item.coverAssetID, "asset-cover-2")
        XCTAssertEqual(item.coverURL, "/api/v1/media/assets/asset-cover-2/content")
    }

    func testUploadFoodInventoryCoverUsesFoodInventoryMediaEndpoint() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/food-inventory/media")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-maohuoban-user-id"), "user-1")
            XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
            let body = String(data: try XCTUnwrap(request.bodyDataForPetRepositoryTest()), encoding: .utf8)
            XCTAssertTrue(body?.contains("name=\"file\"; filename=\"pantry-cover.jpg\"") == true)

            return Self.jsonResponse(
                statusCode: 201,
                body:
                """
                {
                  "success": true,
                  "code": "food_inventory.media_uploaded",
                  "message": "储物柜物品照片已上传",
                  "data": {
                    "asset": {
                      "id": "asset-cover-1",
                      "url": "/api/v1/media/assets/asset-cover-1/content",
                      "uploaded_by_user_id": "user-1",
                      "owner_pet_id": null,
                      "usage_kind": "pet.food_inventory.cover",
                      "source_client": "ios",
                      "original_file_name": "pantry-cover.jpg",
                      "mime_type": "image/jpeg",
                      "byte_size": 3,
                      "sha256_hex": "sha-cover",
                      "bucket": "maohuoban-pet-media",
                      "object_key": "media/users/user-1/asset-cover-1/original.jpg",
                      "status": "uploaded",
                      "width": 1200,
                      "height": 900,
                      "delete_after": null,
                      "deleted_at": null,
                      "created_at": "2026-07-04T08:00:00Z",
                      "updated_at": "2026-07-04T08:00:00Z"
                    },
                    "binding": null,
                    "derivatives": [],
                    "components": []
                  }
                }
                """
            )
        }

        let response = try await repository.uploadFoodInventoryCover(
            draft: PetMediaUploadDraft(
                fileName: "pantry-cover.jpg",
                mimeType: "image/jpeg",
                content: Data([1, 2, 3]),
                sourceClient: "ios"
            ),
            currentUserID: "user-1"
        ) { _ in }

        XCTAssertEqual(response.data?.asset.id, "asset-cover-1")
        XCTAssertEqual(response.data?.asset.usageKind, .foodInventoryCover)
    }

    private static func foodInventoryItemResponse(
        statusCode: Int,
        code: String,
        coverAssetID: String
    ) -> (HTTPURLResponse, Data) {
        jsonResponse(
            statusCode: statusCode,
            body:
            """
            {
              "success": true,
              "code": "\(code)",
              "message": "ok",
              "data": {
                "id": "food-1",
                "scope_type": "user",
                "scope_id": "user-1",
                "created_by_user_id": "user-1",
                "name": "封面主粮",
                "brand": null,
                "category": "main_food",
                "inventory_status": "sealed",
                "quantity": 1,
                "unit": null,
                "spec": null,
                "production_date": "2026-01-01",
                "shelf_life_months": 18,
                "expiry_date": "2027-07-01",
                "cover_asset_id": "\(coverAssetID)",
                "cover_url": "/api/v1/media/assets/\(coverAssetID)/content",
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
}
