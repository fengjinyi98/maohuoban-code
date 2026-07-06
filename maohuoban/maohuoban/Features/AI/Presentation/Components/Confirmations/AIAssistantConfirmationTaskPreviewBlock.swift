import SwiftUI
import MaohuobanDesignSystem

// AIAssistantConfirmationTaskPreviewBlock 写入内容预览
// 核心职责：
// - 展示即将写入的观察文本
// - 保持预览内容在确认前可审阅
struct AIAssistantConfirmationTaskPreviewBlock: View {
    let note: String
    let sourceLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            Text(note)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .fixedSize(horizontal: false, vertical: true)

            if let sourceLabel, sourceLabel.isEmpty == false {
                Text(sourceLabel)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(MHBTheme.ColorToken.labelQuaternary.color.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
