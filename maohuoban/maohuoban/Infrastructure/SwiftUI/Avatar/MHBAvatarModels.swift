import Foundation
import SwiftUI
import MaohuobanDesignSystem

// MHBAvatarSource 头像图片来源
// 核心职责：
// - 统一承接本地资源、远端地址和系统兜底图标
// - 为跨 Feature 头像组件提供稳定输入
nonisolated enum MHBAvatarSource: Equatable, Hashable, Sendable {
    case asset(String)
    case remote(URL)
    case systemSymbol(String)
    case empty

    static func remoteOrAsset(_ rawValue: String?) -> Self {
        guard let rawValue else { return .empty }
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else { return .empty }

        if let url = URL(string: trimmedValue),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return .remote(url)
        }

        return .asset(trimmedValue)
    }
}

// MHBAvatarSex 头像性别展示值
// 核心职责：
// - 为宠物和用户头像描边提供统一性别输入
// - 在性别未知时回落到中性视觉
nonisolated enum MHBAvatarSex: String, Equatable, Hashable, Sendable {
    case male
    case female
    case unknown
}

// MHBAvatarSexVisibility 用户性别展示隐私
// 核心职责：
// - 表达用户是否允许头像展示性别颜色
// - 将隐私设置与头像描边决策解耦
nonisolated enum MHBAvatarSexVisibility: Equatable, Hashable, Sendable {
    case visible
    case hidden
}

// MHBAvatarSpecies 宠物物种展示值
// 核心职责：
// - 为宠物头像缺省态提供稳定图标
// - 隔离业务物种枚举与头像基础设施
nonisolated enum MHBAvatarSpecies: String, Equatable, Hashable, Sendable {
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

// MHBAvatarUser 用户头像展示模型
// 核心职责：
// - 提供用户头像渲染所需的最小身份信息
// - 携带性别隐私以决定用户头像描边
nonisolated struct MHBAvatarUser: Equatable, Hashable, Sendable {
    let id: String
    let displayName: String
    let source: MHBAvatarSource
    let sex: MHBAvatarSex
    let sexVisibility: MHBAvatarSexVisibility
}

// MHBAvatarPet 宠物头像展示模型
// 核心职责：
// - 提供宠物头像渲染所需的最小身份信息
// - 携带物种和性别以决定兜底图标与必选描边
nonisolated struct MHBAvatarPet: Equatable, Hashable, Sendable {
    let id: String
    let name: String
    let source: MHBAvatarSource
    let species: MHBAvatarSpecies
    let sex: MHBAvatarSex
}

// MHBAvatarSubject 头像主体
// 核心职责：
// - 表达单用户、单宠物和人宠融合三类头像语义
// - 让业务层先决定主体，视图层只负责渲染
nonisolated enum MHBAvatarSubject: Equatable, Hashable, Sendable {
    case user(MHBAvatarUser)
    case pet(MHBAvatarPet)
    case petWithUser(pet: MHBAvatarPet, user: MHBAvatarUser)
}

// MHBAvatarBorderPalette 头像描边色板
// 核心职责：
// - 固化宠物头像必选描边和用户隐私描边规则
// - 为 SwiftUI 渲染层提供统一颜色来源
nonisolated enum MHBAvatarBorderPalette: Equatable, Hashable, Sendable {
    case male
    case female
    case neutral

    static func pet(sex: MHBAvatarSex) -> Self {
        switch sex {
        case .male:
            .male
        case .female:
            .female
        case .unknown:
            .neutral
        }
    }

    static func user(
        sex: MHBAvatarSex,
        sexVisibility: MHBAvatarSexVisibility
    ) -> Self {
        guard sexVisibility == .visible else {
            return .neutral
        }

        switch sex {
        case .male:
            return .male
        case .female:
            return .female
        case .unknown:
            return .neutral
        }
    }

    var foregroundColor: Color {
        switch self {
        case .male:
            Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
        case .female:
            Color(red: 236 / 255, green: 72 / 255, blue: 153 / 255)
        case .neutral:
            MHBTheme.ColorToken.labelTertiary.color
        }
    }

    var gradient: LinearGradient {
        switch self {
        case .male:
            LinearGradient(
                colors: [
                    Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255),
                    Color(red: 147 / 255, green: 197 / 255, blue: 253 / 255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .female:
            LinearGradient(
                colors: [
                    Color(red: 236 / 255, green: 72 / 255, blue: 153 / 255),
                    Color(red: 249 / 255, green: 168 / 255, blue: 212 / 255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .neutral:
            LinearGradient(
                colors: [
                    Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255),
                    Color(red: 203 / 255, green: 213 / 255, blue: 225 / 255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MHBAvatarShape 头像形状
// 核心职责：
// - 区分默认圆形头像和高空间利用率方形头像
// - 为方形头像提供随尺寸变化的圆角
nonisolated enum MHBAvatarShape: Equatable, Hashable, Sendable {
    case circle
    case squircle

    func cornerRadius(for size: CGFloat) -> CGFloat {
        switch self {
        case .circle:
            size / 2
        case .squircle:
            max(MHBTheme.Radius.medium, size * 0.3125)
        }
    }
}

// MHBAvatarSize 头像尺寸
// 核心职责：
// - 统一头像在 Feed、评论、入口卡片和资料页中的常用尺寸
// - 保留自定义尺寸以兼容少量特殊布局
nonisolated enum MHBAvatarSize: Equatable, Hashable, Sendable {
    case extraSmall
    case small
    case medium
    case large
    case extraLarge
    case custom(CGFloat)

    var value: CGFloat {
        switch self {
        case .extraSmall:
            28
        case .small:
            36
        case .medium:
            56
        case .large:
            64
        case .extraLarge:
            88
        case .custom(let value):
            value
        }
    }
}

// MHBAvatarCompositeLayout 人宠融合头像布局参数
// 核心职责：
// - 约束主人小头像在紧凑尺寸下的占比
// - 为融合头像视图提供可测试的尺寸计算
nonisolated enum MHBAvatarCompositeLayout {
    static func ownerAvatarSize(for dimension: CGFloat) -> CGFloat {
        min(
            max(dimension * 0.44, 24),
            dimension * 0.62
        )
    }
}
