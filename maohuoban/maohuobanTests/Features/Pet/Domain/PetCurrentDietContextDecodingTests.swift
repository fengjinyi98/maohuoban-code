import XCTest
@testable import maohuoban

// PetCurrentDietContextDecodingTests 饮食上下文解码测试
// 核心职责：
// - 固定后端 food_snapshot 可空字段的解码契约
// - 保护喂食历史快照展示不受品牌/规格缺失影响
final class PetCurrentDietContextDecodingTests: XCTestCase {
    @MainActor
    func testRecentFeedingSnapshotAllowsNullableBrandAndSpec() throws {
        let data = """
        {
          "current_staple": null,
          "trying_foods": [],
          "usual_treats": [],
          "usual_nutritions": [],
          "recent_feeding_events": [
            {
              "event_id": "event-1",
              "occurred_at": "2026-06-25T08:30:00Z",
              "food_item_id": "food-1",
              "food_name": "无品牌主粮",
              "food_snapshot": {
                "name": "无品牌主粮",
                "brand": null,
                "category": "main_food",
                "spec": null
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let context = try JSONDecoder().decode(PetCurrentDietContext.self, from: data)

        let snapshot = try XCTUnwrap(context.recentFeedingEvents.first?.foodSnapshot)
        XCTAssertEqual(snapshot["name"], "无品牌主粮")
        XCTAssertNil(snapshot["brand"])
        XCTAssertEqual(snapshot["category"], "main_food")
        XCTAssertNil(snapshot["spec"])
    }
}
