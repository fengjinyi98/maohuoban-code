import SwiftUI

// AIAssistantHistoryContextMenuContent AI 历史长按菜单内容
// 核心职责：
// - 渲染聊天历史 row 长按后的系统菜单项
// - 将菜单点击转发给历史页面统一处理
struct AIAssistantHistoryContextMenuContent: View {
    let actions: [AIAssistantHistoryContextMenuAction]
    let onAction: (AIAssistantHistoryContextMenuAction) -> Void

    var body: some View {
        ForEach(actions) { action in
            switch action {
            case .delete:
                Button(role: .destructive) {
                    onAction(action)
                } label: {
                    Label(action.title, systemImage: action.systemImageName)
                }
            case .togglePin, .rename:
                Button {
                    onAction(action)
                } label: {
                    Label(action.title, systemImage: action.systemImageName)
                }
            }
        }
    }
}
