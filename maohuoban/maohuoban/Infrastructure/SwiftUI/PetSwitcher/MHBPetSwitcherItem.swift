import Foundation
import SwiftUI
import MaohuobanDesignSystem

// MHBPetSwitcherItem 通用宠物切换展示项
// 核心职责：
// - 为跨页面宠物切换入口提供稳定展示模型
// - 统一维护头像胶囊所需的基础视觉属性
struct MHBPetSwitcherItem: Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let subtitle: String
    let avatarURLString: String?
    let species: MHBPetSwitcherSpecies
    let sex: MHBPetSwitcherSex
    let isSelected: Bool

    var resolvedAvatarURL: URL? {
        guard let avatarURLString, avatarURLString.isEmpty == false else {
            return nil
        }

        return MHBBackendEndpoint.resolve(avatarURLString)
    }
}

// MHBPetSwitcherSpecies 宠物切换物种展示值
// 核心职责：
// - 隔离切换组件所需的物种图标语义
// - 为头像缺省态提供稳定图标
enum MHBPetSwitcherSpecies: String, Hashable, Sendable {
    case dog
    case cat
    case other

    var fallbackSystemImage: String {
        switch self {
        case .dog:
            "pawprint.fill"
        case .cat:
            "cat.fill"
        case .other:
            "heart.fill"
        }
    }
}

// MHBPetSwitcherSex 宠物切换性别展示值
// 核心职责：
// - 统一宠物头像边框的性别色
// - 在未知性别时提供中性边框
enum MHBPetSwitcherSex: String, Hashable, Sendable {
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
