import XCTest
@testable import maohuoban

// HomeDashboardLivePhotoDecodingTests 宠物主人首页 Live Photo 解码测试
// 核心职责：
// - 固化后端 Live Photo 字段到首页快照的解码契约
// - 验证首页英雄媒体选择远端 Live Photo
@MainActor
final class HomeDashboardLivePhotoDecodingTests: XCTestCase {
    func testPetOwnerLivePhotoDashboardJSONDecodesIntoSnapshot() throws {
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
                "selected_pet": {
                  "id": "pet-1",
                  "name": "糯米",
                  "species": "dog",
                  "breed": "比熊犬",
                  "sex": "female",
                  "age_text": "2岁",
                  "status_text": "记录正在形成可信档案",
                  "updated_text": "档案已同步",
                  "avatar_url": "/api/v1/media/assets/avatar-1/content",
                  "hero_image_url": null,
                  "hero_video_url": null,
                  "hero_live_photo": {
                    "still_url": "/api/v1/media/assets/live-1/components/still-1/content",
                    "still_width": 1200,
                    "still_height": 1600,
                    "paired_video_url": "/api/v1/media/assets/live-1/components/video-1/content",
                    "paired_video_width": 1200,
                    "paired_video_height": 1600,
                    "paired_video_duration_ms": 1800,
                    "crop": {
                      "x": 0.125,
                      "y": 0.25,
                      "width": 0.5,
                      "height": 0.375
                    }
                  },
                  "hero_theme_color_hex": "#AABBCC",
                  "hero_content_color_scheme": "light"
                },
                "pet_switcher": [],
                "reminders": [],
                "quick_actions": [],
                "partner_recommendation": null,
                "recent_timeline": [],
                "merchant_dashboard": null,
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

        let selectedPet = try XCTUnwrap(response.data?.selectedPet)
        XCTAssertEqual(selectedPet.heroLivePhoto?.stillURL, "/api/v1/media/assets/live-1/components/still-1/content")
        XCTAssertEqual(selectedPet.heroLivePhoto?.stillWidth, 1200)
        XCTAssertEqual(selectedPet.heroLivePhoto?.pairedVideoURL, "/api/v1/media/assets/live-1/components/video-1/content")
        XCTAssertEqual(selectedPet.heroLivePhoto?.pairedVideoDurationMS, 1800)
        XCTAssertEqual(selectedPet.heroLivePhoto?.cropMetadata?.x, 0.125)
        XCTAssertEqual(selectedPet.heroLivePhoto?.cropMetadata?.y, 0.25)
        XCTAssertEqual(selectedPet.heroLivePhoto?.cropMetadata?.width, 0.5)
        XCTAssertEqual(selectedPet.heroLivePhoto?.cropMetadata?.height, 0.375)
        XCTAssertNil(selectedPet.heroImageURL)
        XCTAssertNil(selectedPet.heroVideoURL)
        if case let .remoteLivePhoto(stillURLString, pairedVideoURLString, cropMetadata, fallbackImageAssetName) = selectedPet.heroMedia {
            XCTAssertEqual(stillURLString, "/api/v1/media/assets/live-1/components/still-1/content")
            XCTAssertEqual(pairedVideoURLString, "/api/v1/media/assets/live-1/components/video-1/content")
            XCTAssertEqual(cropMetadata?.width, 0.5)
            XCTAssertEqual(fallbackImageAssetName, "HomePetHeroMock")
        } else {
            XCTFail("selected pet should use remote live photo")
        }
    }
}
