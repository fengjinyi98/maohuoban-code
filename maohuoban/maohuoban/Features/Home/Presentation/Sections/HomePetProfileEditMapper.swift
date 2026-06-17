import Foundation

// HomePetProfileEditMapper 首页宠物摘要到编辑页模型映射器
// 核心职责：
// - 保留后端返回的宠物核心事实和媒体 URL
// - 隔离首页路由与编辑页展示模型转换
enum HomePetProfileEditMapper {
    static func editProfile(
        for pet: HomeDashboardSnapshot.PetHeroSummary
    ) -> PetProfileEditProfile {
        PetProfileEditProfile(
            id: pet.id,
            name: pet.name,
            species: editSpecies(for: pet.species),
            avatarURL: pet.avatarURL,
            heroMedia: editHeroMedia(for: pet.heroMedia),
            profileCode: pet.profileNumber ?? "平台生成",
            chipNumber: pet.microchipNumber ?? "",
            sexText: sexText(for: pet.sex),
            birthDateText: pet.birthday ?? "暂未设置",
            arrivalDateText: pet.arrivalDate ?? "暂未设置",
            weightText: weightText(weightGrams: pet.weightGrams, stats: pet.stats),
            neuterStatusText: neuterStatusText(for: pet.neuterStatus),
            personalityTags: pet.personalityTags,
            note: pet.note ?? pet.statusText
        )
    }

    static func editProfile(
        for item: HomeDashboardSnapshot.PetSwitchItem,
        selectedPet: HomeDashboardSnapshot.PetHeroSummary,
        selectedProfile: PetProfileEditProfile
    ) -> PetProfileEditProfile {
        guard item.id != selectedPet.id else {
            return selectedProfile
        }

        return PetProfileEditProfile(
            id: item.id,
            name: item.name,
            species: editSpecies(for: item.species),
            avatarURL: item.avatarURL,
            heroMedia: .image(assetName: "HomePetHeroMock"),
            profileCode: item.profileNumber ?? "平台生成",
            chipNumber: item.microchipNumber ?? "",
            sexText: "未知",
            birthDateText: item.birthday ?? "暂未设置",
            arrivalDateText: item.arrivalDate ?? "暂未设置",
            weightText: weightText(weightGrams: item.weightGrams, stats: nil),
            neuterStatusText: neuterStatusText(for: item.neuterStatus),
            personalityTags: item.personalityTags,
            note: item.note ?? "暂未设置"
        )
    }

    private static func editSpecies(
        for species: HomeDashboardSnapshot.Species
    ) -> PetProfileEditProfile.Species {
        switch species {
        case .dog: .dog
        case .cat: .cat
        case .other: .other
        }
    }

    private static func editHeroMedia(
        for media: HomeDashboardSnapshot.PetHeroSummary.HeroMedia
    ) -> PetProfileEditProfile.HeroMedia {
        switch media {
        case .image(let assetName):
            .image(assetName: assetName)
        case .remoteImage(let urlString, let fallbackAssetName):
            .remoteImage(urlString: urlString, fallbackAssetName: fallbackAssetName)
        case .video(let resourceName, let fileExtension, let fallbackImageAssetName):
            .video(
                resourceName: resourceName,
                fileExtension: fileExtension,
                fallbackImageAssetName: fallbackImageAssetName
            )
        case .remoteVideo(let urlString, let fallbackImageURLString, let fallbackImageAssetName):
            .remoteVideo(
                urlString: urlString,
                fallbackImageURLString: fallbackImageURLString,
                fallbackImageAssetName: fallbackImageAssetName
            )
        }
    }

    private static func sexText(for sex: HomeDashboardSnapshot.Sex) -> String {
        switch sex {
        case .female: "母"
        case .male: "公"
        case .unknown: "未知"
        }
    }

    private static func weightText(
        weightGrams: Int?,
        stats: HomeDashboardSnapshot.PetHeroStats?
    ) -> String {
        if let weightGrams {
            let kilograms = Double(weightGrams) / 1000
            return String(format: "%.1f kg", kilograms)
        }

        if let weight = stats?.weightVal, !weight.isEmpty {
            return "\(weight) kg"
        }

        return "暂未记录"
    }

    private static func neuterStatusText(for neuterStatus: PetNeuterStatus?) -> String {
        switch neuterStatus {
        case .neutered: "已绝育"
        case .intact: "未绝育"
        case .unknown, nil: "未知"
        }
    }
}
