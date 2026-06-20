import SwiftUI
import MaohuobanDesignSystem

// FeedCardTopTrailingAction Feed 卡片右上角动作配置
// 核心职责：
// - 描述卡片右上角按钮的图标、文案和触发行为
// - 让宠物世界和我的动态组合不同动作语义
enum FeedCardTopTrailingAction: Equatable {
    case moreMenu
    case delete

    var systemImageName: String {
        switch self {
        case .moreMenu:
            "ellipsis"
        case .delete:
            "trash"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .moreMenu:
            "更多"
        case .delete:
            "删除动态"
        }
    }

    var foregroundColor: Color {
        switch self {
        case .moreMenu:
            MHBTheme.ColorToken.labelSecondary.color
        case .delete:
            MHBTheme.ColorToken.danger.color
        }
    }

    var directAction: FeedMoreAction? {
        switch self {
        case .moreMenu:
            nil
        case .delete:
            .delete
        }
    }
}
