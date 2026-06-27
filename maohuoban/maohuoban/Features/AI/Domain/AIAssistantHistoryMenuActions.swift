import Foundation

// AIAssistantHistoryContextMenuAction AI 历史长按菜单动作
// 核心职责：
// - 描述聊天历史 row 可执行的长按操作
// - 为菜单文案、图标和危险操作语义提供稳定来源
enum AIAssistantHistoryContextMenuAction: Equatable, Identifiable {
    case togglePin(isPinned: Bool)
    case rename
    case delete

    nonisolated var id: String {
        switch self {
        case .togglePin(let isPinned):
            "togglePin.\(isPinned)"
        case .rename:
            "rename"
        case .delete:
            "delete"
        }
    }

    nonisolated var title: String {
        switch self {
        case .togglePin(let isPinned):
            isPinned ? "取消置顶" : "置顶"
        case .rename:
            "重命名"
        case .delete:
            "删除"
        }
    }

    nonisolated var systemImageName: String {
        switch self {
        case .togglePin(let isPinned):
            isPinned ? "pin.slash" : "pin"
        case .rename:
            "pencil"
        case .delete:
            "trash"
        }
    }
}

// AIAssistantHistoryContextMenuActionResolver AI 历史菜单动作解析器
// 核心职责：
// - 根据历史会话状态生成菜单动作顺序
// - 保持菜单展示规则独立于 SwiftUI 视图
enum AIAssistantHistoryContextMenuActionResolver {
    nonisolated static func actions(isPinned: Bool) -> [AIAssistantHistoryContextMenuAction] {
        [
            .togglePin(isPinned: isPinned),
            .rename,
            .delete
        ]
    }
}
