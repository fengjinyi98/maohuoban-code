import SwiftUI
import MaohuobanDesignSystem

// PetManagementAddPetRow 添加宠物入口行
// 核心职责：
// - 在宠物列表末尾展示添加新宠物入口
// - 将点击事件转发给所属 Tab 导航路径
struct PetManagementAddPetRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Image(systemName: "plus")
                    .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .frame(width: 48, height: 48)
                    .background(MHBTheme.ColorToken.labelQuaternary.color.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))

                Text("添加新宠物")
                    .font(MHBTheme.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Spacer(minLength: MHBTheme.Spacing.s2)
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(MHBTheme.ColorToken.cardSolid.color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("添加新宠物")
        .accessibilityIdentifier("pet.management.addPetRow")
    }
}
