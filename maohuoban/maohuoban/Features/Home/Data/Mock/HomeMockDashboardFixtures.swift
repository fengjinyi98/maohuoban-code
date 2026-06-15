import Foundation

// HomeMockDashboardFixtures 首页 Mock 快照工厂
// 核心职责：
// - 集中维护首页 UI 开发阶段的样例数据
// - 输出与后端聚合接口一致的 HomeDashboardSnapshot
enum HomeMockDashboardFixtures {
    static func snapshot(
        scenario: HomeMockScenario,
        selectedPetID: String?
    ) -> HomeDashboardSnapshot {
        switch scenario {
        case .petOwner:
            petOwnerSnapshot(selectedPetID: selectedPetID)
        case .newUser:
            newUserSnapshot()
        case .merchant:
            merchantSnapshot()
        }
    }

    private static func petOwnerSnapshot(selectedPetID: String?) -> HomeDashboardSnapshot {
        let pets = petSwitcher(selectedPetID: selectedPetID)
        let selectedPet = pets.first(where: \.isSelected) ?? pets[0]

        return HomeDashboardSnapshot(
            identity: HomeDashboardSnapshot.Identity(
                kind: .petOwner,
                displayName: "毛伙伴用户",
                city: "上海",
                verificationBadge: nil,
                avatarURL: nil
            ),
            selectedPet: heroSummary(for: selectedPet.id),
            petSwitcher: pets,
            careSummary: HomeDashboardSnapshot.CareSummary(
                title: "今日照护",
                metrics: [
                    HomeDashboardSnapshot.CareMetric(
                        kind: .appetite,
                        title: "食欲",
                        valueText: "旺盛",
                        statusText: "早餐和晚餐已记录"
                    ),
                    HomeDashboardSnapshot.CareMetric(
                        kind: .mood,
                        title: "情绪",
                        valueText: "稳定",
                        statusText: "外出散步 28 分钟"
                    ),
                    HomeDashboardSnapshot.CareMetric(
                        kind: .weight,
                        title: "体重",
                        valueText: selectedPet.id == "pet-mochi" ? "4.8kg" : "4.2kg",
                        statusText: "较上次记录稳定"
                    )
                ]
            ),
            reminders: [
                HomeDashboardSnapshot.Reminder(
                    id: "reminder-deworming",
                    kind: .deworming,
                    title: "内外驱虫",
                    subtitle: "按周期预计 2026-07-01 提醒",
                    dueText: "17 天后"
                ),
                HomeDashboardSnapshot.Reminder(
                    id: "reminder-vaccine",
                    kind: .vaccine,
                    title: "年度疫苗",
                    subtitle: "建议提前预约同城宠物医院",
                    dueText: "下月"
                )
            ],
            quickActions: petOwnerActions(),
            partnerRecommendation: HomeDashboardSnapshot.PartnerRecommendation(
                petID: "pet-neighbor-1",
                petName: "布丁",
                relationshipKind: .sameCity,
                title: "附近也有一只温顺布偶",
                subtitle: "同城 2.4km，疫苗和驱虫节奏接近",
                distanceText: "2.4km"
            ),
            recentTimeline: [
                HomeDashboardSnapshot.TimelineEvent(
                    id: "event-walk",
                    eventKind: .daily,
                    title: "傍晚散步",
                    subtitle: "小区花园活动 28 分钟，精神状态良好",
                    occurredText: "今天 18:42"
                ),
                HomeDashboardSnapshot.TimelineEvent(
                    id: "event-weight",
                    eventKind: .weight,
                    title: "体重记录",
                    subtitle: "4.8kg，保持稳定",
                    occurredText: "昨天"
                ),
                HomeDashboardSnapshot.TimelineEvent(
                    id: "event-deworming",
                    eventKind: .deworming,
                    title: "内外驱虫",
                    subtitle: "已完成本月驱虫",
                    occurredText: "06-13"
                )
            ],
            merchantDashboard: nil,
            emptyState: nil,
            recommendedContent: []
        )
    }

    private static func newUserSnapshot() -> HomeDashboardSnapshot {
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
            careSummary: nil,
            reminders: [],
            quickActions: [
                HomeDashboardSnapshot.Action(
                    kind: .createPet,
                    title: "创建宠物",
                    subtitle: "建立第一只毛孩子主页"
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
                    title: "创建宠物档案",
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
            ]
        )
    }

    private static func merchantSnapshot() -> HomeDashboardSnapshot {
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
            careSummary: nil,
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
                        dueText: "今天"
                    )
                ],
                recentEvents: [
                    HomeDashboardSnapshot.TimelineEvent(
                        id: "merchant-event-1",
                        eventKind: .merchant,
                        title: "A 窝出生记录",
                        subtitle: "3 只幼猫出生，母猫状态稳定",
                        occurredText: "03-18"
                    )
                ]
            ),
            emptyState: nil,
            recommendedContent: []
        )
    }

    private static func petSwitcher(selectedPetID: String?) -> [HomeDashboardSnapshot.PetSwitchItem] {
        let selectedID = selectedPetID ?? "pet-mochi"
        return [
            HomeDashboardSnapshot.PetSwitchItem(
                id: "pet-mochi",
                name: "糯米",
                species: .cat,
                avatarURL: nil,
                isSelected: selectedID == "pet-mochi"
            ),
            HomeDashboardSnapshot.PetSwitchItem(
                id: "pet-tangyuan",
                name: "汤圆",
                species: .cat,
                avatarURL: nil,
                isSelected: selectedID == "pet-tangyuan"
            )
        ]
    }

    private static func heroSummary(for petID: String) -> HomeDashboardSnapshot.PetHeroSummary {
        switch petID {
        case "pet-tangyuan":
            HomeDashboardSnapshot.PetHeroSummary(
                id: "pet-tangyuan",
                name: "汤圆",
                species: .cat,
                breed: "英短银渐层",
                sex: .male,
                ageText: "1岁 4个月",
                statusText: "近期食欲稳定，夜间活动偏多",
                updatedText: "3 条事件已同步",
                avatarURL: nil,
                heroImageAssetName: "HomePetHeroMock",
                birthday: "2025-02-18",
                companionshipDays: 120
            )
        default:
            HomeDashboardSnapshot.PetHeroSummary(
                id: "pet-mochi",
                name: "糯米",
                species: .cat,
                breed: "布偶猫",
                sex: .female,
                ageText: "2岁",
                statusText: "记录正在形成可信档案",
                updatedText: "档案已同步",
                avatarURL: nil,
                heroImageAssetName: "HomePetHeroMock",
                birthday: "2024-04-01",
                companionshipDays: 365
            )
        }
    }

    private static func petOwnerActions() -> [HomeDashboardSnapshot.Action] {
        [
            HomeDashboardSnapshot.Action(
                kind: .dailyRecord,
                title: "记录日常",
                subtitle: "饮食、情绪、排便"
            ),
            HomeDashboardSnapshot.Action(
                kind: .healthRecord,
                title: "健康记录",
                subtitle: "疫苗、驱虫、体检"
            ),
            HomeDashboardSnapshot.Action(
                kind: .bookHospital,
                title: "预约医院",
                subtitle: "同城服务协同"
            ),
            HomeDashboardSnapshot.Action(
                kind: .importTradePet,
                title: "导入交易",
                subtitle: "沉淀履约档案"
            )
        ]
    }
}
