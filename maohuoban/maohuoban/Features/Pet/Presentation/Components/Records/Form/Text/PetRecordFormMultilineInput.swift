import SwiftUI
import MaohuobanDesignSystem

// PetRecordFormMultilineInput 记录流程通用多行输入
// 核心职责：
// - 承载备注和补充说明类长文本
// - 保持输入区域高度稳定
struct PetRecordFormMultilineInput: View {
    let title: LocalizedStringResource
    @Binding var text: String
    let prompt: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            Text(title)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            TextField(title, text: $text, prompt: Text(prompt), axis: .vertical)
                .lineLimit(4...7)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .padding(MHBTheme.Spacing.s3)
                .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        }
        .padding(.vertical, MHBTheme.Spacing.s3)
    }
}
