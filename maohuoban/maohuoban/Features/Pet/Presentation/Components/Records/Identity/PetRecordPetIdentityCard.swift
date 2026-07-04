import SwiftUI
import MaohuobanDesignSystem

// PetRecordPetIdentityCard 记录页宠物身份卡
// 核心职责：
// - 为日常、病历等记录流程统一展示当前宠物上下文
// - 根据宠物性别提供稳定的边框识别色
struct PetRecordPetIdentityCard: View {
    let petID: String?
    let petSex: PetRecordPetSex
    let description: LocalizedStringResource

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: petID == nil ? "pawprint.circle" : "pawprint.fill")
                .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.success.color)
                .frame(width: 44, height: 44)
                .background(MHBTheme.ColorToken.success.color.opacity(0.12), in: .rect(cornerRadius: MHBTheme.Radius.large))

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(petID == nil ? "未选择宠物" : "当前宠物")
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                Text(petID == nil ? "请先创建或选择一只宠物" : description)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }

            Spacer(minLength: MHBTheme.Spacing.s2)

            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(width: 32, height: 32)
                .background(MHBTheme.ColorToken.cardSolid.color, in: Circle())
                .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.background.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                .stroke(petSex.borderColor, lineWidth: 1)
        }
    }
}
