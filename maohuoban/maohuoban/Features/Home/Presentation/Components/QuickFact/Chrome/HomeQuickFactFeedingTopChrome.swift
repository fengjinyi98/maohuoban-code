import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactFeedingTopChrome 喂食弹层顶部控件
// 核心职责：
// - 在弹层顶部展示喂食标题
// - 将宠物切换固定在右上角而不是进入内容流
struct HomeQuickFactFeedingTopChrome: View {
    let selectedItem: MHBPetSwitcherItem?
    let items: [MHBPetSwitcherItem]
    let isDisabled: Bool
    let onSelectPet: (String) -> Void

    var body: some View {
        ZStack {
            Text("喂食")
                .font(MHBTheme.Typography.headline.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(maxWidth: .infinity)

            HStack {
                Spacer()

                HomeQuickFactPetSwitcherMenu(
                    selectedItem: selectedItem,
                    items: items,
                    isDisabled: isDisabled,
                    onSelectPet: onSelectPet
                )
            }
        }
        .frame(height: 48)
    }
}
