import XCTest
@testable import maohuoban

// HomeDashboardDecodingTests 宠物主人首页快照解码测试
// 核心职责：
// - 固化宠物主人 dashboard JSON 与 iOS DTO 的字段契约
// - 验证编辑档案与首页预览上下文映射保留后端媒体信息
@MainActor
final class HomeDashboardDecodingTests: XCTestCase {
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
        XCTAssertFalse(
            Mirror(reflecting: dashboard).children.contains { $0.label == "careSummary" }
        )
        XCTAssertEqual(dashboard.reminders.first?.kind, .deworming)
        XCTAssertEqual(dashboard.reminders.first?.title, "内外驱虫")
        XCTAssertEqual(dashboard.recentTimeline.first?.eventKind, .deworming)
        XCTAssertTrue(dashboard.galleryAlbums.isEmpty)
    }

    func testPetOwnerDashboardDecodesLifecycleFactsInTimeline() throws {
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
                "recent_timeline": [
                  {
                    "id": "pet-1-birth",
                    "event_kind": "daily",
                    "title": "第一次来到这个世界",
                    "subtitle": "糯米在这一天出生",
                    "occurred_text": "2024-04-01",
                    "occurred_at": "2024-04-01T00:00:00Z"
                  },
                  {
                    "id": "pet-1-homecoming",
                    "event_kind": "daily",
                    "title": "到家的第一天",
                    "subtitle": "糯米来到你身边",
                    "occurred_text": "2024-06-16",
                    "occurred_at": "2024-06-16T00:00:00Z"
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
        XCTAssertEqual(dashboard.recentTimeline.count, 2)
        XCTAssertEqual(dashboard.recentTimeline[0].id, "pet-1-birth")
        XCTAssertEqual(dashboard.recentTimeline[0].eventKind, .daily)
        XCTAssertEqual(dashboard.recentTimeline[0].title, "第一次来到这个世界")
        XCTAssertEqual(dashboard.recentTimeline[0].subtitle, "糯米在这一天出生")
        XCTAssertEqual(dashboard.recentTimeline[0].occurredText, "2024-04-01")
        XCTAssertEqual(dashboard.recentTimeline[1].id, "pet-1-homecoming")
        XCTAssertEqual(dashboard.recentTimeline[1].title, "到家的第一天")
        XCTAssertEqual(dashboard.recentTimeline[1].occurredText, "2024-06-16")
    }

    func testAttentionHintDecodesAbnormalDetailEventIDPayload() throws {
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
                "attention_hints": [
                  {
                    "id": "hint-1",
                    "pet_id": "pet-1",
                    "kind": "open_abnormal_episode",
                    "title": "异常追踪",
                    "subtitle": "点击查看异常详情",
                    "icon": "exclamationmark.circle",
                    "tone": "notice",
                    "priority": 10,
                    "status": "active",
                    "source_ref_type": "abnormal_episode",
                    "source_ref_id": "episode-1",
                    "route": {
                      "kind": "abnormal_detail",
                      "payload": {
                        "episode_id": "episode-1",
                        "event_id": "event-1"
                      }
                    },
                    "display_from": null,
                    "display_until": null,
                    "created_by": "system",
                    "created_at": "2026-07-05T11:53:21Z",
                    "updated_at": "2026-07-05T11:53:21Z",
                    "resolved_at": null
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
        let hint = try XCTUnwrap(dashboard.attentionHints.first)
        XCTAssertEqual(hint.kind, .openAbnormalEpisode)
        XCTAssertEqual(hint.route.kind, .abnormalDetail)
        XCTAssertEqual(hint.route.payload?.episodeID, "episode-1")
        XCTAssertEqual(hint.route.payload?.eventID, "event-1")
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
            heroThemeColorHex: "#AABBCC",
            heroContentColorScheme: .light,
            heroImageAssetName: "HomePetHeroMock",
            nameEditPolicy: PetNameEditPolicy(
                maxCount: 5,
                usedCount: 2,
                remainingCount: 3,
                windowDays: 30,
                windowEndsAt: "2026-07-17T00:00:00Z",
                displayText: "7月17日前还可以修改 3 次名字。"
            )
        )

        let profile = HomePetProfileEditMapper.editProfile(for: pet)

        XCTAssertEqual(profile.breed, "比熊犬")
        XCTAssertEqual(profile.avatarURL, "/api/v1/media/assets/avatar-1/content")
        XCTAssertEqual(profile.heroThemeColorHex, "#AABBCC")
        XCTAssertEqual(profile.heroContentColorScheme, .light)
        XCTAssertEqual(profile.nameEditPolicy?.remainingCount, 3)
        XCTAssertEqual(profile.nameEditPolicy?.displayText, "7月17日前还可以修改 3 次名字。")
        if case let .remoteImage(urlString, fallbackAssetName) = profile.heroMedia {
            XCTAssertEqual(urlString, "/api/v1/media/assets/background-1/content")
            XCTAssertEqual(fallbackAssetName, "HomePetHeroMock")
        } else {
            XCTFail("edit profile should keep remote hero image")
        }
    }

    func testHomePreviewContextKeepsBackendHeroThemeColor() throws {
        let profile = PetProfileEditProfile(
            id: "pet-1",
            name: "糯米",
            species: .dog,
            breed: "比熊犬",
            avatarURL: "/api/v1/media/assets/avatar-1/content",
            heroMedia: .remoteImage(
                urlString: "/api/v1/media/assets/background-1/content",
                fallbackAssetName: "HomePetHeroMock"
            ),
            heroThemeColorHex: "#AABBCC",
            heroContentColorScheme: .light,
            profileCode: "MHB-1",
            chipNumber: "",
            sexText: "母",
            birthDateText: "2024-01-01",
            arrivalDateText: "2024-05-01",
            weightText: "4.2 kg",
            neuterStatusText: "已绝育",
            personalityTags: ["亲人"],
            note: "喜欢晒太阳",
            nameEditPolicy: nil
        )

        let context = PetProfileHomePreviewContext(
            profile: profile,
            name: profile.name,
            sexText: profile.sexText,
            birthDateText: profile.birthDateText,
            arrivalDateText: profile.arrivalDateText,
            weightText: profile.weightText,
            noteText: profile.note
        )

        XCTAssertEqual(context.pet.heroThemeColorHex, "#AABBCC")
        XCTAssertEqual(context.pet.heroContentColorScheme, .light)
    }

}
