import SwiftUI
import MaohuobanDesignSystem

// HomePetSwitcherSection 首页宠物切换器
// 核心职责：
// - 展示当前用户的宠物头像索引
// - 将多宠选择事件转发给首页 Store 刷新
struct HomePetSwitcherSection: View {
    let items: [HomeDashboardSnapshot.PetSwitchItem]
    let onSelectPet: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                ForEach(items) { item in
                    Button {
                        guard !item.isSelected else { return }
                        onSelectPet(item.id)
                    } label: {
                        HomePetSwitchItemView(item: item)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.petSwitcher.pet.\(item.id)")
                }
            }
            .padding(.vertical, MHBTheme.Spacing.s1)
        }
        .accessibilityIdentifier("home.petSwitcher")
    }
}

// HomePetSwitchItemView 宠物切换项
// 核心职责：
// - 展示单只宠物的图标、名称和选中态
// - 保持按钮行为和展示样式解耦
private struct HomePetSwitchItemView: View {
    let item: HomeDashboardSnapshot.PetSwitchItem

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s1) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(
                        item.isSelected
                            ? MHBTheme.ColorToken.primaryBackground.color
                            : MHBTheme.ColorToken.cardSolid.color
                    )
                    .frame(width: MHBTheme.IconSize.avatar, height: MHBTheme.IconSize.avatar)
                    .overlay {
                        Circle()
                            .stroke(
                                item.isSelected
                                    ? MHBTheme.ColorToken.primary.color
                                    : MHBTheme.ColorToken.separator.color,
                                lineWidth: item.isSelected ? 2 : 1
                            )
                    }

                Image(systemName: iconName)
                    .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                    .foregroundStyle(
                        item.isSelected
                            ? MHBTheme.ColorToken.primary.color
                            : MHBTheme.ColorToken.labelSecondary.color
                    )

                if item.isSelected {
                    Circle()
                        .fill(MHBTheme.ColorToken.primary.color)
                        .frame(width: MHBTheme.Spacing.s2, height: MHBTheme.Spacing.s2)
                }
            }

            Text(item.name)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(
                    item.isSelected
                        ? MHBTheme.ColorToken.labelPrimary.color
                        : MHBTheme.ColorToken.labelSecondary.color
                )
                .lineLimit(1)
                .frame(width: MHBTheme.IconSize.avatar)
        }
        .accessibilityLabel("\(item.name)\(item.isSelected ? "，当前宠物" : "")")
    }

    private var iconName: String {
        switch item.species {
        case .dog: "pawprint.fill"
        case .cat: "cat.fill"
        case .other: "heart.fill"
        }
    }
}
