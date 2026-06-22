import SwiftUI

// MessageRootScreen 消息 Tab 根视图
// 核心职责：
// - 作为消息 Tab NavigationStack 的根内容
// - 承载私信/评论/交易沟通/系统通知列表
struct MessageRootScreen: View {
    var body: some View {
        MHBTabPlaceholderRootScreen(
            systemImage: "bubble.fill",
            title: "消息",
            subtitle: "通信与通知中心",
            accessibilityIdentifier: "message.root"
        )
    }
}
