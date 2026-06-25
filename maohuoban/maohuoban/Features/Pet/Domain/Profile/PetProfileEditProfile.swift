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
        case remoteImage(urlString: String, fallbackAssetName: String)
        case video(resourceName: String, fileExtension: String, fallbackImageAssetName: String?)
        case remoteVideo(urlString: String, fallbackImageURLString: String?, fallbackImageAssetName: String?)
        case remoteLivePhoto(
            stillURLString: String,
            pairedVideoURLString: String,
            cropMetadata: MHBImageCropMetadata?,
            fallbackImageAssetName: String?
        )
    }

    enum HeroContentColorScheme: Hashable {
        case light
        case dark
    }

    let id: String
    let name: String
    let species: Species
    let breed: String
    let avatarURL: String?
    let heroMedia: HeroMedia
    let heroThemeColorHex: String?
    let heroContentColorScheme: HeroContentColorScheme?
    let profileCode: String
    let chipNumber: String
    let sexText: String
    let birthDateText: String
    let arrivalDateText: String
    let weightText: String
    let neuterStatusText: String
    let personalityTags: [String]
    let note: String
    let nameEditPolicy: PetNameEditPolicy?
    let lifeStatus: String?

    init(
        id: String,
        name: String,
        species: Species,
        breed: String,
        avatarURL: String?,
        heroMedia: HeroMedia,
        heroThemeColorHex: String?,
        heroContentColorScheme: HeroContentColorScheme?,
        profileCode: String,
        chipNumber: String,
        sexText: String,
        birthDateText: String,
        arrivalDateText: String,
        weightText: String,
        neuterStatusText: String,
        personalityTags: [String],
        note: String,
        nameEditPolicy: PetNameEditPolicy?,
        lifeStatus: String? = nil
    ) {
        self.id = id
        self.name = name
        self.species = species
        self.breed = breed
        self.avatarURL = avatarURL
        self.heroMedia = heroMedia
        self.heroThemeColorHex = heroThemeColorHex
        self.heroContentColorScheme = heroContentColorScheme
        self.profileCode = profileCode
        self.chipNumber = chipNumber
        self.sexText = sexText
        self.birthDateText = birthDateText
        self.arrivalDateText = arrivalDateText
        self.weightText = weightText
        self.neuterStatusText = neuterStatusText
        self.personalityTags = personalityTags
        self.note = note
        self.nameEditPolicy = nameEditPolicy
        self.lifeStatus = lifeStatus
    }

    init(
        id: String,
        name: String,
        species: Species,
        avatarURL: String?,
        heroMedia: HeroMedia,
        heroThemeColorHex: String?,
        heroContentColorScheme: HeroContentColorScheme?,
        profileCode: String,
        chipNumber: String,
        sexText: String,
        birthDateText: String,
        arrivalDateText: String,
        weightText: String,
        neuterStatusText: String,
        personalityTags: [String],
        note: String
    ) {
        self.init(
            id: id,
            name: name,
            species: species,
            breed: "",
            avatarURL: avatarURL,
            heroMedia: heroMedia,
            heroThemeColorHex: heroThemeColorHex,
            heroContentColorScheme: heroContentColorScheme,
            profileCode: profileCode,
            chipNumber: chipNumber,
            sexText: sexText,
            birthDateText: birthDateText,
            arrivalDateText: arrivalDateText,
            weightText: weightText,
            neuterStatusText: neuterStatusText,
            personalityTags: personalityTags,
            note: note,
            nameEditPolicy: nil,
            lifeStatus: nil
        )
    }
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
