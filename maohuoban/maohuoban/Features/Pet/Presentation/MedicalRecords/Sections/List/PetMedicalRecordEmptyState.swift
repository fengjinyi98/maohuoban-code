import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordEmptyState 病历记录空状态
// 核心职责：
// - 展示当前宠物尚无医院发布病历
// - 明确病历由合作医院诊疗后回流
struct PetMedicalRecordEmptyState: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

            Text("暂无医院病历")
                .font(MHBTheme.Typography.headline.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("合作医院发布的诊断、处方、检查报告和复诊建议会在这里展示。")
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MHBTheme.Spacing.s6)
    }
}
