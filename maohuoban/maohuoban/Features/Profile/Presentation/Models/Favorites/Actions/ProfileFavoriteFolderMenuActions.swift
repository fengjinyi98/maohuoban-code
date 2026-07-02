import Foundation

// ProfileFavoriteFolderContextMenuAction 收藏夹长按菜单动作
// 核心职责：
// - 描述收藏夹卡片长按菜单可展示的操作
// - 为菜单文案、图标和危险操作语义提供稳定来源
enum ProfileFavoriteFolderContextMenuAction: Equatable, Identifiable {
    case editNameAndPrivacy
    case togglePin(isPinned: Bool)
    case share
    case delete

    nonisolated var id: String {
        switch self {
        case .editNameAndPrivacy:
            "editNameAndPrivacy"
        case .togglePin(let isPinned):
            "togglePin.\(isPinned)"
        case .share:
            "share"
        case .delete:
            "delete"
        }
    }

    nonisolated var title: String {
        switch self {
        case .editNameAndPrivacy:
            "编辑名字和隐私"
        case .togglePin(let isPinned):
            isPinned ? "取消固定" : "固定"
        case .share:
            "分享"
        case .delete:
            "删除"
        }
    }

    nonisolated var systemImageName: String {
        switch self {
        case .editNameAndPrivacy:
            "pencil"
        case .togglePin(let isPinned):
            isPinned ? "pin.slash" : "pin"
        case .share:
            "square.and.arrow.up"
        case .delete:
            "trash"
        }
    }
}

// ProfileFavoriteFolderContextMenuActionResolver 收藏夹长按菜单动作解析器
// 核心职责：
// - 根据收藏夹固定状态生成菜单动作顺序
// - 保持菜单展示规则独立于 SwiftUI 视图
enum ProfileFavoriteFolderContextMenuActionResolver {
    nonisolated static func actions(isPinned: Bool) -> [ProfileFavoriteFolderContextMenuAction] {
        [
            .editNameAndPrivacy,
            .togglePin(isPinned: isPinned),
            .share,
            .delete
        ]
    }
}
