import XCTest
@testable import maohuoban

// HomePantryPreviewDecodingTests 首页储物柜预览解码测试
// 核心职责：
// - 固化首页储物柜预览与后端 JSON 字段契约
// - 验证宠物饮食角色标注可被客户端保留
@MainActor
final class HomePantryPreviewDecodingTests: XCTestCase {
    func testPantryPreviewItemDecodesDietRoleLabel() throws {
        let data = Data(
            #"""
            {
              "success": true,
              "code": "ok",
              "message": "首页已加载",
              "data": {
                "identity": {
                  "kind": "pet_owner",
                  "display_name": "毛伙伴用户",
                  "city": null,
                  "verification_badge": null
                },
                "selected_pet": null,
                "pet_switcher": [],
                "reminders": [],
                "quick_actions": [],
                "partner_recommendation": null,
                "recent_timeline": [],
                "merchant_dashboard": null,
                "empty_state": null,
                "recommended_content": [],
                "pantry_items": [
                  {
                    "id": "food-1",
                    "title": "渴望六种鱼",
                    "subtitle": "主粮",
                    "cover_image_asset_name": "home-pantry-main-food",
                    "diet_role_label": "当前主粮"
                  }
                ]
              }
            }
            """#.utf8
        )

        let response = try JSONDecoder().decode(
            MHBAPIResponse<HomeDashboardSnapshot>.self,
            from: data
        )

        let item = try XCTUnwrap(response.data?.pantryItems?.first)
        XCTAssertEqual(item.dietRoleLabel, "当前主粮")
    }
}
