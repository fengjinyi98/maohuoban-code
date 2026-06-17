import XCTest
import MaohuobanDiagnostics
@testable import maohuoban

// PetRepositoryTests 宠物写入仓库测试
// 核心职责：
// - 固化 iOS 到 Rust 宠物接口的请求契约
// - 验证当前用户上下文通过请求头传递
@MainActor
final class PetRepositoryTests: XCTestCase {
    override func tearDown() {
        PetRepositoryURLProtocol.handler = nil
        Task {
            await Diagnostics.uninstall()
        }
        super.tearDown()
    }

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

    func testPetWriteDraftsRemoveWhitespaceFromPetNameAndBreed() throws {
        let createJSON = try Self.encodedJSONObject(
            PetProfileDraft(
                name: " 奶 盖 宝 宝 兔 兔 ",
                species: .cat,
                breed: " 英 国 长 毛 猫 稀 有 毛 色 版 本 ",
                sex: .female,
                birthday: "2024-04-01"
            )
        )
        XCTAssertEqual(createJSON["name"] as? String, "奶盖宝宝兔兔")
        XCTAssertEqual(createJSON["breed"] as? String, "英国长毛猫稀有毛色版本")

        let updateJSON = try Self.encodedJSONObject(
            PetProfileUpdateDraft(
                name: " 奶 盖 宝 宝 兔 兔 ",
                species: .cat,
                breed: " 超 长 长 长 长 长 长 长 长 长 长 品 种 ",
                sex: .female,
                birthday: "2024-04-01",
                microchipNumber: "",
                arrivalDate: "",
                weightGrams: nil,
                neuterStatus: .unknown,
                personalityTags: [],
                note: ""
            )
        )
        XCTAssertEqual(updateJSON["name"] as? String, "奶盖宝宝兔兔")
        XCTAssertEqual(updateJSON["breed"] as? String, "超长长长长长长长长长长品种")

        let tradeJSON = try Self.encodedJSONObject(
            TradePetImportDraft(
                name: " 奶 盖 宝 宝 兔 兔 ",
                species: .cat,
                breed: " 布 偶 猫 长 毛 系 ",
                sex: .female,
                birthday: "2024-03-20",
                sellerName: "安心猫舍",
                tradeReference: "offline-contract-001",
                summary: "线下交易完成",
                occurredAt: "2026-06-13T10:00:00Z"
            )
        )
        XCTAssertEqual(tradeJSON["name"] as? String, "奶盖宝宝兔兔")
        XCTAssertEqual(tradeJSON["breed"] as? String, "布偶猫长毛系")
    }

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

    func testCreateEventSendsUserContextAndDecodesEvent() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pets/pet-1/events")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["event_kind"] as? String, "health")
            XCTAssertEqual(json?["event_subkind"] as? String, "weight")
            XCTAssertEqual(json?["title"] as? String, "体重记录")
            XCTAssertEqual(json?["summary"] as? String, "5.2kg，较上次稳定")
            XCTAssertEqual(json?["visibility"] as? String, "private")
            XCTAssertEqual(json?["occurred_at"] as? String, "2026-06-13T09:20:00Z")

            return Self.jsonResponse(
                statusCode: 201,
                body:
                """
                {
                  "success": true,
                  "code": "pet.event_created",
                  "message": "宠物事件已记录",
                    "data": {
                      "id": "event-1",
                      "pet_id": "pet-1",
                      "litter_id": null,
                      "event_kind": "health",
                      "event_subkind": "weight",
                      "title": "体重记录",
                      "summary": "5.2kg，较上次稳定",
                      "visibility": "private",
                      "event_payload": {
                        "weight_kg": 5.2
                      },
                      "occurred_at": "2026-06-13T09:20:00Z",
                      "record_revision": 1
                    }
                }
                """
            )
        }

        let response = try await repository.createEvent(
            petID: "pet-1",
            draft: PetEventDraft(
                kind: .health,
                subkind: "weight",
                title: "体重记录",
                summary: "5.2kg，较上次稳定",
                visibility: .private,
                occurredAt: "2026-06-13T09:20:00Z"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "宠物事件已记录")
        XCTAssertEqual(response.data?.petID, "pet-1")
        XCTAssertEqual(response.data?.recordRevision, 1)
    }

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

    func testLoadEventDetailSendsUserContextAndDecodesEvent() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/pet-events/event-1")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            return Self.jsonResponse(
                statusCode: 200,
                body:
                """
                {
                  "success": true,
                  "code": "pet.event_loaded",
                  "message": "宠物事件已加载",
                  "data": {
                    "id": "event-1",
                    "pet_id": "pet-1",
                    "event_kind": "health",
                    "event_subkind": "weight",
                    "title": "体重记录",
                    "summary": "5.2kg，较上次稳定",
                    "visibility": "private",
                    "occurred_at": "2026-06-13T09:20:00Z",
                    "record_revision": 1
                  }
                }
                """
            )
        }

        let response = try await repository.loadEventDetail(
            eventID: "event-1",
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "宠物事件已加载")
        XCTAssertEqual(response.data?.id, "event-1")
        XCTAssertEqual(response.data?.petID, "pet-1")
        XCTAssertNil(response.data?.litterID)
        XCTAssertEqual(response.data?.title, "体重记录")
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

    func testUploadPendingAvatarSendsUserContextAndDecodesUnboundAssetURL() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pet-media/avatar")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            try Self.assertMultipartMediaRequest(
                request,
                fileName: "avatar.png",
                mimeType: "image/png",
                contentText: "avatar-bytes",
                sourceClient: "ios"
            )

            return Self.jsonResponse(
                statusCode: 201,
                body:
                """
                {
                  "success": true,
                  "code": "pet.media_uploaded",
                  "message": "媒体已上传",
                  "data": {
                    "asset": {
                      "id": "asset-1",
                      "url": "/api/v1/media/assets/asset-1/content",
                      "uploaded_by_user_id": "user-1",
                      "owner_pet_id": null,
                      "usage_kind": "pet.avatar",
                      "source_client": "ios",
                      "original_file_name": "avatar.png",
                      "mime_type": "image/png",
                      "byte_size": 12,
                      "sha256_hex": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                      "bucket": "maohuoban-pet-media",
                      "object_key": "pet-media/pet/avatar/asset-1/avatar.png",
                      "status": "uploaded",
                      "width": 96,
                      "height": 96,
                      "created_at": "2026-06-17T00:00:00Z",
                      "updated_at": "2026-06-17T00:00:00Z"
                    },
                    "binding": null,
                    "derivatives": []
                  }
                }
                """
            )
        }

        let response = try await repository.uploadPendingAvatar(
            draft: PetMediaUploadDraft(
                fileName: "avatar.png",
                mimeType: "image/png",
                content: Data("avatar-bytes".utf8),
                sourceClient: "ios"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "媒体已上传")
        XCTAssertEqual(response.data?.asset.id, "asset-1")
        XCTAssertEqual(response.data?.asset.url, "/api/v1/media/assets/asset-1/content")
        XCTAssertNil(response.data?.asset.ownerPetID)
        XCTAssertEqual(response.data?.asset.status, .uploaded)
        XCTAssertEqual(response.data?.asset.width, 96)
        XCTAssertEqual(response.data?.asset.height, 96)
        XCTAssertNil(response.data?.binding)
    }

    func testBindUploadedMediaSendsAssetIDAndDecodesMediaBinding() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pets/pet-1/media-bindings")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")

            let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["asset_id"] as? String, "asset-1")

            return Self.mediaUploadResponse(
                usageKind: "pet.avatar",
                objectKey: "pets/pet-1/pet/avatar/asset-1/avatar.png"
            )
        }

        let response = try await repository.bindUploadedMedia(
            petID: "pet-1",
            assetID: "asset-1",
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.data?.asset.status, .bound)
        XCTAssertEqual(response.data?.binding?.petID, "pet-1")
    }

    func testUploadPendingBackgroundImageSendsUserContextAndDecodesUnboundAsset() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pet-media/background-image")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
            try Self.assertMultipartMediaRequest(
                request,
                fileName: "background.jpg",
                mimeType: "image/jpeg",
                contentText: "image-bytes",
                sourceClient: "ios"
            )

            return Self.pendingMediaUploadResponse(
                usageKind: "pet.background.image",
                objectKey: "pet-media/pet/background/image/asset-1/background.jpg"
            )
        }

        let response = try await repository.uploadPendingBackgroundImage(
            draft: PetMediaUploadDraft(
                fileName: "background.jpg",
                mimeType: "image/jpeg",
                content: Data("image-bytes".utf8),
                sourceClient: "ios"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "媒体已上传")
        XCTAssertEqual(response.data?.asset.usageKind, .backgroundImage)
        XCTAssertNil(response.data?.asset.ownerPetID)
        XCTAssertEqual(response.data?.asset.status, .uploaded)
        XCTAssertEqual(response.data?.asset.width, 1280)
        XCTAssertEqual(response.data?.asset.height, 720)
        XCTAssertNil(response.data?.binding)
        XCTAssertEqual(response.data?.derivatives.count, 2)
        XCTAssertEqual(response.data?.themeColorHex, "#FF0000")
    }

    func testUploadPendingBackgroundVideoSendsUserContextAndDecodesUnboundAsset() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pet-media/background-video")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
            try Self.assertMultipartMediaRequest(
                request,
                fileName: "background.mp4",
                mimeType: "video/mp4",
                contentText: "video-bytes",
                sourceClient: "ios"
            )

            return Self.pendingMediaUploadResponse(
                usageKind: "pet.background.video",
                objectKey: "pet-media/pet/background/video/asset-1/background.mp4"
            )
        }

        let response = try await repository.uploadPendingBackgroundVideo(
            draft: PetMediaUploadDraft(
                fileName: "background.mp4",
                mimeType: "video/mp4",
                content: Data("video-bytes".utf8),
                sourceClient: "ios"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "媒体已上传")
        XCTAssertEqual(response.data?.asset.usageKind, .backgroundVideo)
        XCTAssertNil(response.data?.asset.ownerPetID)
        XCTAssertEqual(response.data?.asset.status, .uploaded)
        XCTAssertEqual(response.data?.asset.width, 1280)
        XCTAssertEqual(response.data?.asset.height, 720)
        XCTAssertNil(response.data?.binding)
        XCTAssertEqual(response.data?.coverFrame?.objectKey, "pets/pet-1/cover-frame.png")
    }

    func testUploadPendingBackgroundLivePhotoSendsPairedResourcesAndDecodesComponents() async throws {
        let repository = makeRepository { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/pet-media/background-live-photo")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access-token")
            try Self.assertMultipartLivePhotoRequest(
                request,
                stillFileName: "background.heic",
                stillMimeType: "image/heic",
                stillContentText: "still-bytes",
                pairedVideoFileName: "background.mov",
                pairedVideoMimeType: "video/quicktime",
                pairedVideoContentText: "video-bytes",
                sourceClient: "ios"
            )

            return Self.pendingLivePhotoUploadResponse()
        }

        let response = try await repository.uploadPendingBackgroundLivePhoto(
            draft: PetLivePhotoUploadDraft(
                still: PetMediaUploadDraft(
                    fileName: "background.heic",
                    mimeType: "image/heic",
                    content: Data("still-bytes".utf8),
                    sourceClient: "ios"
                ),
                pairedVideo: PetMediaUploadDraft(
                    fileName: "background.mov",
                    mimeType: "video/quicktime",
                    content: Data("video-bytes".utf8),
                    sourceClient: "ios"
                )
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(response.message, "媒体已上传")
        XCTAssertEqual(response.data?.asset.usageKind, .backgroundLivePhoto)
        XCTAssertEqual(response.data?.components.count, 2)
        XCTAssertTrue(response.data?.components.contains { component in
            component.componentKind == .still
                && component.url == "/api/v1/media/assets/asset-1/components/component-still/content"
                && component.width == 1200
                && component.height == 1600
        } == true)
        XCTAssertTrue(response.data?.components.contains { component in
            component.componentKind == .pairedVideo
                && component.url == "/api/v1/media/assets/asset-1/components/component-video/content"
                && component.durationMS == 1800
        } == true)
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

    private func makeRepository(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> DefaultPetRepository {
        let client = makeHTTPClient(handler: handler)
        return DefaultPetRepository(
            client: client,
            authorizationHeaderProvider: MHBAuthorizationHeaderProvider(
                tokenStore: PetRepositoryTestTokenStore()
            )
        )
    }

    private func makeHTTPClient(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> MHBHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PetRepositoryURLProtocol.self]
        PetRepositoryURLProtocol.handler = handler
        let session = URLSession(configuration: configuration)
        return MHBHTTPClient(baseURL: URL(string: "http://127.0.0.1:18080")!, session: session)
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

    private static func mediaUploadResponse(
        usageKind: String,
        objectKey: String
    ) -> (HTTPURLResponse, Data) {
        jsonResponse(
            statusCode: 201,
            body:
            """
            {
              "success": true,
              "code": "pet.background_uploaded",
              "message": "宠物背景已上传",
              "data": {
                "asset": {
                  "id": "asset-1",
                  "uploaded_by_user_id": "user-1",
                  "owner_pet_id": "pet-1",
                  "usage_kind": "\(usageKind)",
                  "source_client": "ios",
                  "original_file_name": "background",
                  "mime_type": "application/octet-stream",
                  "byte_size": 12,
                  "sha256_hex": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                  "bucket": "maohuoban-pet-media",
                  "object_key": "\(objectKey)",
                  "status": "bound",
                  "width": 1280,
                  "height": 720,
                  "created_at": "2026-06-17T00:00:00Z",
                  "updated_at": "2026-06-17T00:00:00Z"
                },
                "binding": {
                  "id": "binding-1",
                  "asset_id": "asset-1",
                  "pet_id": "pet-1",
                  "usage_kind": "\(usageKind)",
                  "status": "active",
                  "bound_by_user_id": "user-1",
                  "bound_at": "2026-06-17T00:00:00Z",
                  "created_at": "2026-06-17T00:00:00Z"
                },
                "derivatives": [
                  {
                    "id": "derivative-1",
                    "parent_asset_id": "asset-1",
                    "derivative_kind": "video_cover_frame",
                    "bucket": "maohuoban-pet-media",
                    "object_key": "pets/pet-1/cover-frame.png",
                    "mime_type": "image/png",
                    "byte_size": 12,
                    "sha256_hex": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                    "metadata": {
                      "width": 512,
                      "height": 512
                    },
                    "created_at": "2026-06-17T00:00:00Z"
                  },
                  {
                    "id": "derivative-2",
                    "parent_asset_id": "asset-1",
                    "derivative_kind": "theme_color_frame",
                    "bucket": "maohuoban-pet-media",
                    "object_key": "pets/pet-1/theme-color.json",
                    "mime_type": "application/json",
                    "byte_size": 24,
                    "sha256_hex": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
                    "metadata": {
                      "theme_color_hex": "#FF0000"
                    },
                    "created_at": "2026-06-17T00:00:00Z"
                  }
                ]
              }
            }
            """
        )
    }

    private static func pendingMediaUploadResponse(
        usageKind: String,
        objectKey: String
    ) -> (HTTPURLResponse, Data) {
        jsonResponse(
            statusCode: 201,
            body:
            """
            {
              "success": true,
              "code": "pet.media_uploaded",
              "message": "媒体已上传",
              "data": {
                "asset": {
                  "id": "asset-1",
                  "url": "/api/v1/media/assets/asset-1/content",
                  "uploaded_by_user_id": "user-1",
                  "owner_pet_id": null,
                  "usage_kind": "\(usageKind)",
                  "source_client": "ios",
                  "original_file_name": "background",
                  "mime_type": "application/octet-stream",
                  "byte_size": 12,
                  "sha256_hex": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                  "bucket": "maohuoban-pet-media",
                  "object_key": "\(objectKey)",
                  "status": "uploaded",
                  "width": 1280,
                  "height": 720,
                  "created_at": "2026-06-17T00:00:00Z",
                  "updated_at": "2026-06-17T00:00:00Z"
                },
                "binding": null,
                "derivatives": [
                  {
                    "id": "derivative-1",
                    "parent_asset_id": "asset-1",
                    "derivative_kind": "video_cover_frame",
                    "bucket": "maohuoban-pet-media",
                    "object_key": "pets/pet-1/cover-frame.png",
                    "mime_type": "image/png",
                    "byte_size": 12,
                    "sha256_hex": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                    "metadata": {
                      "width": 512,
                      "height": 512
                    },
                    "created_at": "2026-06-17T00:00:00Z"
                  },
                  {
                    "id": "derivative-2",
                    "parent_asset_id": "asset-1",
                    "derivative_kind": "theme_color_frame",
                    "bucket": "maohuoban-pet-media",
                    "object_key": "pets/pet-1/theme-color.json",
                    "mime_type": "application/json",
                    "byte_size": 24,
                    "sha256_hex": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
                    "metadata": {
                      "theme_color_hex": "#FF0000"
                    },
                    "created_at": "2026-06-17T00:00:00Z"
                  }
                ]
              }
            }
            """
        )
    }

    private static func pendingLivePhotoUploadResponse() -> (HTTPURLResponse, Data) {
        jsonResponse(
            statusCode: 201,
            body:
            """
            {
              "success": true,
              "code": "pet.media_uploaded",
              "message": "媒体已上传",
              "data": {
                "asset": {
                  "id": "asset-1",
                  "url": null,
                  "uploaded_by_user_id": "user-1",
                  "owner_pet_id": null,
                  "usage_kind": "pet.background.live_photo",
                  "source_client": "ios",
                  "original_file_name": "background.heic",
                  "mime_type": "image/heic",
                  "byte_size": 32,
                  "sha256_hex": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                  "bucket": "maohuoban-pet-media",
                  "object_key": "pet-media/pet/background/live-photo/asset-1/background.heic",
                  "status": "uploaded",
                  "width": 1200,
                  "height": 1600,
                  "created_at": "2026-06-17T00:00:00Z",
                  "updated_at": "2026-06-17T00:00:00Z"
                },
                "binding": null,
                "components": [
                  {
                    "id": "component-still",
                    "asset_id": "asset-1",
                    "url": "/api/v1/media/assets/asset-1/components/component-still/content",
                    "component_kind": "still",
                    "bucket": "maohuoban-pet-media",
                    "object_key": "pet-media/pet/background/live-photo/asset-1/still.heic",
                    "mime_type": "image/heic",
                    "byte_size": 12,
                    "sha256_hex": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
                    "width": 1200,
                    "height": 1600,
                    "duration_ms": null,
                    "created_at": "2026-06-17T00:00:00Z"
                  },
                  {
                    "id": "component-video",
                    "asset_id": "asset-1",
                    "url": "/api/v1/media/assets/asset-1/components/component-video/content",
                    "component_kind": "paired_video",
                    "bucket": "maohuoban-pet-media",
                    "object_key": "pet-media/pet/background/live-photo/asset-1/paired.mov",
                    "mime_type": "video/quicktime",
                    "byte_size": 20,
                    "sha256_hex": "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
                    "width": 1200,
                    "height": 1600,
                    "duration_ms": 1800,
                    "created_at": "2026-06-17T00:00:00Z"
                  }
                ],
                "derivatives": []
              }
            }
            """
        )
    }

    private static func assertMultipartMediaRequest(
        _ request: URLRequest,
        fileName: String,
        mimeType: String,
        contentText: String,
        sourceClient: String
    ) throws {
        let contentType = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))
        let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
        let bodyText = String(decoding: body, as: UTF8.self)

        XCTAssertTrue(
            bodyText.contains("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"")
        )
        XCTAssertTrue(bodyText.contains("Content-Type: \(mimeType)"))
        XCTAssertTrue(bodyText.contains(contentText))
        XCTAssertTrue(bodyText.contains("Content-Disposition: form-data; name=\"source_client\""))
        XCTAssertTrue(bodyText.contains(sourceClient))
    }

    private static func assertMultipartLivePhotoRequest(
        _ request: URLRequest,
        stillFileName: String,
        stillMimeType: String,
        stillContentText: String,
        pairedVideoFileName: String,
        pairedVideoMimeType: String,
        pairedVideoContentText: String,
        sourceClient: String
    ) throws {
        let contentType = try XCTUnwrap(request.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))
        let body = try XCTUnwrap(request.bodyDataForPetRepositoryTest())
        let bodyText = String(decoding: body, as: UTF8.self)

        XCTAssertTrue(
            bodyText.contains("Content-Disposition: form-data; name=\"still_file\"; filename=\"\(stillFileName)\"")
        )
        XCTAssertTrue(bodyText.contains("Content-Type: \(stillMimeType)"))
        XCTAssertTrue(bodyText.contains(stillContentText))
        XCTAssertTrue(
            bodyText.contains(
                "Content-Disposition: form-data; name=\"paired_video_file\"; filename=\"\(pairedVideoFileName)\""
            )
        )
        XCTAssertTrue(bodyText.contains("Content-Type: \(pairedVideoMimeType)"))
        XCTAssertTrue(bodyText.contains(pairedVideoContentText))
        XCTAssertTrue(bodyText.contains("Content-Disposition: form-data; name=\"source_client\""))
        XCTAssertTrue(bodyText.contains(sourceClient))
    }

    private static func encodedJSONObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private static func installDiagnostics() async throws -> DiagnosticsRuntime {
        await Diagnostics.uninstall()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("maohuoban-http-client-tests-\(UUID().uuidString)", isDirectory: true)
        return try await Diagnostics.install(
            DiagnosticsConfiguration(
                serviceName: "maohuoban-ios-tests",
                environment: "test",
                storageDirectory: root
            )
        )
    }
}

// PetRepositoryURLProtocol 宠物仓库测试协议桩
// 核心职责：
// - 拦截 URLSession 请求
// - 将请求交给测试断言并返回固定响应
private final class PetRepositoryURLProtocol: URLProtocol {
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

// PetRepositoryTestTokenStore 宠物仓库测试 token 存储
// 核心职责：
// - 为仓库契约测试提供固定 Authorization 请求头
// - 避免测试读取真实 Keychain 登录状态
private struct PetRepositoryTestTokenStore: MHBTokenStore {
    func loadTokens() throws -> MHBStoredTokens? {
        MHBStoredTokens(
            accessToken: "test-access-token",
            refreshToken: "test-refresh-token",
            tokenType: "Bearer",
            expiresInSeconds: 3600,
            refreshExpiresInSeconds: 86_400
        )
    }

    func saveTokens(_ tokens: MHBStoredTokens) throws {}

    func clearTokens() throws {}
}

private extension URLRequest {
    func bodyDataForPetRepositoryTest() -> Data? {
        if let httpBody {
            return httpBody
        }
        guard let httpBodyStream else {
            return nil
        }

        httpBodyStream.open()
        defer { httpBodyStream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while httpBodyStream.hasBytesAvailable {
            let readCount = httpBodyStream.read(&buffer, maxLength: buffer.count)
            if readCount < 0 {
                return nil
            }
            if readCount == 0 {
                break
            }
            data.append(buffer, count: readCount)
        }
        return data
    }
}
