import SwiftUI
import MaohuobanDesignSystem

// MessageRootScreen 消息 Tab 根视图
// 核心职责：
// - 作为消息 Tab NavigationStack 的根内容
// - 承载私信/评论/交易沟通/系统通知列表
struct MessageRootScreen: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "bubble.fill")
                .font(.system(size: 48))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)

            Text("消息")
                .font(MHBTheme.Typography.title)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("通信与通知中心")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("消息")
    }
}
