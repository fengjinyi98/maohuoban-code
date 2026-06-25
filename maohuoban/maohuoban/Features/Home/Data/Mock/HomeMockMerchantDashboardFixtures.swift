import Foundation

extension HomeMockDashboardFixtures {
    static func merchantSnapshot() -> HomeDashboardSnapshot {
        HomeDashboardSnapshot(
            identity: HomeDashboardSnapshot.Identity(
                kind: .certifiedMerchant,
                displayName: "梧桐猫舍",
                city: "成都",
                verificationBadge: "已认证",
                avatarURL: nil
            ),
            selectedPet: nil,
            petSwitcher: [],
            reminders: [],
            quickActions: [
                HomeDashboardSnapshot.Action(
                    kind: .addMerchantPet,
                    title: "新增宠物",
                    subtitle: "录入店内宠物或窝次"
                ),
                HomeDashboardSnapshot.Action(
                    kind: .publishAvailableStatus,
                    title: "发布在售状态",
                    subtitle: "同步同城交易入口"
                )
            ],
            partnerRecommendation: nil,
            recentTimeline: [],
            merchantDashboard: HomeDashboardSnapshot.MerchantDashboardSummary(
                merchantID: "merchant-wutong",
                merchantName: "梧桐猫舍",
                statusCounts: [
                    HomeDashboardSnapshot.StatusCount(
                        status: .available,
                        title: "在售",
                        count: 4
                    ),
                    HomeDashboardSnapshot.StatusCount(
                        status: .reserved,
                        title: "已预定",
                        count: 2
                    ),
                    HomeDashboardSnapshot.StatusCount(
                        status: .needsRecord,
                        title: "待补记录",
                        count: 3
                    )
                ],
                litters: [
                    HomeDashboardSnapshot.LitterSummary(
                        id: "litter-2026-spring-a",
                        name: "2026 春季 A 窝",
                        parentText: "父亲 Leo · 母亲 Luna",
                        bornText: "2026-03-18 出生",
                        availableCount: 2
                    ),
                    HomeDashboardSnapshot.LitterSummary(
                        id: "litter-2026-spring-b",
                        name: "2026 春季 B 窝",
                        parentText: "父亲 Milo · 母亲 Nini",
                        bornText: "2026-04-02 出生",
                        availableCount: 2
                    )
                ],
                pendingTasks: [
                    HomeDashboardSnapshot.Reminder(
                        id: "merchant-health",
                        kind: .completeHealthRecord,
                        title: "补齐健康记录",
                        subtitle: "3 只宠物待补疫苗或体检记录",
                        dueText: "今天",
                        remarks: nil,
                        sourceRef: nil
                    )
                ],
                recentEvents: [
                    HomeDashboardSnapshot.TimelineEvent(
                        id: "merchant-event-1",
                        eventKind: .merchant,
                        title: "A 窝出生记录",
                        subtitle: "3 只幼猫出生，母猫状态稳定",
                        occurredText: "03-18",
                        occurredAt: nil
                    )
                ]
            ),
            emptyState: nil,
            recommendedContent: [],
            petAlbums: nil,
            galleryAlbums: nil
        )
    }
}
