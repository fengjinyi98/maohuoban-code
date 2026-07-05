import Foundation

// AIAssistantMessageContextMenuAction AI 消息长按菜单动作
// 核心职责：
// - 描述消息气泡长按后的系统菜单项
// - 为发送者消息提供复制和编辑入口
enum AIAssistantMessageContextMenuAction: String, Identifiable {
    case copy
    case edit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .copy:
            "复制"
        case .edit:
            "编辑"
        }
    }

    var systemImageName: String {
        switch self {
        case .copy:
            "doc.on.doc"
        case .edit:
            "pencil"
        }
    }
}
