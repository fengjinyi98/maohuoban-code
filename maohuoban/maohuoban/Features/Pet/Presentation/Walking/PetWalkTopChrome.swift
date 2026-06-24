import SwiftUI
import MaohuobanDesignSystem

// PetWalkTopChrome 遛弯页自绘顶部导航控件
// 核心职责：
// - 在系统导航栏位置展示返回、宠物切换和更多入口
// - 避免系统导航栏背景参与地图页渲染
struct PetWalkTopChrome: View {
    let petItem: MHBPetSwitcherItem?
    let petItems: [MHBPetSwitcherItem]
    let isPetSwitcherDisabled: Bool
    let onBack: () -> Void
    let onSelectPet: (String) -> Void
    let onOpenHistory: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
            ZStack {
                HStack {
                    PetWalkBackButton(onBack: onBack)

                    Spacer(minLength: MHBTheme.Spacing.s4)

                    PetWalkMoreMenu(onOpenHistory: onOpenHistory)
                }

                PetWalkPetSwitcherMenu(
                    petItem: petItem,
                    petItems: petItems,
                    isPetSwitcherDisabled: isPetSwitcherDisabled,
                    onSelectPet: onSelectPet
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// PetWalkBackButton 遛弯页返回按钮
// 核心职责：
// - 承载顶部左侧返回动作
// - 保持 Liquid Glass 圆形触控反馈
struct PetWalkBackButton: View {
    let onBack: () -> Void

    var body: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("返回")
        .accessibilityIdentifier("pet.walkTracking.backButton")
    }
}

// PetWalkPetSwitcherMenu 遛弯页宠物切换菜单
// 核心职责：
// - 在顶部居中展示当前宠物
// - 通过原生 Menu 承载宠物切换动作
struct PetWalkPetSwitcherMenu: View {
    let petItem: MHBPetSwitcherItem?
    let petItems: [MHBPetSwitcherItem]
    let isPetSwitcherDisabled: Bool
    let onSelectPet: (String) -> Void

    var body: some View {
        Menu {
            ForEach(petItems) { item in
                Button {
                    guard item.isSelected == false else { return }
                    onSelectPet(item.id)
                } label: {
                    Label(
                        item.name,
                        systemImage: item.isSelected ? "checkmark" : item.species.fallbackSystemImage
                    )
                }
            }
        } label: {
            MHBPetSwitcherCapsule(
                item: petItem,
                isDisabled: isPetSwitcherDisabled
            )
        }
        .disabled(isPetSwitcherDisabled)
        .buttonStyle(.plain)
        .accessibilityIdentifier("pet.walkTracking.petSwitcherButton")
    }
}

// PetWalkMoreMenu 遛弯页更多菜单
// 核心职责：
// - 在顶部右侧展示更多入口
// - 使用原生 Menu 承载后续遛弯相关动作
struct PetWalkMoreMenu: View {
    let onOpenHistory: () -> Void

    var body: some View {
        Menu {
            Button(action: onOpenHistory) {
                Label("遛弯记录", systemImage: "clock.arrow.circlepath")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("更多")
        .accessibilityIdentifier("pet.walkTracking.moreButton")
    }
}
