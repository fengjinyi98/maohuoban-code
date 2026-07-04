import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordRow 病历记录列表行
// 核心职责：
// - 展示单条病历的诊断、医院和最近追加状态
// - 提供稳定点击区域进入详情页
struct PetMedicalRecordRow: View {
    let record: PetMedicalRecord

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "cross.case.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: 36, height: 36)
                .background(MHBTheme.ColorToken.primary.color.opacity(0.10), in: RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(record.title)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)

                Text(record.subtitle)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)

                Text(record.occurredAtText)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    .lineLimit(1)
            }

            Spacer(minLength: MHBTheme.Spacing.s2)

            VStack(alignment: .trailing, spacing: MHBTheme.Spacing.s2) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

                if !record.updates.isEmpty {
                    Text("\(record.updates.count) 条追加")
                        .font(MHBTheme.Typography.caption.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.success.color)
                }
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .contentShape(Rectangle())
    }
}
