import SwiftUI
import MaohuobanDesignSystem

// PetRecordEntryContext 宠物记录入口上下文
// 核心职责：
// - 承载日常和健康记录页共享的当前宠物信息
// - 为宠物切换卡片提供性别展示状态
struct PetRecordEntryContext: Hashable, Sendable {
    let petID: String?
    let petName: String?
    let petAvatarURL: String?
    let petSex: PetRecordPetSex

    init(
        petID: String?,
        petName: String? = nil,
        petAvatarURL: String? = nil,
        petSex: PetRecordPetSex = .unknown
    ) {
        self.petID = petID
        self.petName = petName
        self.petAvatarURL = petAvatarURL
        self.petSex = petSex
    }
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
enum PetRecordPetSex: String, Hashable, Sendable {
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
