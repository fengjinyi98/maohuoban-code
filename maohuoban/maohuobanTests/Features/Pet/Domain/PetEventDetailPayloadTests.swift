import XCTest
@testable import maohuoban

// PetEventDetailPayloadTests 宠物事件详情载荷测试
// 核心职责：
// - 固化喂食详情所需 payload 字段解码契约
// - 防止详情页回退到本地 mock 展示数据
@MainActor
final class PetEventDetailPayloadTests: XCTestCase {
    func testDecodesFeedingPayloadAndAttachmentAssetIDs() throws {
        let object: [String: Any] = [
            "food_item_id": "food-1",
            "food_role": "main_food",
            "amount_text": "正常",
            "food_snapshot": [
                "name": "渴望六种鱼",
                "brand": "Orijen",
                "category": "main_food",
                "spec": "5.4kg"
            ],
            "is_default_food": true,
            "note": "晚餐吃完了",
            "attachment_asset_ids": ["asset-1", "asset-2"]
        ]
        let data = try JSONSerialization.data(withJSONObject: object)

        let payload = try JSONDecoder().decode(PetEventDetailPayload.self, from: data)

        XCTAssertEqual(payload.foodItemID, "food-1")
        XCTAssertEqual(payload.foodRole, "main_food")
        XCTAssertEqual(payload.amountText, "正常")
        XCTAssertEqual(payload.foodSnapshot?.name, "渴望六种鱼")
        XCTAssertEqual(payload.foodSnapshot?.brand, "Orijen")
        XCTAssertEqual(payload.foodSnapshot?.category, "main_food")
        XCTAssertEqual(payload.foodSnapshot?.spec, "5.4kg")
        XCTAssertEqual(payload.isDefaultFood, true)
        XCTAssertEqual(payload.note, "晚餐吃完了")
        XCTAssertEqual(payload.attachmentAssetIDs, ["asset-1", "asset-2"])
    }

    func testDecodesEventAttachmentAssetsWithDimensions() throws {
        let object: [String: Any] = [
            "id": "event-1",
            "pet_id": "pet-1",
            "event_kind": "health",
            "event_subkind": "vaccine",
            "title": "狂犬疫苗",
            "summary": "已完成",
            "visibility": "private",
            "occurred_at": "2026-07-04T08:00:00Z",
            "record_revision": 1,
            "event_payload": [
                "note": "疫苗本照片",
                "attachment_asset_ids": ["asset-1"]
            ],
            "attachment_assets": [
                [
                    "id": "asset-1",
                    "url": "/api/v1/media/assets/asset-1/content",
                    "width": 4032,
                    "height": 3024
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: object)

        let event = try JSONDecoder().decode(PetEventDetail.self, from: data)

        XCTAssertEqual(event.eventPayload?.attachmentAssetIDs, ["asset-1"])
        XCTAssertEqual(event.attachmentAssets, [
            PetEventAttachmentAsset(
                id: "asset-1",
                url: "/api/v1/media/assets/asset-1/content",
                width: 4032,
                height: 3024
            )
        ])
    }
}
