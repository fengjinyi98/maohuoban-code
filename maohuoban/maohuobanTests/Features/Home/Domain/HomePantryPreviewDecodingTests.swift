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
                "gallery_albums": [
                  {
                    "id": "album-1",
                    "title": "睡觉合集",
                    "cover_url": "/api/v1/media/assets/album-cover/content",
                    "photo_count": 8
                  }
                ],
                "pantry_items": [
                  {
                    "id": "food-1",
                    "title": "渴望六种鱼",
                    "subtitle": "主食干粮",
                    "category": "main_food",
                    "cover_url": "/api/v1/media/assets/asset-1/content",
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
        XCTAssertEqual(item.subtitle, "主食干粮")
        XCTAssertEqual(item.category, .mainFood)
        XCTAssertEqual(item.pantryCategory, .mainFood)
        XCTAssertEqual(item.coverURL, "/api/v1/media/assets/asset-1/content")
        XCTAssertEqual(item.dietRoleLabel, "当前主粮")

        let album = try XCTUnwrap(response.data?.galleryAlbums.first)
        XCTAssertEqual(album.id, "album-1")
        XCTAssertEqual(album.coverImageAssetName, "/api/v1/media/assets/album-cover/content")
        XCTAssertEqual(album.photoCount, 8)
        XCTAssertEqual(album.dateText, "8 张照片")
    }
}
