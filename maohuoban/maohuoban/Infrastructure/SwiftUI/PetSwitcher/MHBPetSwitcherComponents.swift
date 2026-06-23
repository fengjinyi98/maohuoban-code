import SwiftUI
import MaohuobanDesignSystem

// MHBPetSwitcherCapsule 通用宠物切换头像胶囊
// 核心职责：
// - 展示当前宠物头像、名称和菜单箭头
// - 作为业务页面原生 Menu 的统一 label
struct MHBPetSwitcherCapsule: View {
    let item: MHBPetSwitcherItem?
    let isExpanded: Bool
    let isDisabled: Bool

    init(
        item: MHBPetSwitcherItem?,
        isExpanded: Bool = false,
        isDisabled: Bool = false
    ) {
        self.item = item
        self.isExpanded = isExpanded
        self.isDisabled = isDisabled
    }

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            MHBPetSwitcherAvatar(item: item, size: 32)

            Text(item?.name ?? "选择宠物")
                .font(MHBTheme.Typography.callout.weight(.bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)
                .truncationMode(.tail)

            MHBAnimatedDisclosureChevron(
                isExpanded: isExpanded,
                size: 12,
                weight: .bold,
                color: MHBTheme.ColorToken.labelTertiary.color,
                systemImage: "chevron.down",
                expandedRotation: 180
            )
        }
        .padding(.leading, MHBTheme.Spacing.s2)
        .padding(.trailing, MHBTheme.Spacing.s3)
        .frame(height: 44)
        .frame(maxWidth: 148)
        .contentShape(Capsule())
        .opacity(isDisabled ? 0.52 : 1)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel("切换宠物，当前宠物 \(item?.name ?? "未选择")")
    }
}

// MHBPetSwitcherAvatar 宠物切换头像
// 核心职责：
// - 优先展示宠物头像图片
// - 按性别显示头像边框色并提供缺省图标
private struct MHBPetSwitcherAvatar: View {
    let item: MHBPetSwitcherItem?
    let size: CGFloat

    var body: some View {
        MHBAvatar(
            subject: item?.avatarSubject ?? fallbackSubject,
            size: .custom(size),
            shape: .circle
        )
    }

    private var fallbackSubject: MHBAvatarSubject {
        .pet(
            MHBAvatarPet(
                id: "pet-switcher-empty",
                name: "选择宠物",
                source: .empty,
                species: .other,
                sex: .unknown
            )
        )
    }
}
