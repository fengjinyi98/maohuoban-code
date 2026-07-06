import Foundation
@testable import maohuoban

// HomeRealtimeDashboardFixtures 首页实时测试夹具
// 核心职责：
// - 构造首页实时刷新测试需要的快照和轻提示
// - 保持测试数据通过真实 JSON 解码路径创建
enum HomeRealtimeDashboardFixtures {
    @MainActor
    static func snapshot(
        selectedPetID: String,
        attentionHints: [HomeDashboardSnapshot.AttentionHint] = []
    ) -> HomeDashboardSnapshot {
        HomeDashboardSnapshot(
            identity: HomeDashboardSnapshot.Identity(
                kind: .petOwner,
                displayName: "毛伙伴用户",
                city: nil,
                verificationBadge: nil
            ),
            selectedPet: HomeDashboardSnapshot.PetHeroSummary(
                id: selectedPetID,
                name: "糯米",
                species: .dog,
                breed: "比熊",
                sex: .female,
                ageText: "2岁",
                statusText: "记录正在形成可信档案",
                updatedText: "档案已同步",
                avatarURL: nil,
                heroImageAssetName: "HomePetHeroMock"
            ),
            petSwitcher: [],
            reminders: [],
            quickActions: [],
            partnerRecommendation: nil,
            recentTimeline: [],
            merchantDashboard: nil,
            emptyState: nil,
            recommendedContent: [],
            attentionHints: attentionHints
        )
    }

    @MainActor
    static func attentionHint(id: String) throws -> HomeDashboardSnapshot.AttentionHint {
        let data = Data(
            """
            {
              "id": "\(id)",
              "pet_id": "pet-1",
              "kind": "abnormal_followup_due",
              "title": "馒头今天的状况怎么样了？",
              "subtitle": "今天早上你记录到异常，现在想了解最新状态。",
              "icon": "cross.case.fill",
              "tone": "notice",
              "priority": 10,
              "status": "active",
              "source_ref_type": "agent_proactive_followup",
              "source_ref_id": "followup-1",
              "route": {
                "kind": "abnormal_detail",
                "payload": {
                  "event_id": "event-1",
                  "episode_id": "episode-1",
                  "record_id": "event-1",
                  "agent_followup_id": "followup-1",
                  "source_hint_id": "\(id)",
                  "actions": []
                }
              },
              "display_from": null,
              "display_until": null,
              "created_by": "system",
              "created_at": "2026-07-06T09:00:52Z",
              "updated_at": "2026-07-06T09:00:52Z",
              "resolved_at": null
            }
            """.utf8
        )
        return try JSONDecoder().decode(HomeDashboardSnapshot.AttentionHint.self, from: data)
    }
}
