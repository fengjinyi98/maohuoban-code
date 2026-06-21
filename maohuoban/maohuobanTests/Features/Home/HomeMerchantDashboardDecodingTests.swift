import XCTest
@testable import maohuoban

// HomeMerchantDashboardDecodingTests 商家首页快照解码测试
// 核心职责：
// - 固化认证商家 dashboard JSON 与 iOS DTO 的字段契约
// - 覆盖商家窝次、待办和近期事件解码
@MainActor
final class HomeMerchantDashboardDecodingTests: XCTestCase {
    func testMerchantDashboardJSONDecodesIntoSnapshot() throws {
        let data = Data(
            #"""
            {
              "success": true,
              "code": "ok",
              "message": "首页已加载",
              "data": {
                "identity": {
                  "kind": "certified_merchant",
                  "display_name": "梧桐猫舍",
                  "city": "成都",
                  "verification_badge": "已认证"
                },
                "selected_pet": null,
                "pet_switcher": [],
                "care_summary": null,
                "reminders": [],
                "quick_actions": [
                  {
                    "kind": "add_merchant_pet",
                    "title": "新增宠物",
                    "subtitle": "录入店内宠物或窝次"
                  }
                ],
                "partner_recommendation": null,
                "recent_timeline": [],
                "merchant_dashboard": {
                  "merchant_id": "merchant-1",
                  "merchant_name": "梧桐猫舍",
                  "status_counts": [
                    {
                      "status": "available",
                      "title": "在售",
                      "count": 2
                    }
                  ],
                  "litters": [
                    {
                      "id": "litter-1",
                      "name": "2026 春季 A 窝",
                      "parent_text": "父亲 Leo · 母亲 Luna",
                      "born_text": "2026-03-18 出生",
                      "available_count": 2
                    }
                  ],
                  "pending_tasks": [
                    {
                      "id": "merchant-1",
                      "kind": "complete_health_record",
                      "title": "补齐健康记录",
                      "subtitle": "1 只宠物待补健康或成长记录",
                      "due_text": "今天"
                    }
                  ],
                  "recent_events": [
                    {
                      "id": "event-1",
                      "event_kind": "merchant",
                      "title": "A 窝出生记录",
                      "subtitle": "3 只幼猫出生",
                      "occurred_text": "2026-03-18"
                    }
                  ]
                },
                "empty_state": null,
                "recommended_content": []
              }
            }
            """#.utf8
        )

        let response = try JSONDecoder().decode(
            MHBAPIResponse<HomeDashboardSnapshot>.self,
            from: data
        )

        let dashboard = try XCTUnwrap(response.data)
        XCTAssertEqual(dashboard.identity.kind, .certifiedMerchant)
        XCTAssertEqual(dashboard.merchantDashboard?.merchantID, "merchant-1")
        XCTAssertEqual(dashboard.merchantDashboard?.statusCounts.first?.status, .available)
        XCTAssertEqual(dashboard.merchantDashboard?.litters.first?.parentText, "父亲 Leo · 母亲 Luna")
        XCTAssertEqual(dashboard.merchantDashboard?.pendingTasks.first?.kind, .completeHealthRecord)
        XCTAssertEqual(dashboard.merchantDashboard?.recentEvents.first?.eventKind, .merchant)
    }
}
