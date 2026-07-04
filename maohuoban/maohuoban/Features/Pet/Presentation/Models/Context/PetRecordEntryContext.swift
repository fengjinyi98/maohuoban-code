import SwiftUI
import MaohuobanDesignSystem

// PetRecordEntryContext 宠物记录入口上下文
// 核心职责：
// - 承载日常、病历和专项记录页共享的当前宠物信息
// - 为宠物切换卡片提供性别展示状态
struct PetRecordEntryContext: Hashable, Sendable {
    let petID: String?
    let petName: String?
    let petAvatarURL: String?
    let petSpecies: PetRecordPetSpecies
    let petSex: PetRecordPetSex
    let lifeStatus: String?
    let availablePets: [PetRecordSwitchPet]

    init(
        petID: String?,
        petName: String? = nil,
        petAvatarURL: String? = nil,
        petSpecies: PetRecordPetSpecies = .other,
        petSex: PetRecordPetSex = .unknown,
        lifeStatus: String? = nil,
        availablePets: [PetRecordSwitchPet] = []
    ) {
        self.petID = petID
        self.petName = petName
        self.petAvatarURL = petAvatarURL
        self.petSpecies = petSpecies
        self.petSex = petSex
        self.lifeStatus = lifeStatus
        self.availablePets = availablePets
    }

    var selectedSwitchPet: PetRecordSwitchPet? {
        if let petID,
           let selectedPet = availablePets.first(where: { $0.id == petID }) {
            return selectedPet
        }

        guard let petID else { return nil }
        return PetRecordSwitchPet(
            id: petID,
            name: petName,
            species: petSpecies,
            breed: "",
            avatarURL: petAvatarURL,
            sex: petSex,
            lifeStatus: lifeStatus,
            isSelected: true
        )
    }

    var resolvedPetID: String? {
        petID ?? selectedSwitchPet?.id
    }

    var resolvedPetName: String? {
        petName ?? selectedSwitchPet?.name
    }

    var resolvedPetSex: PetRecordPetSex {
        switch petSex {
        case .female, .male:
            petSex
        case .unknown:
            selectedSwitchPet?.sex ?? .unknown
        }
    }

    var resolvedPetSpecies: PetRecordPetSpecies {
        selectedSwitchPet?.species ?? petSpecies
    }
}

// PetRecordSwitchPet 记录流程可切换宠物
// 核心职责：
// - 承载记录类页面切换宠物所需的最小资料
// - 避免记录流程依赖首页完整快照模型
struct PetRecordSwitchPet: Hashable, Identifiable, Sendable {
    let id: String
    let name: String?
    let species: PetRecordPetSpecies
    let breed: String
    let avatarURL: String?
    let sex: PetRecordPetSex
    let lifeStatus: String?
    let isSelected: Bool

    init(
        id: String,
        name: String? = nil,
        species: PetRecordPetSpecies = .other,
        breed: String = "",
        avatarURL: String? = nil,
        sex: PetRecordPetSex = .unknown,
        lifeStatus: String? = nil,
        isSelected: Bool
    ) {
        self.id = id
        self.name = name
        self.species = species
        self.breed = breed
        self.avatarURL = avatarURL
        self.sex = sex
        self.lifeStatus = lifeStatus
        self.isSelected = isSelected
    }
}

// PetRecordPetSpecies 记录流程宠物物种展示值
// 核心职责：
// - 以稳定枚举承载记录流程需要的物种信息
// - 解耦记录上下文和首页模型
enum PetRecordPetSpecies: String, Decodable, Hashable, Sendable {
    case dog
    case cat
    case other
}

// PetDailyRecordEntryContext 日常记录入口上下文
// 核心职责：
// - 同时承载记录页展示上下文和后续发布页上下文
// - 保持日常记录保存后进入发布动态的原有链路
struct PetDailyRecordEntryContext: Hashable, Sendable {
    let recordContext: PetRecordEntryContext
    let publishContext: PublishEntryContext
}

// PetRecordPetSex 记录页宠物性别展示值
// 核心职责：
// - 隔离记录页视觉所需的性别状态
// - 提供性别边框颜色和跨首页模型的映射入口
enum PetRecordPetSex: String, Decodable, Hashable, Sendable {
    case female
    case male
    case unknown

    var borderColor: Color {
        switch self {
        case .male:
            Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
        case .female:
            Color(red: 244 / 255, green: 63 / 255, blue: 94 / 255)
        case .unknown:
            MHBTheme.ColorToken.separator.color
        }
    }
}
