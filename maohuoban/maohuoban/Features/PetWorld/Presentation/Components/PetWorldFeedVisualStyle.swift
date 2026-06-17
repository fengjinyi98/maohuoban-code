import SwiftUI
import MaohuobanDesignSystem

// PetWorldFeedVisualStyle 宠物世界视觉样式映射
// 核心职责：
// - 统一 mock 媒体色调到主题色的映射
// - 统一推荐解释类型到标签样式的映射
extension PetWorldMediaTone {
    var gradientColors: [Color] {
        switch self {
        case .primary:
            [
                MHBTheme.ColorToken.primaryLight.color,
                MHBTheme.ColorToken.primary.color
            ]
        case .teal:
            [
                MHBTheme.ColorToken.teal.color.opacity(0.72),
                MHBTheme.ColorToken.success.color.opacity(0.86)
            ]
        case .purple:
            [
                MHBTheme.ColorToken.purple.color.opacity(0.72),
                MHBTheme.ColorToken.primaryDark.color.opacity(0.86)
            ]
        case .warning:
            [
                MHBTheme.ColorToken.warning.color.opacity(0.62),
                MHBTheme.ColorToken.primary.color.opacity(0.76)
            ]
        }
    }
}

extension PetWorldRecommendationBadgeStyle {
    var tagStyle: MHBTagView<EmptyView>.Style {
        switch self {
        case .relation:
            .primary
        case .quality:
            .success
        case .growth:
            .purple
        case .experience:
            .warning
        }
    }
}
