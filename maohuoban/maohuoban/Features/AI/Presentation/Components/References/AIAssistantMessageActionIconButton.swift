import SwiftUI
import MaohuobanDesignSystem

// AIAssistantMessageActionIconButton AI 回复操作图标按钮
// 核心职责：
// - 统一回复底部操作按钮尺寸和图标样式
// - 将具体动作交由父级注入
struct AIAssistantMessageActionIconButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringResource
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
