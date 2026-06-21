import Foundation

// AIAssistantAttachmentSource AI 助手附件来源
// 核心职责：
// - 表达输入框加号菜单中的媒体来源
// - 为后续接入系统相机和相册权限预留稳定入口
enum AIAssistantAttachmentSource: Hashable, Identifiable {
    case camera
    case photoLibrary

    var id: String {
        switch self {
        case .camera: "camera"
        case .photoLibrary: "photoLibrary"
        }
    }

    var title: String {
        switch self {
        case .camera: "相机"
        case .photoLibrary: "相册"
        }
    }
}

// AIAssistantConversationHistoryItem AI 对话历史项
// 核心职责：
// - 为右侧对话记录栏提供前端展示数据
// - 保持历史列表与当前本地会话解耦
struct AIAssistantConversationHistoryItem: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
}
