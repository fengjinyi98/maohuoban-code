import Foundation

extension HomeMockDashboardFixtures {
    static func petOwnerSnapshot(selectedPetID: String?) -> HomeDashboardSnapshot {
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
            reminders: [
                HomeDashboardSnapshot.Reminder(
                    id: "reminder-vaccine",
                    kind: .vaccine,
                    title: "狂犬疫苗",
                    subtitle: "2026.06.08",
                    dueText: "14 天后",
                    remarks: "建议提前预约同城宠物医院",
                    sourceRef: HomeDashboardSnapshot.Reminder.SourceRef(
                        domain: .preventiveCare,
                        type: .vaccine,
                        recordID: "vaccine-rabies-2026-06"
                    )
                ),
                HomeDashboardSnapshot.Reminder(
                    id: "reminder-deworming",
                    kind: .deworming,
                    title: "体内驱虫",
                    subtitle: "2026.05.28",
                    dueText: "3 天后",
                    remarks: nil,
                    sourceRef: HomeDashboardSnapshot.Reminder.SourceRef(
                        domain: .preventiveCare,
                        type: .deworming,
                        recordID: "deworming-2026-06"
                    )
                ),
                HomeDashboardSnapshot.Reminder(
                    id: "reminder-physical",
                    kind: .followUp,
                    title: "定期体检",
                    subtitle: "2026.04.15",
                    dueText: "30 天后",
                    remarks: "基础血常规与生化筛查",
                    sourceRef: nil
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
                    id: "event-abnormal",
                    eventKind: .health,
                    title: "异常记录",
                    subtitle: "食欲、精神 · 明显，待跟进",
                    occurredText: "22:15",
                    occurredAt: nil
                ),
                HomeDashboardSnapshot.TimelineEvent(
                    id: "event-feeding",
                    eventKind: .daily,
                    title: "已喂食",
                    subtitle: "主粮 · 正常",
                    occurredText: "08:30",
                    occurredAt: nil
                ),
                HomeDashboardSnapshot.TimelineEvent(
                    id: "event-quick-poop-normal",
                    eventKind: .daily,
                    title: "便便正常",
                    subtitle: "粪便状态：健康成型",
                    occurredText: "09:10",
                    occurredAt: nil
                ),
                HomeDashboardSnapshot.TimelineEvent(
                    id: "event-quick-energy-normal",
                    eventKind: .daily,
                    title: "精神不错",
                    subtitle: "精神与活力：正常平稳",
                    occurredText: "12:20",
                    occurredAt: nil
                ),
                HomeDashboardSnapshot.TimelineEvent(
                    id: "event-quick-appetite-normal",
                    eventKind: .daily,
                    title: "食欲正常",
                    subtitle: "晚餐吃完，状态稳定",
                    occurredText: "18:40",
                    occurredAt: nil
                ),
                HomeDashboardSnapshot.TimelineEvent(
                    id: "event-weight",
                    eventKind: .weight,
                    title: "体重更新",
                    subtitle: "4.20 kg，较上次 -0.15 kg",
                    occurredText: "21:05",
                    occurredAt: nil
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
            ],
            pantryItems: [
                HomeDashboardSnapshot.PantryPreviewItem(
                    id: "pantry-1",
                    title: "原味六种鱼",
                    subtitle: "消耗中",
                    coverImageAssetName: "https://picsum.photos/400/500?random=11"
                ),
                HomeDashboardSnapshot.PantryPreviewItem(
                    id: "pantry-2",
                    title: "风干厚切牛肉",
                    subtitle: "消耗中",
                    coverImageAssetName: "https://picsum.photos/400/500?random=13"
                ),
                HomeDashboardSnapshot.PantryPreviewItem(
                    id: "pantry-3",
                    title: "高纯营养化毛膏",
                    subtitle: "周期喂食",
                    coverImageAssetName: "https://picsum.photos/400/500?random=14"
                ),
                HomeDashboardSnapshot.PantryPreviewItem(
                    id: "pantry-4",
                    title: "三文鱼主食罐",
                    subtitle: "消耗中",
                    coverImageAssetName: "https://picsum.photos/400/500?random=16"
                )
            ]
        )
    }

    static func petSwitcher(selectedPetID: String?) -> [HomeDashboardSnapshot.PetSwitchItem] {
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

    static func heroSummary(for _: String) -> HomeDashboardSnapshot.PetHeroSummary {
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
                pantryItemCount: 12,
                pantryLastAddedDate: "2026.06.24",
                dewormingDaysLeft: 3,
                dewormingDate: "2026.05.28",
                preventiveCare: HomeDashboardSnapshot.PetHeroStats.PreventiveCareSummary(
                    kind: .vaccine,
                    daysDelta: 3,
                    dueDateText: "2026.06.28"
                )
            )
        )
    }

    static func petOwnerActions() -> [HomeDashboardSnapshot.Action] {
        [
            HomeDashboardSnapshot.Action(
                kind: .walk,
                title: "遛弯",
                subtitle: "户外活动记录"
            ),
            HomeDashboardSnapshot.Action(
                kind: .healthRecord,
                title: "健康记录",
                subtitle: "疫苗、驱虫、体检"
            ),
            HomeDashboardSnapshot.Action(
                kind: .preventiveCare,
                title: "疫苗/驱虫",
                subtitle: "查看提醒与历史"
            ),
            HomeDashboardSnapshot.Action(
                kind: .addReminder,
                title: "添加提醒",
                subtitle: "待定稿"
            ),
            HomeDashboardSnapshot.Action(
                kind: .bookHospital,
                title: "预约医院",
                subtitle: "同城服务协同"
            )
        ]
    }
}
