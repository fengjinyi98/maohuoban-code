import XCTest
@testable import maohuoban

// HomeRouteTests 首页路由测试
// 核心职责：
// - 固化首页路由关联值契约
// - 防止商家待办入口丢失商家上下文
final class HomeRouteTests: XCTestCase {
    @MainActor
    func testPetAssistantRouteCarriesCurrentPetContext() {
        let route = HomeRoute.petAssistant(
            AIAssistantEntryContext(
                selectedPetID: "pet-1",
                selectedPetName: "糯米",
                selectedPetAvatarURL: "/media/pet/avatar.png",
                selectedPetSpecies: .cat
            )
        )

        guard case .petAssistant(let context) = route else {
            XCTFail("Expected pet assistant route")
            return
        }

        XCTAssertEqual(context.selectedPetID, "pet-1")
        XCTAssertEqual(context.selectedPetName, "糯米")
        XCTAssertEqual(context.selectedPetAvatarURL, "/media/pet/avatar.png")
        XCTAssertEqual(context.selectedPetSpecies, .cat)
        XCTAssertEqual(route.systemImage, "sparkles")
    }

    @MainActor
    func testAttentionHintAskAgentRouteCarriesPetAndAbnormalContext() throws {
        let hint = try decodeAttentionHint(
            """
            {
              "id": "hint-1",
              "pet_id": "pet-1",
              "kind": "abnormal_followup_due",
              "title": "异常追踪",
              "subtitle": "需要更新",
              "icon": "cross.case.fill",
              "tone": "warning",
              "priority": 90,
              "status": "active",
              "source_ref_type": "pet_event",
              "source_ref_id": "event-from-source",
              "route": {
                "kind": "abnormal_detail",
                "payload": {
                  "event_id": "event-1",
                  "episode_id": "episode-1",
                  "agent_followup_id": "followup-route",
                  "actions": [
                    {
                      "id": "ask_agent",
                      "title": "问问毛球",
                      "route_kind": "ai_chat",
                      "chat_context": {
                        "kind": "abnormal_episode_followup",
                        "episode_id": "episode-1",
                        "source_hint_id": "hint-from-chat",
                        "agent_followup_id": "followup-chat"
                      }
                    }
                  ]
                }
              },
              "created_by": "agent",
              "created_at": "2026-07-06T09:00:00Z",
              "updated_at": "2026-07-06T09:00:00Z"
            }
            """
        )
        let action = try XCTUnwrap(hint.route.payload?.actions.first)
        let recordContext = PetRecordEntryContext(
            petID: "pet-1",
            petName: "馒头",
            petAvatarURL: "/media/pet/mantou.png",
            availablePets: [
                PetRecordSwitchPet(
                    id: "pet-1",
                    name: "馒头",
                    species: .cat,
                    breed: "英短",
                    avatarURL: "/media/pet/mantou.png",
                    isSelected: true
                )
            ]
        )

        let route = HomeAttentionHintRouteResolver.route(
            for: action,
            hint: hint,
            petName: "馒头",
            recordContext: recordContext
        )

        guard case .petAssistant(let context) = route else {
            return XCTFail("ask agent action should route to pet assistant")
        }
        XCTAssertEqual(context.selectedPetID, "pet-1")
        XCTAssertEqual(context.selectedPetName, "馒头")
        XCTAssertEqual(context.selectedPetAvatarURL, "/media/pet/mantou.png")
        XCTAssertEqual(context.selectedPetSpecies, .cat)
        XCTAssertEqual(context.abnormalEpisodeID, "episode-1")
        XCTAssertEqual(context.abnormalEventID, "event-1")
        XCTAssertEqual(context.sourceHintID, "hint-from-chat")
        XCTAssertEqual(context.agentFollowupID, "followup-chat")
    }

    @MainActor
    func testBookHospitalRouteCarriesPetAndCityContext() {
        let action = HomeDashboardSnapshot.Action(
            kind: .bookHospital,
            title: "预约合作医院",
            subtitle: "HIS 病历回流"
        )
        let context = HomeActionRoutingContext(
            selectedPetID: "pet-1",
            merchantID: nil,
            city: "成都"
        )

        let route = HomeActionRouteResolver.route(for: action, context: context)

        guard case .bookHospital(let petID, let city) = route else {
            XCTFail("Expected hospital booking route")
            return
        }

        XCTAssertEqual(petID, "pet-1")
        XCTAssertEqual(city, "成都")
    }

    @MainActor
    func testMerchantTaskRouteCarriesMerchantAndReminderIDs() {
        let route = HomeRoute.merchantTask(
            merchantID: "merchant-1",
            reminderID: "merchant-task-needs-record"
        )

        guard case .merchantTask(let merchantID, let reminderID) = route else {
            XCTFail("Expected merchant task route")
            return
        }

        XCTAssertEqual(merchantID, "merchant-1")
        XCTAssertEqual(reminderID, "merchant-task-needs-record")
    }

    @MainActor
    func testPetAlbumRouteCarriesEntrySourceContext() {
        let context = PetAlbumEntryContext(
            petID: "pet-1",
            petName: "糯米"
        )
        let route = HomeRoute.petAlbum(context)

        guard case .petAlbum(let actualContext) = route else {
            XCTFail("Expected pet album entry route")
            return
        }

        XCTAssertEqual(actualContext, context)
        XCTAssertEqual(route.systemImage, "photo.on.rectangle.angled")
        XCTAssertEqual(route.title, "宠物相册")
    }

    @MainActor
    func testPetPantryRouteCarriesEntryContextWithoutOwningPetScope() {
        let context = PetPantryEntryContext(
            sourcePetID: "pet-1",
            sourcePetName: "糯米"
        )
        let route = HomeRoute.petPantry(context)

        guard case .petPantry(let actualContext) = route else {
            XCTFail("Expected pantry entry route")
            return
        }

        XCTAssertEqual(actualContext, context)
        XCTAssertEqual(actualContext.sourcePetID, "pet-1")
        XCTAssertEqual(actualContext.sourcePetName, "糯米")
        XCTAssertEqual(route.subtitle, "进入用户储物柜")
    }

    @MainActor
    func testHealthReminderRoutesToTimelineEventDetail() {
        let reminder = HomeDashboardSnapshot.Reminder(
            id: "event-1",
            kind: .deworming,
            title: "内外驱虫",
            subtitle: "预计 2026-06-16 提醒",
            dueText: "待提醒",
            remarks: nil,
            sourceRef: nil
        )
        let context = HomeActionRoutingContext(selectedPetID: "pet-1")

        let route = HomeReminderRouteResolver.route(for: reminder, context: context)

        guard case .petRecordDetail = route else {
            XCTFail("Expected pet record detail route")
            return
        }
        XCTAssertNotNil(route)
    }

    @MainActor
    func testWeightTimelineEventRoutesToWeightRecordDetailWithPetContext() {
        let event = HomeDashboardSnapshot.TimelineEvent(
            id: "weight-record-1",
            eventKind: .weight,
            title: "记录体重",
            subtitle: "4.20 kg",
            occurredText: "09:30",
            occurredAt: "2026-07-04T01:30:00Z"
        )
        let context = PetRecordEntryContext(
            petID: "pet-1",
            petName: "糯米",
            petAvatarURL: "/media/pet/avatar",
            petSex: .female
        )

        let route = HomeTimelineRecordRouteResolver.route(
            for: event,
            recordContext: context
        )

        guard case .petWeightRecordDetail(let recordID, let routeContext) = route else {
            XCTFail("Expected real weight record detail route")
            return
        }
        XCTAssertEqual(recordID, "weight-record-1")
        XCTAssertEqual(routeContext, context)
    }

    @MainActor
    func testQuickFactTimelineEventPreservesBackendRecordID() {
        let event = HomeDashboardSnapshot.TimelineEvent(
            id: "quick-fact-event-1",
            eventKind: .daily,
            title: "便便正常",
            subtitle: "状态正常",
            occurredText: "10:30",
            occurredAt: "2026-07-04T02:30:00Z"
        )
        let context = PetRecordEntryContext(
            petID: "pet-1",
            petName: "糯米",
            petAvatarURL: "/media/pet/avatar",
            petSex: .female
        )

        let route = HomeTimelineRecordRouteResolver.route(
            for: event,
            recordContext: context
        )

        guard case .petRecordDetail(let detailRoute) = route else {
            XCTFail("Expected pet record detail route")
            return
        }
        guard case .quickFact(let recordID, let kind, let routeContext) = detailRoute else {
            XCTFail("Expected quick fact detail route")
            return
        }
        XCTAssertEqual(recordID, "quick-fact-event-1")
        XCTAssertEqual(kind, .poopNormal)
        XCTAssertEqual(routeContext, context)
        XCTAssertEqual(detailRoute.id, "quickFact-quick-fact-event-1")
    }

    @MainActor
    func testMerchantReminderRoutesToMerchantTaskWhenMerchantContextExists() {
        let reminder = HomeDashboardSnapshot.Reminder(
            id: "merchant-task-needs-record",
            kind: .merchantTask,
            title: "待补健康记录",
            subtitle: "3 只宠物缺少买家可见健康信息",
            dueText: "今日",
            remarks: nil,
            sourceRef: nil
        )
        let context = HomeActionRoutingContext(merchantID: "merchant-1")

        let route = HomeReminderRouteResolver.route(for: reminder, context: context)

        guard case .merchantTask(let merchantID, let reminderID) = route else {
            XCTFail("Expected merchant task route")
            return
        }
        XCTAssertEqual(merchantID, "merchant-1")
        XCTAssertEqual(reminderID, "merchant-task-needs-record")
    }

    @MainActor
    func testMerchantReminderWithoutMerchantContextHasNoRoute() {
        let reminder = HomeDashboardSnapshot.Reminder(
            id: "merchant-task-needs-record",
            kind: .merchantTask,
            title: "待补健康记录",
            subtitle: "3 只宠物缺少买家可见健康信息",
            dueText: "今日",
            remarks: nil,
            sourceRef: nil
        )

        let route = HomeReminderRouteResolver.route(
            for: reminder,
            context: HomeActionRoutingContext()
        )

        XCTAssertNil(route)
    }

    @MainActor
    private func decodeAttentionHint(_ json: String) throws -> HomeDashboardSnapshot.AttentionHint {
        try JSONDecoder().decode(
            HomeDashboardSnapshot.AttentionHint.self,
            from: Data(json.utf8)
        )
    }
}
