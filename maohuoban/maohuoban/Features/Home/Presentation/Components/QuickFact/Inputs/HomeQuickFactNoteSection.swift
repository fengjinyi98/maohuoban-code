import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactNoteSection 快捷事实备注区
// 核心职责：
// - 承载可选补充描述
// - 保持输入区域尺寸稳定
struct HomeQuickFactNoteSection: View {
    let title: LocalizedStringResource
    let prompt: LocalizedStringResource
    @Binding var note: String

    var body: some View {
        HomeQuickFactSheetSection(title: title) {
            TextField(title, text: $note, prompt: Text(prompt), axis: .vertical)
                .lineLimit(3...5)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .padding(MHBTheme.Spacing.s3)
                .background(MHBTheme.ColorToken.cardSolid.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                        .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                }
        }
    }
}
