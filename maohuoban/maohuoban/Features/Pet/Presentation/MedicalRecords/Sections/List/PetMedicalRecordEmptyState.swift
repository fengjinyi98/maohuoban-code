import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordEmptyState 病历记录空状态
// 核心职责：
// - 展示当前宠物尚无病历记录
// - 引导用户通过底部 CTA 新增第一条病历
struct PetMedicalRecordEmptyState: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

            Text("暂无病历记录")
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("就诊、检查、诊断和处方会在这里集中管理。")
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, MHBTheme.Spacing.s8)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
    }
}
