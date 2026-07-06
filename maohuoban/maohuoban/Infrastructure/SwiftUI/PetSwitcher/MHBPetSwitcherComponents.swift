import SwiftUI
import MaohuobanDesignSystem

// MHBPetSwitcherCapsule 通用宠物切换头像胶囊
// 核心职责：
// - 展示当前宠物头像、名称和菜单箭头
// - 作为业务页面原生 Menu 的统一 label
// - 通过 chrome 参数区分自绘头部和系统 toolbar 的容器职责
struct MHBPetSwitcherCapsule: View {
    let item: MHBPetSwitcherItem?
    let isExpanded: Bool
    let isDisabled: Bool
    let chrome: MHBPetSwitcherCapsuleChrome

    init(
        item: MHBPetSwitcherItem?,
        isExpanded: Bool = false,
        isDisabled: Bool = false,
        chrome: MHBPetSwitcherCapsuleChrome = .glass
    ) {
        self.item = item
        self.isExpanded = isExpanded
        self.isDisabled = isDisabled
        self.chrome = chrome
    }

    var body: some View {
        switch chrome {
        case .glass:
            MHBPetSwitcherCapsuleGlassChrome {
                content
            }
        case .toolbar:
            MHBPetSwitcherCapsulePlainChrome {
                content
            }
        }
    }

    private var content: some View {
        MHBPetSwitcherCapsuleContent(
            item: item,
            isExpanded: isExpanded,
            isDisabled: isDisabled
        )
    }
}

// MHBPetSwitcherCapsuleChrome 宠物切换胶囊外观模式
// 核心职责：
// - 区分组件自带 Liquid Glass 与系统 toolbar 无外壳场景
// - 保持默认业务调用的既有视觉
enum MHBPetSwitcherCapsuleChrome {
    case glass
    case toolbar
}

// MHBPetSwitcherCapsuleContent 宠物切换胶囊内容
// 核心职责：
// - 承载头像、名称和展开箭头
// - 保持不同外观模式下的内容布局一致
private struct MHBPetSwitcherCapsuleContent: View {
    let item: MHBPetSwitcherItem?
    let isExpanded: Bool
    let isDisabled: Bool

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
        .accessibilityLabel("切换宠物，当前宠物 \(item?.name ?? "未选择")")
    }
}

// MHBPetSwitcherCapsuleGlassChrome 宠物切换 Liquid Glass 外壳
// 核心职责：
// - 为自绘头部和自定义导航区域提供组件自带 glass 容器
// - 保持历史调用默认视觉不变
private struct MHBPetSwitcherCapsuleGlassChrome<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .glassEffect(.regular.interactive(), in: .capsule)
    }
}

// MHBPetSwitcherCapsulePlainChrome 宠物切换无外壳容器
// 核心职责：
// - 为系统导航栏 toolbar 提供无 Liquid Glass 的胶囊内容
// - 避免 toolbar 系统容器和组件 glass 容器叠加
private struct MHBPetSwitcherCapsulePlainChrome<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
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
