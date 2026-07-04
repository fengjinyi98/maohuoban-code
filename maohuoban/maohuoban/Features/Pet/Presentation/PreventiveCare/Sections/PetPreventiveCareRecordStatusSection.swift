import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareRecordStatusSection 疫苗驱虫提醒状态区
// 核心职责：
// - 突出展示记录状态和下次提醒日期
// - 解释当前记录对首页疫苗驱虫提醒的影响
struct PetPreventiveCareRecordStatusSection: View {
    let presentation: PetPreventiveCareRecordDetailPresentation

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
            Image(systemName: presentation.statusSystemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(presentation.statusTint)
                .frame(width: 36, height: 36)
                .background(presentation.statusTint.opacity(0.12), in: RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(presentation.statusTitle)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(presentation.statusDescription)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: MHBTheme.Spacing.s2)
        }
        .padding(MHBTheme.Spacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.02), radius: 10, y: 3)
    }
}
