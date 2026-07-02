import SwiftUI
import MaohuobanDesignSystem

// AIAssistantAttachmentMenu AI 附件来源菜单
// 核心职责：
// - 提供相机和相册两个媒体入口
// - 将选择事件交给上层状态容器
struct AIAssistantAttachmentMenu: View {
    let onSelectAttachmentSource: (AIAssistantAttachmentSource) -> Void

    var body: some View {
        Menu {
            Button {
                onSelectAttachmentSource(.camera)
            } label: {
                Label("相机", systemImage: "camera.fill")
            }

            Button {
                onSelectAttachmentSource(.photoLibrary)
            } label: {
                Label("相册", systemImage: "photo.on.rectangle.angled")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 27, weight: .regular))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("添加附件")
        .accessibilityIdentifier("ai.assistant.attachmentMenu")
    }
}
