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
                        valueText: "4.8kg",
                        statusText: "较上次记录稳定"
                    )
                ]
            ),
            reminders: [
                HomeDashboardSnapshot.Reminder(
                    id: "reminder-vaccine",
                    kind: .vaccine,
                    title: "狂犬疫苗",
                    subtitle: "2026.06.08",
                    dueText: "14 天后",
                    remarks: "建议提前预约同城宠物医院"
                ),
                HomeDashboardSnapshot.Reminder(
                    id: "reminder-deworming",
                    kind: .deworming,
                    title: "体内驱虫",
                    subtitle: "2026.05.28",
                    dueText: "3 天后",
                    remarks: nil
                ),
                HomeDashboardSnapshot.Reminder(
                    id: "reminder-physical",
                    kind: .followUp,
                    title: "定期体检",
                    subtitle: "2026.04.15",
                    dueText: "30 天后",
                    remarks: "基础血常规与生化筛查"
                )
            ],
            quickActions: petOwnerActions(),
            partnerRecommendation: HomeDashboardSnapshot.PartnerRecommendation(
                petID: "pet-neighbor-1",
                petName: "奶盖",
                relationshipKind: .sameLitter,
                title: "今日伙伴",
                subtitle: "你们都来自 萌宠阁 猫舍，生日只差3天~",
                distanceText: "2km",
                sex: .female
            ),
            recentTimeline: [
                HomeDashboardSnapshot.TimelineEvent(
                    id: "event-breakfast",
                    eventKind: .daily,
                    title: "记录了早餐",
                    subtitle: "鸡肉 + 南瓜 + 狗粮",
                    occurredText: "08:30"
                ),
                HomeDashboardSnapshot.TimelineEvent(
                    id: "event-weight",
                    eventKind: .weight,
                    title: "体重更新",
                    subtitle: "3.6 kg",
                    occurredText: "09:15"
                ),
                HomeDashboardSnapshot.TimelineEvent(
                    id: "event-deworming",
                    eventKind: .deworming,
                    title: "完成驱虫",
                    subtitle: "大宠爱体外驱虫滴剂",
                    occurredText: "11:30"
                ),
                HomeDashboardSnapshot.TimelineEvent(
                    id: "event-walk",
                    eventKind: .daily,
                    title: "夜间散步",
                    subtitle: "32 分钟 · 2.3 km",
                    occurredText: "20:20"
                )
            ],
            merchantDashboard: nil,
            emptyState: nil,
            recommendedContent: [],
            petAlbums: [
                HomeDashboardSnapshot.PetAlbumItem(
                    id: "album-1",
                    title: "第一天带回家",
                    dateText: "2024年",
                    coverImageAssetName: "HomePetAlbum1"
                ),
                HomeDashboardSnapshot.PetAlbumItem(
                    id: "album-2",
                    title: "在阳光下打盹",
                    dateText: "2025年",
                    coverImageAssetName: "HomePetAlbum2"
                ),
                HomeDashboardSnapshot.PetAlbumItem(
                    id: "album-3",
                    title: "抓蝴蝶失败",
                    dateText: "2025年",
                    coverImageAssetName: "HomePetAlbum3"
                ),
                HomeDashboardSnapshot.PetAlbumItem(
                    id: "album-4",
                    title: "冬日小棉袄",
                    dateText: "2025年",
                    coverImageAssetName: "HomePetAlbum4"
                )
            ],
            galleryAlbums: [
                HomeDashboardSnapshot.PetGalleryAlbum(
                    id: "gallery-1",
                    title: "睡颜大赏",
                    dateText: "创建于 2024年",
                    coverImageAssetName: "HomeGalleryAlbum1"
                ),
                HomeDashboardSnapshot.PetGalleryAlbum(
                    id: "gallery-2",
                    title: "户外冒险",
                    dateText: "创建于 2025年",
                    coverImageAssetName: "HomeGalleryAlbum2"
                ),
                HomeDashboardSnapshot.PetGalleryAlbum(
                    id: "gallery-3",
                    title: "吃货瞬间",
                    dateText: "创建于 2025年",
                    coverImageAssetName: "HomeGalleryAlbum3"
                )
            ]
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
            petAlbums: nil,
            galleryAlbums: nil
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
                        dueText: "今天",
                        remarks: nil
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
            recommendedContent: [],
            petAlbums: nil,
            galleryAlbums: nil
        )
    }

    private static func petSwitcher(selectedPetID: String?) -> [HomeDashboardSnapshot.PetSwitchItem] {
        return [
            HomeDashboardSnapshot.PetSwitchItem(
                id: "pet-mochi",
                name: "糯米",
                species: .cat,
                avatarURL: nil,
                profileNumber: "9011562600000019",
                microchipNumber: nil,
                birthday: "2024-04-01",
                arrivalDate: "2024-06-16",
                weightGrams: 3600,
                neuterStatus: .neutered,
                personalityTags: ["亲人", "爱撒娇", "安静"],
                note: "记录正在形成可信档案",
                isSelected: true
            )
        ]
    }

    private static func heroSummary(for _: String) -> HomeDashboardSnapshot.PetHeroSummary {
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
            profileNumber: "9011562600000019",
            microchipNumber: nil,
            birthday: "2024-04-01",
            arrivalDate: "2024-06-16",
            weightGrams: 3600,
            neuterStatus: .neutered,
            personalityTags: ["亲人", "爱撒娇", "安静"],
            note: "记录正在形成可信档案",
            companionshipDays: 365,
            stats: HomeDashboardSnapshot.PetHeroStats(
                weightVal: "3.6",
                weightChange: "较上周 +0.2",
                recordDays: 27,
                recordStreakText: "连续记录",
                vaccineDaysLeft: 14,
                vaccineDate: "2026.06.08",
                dewormingDaysLeft: 3,
                dewormingDate: "2026.05.28"
            )
        )
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
