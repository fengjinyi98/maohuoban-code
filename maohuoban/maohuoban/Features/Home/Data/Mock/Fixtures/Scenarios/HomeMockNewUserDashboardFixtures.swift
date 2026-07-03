import Foundation

extension HomeMockDashboardFixtures {
    static func newUserSnapshot() -> HomeDashboardSnapshot {
        HomeDashboardSnapshot(
            identity: HomeDashboardSnapshot.Identity(
                kind: .newUser,
                displayName: "新毛伙伴",
                city: "上海",
                verificationBadge: nil,
                avatarURL: nil
            ),
            selectedPet: nil,
            petSwitcher: [],
            reminders: [],
            quickActions: [
                HomeDashboardSnapshot.Action(
                    kind: .createPet,
                    title: "添加宠物",
                    subtitle: "添加第一只毛孩子档案"
                ),
                HomeDashboardSnapshot.Action(
                    kind: .importTradePet,
                    title: "导入交易宠物",
                    subtitle: "从履约记录生成档案"
                )
            ],
            partnerRecommendation: nil,
            recentTimeline: [],
            merchantDashboard: nil,
            emptyState: HomeDashboardSnapshot.EmptyState(
                kind: .createFirstPet,
                title: "先建立第一只毛孩子主页",
                subtitle: "首页会围绕宠物档案、事件、照护和同城服务组织信息。",
                primaryAction: HomeDashboardSnapshot.Action(
                    kind: .createPet,
                    title: "添加宠物档案",
                    subtitle: nil
                )
            ),
            recommendedContent: [
                HomeDashboardSnapshot.RecommendedContent(
                    id: "guide-profile",
                    kind: .guide,
                    title: "宠物档案应该记录哪些信息",
                    sourceText: "新手指南"
                ),
                HomeDashboardSnapshot.RecommendedContent(
                    id: "guide-event",
                    kind: .ugc,
                    title: "一条事件记录如何串起健康、交易和保险",
                    sourceText: "毛伙伴精选"
                )
            ],
            attentionHints: []
        )
    }
}
