import SwiftUI

// AIAssistantMessageContextMenuContent AI 消息长按菜单内容
// 核心职责：
// - 渲染发送者消息长按后的系统菜单项
// - 将菜单点击转发给消息气泡处理
struct AIAssistantMessageContextMenuContent: View {
    let actions: [AIAssistantMessageContextMenuAction]
    let onAction: (AIAssistantMessageContextMenuAction) -> Void

    var body: some View {
        ForEach(actions) { action in
            Button {
                onAction(action)
            } label: {
                Label(action.title, systemImage: action.systemImageName)
            }
        }
    }
}
