import XCTest
@testable import maohuoban

// HomeDashboardDecodingTests 首页快照解码测试
// 核心职责：
// - 固化后端 dashboard JSON 与 iOS DTO 的字段契约
// - 覆盖认证商家、窝次、待办和近期事件解码
final class HomeDashboardDecodingTests: XCTestCase {
    @MainActor
    func testPetOwnerEventDerivedDashboardJSONDecodesIntoSnapshot() throws {
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
                  "avatar_width": 96,
                  "avatar_height": 96,
                  "hero_image_url": "/api/v1/media/assets/background-1/content",
                  "hero_image_width": 1200,
                  "hero_image_height": 1600,
                  "hero_theme_color_hex": "#FF0000",
                  "hero_content_color_scheme": "dark"
                },
                "pet_switcher": [
                  {
                    "id": "pet-1",
                    "name": "糯米",
                    "species": "dog",
                    "avatar_url": "/api/v1/media/assets/avatar-1/content",
                    "avatar_width": 96,
                    "avatar_height": 96,
                    "is_selected": true
                  }
                ],
                "care_summary": {
                  "title": "今日照护",
                  "metrics": [
                    {
                      "kind": "appetite",
                      "title": "食欲",
                      "value_text": "旺盛",
                      "status_text": "早餐和晚餐已记录"
                    },
                    {
                      "kind": "weight",
                      "title": "体重",
                      "value_text": "6.4kg",
                      "status_text": "已同步"
                    }
                  ]
                },
                "reminders": [
                  {
                    "id": "event-3",
                    "kind": "deworming",
                    "title": "内外驱虫",
                    "subtitle": "预计 2026-07-01 提醒",
                    "due_text": "待提醒"
                  }
                ],
                "quick_actions": [],
                "partner_recommendation": null,
                "recent_timeline": [
                  {
                    "id": "event-3",
                    "event_kind": "deworming",
                    "title": "内外驱虫",
                    "subtitle": "已完成本月驱虫",
                    "occurred_text": "2026-06-13"
                  }
                ],
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

        let dashboard = try XCTUnwrap(response.data)
        XCTAssertEqual(dashboard.identity.kind, .petOwner)
        XCTAssertEqual(dashboard.selectedPet?.id, "pet-1")
        XCTAssertEqual(dashboard.selectedPet?.avatarURL, "/api/v1/media/assets/avatar-1/content")
        XCTAssertEqual(dashboard.selectedPet?.avatarWidth, 96)
        XCTAssertEqual(dashboard.selectedPet?.avatarHeight, 96)
        XCTAssertEqual(dashboard.selectedPet?.heroImageWidth, 1200)
        XCTAssertEqual(dashboard.selectedPet?.heroImageHeight, 1600)
        XCTAssertEqual(dashboard.selectedPet?.heroThemeColorHex, "#FF0000")
        XCTAssertEqual(dashboard.selectedPet?.heroContentColorScheme, .dark)
        XCTAssertEqual(dashboard.petSwitcher.first?.avatarWidth, 96)
        XCTAssertEqual(dashboard.petSwitcher.first?.avatarHeight, 96)
        let selectedPet = try XCTUnwrap(dashboard.selectedPet)
        if case let .remoteImage(urlString, _) = selectedPet.heroMedia {
            XCTAssertEqual(urlString, "/api/v1/media/assets/background-1/content")
        } else {
            XCTFail("selected pet should use remote hero image")
        }
        XCTAssertEqual(dashboard.careSummary?.metrics.first?.kind, .appetite)
        XCTAssertEqual(dashboard.careSummary?.metrics.first?.valueText, "旺盛")
        XCTAssertEqual(dashboard.careSummary?.metrics.last?.kind, .weight)
        XCTAssertEqual(dashboard.careSummary?.metrics.last?.valueText, "6.4kg")
        XCTAssertEqual(dashboard.reminders.first?.kind, .deworming)
        XCTAssertEqual(dashboard.reminders.first?.title, "内外驱虫")
        XCTAssertEqual(dashboard.recentTimeline.first?.eventKind, .deworming)
    }

    @MainActor
    func testEditProfileMappingKeepsRemoteHeroImageURL() throws {
        let pet = HomeDashboardSnapshot.PetHeroSummary(
            id: "pet-1",
            name: "糯米",
            species: .dog,
            breed: "比熊犬",
            sex: .female,
            ageText: "2岁",
            statusText: "记录正在形成可信档案",
            updatedText: "档案已同步",
            avatarURL: "/api/v1/media/assets/avatar-1/content",
            heroImageURL: "/api/v1/media/assets/background-1/content",
            heroImageAssetName: "HomePetHeroMock"
        )

        let profile = HomePetProfileEditMapper.editProfile(for: pet)

        XCTAssertEqual(profile.avatarURL, "/api/v1/media/assets/avatar-1/content")
        if case let .remoteImage(urlString, fallbackAssetName) = profile.heroMedia {
            XCTAssertEqual(urlString, "/api/v1/media/assets/background-1/content")
            XCTAssertEqual(fallbackAssetName, "HomePetHeroMock")
        } else {
            XCTFail("edit profile should keep remote hero image")
        }
    }

    @MainActor
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
