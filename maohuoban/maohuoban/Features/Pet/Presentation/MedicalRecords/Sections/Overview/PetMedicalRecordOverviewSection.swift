import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordOverviewSection 病历记录概览区
// 核心职责：
// - 展示当前宠物病历数量和模块边界
// - 强化病历记录只承载就诊、诊断和处置内容
struct PetMedicalRecordOverviewSection: View {
    let recordCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .frame(width: 48, height: 48)
                    .background(MHBTheme.ColorToken.primary.color.opacity(0.12), in: RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text("病历记录")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Text("\(recordCount) 条就诊、诊断或处置记录")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                }

                Spacer(minLength: MHBTheme.Spacing.s2)
            }

            Text("疫苗和驱虫已经归入独立模块；这里仅记录就诊、检查、诊断、处方和复诊过程。")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(MHBTheme.Spacing.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.03), radius: 16, y: 4)
    }
}
