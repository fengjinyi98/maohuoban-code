import SwiftUI
import MaohuobanDesignSystem

// ProfileUserHomePetFamilySection 用户主页毛孩子卡片
// 核心职责：
// - 展示个人主页关联宠物头像列表
// - 提供健康档案和添加宠物的轻量入口外观
struct ProfileUserHomePetFamilySection: View {
    let pets: [ProfileUserHomePet]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            HStack {
                Text("我的毛孩子")
                    .font(MHBTheme.Typography.callout.weight(.heavy))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Spacer(minLength: MHBTheme.Spacing.s3)

                Button {
                } label: {
                    HStack(spacing: MHBTheme.Spacing.s1) {
                        Text("健康档案")
                            .font(MHBTheme.Typography.caption.weight(.semibold))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                }
                .buttonStyle(.plain)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MHBTheme.Spacing.s4) {
                    ForEach(pets) { pet in
                        ProfileUserHomePetAvatarItem(pet: pet)
                    }

                    ProfileUserHomeAddPetItem()
                }
                .padding(.bottom, MHBTheme.Spacing.s1)
            }
        }
        .padding(MHBTheme.Spacing.s5)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 1)
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.bottom, MHBTheme.Spacing.s5)
    }
}

// ProfileUserHomePetAvatarItem 用户主页宠物头像项
// 核心职责：
// - 展示单只宠物头像和名称
// - 为横向宠物列表保持固定尺寸
private struct ProfileUserHomePetAvatarItem: View {
    let pet: ProfileUserHomePet

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s2) {
            Image(pet.avatarAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 56, height: 56)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(MHBTheme.ColorToken.separatorSoft.color, lineWidth: 1)
                }

            Text(pet.name)
                .font(MHBTheme.Typography.caption.weight(.bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)
                .frame(width: 64)
        }
        .accessibilityElement(children: .combine)
    }
}

// ProfileUserHomeAddPetItem 用户主页添加宠物项
// 核心职责：
// - 展示添加宠物的占位入口
// - 与已有宠物头像保持相同排布节奏
private struct ProfileUserHomeAddPetItem: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s2) {
            Image(systemName: "plus")
                .font(.system(size: MHBTheme.IconSize.medium, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .frame(width: 56, height: 56)
                .background(MHBTheme.ColorToken.separatorSoft.color.opacity(0.35), in: Circle())
                .overlay {
                    Circle()
                        .stroke(
                            MHBTheme.ColorToken.labelQuaternary.color,
                            style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                        )
                }

            Text("添加")
                .font(MHBTheme.Typography.caption.weight(.bold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .lineLimit(1)
                .frame(width: 64)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("添加宠物")
    }
}
