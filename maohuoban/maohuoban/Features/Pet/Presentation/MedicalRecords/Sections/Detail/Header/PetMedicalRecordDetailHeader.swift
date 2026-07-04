import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordDetailHeader 病历详情头部
// 核心职责：
// - 展示病历标题、医院和发生时间
// - 让用户快速确认当前病历主体
struct PetMedicalRecordDetailHeader: View {
    let record: PetMedicalRecord

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "cross.case.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: 58, height: 58)
                .background(MHBTheme.ColorToken.primary.color.opacity(0.12), in: RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))

            Text(record.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(record.hospitalName) · \(record.occurredAtText)")
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .lineLimit(2)
        }
        .padding(.vertical, MHBTheme.Spacing.s4)
    }
}
