import SwiftUI
import MaohuobanDesignSystem

// AIAssistantConfirmationTaskCardHeader 写入确认卡标题
// 核心职责：
// - 承载确认任务图标和标题
// - 保持卡片头部与参考权限卡结构一致
struct AIAssistantConfirmationTaskCardHeader: View {
    let title: String

    var body: some View {
        Label {
            Text(title)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        } icon: {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
        }
    }
}
