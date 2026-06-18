import Foundation
import XCTest
@testable import maohuoban

// PetRepositoryProfileContractTests 宠物档案仓库契约测试
// 核心职责：
// - 验证宠物档案创建、更新与删除请求契约
// - 验证宠物档案响应解码行为
@MainActor
final class PetRepositoryProfileContractTests: PetRepositoryTestCase {
    func testCreatePetSendsUserContextAndDecodesProfile() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pets")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["name"] as? String, "糯米")
            XCTAssertEqual(json?["species"] as? String, "dog")
            XCTAssertEqual(json?["breed"] as? String, "比熊犬")
            XCTAssertEqual(json?["sex"] as? String, "female")
            XCTAssertEqual(json?["birthday"] as? String, "2024-04-01")
            XCTAssertEqual(json?["microchip_number"] as? String, "156000000000001")
            XCTAssertEqual(json?["arrival_date"] as? String, "2024-05-01")
            XCTAssertEqual(json?["weight_grams"] as? Int, 4200)
            XCTAssertEqual(json?["neuter_status"] as? String, "neutered")
            XCTAssertEqual(json?["personality_tags"] as? [String], ["亲人", "爱玩"])
            XCTAssertEqual(json?["note"] as? String, "对鸡肉过敏")
            XCTAssertEqual(json?["avatar_asset_id"] as? String, "avatar-asset-1")
            XCTAssertEqual(json?["background_asset_id"] as? String, "background-asset-1")

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
                    "birthday": "2024-04-01",
                    "microchip_number": "156000000000001",
                    "arrival_date": "2024-05-01",
                    "weight_grams": 4200,
                    "neuter_status": "neutered",
                    "personality_tags": ["亲人", "爱玩"],
                    "note": "对鸡肉过敏",
                    "avatar_asset_id": "avatar-asset-1",
                    "background_asset_id": "background-asset-1",
                    "background_media_kind": "image",
                    "name_edit_policy": {
                      "max_count": 5,
                      "used_count": 0,
                      "remaining_count": 5,
                      "window_days": 30,
                      "window_ends_at": null,
                      "display_text": "30 天内最多修改 5 次名字。"
                    }
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
                birthday: "2024-04-01",
                microchipNumber: "156000000000001",
                arrivalDate: "2024-05-01",
                weightGrams: 4200,
                neuterStatus: .neutered,
                personalityTags: ["亲人", "爱玩"],
                note: "对鸡肉过敏",
                avatarAssetID: "avatar-asset-1",
                backgroundAssetID: "background-asset-1"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "宠物档案已创建")
        XCTAssertEqual(response.data?.id, "pet-1")
        XCTAssertEqual(response.data?.ownerUserID, "user-1")
        XCTAssertEqual(response.data?.arrivalDate, "2024-05-01")
        XCTAssertEqual(response.data?.personalityTags, ["亲人", "爱玩"])
        XCTAssertEqual(response.data?.avatarAssetID, "avatar-asset-1")
        XCTAssertEqual(response.data?.backgroundAssetID, "background-asset-1")
        XCTAssertEqual(response.data?.backgroundMediaKind, .image)
        XCTAssertEqual(response.data?.nameEditPolicy?.remainingCount, 5)
        XCTAssertEqual(response.data?.nameEditPolicy?.displayText, "30 天内最多修改 5 次名字。")
    }

    func testUpdatePetSendsExtendedProfileFieldsAndDecodesProfile() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.url?.path, "/api/v1/pets/pet-1")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["name"] as? String, "奶盖宝")
            XCTAssertEqual(json?["microchip_number"] as? String, "156000000000001")
            XCTAssertEqual(json?["arrival_date"] as? String, "2024-05-01")
            XCTAssertEqual(json?["weight_grams"] as? Int, 4350)
            XCTAssertEqual(json?["neuter_status"] as? String, "neutered")
            XCTAssertEqual(json?["personality_tags"] as? [String], ["亲人", "安静"])
            XCTAssertEqual(json?["note"] as? String, "鸡肉过敏")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "pet.updated",
                  "message": "宠物档案已更新",
                  "data": {
                    "id": "pet-1",
                    "owner_user_id": "user-1",
                    "name": "奶盖宝",
                    "species": "cat",
                    "breed": "布偶猫",
                    "sex": "female",
                    "birthday": "2024-03-20",
                    "profile_number": "0000000000000001",
                    "microchip_number": "156000000000001",
                    "arrival_date": "2024-05-01",
                    "weight_grams": 4350,
                    "neuter_status": "neutered",
                    "personality_tags": ["亲人", "安静"],
                    "note": "鸡肉过敏",
                    "name_edit_policy": {
                      "max_count": 5,
                      "used_count": 1,
                      "remaining_count": 4,
                      "window_days": 30,
                      "window_ends_at": "2026-07-17T00:00:00Z",
                      "display_text": "7月17日前还可以修改 4 次名字。"
                    }
                  }
                }
                """
            )
        }

        let response = try await repository.updatePet(
            petID: "pet-1",
            draft: PetProfileUpdateDraft(
                name: "奶盖宝",
                species: .cat,
                breed: "布偶猫",
                sex: .female,
                birthday: "2024-03-20",
                microchipNumber: "156000000000001",
                arrivalDate: "2024-05-01",
                weightGrams: 4350,
                neuterStatus: .neutered,
                personalityTags: ["亲人", "安静"],
                note: "鸡肉过敏"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "宠物档案已更新")
        XCTAssertEqual(response.data?.profileNumber, "0000000000000001")
        XCTAssertEqual(response.data?.microchipNumber, "156000000000001")
        XCTAssertEqual(response.data?.weightGrams, 4350)
        XCTAssertEqual(response.data?.nameEditPolicy?.usedCount, 1)
        XCTAssertEqual(response.data?.nameEditPolicy?.remainingCount, 4)
    }

    func testDeletePetSendsReasonAndDecodesRecoverableProfile() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.url?.path, "/api/v1/pets/pet-1")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["reason"] as? String, "用户主动删除")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "pet.deleted",
                  "message": "宠物档案已删除",
                  "data": {
                    "id": "pet-1",
                    "owner_user_id": "user-1",
                    "name": "豆包",
                    "species": "cat",
                    "breed": null,
                    "sex": "unknown",
                    "birthday": null,
                    "profile_number": "0000000000000002",
                    "deleted_at": "2026-06-17T00:00:00Z",
                    "delete_requested_by_user_id": "user-1",
                    "recoverable_until": "2026-07-17T00:00:00Z",
                    "delete_reason": "用户主动删除"
                  }
                }
                """
            )
        }

        let response = try await repository.deletePet(
            petID: "pet-1",
            reason: "用户主动删除",
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "宠物档案已删除")
        XCTAssertEqual(response.data?.deletedAt, "2026-06-17T00:00:00Z")
        XCTAssertEqual(response.data?.recoverableUntil, "2026-07-17T00:00:00Z")
    }
}
