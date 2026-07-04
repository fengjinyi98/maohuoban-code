import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareRecordDetailHeader 疫苗驱虫详情头部
// 核心职责：
// - 展示记录名称、类型图标和宠物身份
// - 让用户快速确认当前记录归属与完成时间
struct PetPreventiveCareRecordDetailHeader: View {
    let presentation: PetPreventiveCareRecordDetailPresentation

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: presentation.kind.systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(presentation.kind.tint)
                .frame(width: 56, height: 56)
                .background(presentation.kind.tint.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text(presentation.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)

                HStack(spacing: MHBTheme.Spacing.s2) {
                    MHBAvatar(
                        subject: .pet(presentation.pet.avatarPet),
                        size: .custom(24),
                        shape: .circle
                    )

                    Text("\(presentation.pet.name) · \(presentation.completedAtText)")
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: MHBTheme.Spacing.s2)
        }
        .padding(.vertical, MHBTheme.Spacing.s4)
    }
}
