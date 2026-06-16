import Foundation

// PetProfileEditProfile 宠物资料编辑展示模型
// 核心职责：
// - 承载编辑资料页首屏需要展示的宠物字段
// - 让导航路由只携带页面所需的轻量数据
struct PetProfileEditProfile: Hashable, Identifiable {
    enum Species: String, Hashable {
        case dog
        case cat
        case other

        var systemImage: String {
            switch self {
            case .dog: "dog.fill"
            case .cat: "cat.fill"
            case .other: "pawprint.fill"
            }
        }
    }

    enum HeroMedia: Hashable {
        case image(assetName: String)
        case video(resourceName: String, fileExtension: String, fallbackImageAssetName: String?)
    }

    let id: String
    let name: String
    let species: Species
    let avatarURL: String?
    let heroMedia: HeroMedia
    let chipNumber: String
    let sexText: String
    let birthDateText: String
    let weightText: String
    let neuterStatusText: String
    let personalityTags: [String]
    let note: String
}

// PetProfileEditContext 宠物资料编辑上下文
// 核心职责：
// - 承载编辑页初始选中宠物和可切换宠物列表
// - 保证编辑页路由携带完整首屏展示数据
struct PetProfileEditContext: Hashable {
    let selectedProfile: PetProfileEditProfile
    let profiles: [PetProfileEditProfile]

    init(
        selectedProfile: PetProfileEditProfile,
        profiles: [PetProfileEditProfile]
    ) {
        self.selectedProfile = selectedProfile

        var uniqueProfiles: [PetProfileEditProfile] = []
        for profile in [selectedProfile] + profiles where !uniqueProfiles.contains(where: { $0.id == profile.id }) {
            uniqueProfiles.append(profile)
        }
        self.profiles = uniqueProfiles
    }
}
