import Foundation

// PetManagementPet 我的宠物列表展示模型
// 核心职责：
// - 承载“我的宠物”列表首屏展示字段
// - 提供进入现有宠物编辑流程所需的轻量档案上下文
struct PetManagementPet: Hashable, Identifiable {
    enum Sex: Hashable {
        case male
        case female
        case unknown

        var symbolText: String? {
            switch self {
            case .male: "♂"
            case .female: "♀"
            case .unknown: nil
            }
        }
    }

    let id: String
    let name: String
    let species: PetProfileEditProfile.Species
    let breedText: String
    let ageText: String
    let sex: Sex
    let avatarAssetName: String?
    let avatarURL: String?
    let statusTags: [PetManagementStatusTag]
    let companionshipDays: Int
    let editProfile: PetProfileEditProfile

    static let mockPets = [
        PetManagementPet(
            id: "pet-mochi",
            name: "糯米",
            species: .dog,
            breedText: "金毛寻回犬",
            ageText: "2岁4个月",
            sex: .male,
            avatarAssetName: "HomePetHeroMock",
            avatarURL: nil,
            statusTags: [
                PetManagementStatusTag(
                    id: "coCareMay",
                    title: "与阿May共管",
                    systemImage: "person.2.fill",
                    style: .highlighted
                ),
                PetManagementStatusTag(id: "neutered", title: "已绝育")
            ],
            companionshipDays: 845,
            editProfile: PetProfileEditProfile(
                id: "pet-mochi",
                name: "糯米",
                species: .dog,
                breed: "金毛寻回犬",
                avatarURL: nil,
                heroMedia: .image(assetName: "HomePetHeroMock"),
                heroThemeColorHex: nil,
                heroContentColorScheme: nil,
                profileCode: "9011562600000019",
                chipNumber: "",
                sexText: "公",
                birthDateText: "2024-02-12",
                arrivalDateText: "2024-02-26",
                weightText: "28.5 kg",
                neuterStatusText: "已绝育",
                personalityTags: ["亲人", "活跃", "爱玩"],
                note: "与阿May共管，日常照护记录稳定。",
                nameEditPolicy: nil
            )
        ),
        PetManagementPet(
            id: "pet-tuanzi",
            name: "团子",
            species: .cat,
            breedText: "英国短毛猫",
            ageText: "8个月",
            sex: .female,
            avatarAssetName: "HomePetAlbum2",
            avatarURL: nil,
            statusTags: [
                PetManagementStatusTag(
                    id: "privateRecord",
                    title: "私密记录",
                    systemImage: "lock.fill"
                ),
                PetManagementStatusTag(id: "intact", title: "未绝育")
            ],
            companionshipDays: 210,
            editProfile: PetProfileEditProfile(
                id: "pet-tuanzi",
                name: "团子",
                species: .cat,
                breed: "英国短毛猫",
                avatarURL: nil,
                heroMedia: .image(assetName: "HomePetAlbum2"),
                heroThemeColorHex: nil,
                heroContentColorScheme: nil,
                profileCode: "9011562600000020",
                chipNumber: "",
                sexText: "母",
                birthDateText: "2025-10-08",
                arrivalDateText: "2025-11-22",
                weightText: "3.2 kg",
                neuterStatusText: "未绝育",
                personalityTags: ["好奇", "黏人"],
                note: "私密记录，仅主人可见。",
                nameEditPolicy: nil
            )
        )
    ]

    static func editContext(
        selectedPet: PetManagementPet,
        pets: [PetManagementPet]
    ) -> PetProfileEditContext {
        PetProfileEditContext(
            selectedProfile: selectedPet.editProfile,
            profiles: pets.map(\.editProfile)
        )
    }
}
