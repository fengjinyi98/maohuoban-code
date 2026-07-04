import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareRecordInfoRow 疫苗驱虫详情键值行
// 核心职责：
// - 展示单项详情字段标题和值
// - 保持详情页信息行对齐和文本样式统一
struct PetPreventiveCareRecordInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Text(title)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Spacer(minLength: MHBTheme.Spacing.s3)

            Text(value)
                .font(MHBTheme.Typography.callout.weight(.medium))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, MHBTheme.Spacing.s3)
    }
}
