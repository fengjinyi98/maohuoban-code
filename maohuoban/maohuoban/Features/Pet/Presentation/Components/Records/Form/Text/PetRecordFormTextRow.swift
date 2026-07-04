import SwiftUI
import MaohuobanDesignSystem

// PetRecordFormTextRow 记录流程通用单行输入
// 核心职责：
// - 统一记录表单字段标题和右侧输入布局
// - 支持短文本信息录入
struct PetRecordFormTextRow: View {
    let title: LocalizedStringResource
    @Binding var text: String
    let prompt: LocalizedStringResource

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Text(title)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Spacer(minLength: MHBTheme.Spacing.s2)

            TextField(title, text: $text, prompt: Text(prompt))
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.vertical, MHBTheme.Spacing.s3)
    }
}
