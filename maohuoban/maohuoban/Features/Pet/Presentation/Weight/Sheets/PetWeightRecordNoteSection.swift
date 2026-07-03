import SwiftUI
import MaohuobanDesignSystem

// PetWeightRecordNoteSection 体重记录备注区域
// 核心职责：
// - 接收用户对称重场景和状态的备注
// - 替代旧标签选择模型，保持自由文本输入
struct PetWeightRecordNoteSection: View {
    @Binding var noteText: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("备注（选填）")
                .font(MHBTheme.Typography.caption.weight(.medium))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            TextField("例如：饭前称重、体检后记录", text: $noteText, axis: .vertical)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(3, reservesSpace: true)
                .padding(MHBTheme.Spacing.s3)
                .background(MHBTheme.ColorToken.cardSolid.color, in: RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        }
        .padding(.horizontal, MHBTheme.Spacing.s5)
        .padding(.top, MHBTheme.Spacing.s4)
    }
}
