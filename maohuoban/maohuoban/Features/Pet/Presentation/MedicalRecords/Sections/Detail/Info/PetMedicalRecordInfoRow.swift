import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordInfoRow 病历详情信息行
// 核心职责：
// - 展示病历字段和值
// - 支持右侧多行医疗文本
struct PetMedicalRecordInfoRow: View {
    let title: LocalizedStringResource
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s4) {
            Text(title)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Spacer(minLength: MHBTheme.Spacing.s4)

            Text(value.isEmpty ? "未填写" : value)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, MHBTheme.Spacing.s3)
    }
}
