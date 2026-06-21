import SwiftUI
import MaohuobanDesignSystem

// ProfileBadgeRarity 展示样式扩展
// 核心职责：
// - 将勋章稀有度映射为展示层色彩
// - 保持网格标签、详情标签和进度强调色一致
extension ProfileBadgeRarity {
    var accentColor: Color {
        switch self {
        case .normal:
            MHBTheme.ColorToken.primary.color
        case .rare:
            MHBTheme.ColorToken.warning.color
        case .epic:
            MHBTheme.ColorToken.purple.color
        case .legendary:
            MHBTheme.ColorToken.primaryDark.color
        }
    }

    var tagBackgroundColor: Color {
        switch self {
        case .normal:
            MHBTheme.ColorToken.primaryBackground.color
        case .rare:
            MHBTheme.ColorToken.warning.color.opacity(0.14)
        case .epic:
            MHBTheme.ColorToken.purple.color.opacity(0.13)
        case .legendary:
            MHBTheme.ColorToken.primaryDark.color.opacity(0.13)
        }
    }
}

// ProfileBadgeStatusPill 勋章状态标签
// 核心职责：
// - 展示已点亮或进度状态
// - 为首页缩略列表和完整网格提供一致的状态表达
struct ProfileBadgeStatusPill: View {
    let badge: ProfileBadge

    var body: some View {
        Text(badge.progressText)
            .font(MHBTheme.Typography.section.weight(.bold))
            .foregroundStyle(foregroundColor)
            .lineLimit(1)
            .padding(.horizontal, MHBTheme.Spacing.s2)
            .padding(.vertical, 3)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous))
    }

    private var foregroundColor: Color {
        badge.isEarned ? MHBTheme.ColorToken.danger.color : MHBTheme.ColorToken.labelSecondary.color
    }

    private var backgroundColor: Color {
        badge.isEarned ? MHBTheme.ColorToken.danger.color.opacity(0.1) : MHBTheme.ColorToken.separator.color
    }
}
