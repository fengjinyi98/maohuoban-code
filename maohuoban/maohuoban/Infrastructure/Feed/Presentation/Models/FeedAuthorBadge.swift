import SwiftUI
import MaohuobanDesignSystem

// FeedAuthorBadge Feed 作者行身份标签
// 核心职责：
// - 描述作者名称旁的推荐、认证或身份标签
// - 将标签语义样式收敛到 Feed 基础设施
struct FeedAuthorBadge: Equatable {
    let title: String
    let systemImageName: String?
    let style: FeedAuthorBadgeStyle
}

// FeedAuthorBadgeStyle Feed 作者身份标签样式
// 核心职责：
// - 提供 Feed 作者行标签的语义配色
// - 让业务卡片复用同一套身份标签外观
enum FeedAuthorBadgeStyle: Equatable {
    case subtle
    case primary
    case success
    case warning

    var foregroundColor: Color {
        switch self {
        case .subtle:
            MHBTheme.ColorToken.labelSecondary.color
        case .primary:
            MHBTheme.ColorToken.primaryDark.color
        case .success:
            MHBTheme.ColorToken.success.color
        case .warning:
            MHBTheme.ColorToken.warning.color
        }
    }

    var backgroundColor: Color {
        switch self {
        case .subtle:
            MHBTheme.ColorToken.separatorSoft.color
        case .primary:
            MHBTheme.ColorToken.primaryBackground.color
        case .success:
            MHBTheme.ColorToken.success.color.opacity(0.12)
        case .warning:
            MHBTheme.ColorToken.warning.color.opacity(0.14)
        }
    }

    var borderColor: Color {
        switch self {
        case .subtle:
            MHBTheme.ColorToken.separator.color
        case .primary:
            MHBTheme.ColorToken.primary.color.opacity(0.22)
        case .success:
            MHBTheme.ColorToken.success.color.opacity(0.24)
        case .warning:
            MHBTheme.ColorToken.warning.color.opacity(0.24)
        }
    }
}
