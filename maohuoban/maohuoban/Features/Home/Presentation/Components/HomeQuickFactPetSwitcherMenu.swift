import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactPetSwitcherMenu 快捷事实宠物切换菜单
// 核心职责：
// - 复用通用宠物头像胶囊展示当前宠物
// - 在多宠场景使用系统 Menu 完成宠物切换
struct HomeQuickFactPetSwitcherMenu: View {
    let selectedItem: MHBPetSwitcherItem?
    let items: [MHBPetSwitcherItem]
    let isDisabled: Bool
    let onSelectPet: (String) -> Void

    var body: some View {
        if isDisabled {
            MHBPetSwitcherCapsule(item: selectedItem)
                .accessibilityIdentifier("home.quickFact.petSwitcherButton")
        } else {
            Menu {
                ForEach(items) { item in
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
                MHBPetSwitcherCapsule(item: selectedItem)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.quickFact.petSwitcherButton")
        }
    }
}
