import SwiftUI
import MaohuobanDesignSystem

// PetWeightRecordDateRow 体重记录时间行
// 核心职责：
// - 使用系统 DatePicker 选择记录时间
// - 保持行式表单的信息密度
struct PetWeightRecordDateRow: View {
    @Binding var recordedAt: Date

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "calendar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: 28, height: 28)
                .background(MHBTheme.ColorToken.separatorSoft.color, in: RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous))

            Text("记录时间")
                .font(MHBTheme.Typography.callout.weight(.medium))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Spacer()

            DatePicker(
                "记录时间",
                selection: $recordedAt,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
        }
        .padding(.horizontal, MHBTheme.Spacing.s5)
        .frame(height: 68)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MHBTheme.ColorToken.separatorSoft.color)
                .frame(height: 1)
                .padding(.leading, MHBTheme.Spacing.s5)
        }
    }
}
