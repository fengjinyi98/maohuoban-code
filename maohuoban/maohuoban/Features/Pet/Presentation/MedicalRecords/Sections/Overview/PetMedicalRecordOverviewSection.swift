import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordOverviewSection 病历记录概览区
// 核心职责：
// - 展示当前宠物医院病历数量和模块边界
// - 强化病历记录由合作医院发布回流
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
                    Text("医院病历")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                    Text("\(recordCount) 条医院发布记录")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                }

                Spacer(minLength: MHBTheme.Spacing.s2)
            }

            Text("这里展示合作医院发布回流的诊断、处方、检查报告和复诊建议。")
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
