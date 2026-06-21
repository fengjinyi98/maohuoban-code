import Foundation

// AIAssistantSelectedAttachment AI 助手已选附件
// 核心职责：
// - 表达输入栏当前已挂载的媒体附件摘要
// - 将附件来源和展示文案与图片对象解耦
struct AIAssistantSelectedAttachment: Identifiable, Equatable {
    let id = UUID()
    let source: AIAssistantAttachmentSource
    let title: String
}
