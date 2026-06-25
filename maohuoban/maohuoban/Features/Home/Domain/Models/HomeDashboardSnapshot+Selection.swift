import Foundation

private extension Array {
    var nonEmpty: [Element]? {
        isEmpty ? nil : self
    }
}

private extension Array where Element == HomeDashboardSnapshot.Action {
    func resolvedQuickActions(
        for identityKind: HomeDashboardSnapshot.IdentityKind,
        fallback: [HomeDashboardSnapshot.Action]
    ) -> [HomeDashboardSnapshot.Action] {
        let clientActions = HomeDashboardSnapshot.Action.clientOwnedQuickActions(for: identityKind)
        guard clientActions.isEmpty else {
            return appendingServerOnlyActions(after: clientActions)
        }

        return isEmpty ? fallback : self
    }

    func appendingServerOnlyActions(
        after clientActions: [HomeDashboardSnapshot.Action]
    ) -> [HomeDashboardSnapshot.Action] {
        guard clientActions.isEmpty == false else {
            return self
        }

        let clientKinds = clientActions.map(\.kind)
        let serverOnlyActions = filter { action in
            !clientKinds.contains(action.kind)
        }

        return clientActions + serverOnlyActions
    }
}

extension HomeDashboardSnapshot {
    // supplementingMissingSections 合并首页缺省展示模块
    // 核心职责：
    // - 保留后端返回的真实身份、宠物和已有业务数据
    // - 在开发态用 Mock 数据补齐尚未接入后端的展示 section
    func supplementingMissingSections(from fallback: HomeDashboardSnapshot) -> HomeDashboardSnapshot {
        HomeDashboardSnapshot(
            identity: identity,
            selectedPet: selectedPet,
            petSwitcher: petSwitcher,
            reminders: reminders.isEmpty ? fallback.reminders : reminders,
            quickActions: quickActions.resolvedQuickActions(
                for: identity.kind,
                fallback: fallback.quickActions
            ),
            partnerRecommendation: partnerRecommendation ?? fallback.partnerRecommendation,
            recentTimeline: recentTimeline.toppingUpHomeTimeline(from: fallback.recentTimeline, minimumCount: 4),
            merchantDashboard: merchantDashboard,
            emptyState: emptyState,
            recommendedContent: recommendedContent.isEmpty ? fallback.recommendedContent : recommendedContent,
            petAlbums: petAlbums?.nonEmpty ?? fallback.petAlbums,
            galleryAlbums: galleryAlbums?.nonEmpty ?? fallback.galleryAlbums,
            pantryItems: pantryItems?.nonEmpty ?? fallback.pantryItems
        )
    }

    // resolvingClientOwnedQuickActions 解析客户端自有快捷入口
    // 核心职责：
    // - 让基础功能入口脱离后端 quick_actions 控制
    // - 保留后端后续可能追加的非基础业务入口
    func resolvingClientOwnedQuickActions() -> HomeDashboardSnapshot {
        HomeDashboardSnapshot(
            identity: identity,
            selectedPet: selectedPet,
            petSwitcher: petSwitcher,
            reminders: reminders,
            quickActions: quickActions.resolvedQuickActions(
                for: identity.kind,
                fallback: []
            ),
            partnerRecommendation: partnerRecommendation,
            recentTimeline: recentTimeline,
            merchantDashboard: merchantDashboard,
            emptyState: emptyState,
            recommendedContent: recommendedContent,
            petAlbums: petAlbums,
            galleryAlbums: galleryAlbums,
            pantryItems: pantryItems
        )
    }
}

private extension Array where Element == HomeDashboardSnapshot.TimelineEvent {
    func toppingUpHomeTimeline(
        from fallback: [HomeDashboardSnapshot.TimelineEvent],
        minimumCount: Int
    ) -> [HomeDashboardSnapshot.TimelineEvent] {
        guard count < minimumCount else {
            return self
        }

        var result = self
        var existingIDs = Set(map(\.id))
        var existingFingerprints = Set(map(\.homeTimelineSupplementFingerprint))

        for event in fallback
        where !existingIDs.contains(event.id)
            && !existingFingerprints.contains(event.homeTimelineSupplementFingerprint) {
            result.append(event)
            existingIDs.insert(event.id)
            existingFingerprints.insert(event.homeTimelineSupplementFingerprint)

            if result.count >= minimumCount {
                break
            }
        }

        return result.isEmpty ? fallback : result
    }
}

private extension HomeDashboardSnapshot.TimelineEvent {
    var homeTimelineSupplementFingerprint: String {
        "\(eventKind.rawValue)|\(title)|\(subtitle)"
    }
}

private extension HomeDashboardSnapshot.Action {
    static func clientOwnedQuickActions(
        for identityKind: HomeDashboardSnapshot.IdentityKind
    ) -> [HomeDashboardSnapshot.Action] {
        switch identityKind {
        case .petOwner:
            [
                HomeDashboardSnapshot.Action(
                    kind: .dailyRecord,
                    title: "记录日常",
                    subtitle: "饮食、情绪、排便"
                ),
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
                    kind: .bookHospital,
                    title: "预约医院",
                    subtitle: "同城服务协同"
                )
            ]
        case .newUser, .familyCaretaker, .certifiedMerchant, .unverifiedMerchant:
            []
        }
    }
}

extension HomeDashboardSnapshot {
    // optimisticSelectingPet 构造宠物切换的乐观首页快照
    // 核心职责：
    // - 在后端新快照返回前立即更新选中宠物入口
    // - 保持页面处于 loaded 状态，避免切换宠物时回到全屏加载态
    func optimisticallySelectingPet(id petID: String) -> HomeDashboardSnapshot? {
        guard let selectedItem = petSwitcher.first(where: { $0.id == petID }) else {
            return nil
        }

        let updatedPetSwitcher = petSwitcher.map { item in
            PetSwitchItem(
                id: item.id,
                name: item.name,
                species: item.species,
                breed: item.breed,
                avatarURL: item.avatarURL,
                avatarWidth: item.avatarWidth,
                avatarHeight: item.avatarHeight,
                sex: item.sex,
                nameEditPolicy: item.nameEditPolicy,
                isSelected: item.id == petID
            )
        }

        let optimisticPet = PetHeroSummary(
            id: selectedItem.id,
            name: selectedItem.name,
            species: selectedItem.species,
            breed: selectedItem.breed.isEmpty ? selectedPet?.breed ?? "" : selectedItem.breed,
            sex: selectedPet?.sex ?? .unknown,
            ageText: selectedPet?.ageText ?? "",
            statusText: "正在同步档案",
            updatedText: "同步中",
            avatarURL: selectedItem.avatarURL,
            avatarWidth: selectedItem.avatarWidth,
            avatarHeight: selectedItem.avatarHeight,
            heroImageURL: selectedPet?.heroImageURL,
            heroImageWidth: selectedPet?.heroImageWidth,
            heroImageHeight: selectedPet?.heroImageHeight,
            heroVideoURL: selectedPet?.heroVideoURL,
            heroVideoWidth: selectedPet?.heroVideoWidth,
            heroVideoHeight: selectedPet?.heroVideoHeight,
            heroLivePhoto: selectedPet?.heroLivePhoto,
            heroThemeColorHex: selectedPet?.heroThemeColorHex,
            heroContentColorScheme: selectedPet?.heroContentColorScheme,
            heroImageAssetName: selectedPet?.heroImageAssetName,
            heroVideoResourceName: selectedPet?.heroVideoResourceName,
            birthday: selectedPet?.birthday,
            companionshipDays: selectedPet?.companionshipDays,
            nameEditPolicy: selectedItem.nameEditPolicy ?? selectedPet?.nameEditPolicy,
            stats: selectedPet?.stats
        )

        return HomeDashboardSnapshot(
            identity: identity,
            selectedPet: optimisticPet,
            petSwitcher: updatedPetSwitcher,
            reminders: reminders,
            quickActions: quickActions,
            partnerRecommendation: partnerRecommendation,
            recentTimeline: recentTimeline,
            merchantDashboard: merchantDashboard,
            emptyState: emptyState,
            recommendedContent: recommendedContent,
            petAlbums: petAlbums,
            galleryAlbums: galleryAlbums,
            pantryItems: pantryItems
        )
    }
}
