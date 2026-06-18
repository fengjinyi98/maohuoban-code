import Foundation

private extension Array {
    var nonEmpty: [Element]? {
        isEmpty ? nil : self
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
            careSummary: careSummary ?? fallback.careSummary,
            reminders: reminders.isEmpty ? fallback.reminders : reminders,
            quickActions: quickActions.isEmpty ? fallback.quickActions : quickActions,
            partnerRecommendation: partnerRecommendation ?? fallback.partnerRecommendation,
            recentTimeline: recentTimeline.isEmpty ? fallback.recentTimeline : recentTimeline,
            merchantDashboard: merchantDashboard,
            emptyState: emptyState,
            recommendedContent: recommendedContent.isEmpty ? fallback.recommendedContent : recommendedContent,
            petAlbums: petAlbums?.nonEmpty ?? fallback.petAlbums,
            galleryAlbums: galleryAlbums?.nonEmpty ?? fallback.galleryAlbums
        )
    }

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
            careSummary: careSummary,
            reminders: reminders,
            quickActions: quickActions,
            partnerRecommendation: partnerRecommendation,
            recentTimeline: recentTimeline,
            merchantDashboard: merchantDashboard,
            emptyState: emptyState,
            recommendedContent: recommendedContent,
            petAlbums: petAlbums,
            galleryAlbums: galleryAlbums
        )
    }
}
