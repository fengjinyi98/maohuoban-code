import XCTest
@testable import maohuoban

// HomeQuickFactFeedingInputTests 首页喂食快捷输入测试
// 核心职责：
// - 固定喂食事件结构化 payload 编码契约
// - 保护食品资产引用和快照不丢失
@MainActor
final class HomeQuickFactFeedingInputTests: XCTestCase {
    func testFeedingInputBuildsStructuredEventPayload() throws {
        let input = HomeQuickFactFeedingInput(
            petID: "pet-1",
            lifeStatus: nil,
            foodKind: .mainFood,
            foodName: "渴望六种鱼",
            foodItemID: "food-1",
            foodSnapshotJSON: """
            {"name":"渴望六种鱼","brand":"Orijen","category":"main_food","spec":"5.4kg"}
            """,
            isDefaultFood: true,
            amount: .normal,
            occurredAt: Date(timeIntervalSince1970: 0),
            note: "状态正常",
            photoAssetNames: []
        )

        let json = try encodedJSONObject(input.eventDraft())
        let payload = try XCTUnwrap(json["event_payload"] as? [String: Any])
        let snapshot = try XCTUnwrap(payload["food_snapshot"] as? [String: Any])

        XCTAssertEqual(payload["food_item_id"] as? String, "food-1")
        XCTAssertEqual(payload["food_role"] as? String, "main_food")
        XCTAssertEqual(payload["amount_text"] as? String, "正常")
        XCTAssertEqual(snapshot["name"] as? String, "渴望六种鱼")
        XCTAssertEqual(snapshot["brand"] as? String, "Orijen")
    }

    func testFoodOptionBuildsFeedingInputWithSnapshot() throws {
        let option = HomeQuickFactFeedingFoodOption(
            id: "food-1",
            kind: .mainFood,
            name: "渴望六种鱼",
            brand: "Orijen",
            category: "main_food",
            spec: "5.4kg",
            imageURL: nil,
            isDefault: true
        )

        let input = option.feedingInput(
            petID: "pet-1",
            lifeStatus: nil,
            amount: .normal,
            occurredAt: Date(timeIntervalSince1970: 0),
            note: "",
            photoAssetNames: []
        )
        let json = try encodedJSONObject(input.eventDraft())
        let payload = try XCTUnwrap(json["event_payload"] as? [String: Any])
        let snapshot = try XCTUnwrap(payload["food_snapshot"] as? [String: Any])

        XCTAssertEqual(payload["food_item_id"] as? String, "food-1")
        XCTAssertEqual(payload["is_default_food"] as? Bool, true)
        XCTAssertEqual(snapshot["name"] as? String, "渴望六种鱼")
        XCTAssertEqual(snapshot["brand"] as? String, "Orijen")
        XCTAssertEqual(snapshot["category"] as? String, "main_food")
        XCTAssertEqual(snapshot["spec"] as? String, "5.4kg")
    }

    func testNonDefaultFoodOptionBuildsFeedingInputWithDefaultFlagFalse() throws {
        let option = HomeQuickFactFeedingFoodOption(
            id: "food-2",
            kind: .snack,
            name: "风干牛肉",
            brand: "Ziwi",
            category: "treats",
            spec: "100g",
            imageURL: nil,
            isDefault: false
        )

        let input = option.feedingInput(
            petID: "pet-1",
            lifeStatus: nil,
            amount: .small,
            occurredAt: Date(timeIntervalSince1970: 0),
            note: "",
            photoAssetNames: []
        )
        let json = try encodedJSONObject(input.eventDraft())
        let payload = try XCTUnwrap(json["event_payload"] as? [String: Any])

        XCTAssertEqual(payload["food_item_id"] as? String, "food-2")
        XCTAssertEqual(payload["is_default_food"] as? Bool, false)
    }

    private func encodedJSONObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
